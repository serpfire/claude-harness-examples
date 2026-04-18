#!/bin/bash
#
# Database Query Guard - PreToolUse Hook for Claude Code
#
# Automatically estimates BigQuery costs before execution and warns about
# dangerous database operations.
#
# Features:
# - Runs --dry_run automatically to get actual bytes scanned
# - Calculates and displays cost estimate ($5/TB)
# - User decides whether to proceed (ask, not block)
# - Warns about dangerous SQL operations (DELETE without WHERE, etc.)
#

# =============================================================================
# DEBUG LOGGING - Set to true to enable, false to disable
# =============================================================================
DEBUG=false
DEBUG_LOG="/tmp/db-query-guard-debug.log"

log_debug() {
    if [ "$DEBUG" = true ]; then
        echo "$1" >> "$DEBUG_LOG"
    fi
}

log_debug "=== Hook invoked at $(date -u +"%Y-%m-%dT%H:%M:%SZ") ==="

# Read JSON input from stdin
INPUT=$(cat)
log_debug "RAW INPUT: $INPUT"

# Extract the command from JSON input using Python (handles escaping correctly)
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'tool_input' in data and 'command' in data['tool_input']:
        print(data['tool_input']['command'])
    elif 'command' in data:
        print(data['command'])
except:
    pass
" 2>/dev/null)

# If Python fails, try grep/sed fallback
if [ -z "$COMMAND" ]; then
    COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"command"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' | head -1)
fi

# If no command found, allow silently
if [ -z "$COMMAND" ]; then
    log_debug "NO COMMAND EXTRACTED - allowing"
    exit 0
fi

# Check for bypass flag (used after Claude reviews and user approves)
if echo "$COMMAND" | grep -qE '^REVIEWED_AND_APPROVED=1\s'; then
    log_debug "REVIEWED_AND_APPROVED flag set - allowing"
    exit 0
fi

log_debug "EXTRACTED COMMAND: $COMMAND"

# =============================================================================
# Helper: Format bytes to human readable
# =============================================================================
format_bytes() {
    local bytes=$1
    if [ "$bytes" -ge 1099511627776 ]; then
        echo "$(echo "scale=2; $bytes / 1099511627776" | bc) TB"
    elif [ "$bytes" -ge 1073741824 ]; then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc) GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(echo "scale=2; $bytes / 1048576" | bc) MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$(echo "scale=2; $bytes / 1024" | bc) KB"
    else
        echo "$bytes bytes"
    fi
}

# =============================================================================
# Helper: Calculate cost from bytes ($5 per TB)
# =============================================================================
calculate_cost() {
    local bytes=$1
    # $5 per TB = $0.000000000005 per byte
    # Using bc for floating point math
    echo "scale=4; $bytes * 5 / 1099511627776" | bc | sed 's/^\./0./'
}

# =============================================================================
# Helper: Output JSON response
# =============================================================================
output_response() {
    local decision="$1"
    local reason="$2"

    # Escape double quotes for valid JSON
    local escaped_reason=$(echo "$reason" | sed 's/"/\\"/g')

    log_debug "DECISION: $decision"
    log_debug "REASON: $escaped_reason"

    # Build JSON output
    local json_output="{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"$decision\",
    \"permissionDecisionReason\": \"$escaped_reason\"
  }
}"

    log_debug "STDOUT OUTPUT:"
    log_debug "$json_output"
    log_debug "END STDOUT OUTPUT"

    # Write to stdout for Claude Code
    echo "$json_output"
}

# =============================================================================
# BigQuery Cost Estimation
# =============================================================================
if echo "$COMMAND" | grep -qE '\bbq\s+query\b'; then
    log_debug "Detected bq query command"

    # Skip if already has --dry_run (user is being careful)
    if echo "$COMMAND" | grep -q '\-\-dry_run'; then
        log_debug "Command already has --dry_run - allowing"
        exit 0
    fi

    # Insert --dry_run after "bq query"
    DRY_RUN_CMD=$(echo "$COMMAND" | sed 's/bq query/bq query --dry_run/')

    log_debug "Running dry run: $DRY_RUN_CMD"

    # Run the dry run to get byte estimate
    DRY_RUN_OUTPUT=$(eval "$DRY_RUN_CMD" 2>&1)
    DRY_RUN_EXIT=$?

    log_debug "Dry run output: $DRY_RUN_OUTPUT"
    log_debug "Dry run exit code: $DRY_RUN_EXIT"

    # Check if dry run succeeded
    if [ $DRY_RUN_EXIT -ne 0 ]; then
        # Dry run failed - could be syntax error, auth issue, etc.
        # Pass through the error so user sees it
        ERROR_MSG=$(echo "$DRY_RUN_OUTPUT" | head -3 | tr '\n' ' ')
        output_response "ask" "⚠️ Query validation failed: $ERROR_MSG"
        exit 0
    fi

    # Parse bytes from output: "...will process X bytes of data"
    BYTES=$(echo "$DRY_RUN_OUTPUT" | grep -oE '[0-9]+ bytes' | grep -oE '[0-9]+')

    if [ -z "$BYTES" ]; then
        # Couldn't parse bytes - allow with warning
        output_response "ask" "⚠️ Could not estimate query cost. Proceed with caution."
        exit 0
    fi

    log_debug "Bytes to scan: $BYTES"

    # Calculate cost
    HUMAN_SIZE=$(format_bytes "$BYTES")
    COST=$(calculate_cost "$BYTES")

    log_debug "Human size: $HUMAN_SIZE, Cost: \$$COST"

    # Threshold: $0.10 = ~20GB
    # Queries under this threshold are auto-allowed
    # Queries over this threshold require explicit approval
    COST_THRESHOLD_BYTES=21990232555  # ~20GB = $0.10

    if [ "$BYTES" -lt "$COST_THRESHOLD_BYTES" ]; then
        # Under $0.10 - auto-allow (cheap query)
        log_debug "Cheap query (<\$0.10) - auto-allowing"
        exit 0
    fi

    # Expensive query - determine severity and block
    if [ "$BYTES" -lt 100000000000 ]; then
        # Less than 100GB (<$0.50)
        ICON="💰"
        LEVEL="Cost warning"
    elif [ "$BYTES" -lt 500000000000 ]; then
        # Less than 500GB (<$2.50)
        ICON="💰💰"
        LEVEL="Significant cost"
    elif [ "$BYTES" -lt 1099511627776 ]; then
        # Less than 1TB (<$5)
        ICON="💰💰💰"
        LEVEL="High cost"
    else
        # 1TB+ ($5+)
        ICON="🚨"
        LEVEL="EXPENSIVE"
    fi

    # Build the message
    MSG="$ICON $LEVEL: This query will scan $HUMAN_SIZE (~\$$COST). Tell me to proceed if you approve."

    # Use "deny" to show the message - user must explicitly approve
    output_response "deny" "$MSG"
    exit 0
fi

# =============================================================================
# Other Database Warnings (non-BigQuery)
# =============================================================================
WARNINGS=""

add_warning() {
    local level="$1"
    local msg="$2"
    if [ -z "$WARNINGS" ]; then
        WARNINGS="[$level] $msg"
    else
        WARNINGS="$WARNINGS | [$level] $msg"
    fi
}

# PostgreSQL
if echo "$COMMAND" | grep -qE '\bpsql\b'; then
    if echo "$COMMAND" | grep -qiE '(DELETE|UPDATE)\s+' && ! echo "$COMMAND" | grep -qiE '\bWHERE\b'; then
        add_warning "DANGER" "DELETE/UPDATE without WHERE clause"
    fi
    if echo "$COMMAND" | grep -qiE '\bDROP\s+(TABLE|DATABASE|INDEX|SCHEMA)'; then
        add_warning "DANGER" "DROP command - destructive operation"
    fi
    if echo "$COMMAND" | grep -qiE '\bTRUNCATE\b'; then
        add_warning "DANGER" "TRUNCATE deletes ALL data"
    fi
    # Read operation warnings
    if echo "$COMMAND" | grep -qiE 'SELECT\s+\*' && ! echo "$COMMAND" | grep -qiE '\bLIMIT\b'; then
        add_warning "COST" "SELECT * without LIMIT - could return massive dataset"
    fi
fi

# MySQL
if echo "$COMMAND" | grep -qE '\bmysql\b'; then
    if echo "$COMMAND" | grep -qiE '(DELETE|UPDATE)\s+' && ! echo "$COMMAND" | grep -qiE '\bWHERE\b'; then
        add_warning "DANGER" "DELETE/UPDATE without WHERE clause"
    fi
    if echo "$COMMAND" | grep -qiE '\bDROP\s+(TABLE|DATABASE)'; then
        add_warning "DANGER" "DROP command - destructive"
    fi
    # Read operation warnings
    if echo "$COMMAND" | grep -qiE 'SELECT\s+\*' && ! echo "$COMMAND" | grep -qiE '\bLIMIT\b'; then
        add_warning "COST" "SELECT * without LIMIT - could return massive dataset"
    fi
fi

# MongoDB
if echo "$COMMAND" | grep -qE '\b(mongosh|mongo)\b'; then
    if echo "$COMMAND" | grep -qE 'deleteMany\(\s*\{\s*\}\s*\)'; then
        add_warning "DANGER" "deleteMany({}) deletes ALL documents"
    fi
    if echo "$COMMAND" | grep -qE '\.drop\(\)'; then
        add_warning "DANGER" "drop() deletes entire collection"
    fi
    # Read operation warnings
    if echo "$COMMAND" | grep -qE '\.find\(\s*\{\s*\}\s*\)' && ! echo "$COMMAND" | grep -qE '\.limit\('; then
        add_warning "COST" "find({}) without limit - returns ALL documents"
    fi
    if echo "$COMMAND" | grep -qE '\.find\(\)' && ! echo "$COMMAND" | grep -qE '\.limit\('; then
        add_warning "COST" "find() without limit - returns ALL documents"
    fi
fi

# Firebase/Firestore
if echo "$COMMAND" | grep -qE '\b(firebase|gcloud)\b.*firestore'; then
    if echo "$COMMAND" | grep -qE 'delete|--recursive'; then
        add_warning "DANGER" "Firestore delete operation"
    fi
    # Read operation warnings - Firestore charges per document read
    if echo "$COMMAND" | grep -qE 'export'; then
        add_warning "COST" "Firestore export - charges per document read"
    fi
fi

# Supabase
if echo "$COMMAND" | grep -qE '\bsupabase\s+db\b'; then
    if echo "$COMMAND" | grep -qE '\breset\b'; then
        add_warning "DANGER" "db reset DROPS and recreates database"
    fi
fi

# AWS DynamoDB
if echo "$COMMAND" | grep -qE '\baws\s+dynamodb\b'; then
    if echo "$COMMAND" | grep -qE '\bscan\b'; then
        add_warning "COST" "DynamoDB SCAN reads entire table"
    fi
    if echo "$COMMAND" | grep -qE '\bdelete-table\b'; then
        add_warning "DANGER" "delete-table is destructive"
    fi
fi

# Redis
if echo "$COMMAND" | grep -qE '\bredis-cli\b'; then
    if echo "$COMMAND" | grep -qiE '\bFLUSH(ALL|DB)\b'; then
        add_warning "DANGER" "FLUSH deletes all Redis data"
    fi
fi

# SQLite
if echo "$COMMAND" | grep -qE '\bsqlite3?\b'; then
    if echo "$COMMAND" | grep -qiE '\bDROP\s+(TABLE|DATABASE)\b'; then
        add_warning "DANGER" "DROP command - destructive"
    fi
    if echo "$COMMAND" | grep -qiE '(DELETE|UPDATE)\s+' && ! echo "$COMMAND" | grep -qiE '\bWHERE\b'; then
        add_warning "DANGER" "DELETE/UPDATE without WHERE clause"
    fi
    # Read operation warnings
    if echo "$COMMAND" | grep -qiE 'SELECT\s+\*' && ! echo "$COMMAND" | grep -qiE '\bLIMIT\b'; then
        add_warning "COST" "SELECT * without LIMIT - could return massive dataset"
    fi
fi

# Cassandra (cqlsh)
if echo "$COMMAND" | grep -qE '\bcqlsh\b'; then
    if echo "$COMMAND" | grep -qiE '\bTRUNCATE\b'; then
        add_warning "DANGER" "TRUNCATE deletes all data"
    fi
    if echo "$COMMAND" | grep -qiE '\bDROP\s+(TABLE|KEYSPACE)\b'; then
        add_warning "DANGER" "DROP command - destructive"
    fi
fi

# ClickHouse
if echo "$COMMAND" | grep -qE '\bclickhouse-client\b'; then
    if echo "$COMMAND" | grep -qiE '\bDROP\s+(TABLE|DATABASE)\b'; then
        add_warning "DANGER" "DROP command - destructive"
    fi
    if echo "$COMMAND" | grep -qiE '\bTRUNCATE\b'; then
        add_warning "DANGER" "TRUNCATE deletes all data"
    fi
    # Read operation warnings - ClickHouse often has billions of rows
    if echo "$COMMAND" | grep -qiE 'SELECT\s+\*' && ! echo "$COMMAND" | grep -qiE '\bLIMIT\b'; then
        add_warning "COST" "SELECT * without LIMIT on ClickHouse - could scan billions of rows"
    fi
fi

# Snowflake (snowsql)
if echo "$COMMAND" | grep -qE '\bsnowsql\b'; then
    if echo "$COMMAND" | grep -qiE '\bDROP\s+(TABLE|DATABASE|SCHEMA)\b'; then
        add_warning "DANGER" "Snowflake DROP command - destructive"
    fi
    if echo "$COMMAND" | grep -qiE '(DELETE|UPDATE)\s+' && ! echo "$COMMAND" | grep -qiE '\bWHERE\b'; then
        add_warning "DANGER" "DELETE/UPDATE without WHERE clause"
    fi
fi

# CockroachDB
if echo "$COMMAND" | grep -qE '\bcockroach\s+sql\b'; then
    if echo "$COMMAND" | grep -qiE '\bDROP\s+(TABLE|DATABASE)\b'; then
        add_warning "DANGER" "DROP command - destructive"
    fi
fi

# Azure Cosmos DB
if echo "$COMMAND" | grep -qE '\baz\s+cosmosdb\b'; then
    if echo "$COMMAND" | grep -qE '\bdelete\b'; then
        add_warning "DANGER" "Cosmos DB delete operation"
    fi
fi

# Google Cloud SQL
if echo "$COMMAND" | grep -qE '\bgcloud\s+sql\b'; then
    if echo "$COMMAND" | grep -qE '\bdelete\b'; then
        add_warning "DANGER" "Cloud SQL delete operation"
    fi
fi

# =============================================================================
# Script Execution Guard (multiple languages)
# Scripts can contain hidden database operations - require approval
# =============================================================================
# Supported: node, python, ts-node, ruby, php, perl, go run, deno, bun, bash/sh scripts
if echo "$COMMAND" | grep -qE '\b(node|python3?|ts-node|ruby|php|perl|deno|bun)\b' || \
   echo "$COMMAND" | grep -qE '\bgo\s+run\b' || \
   echo "$COMMAND" | grep -qE '\b(bash|sh|zsh)\s+[^ ]+\.(sh|bash)\b'; then
    # Skip safe patterns
    SAFE_SCRIPT=false

    # npm/npx/yarn/pnpm run commands (package.json scripts are reviewed)
    if echo "$COMMAND" | grep -qE '\b(npm|yarn|pnpm)\s+(run|test|start|build|dev|lint|format)\b'; then
        SAFE_SCRIPT=true
    fi

    # npx/bunx with known safe tools
    if echo "$COMMAND" | grep -qE '\b(npx|bunx)\s+(prettier|eslint|jest|vitest|playwright|tsc|webpack|vite|next|turbo|tsx)\b'; then
        SAFE_SCRIPT=true
    fi

    # Python package managers and tools
    if echo "$COMMAND" | grep -qE '\b(pip|pip3|conda|poetry|uv|pipx)\b'; then
        SAFE_SCRIPT=true
    fi

    # Python test runners and dev tools
    if echo "$COMMAND" | grep -qE '\b(pytest|python3?\s+-m\s+(pytest|unittest|doctest))\b'; then
        SAFE_SCRIPT=true
    fi
    if echo "$COMMAND" | grep -qE '\b(ruff|mypy|pyright|black|isort|flake8|pylint|bandit|coverage)\b'; then
        SAFE_SCRIPT=true
    fi

    # Python running test files (test_*.py or *_test.py)
    if echo "$COMMAND" | grep -qE '\bpython3?\s+.*test[_s].*\.py\b'; then
        SAFE_SCRIPT=true
    fi
    if echo "$COMMAND" | grep -qE '\bpython3?\s+.*run_all\.py\b'; then
        SAFE_SCRIPT=true
    fi

    # node_modules paths (installed packages)
    if echo "$COMMAND" | grep -qE 'node_modules/'; then
        SAFE_SCRIPT=true
    fi

    # Simple one-liners (node -e, python -c, ruby -e, perl -e)
    if echo "$COMMAND" | grep -qE '\bnode\s+-e\b|\bpython3?\s+-c\b|\bruby\s+-e\b|\bperl\s+-e\b'; then
        SAFE_SCRIPT=true
    fi

    # Version/help checks
    if echo "$COMMAND" | grep -qE '\b(node|python3?|ruby|go|deno|bun)\s+(-[-]?version|-[-]?help|-V)\b'; then
        SAFE_SCRIPT=true
    fi

    # Build tools and task runners
    if echo "$COMMAND" | grep -qE '\b(make|gradle|mvn|cargo|dotnet)\s'; then
        SAFE_SCRIPT=true
    fi

    # Go test/vet/build
    if echo "$COMMAND" | grep -qE '\bgo\s+(test|vet|build|generate)\b'; then
        SAFE_SCRIPT=true
    fi

    if [ "$SAFE_SCRIPT" = false ]; then
        # Extract script path for review instruction
        SCRIPT_PATH=$(echo "$COMMAND" | grep -oE '[^ ]+\.(js|ts|mjs|py)' | head -1)

        # Check for high-risk script names
        if echo "$COMMAND" | grep -qiE '(backfill|migrate|seed|etl|pipeline|bigquery|bq_)'; then
            # High risk - likely database/ETL operation
            output_response "ask" "💰 Possible database/ETL script detected ($SCRIPT_PATH). Review for costly operations before running."
            exit 0
        fi

        # Check for production indicators
        if echo "$COMMAND" | grep -qiE '(\-\-prod|\-\-production|NODE_ENV=prod|=production\b|--live)'; then
            output_response "ask" "🚨 Production flag detected. Verify $SCRIPT_PATH is safe for production before running."
            exit 0
        fi
    fi
fi

# Output warnings if any
if [ -n "$WARNINGS" ]; then
    # Determine icon based on severity
    if echo "$WARNINGS" | grep -q '\[DANGER\]'; then
        ICON="🚨"
    else
        ICON="⚠️"
    fi

    output_response "ask" "$ICON $WARNINGS"
    exit 0
fi

# No issues detected - allow silently
log_debug "No issues detected - allowing"
exit 0
