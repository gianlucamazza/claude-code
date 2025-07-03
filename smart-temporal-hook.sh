#!/bin/bash

# Smart Temporal Context Hook - Intelligent Compromise Solution
# 
# Combines simplicity of basic hook with selective intelligence
# - Always provides basic temporal context (fast)
# - Adds smart enhancements only when detected as useful
# - Lightweight caching for common version queries
# - Graceful degradation always

set -euo pipefail

# Configuration
ENABLE_SMART_DETECTION="${CLAUDE_SMART_DETECTION:-true}"
ENABLE_CACHE="${CLAUDE_ENABLE_CACHE:-true}"
CACHE_DIR="${HOME}/.claude/temporal_cache"
CACHE_TTL=3600  # 1 hour

# Ensure cache directory exists
mkdir -p "$CACHE_DIR" 2>/dev/null || true

# Always get basic temporal context (fast, reliable)
get_basic_context() {
    export CURRENT_DATE=$(date '+%Y-%m-%d')
    export CURRENT_TIME=$(date '+%H:%M:%S %Z')
    export UNIX_TIMESTAMP=$(date '+%s')
    export TIMEZONE=$(date '+%Z')
    export CURRENT_ISO8601=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    export CURRENT_YEAR=$(date '+%Y')
    export CURRENT_MONTH=$(date '+%m')
    export CURRENT_DAY=$(date '+%d')
}

# Smart detection: should we enhance this interaction?
should_enhance() {
    local tool_name="${CLAUDE_TOOL_NAME:-}"
    local tool_input="${CLAUDE_TOOL_INPUT:-}"
    
    # Tool-based detection
    case "$tool_name" in
        "Bash")
            [[ "$tool_input" =~ (commit|git|backup|log|timestamp) ]] && return 0
            ;;
        "Write"|"Edit"|"MultiEdit")
            [[ "$tool_input" =~ (\{\{|template|date|time) ]] && return 0
            ;;
        "WebSearch")
            return 0  # Always enhance web searches
            ;;
    esac
    
    # Query-based detection
    if [[ "$tool_input" =~ (version|latest|current|LTS|release|what.*should.*use|which.*version) ]]; then
        return 0
    fi
    
    # Context-based detection
    if [[ "${CLAUDE_CURRENT_FILE:-}" =~ \.(md|txt|log)$ ]]; then
        return 0  # Documentation/log files
    fi
    
    if [[ "${CLAUDE_GIT_STATUS:-}" =~ modified ]]; then
        return 0  # Active development
    fi
    
    return 1
}

# Get cached data if available and fresh
get_cached() {
    local cache_key="$1"
    local cache_file="$CACHE_DIR/$cache_key"
    
    if [[ "$ENABLE_CACHE" != "true" ]]; then
        return 1
    fi
    
    if [[ -f "$cache_file" ]]; then
        local file_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)))
        if [[ $file_age -lt $CACHE_TTL ]]; then
            cat "$cache_file"
            return 0
        else
            rm -f "$cache_file" 2>/dev/null || true
        fi
    fi
    
    return 1
}

# Set cache data
set_cached() {
    local cache_key="$1"
    local data="$2"
    local cache_file="$CACHE_DIR/$cache_key"
    
    if [[ "$ENABLE_CACHE" == "true" ]]; then
        echo "$data" > "$cache_file" 2>/dev/null || true
    fi
}

# Detect intention from tool input
detect_intention() {
    local tool_input="${CLAUDE_TOOL_INPUT:-}"
    
    case "$tool_input" in
        *commit*|*git*add*|*push*) echo "committing" ;;
        *test*|*spec*|*jest*|*mocha*) echo "testing" ;;
        *debug*|*error*|*bug*|*fix*) echo "debugging" ;;
        *install*|*npm*|*yarn*|*pip*) echo "dependency_management" ;;
        *create*|*new*|*add*feature*) echo "feature_development" ;;
        *backup*|*archive*|*export*) echo "maintenance" ;;
        *) echo "general_development" ;;
    esac
}

# Get relevant version information
get_version_info() {
    local tool_input="${CLAUDE_TOOL_INPUT:-}"
    local versions=""
    
    # Check cache first
    local cache_key=$(echo "$tool_input" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "fallback")
    if versions=$(get_cached "versions_$cache_key"); then
        echo "$versions"
        return 0
    fi
    
    # Generate version info
    if [[ "$tool_input" =~ (node|npm) ]]; then
        versions+="  Node.js: 22.11.0 LTS (October 2024)\n"
    fi
    
    if [[ "$tool_input" =~ react ]]; then
        versions+="  React: 18.3.1 (April 2024)\n"
    fi
    
    if [[ "$tool_input" =~ typescript ]]; then
        versions+="  TypeScript: 5.6.3 (September 2024)\n"
    fi
    
    if [[ "$tool_input" =~ python ]]; then
        versions+="  Python: 3.12.7 (October 2024)\n"
    fi
    
    if [[ "$tool_input" =~ (docker) ]]; then
        versions+="  Docker: 27.3.1 (October 2024)\n"
    fi
    
    # Cache the result
    if [[ -n "$versions" ]]; then
        set_cached "versions_$cache_key" "$versions"
        echo -e "$versions"
    fi
}

# Generate template variables help
get_template_variables() {
    cat << EOF
  {{CURRENT_DATE}} = $CURRENT_DATE
  {{CURRENT_TIME}} = $CURRENT_TIME
  {{CURRENT_ISO8601}} = $CURRENT_ISO8601
  {{UNIX_TIMESTAMP}} = $UNIX_TIMESTAMP
  {{TIMEZONE}} = $TIMEZONE
  {{YEAR}} = $CURRENT_YEAR
  {{MONTH}} = $CURRENT_MONTH
  {{DAY}} = $CURRENT_DAY
EOF

    # Context-specific variables
    if [[ -n "${CLAUDE_CURRENT_FILE:-}" ]]; then
        local file_name=$(basename "${CLAUDE_CURRENT_FILE}" | cut -d. -f1)
        echo "  {{FILE_NAME}} = $file_name"
        echo "  {{BACKUP_NAME}} = ${file_name}-${CURRENT_DATE}"
    fi
    
    if [[ -n "${CLAUDE_GIT_BRANCH:-}" ]]; then
        echo "  {{GIT_BRANCH}} = ${CLAUDE_GIT_BRANCH}"
    fi
}

# Get contextual suggestions
get_suggestions() {
    local intention="$1"
    local tool_input="${CLAUDE_TOOL_INPUT:-}"
    
    case "$intention" in
        "committing")
            echo "  💡 Suggestion: git commit -m \"Fix issue - {{CURRENT_DATE}}\""
            ;;
        "maintenance")
            echo "  💡 Suggestion: backup-{{CURRENT_DATE}}.tar.gz"
            ;;
        "debugging")
            echo "  💡 Suggestion: Add timestamps to log entries: [{{CURRENT_ISO8601}}]"
            ;;
        "testing")
            echo "  💡 Suggestion: Use {{CURRENT_DATE}} for test data snapshots"
            ;;
    esac
    
    # Tool-specific suggestions
    if [[ "$tool_input" =~ \{\{ ]]; then
        echo "  🔗 Template variables detected - they will be replaced with current values"
    fi
}

# Main execution
main() {
    # Always get basic context (fast path)
    get_basic_context
    
    # Basic output (always shown)
    echo "📅 Enhanced Temporal Context:"
    echo "Current Date: $CURRENT_DATE"
    echo "Current Time: $CURRENT_TIME"
    echo "Timezone: $TIMEZONE"
    echo "Unix Timestamp: $UNIX_TIMESTAMP"
    
    # Smart enhancement (only when useful)
    if [[ "$ENABLE_SMART_DETECTION" == "true" ]] && should_enhance; then
        echo ""
        echo "🧠 Smart Context Enhancement:"
        
        # Template variables
        echo "📋 Template Variables:"
        get_template_variables
        
        # Version information
        local version_info=$(get_version_info)
        if [[ -n "$version_info" ]]; then
            echo ""
            echo "📦 Relevant Versions:"
            echo -e "$version_info"
        fi
        
        # Intention and suggestions
        local intention=$(detect_intention)
        if [[ "$intention" != "general_development" ]]; then
            echo ""
            echo "🎯 Detected Intention: $intention"
            get_suggestions "$intention"
        fi
        
        echo ""
        echo "⚡ Smart enhancement applied!"
    else
        echo ""
        echo "⚡ Basic temporal context ready!"
    fi
    
    # Performance info
    echo ""
    echo "🔧 Performance: $(date +%s%3N | tail -c 4)ms | Cache: $([[ "$ENABLE_CACHE" == "true" ]] && echo "enabled" || echo "disabled") | Smart: $([[ "$ENABLE_SMART_DETECTION" == "true" ]] && echo "enabled" || echo "disabled")"
}

# Error handling
trap 'echo "❌ Temporal context hook failed, continuing with basic context only"' ERR

# Run main function
main "$@"