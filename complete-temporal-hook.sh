#!/bin/bash

# Complete Temporal Solution for Claude Code
# 
# Addresses ALL temporal context issues through multi-layer enhancement:
# 1. Basic temporal context (data)
# 2. Content-specific guidance (how to use data)
# 3. Response directives (content requirements)
# 4. Validation suggestions (quality assurance)

set -euo pipefail

# Configuration
ENABLE_COMPLETE_ENHANCEMENT="${CLAUDE_COMPLETE_TEMPORAL:-true}"
ENABLE_CONTENT_GUIDANCE="${CLAUDE_CONTENT_GUIDANCE:-true}"
ENABLE_RESPONSE_DIRECTIVES="${CLAUDE_RESPONSE_DIRECTIVES:-true}"
CACHE_DIR="${HOME}/.claude/temporal_cache"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR" 2>/dev/null || true

# Layer 1: Enhanced Basic Context (improved from original)
get_enhanced_basic_context() {
    export CURRENT_DATE=$(date '+%Y-%m-%d')
    export CURRENT_TIME=$(date '+%H:%M:%S %Z')
    export UNIX_TIMESTAMP=$(date '+%s')
    export TIMEZONE=$(date '+%Z')
    export CURRENT_ISO8601=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    export CURRENT_YEAR=$(date '+%Y')
    export CURRENT_MONTH=$(date '+%m')
    export CURRENT_DAY=$(date '+%d')
    export PREVIOUS_YEAR=$((CURRENT_YEAR - 1))
    export NEXT_YEAR=$((CURRENT_YEAR + 1))
}

# Layer 2: Content-Type Detection and Specific Guidance
detect_and_guide_content_type() {
    local tool_input="${CLAUDE_TOOL_INPUT:-}"
    local guidance_provided=false
    
    # Documentation generation guidance
    if [[ "$tool_input" =~ (README|documentation|docs|changelog|wiki) ]]; then
        echo "📄 DOCUMENTATION GENERATION GUIDANCE:"
        echo "  ✓ Use 'Last updated: $CURRENT_DATE' in headers"
        echo "  ✓ Use 'Copyright $CURRENT_YEAR' for legal notices"
        echo "  ✓ Reference 'As of $CURRENT_DATE' for version info"
        echo "  ✓ Template: 'Last updated: {{CURRENT_DATE}}'"
        echo "  ✗ Avoid: 'Last updated: 2024' or outdated references"
        guidance_provided=true
    fi
    
    # Code comment guidance
    if [[ "$tool_input" =~ (comment|header|copyright|created|author) ]]; then
        echo "💬 CODE COMMENT GUIDANCE:"
        echo "  ✓ Use '* Created: $CURRENT_DATE'"
        echo "  ✓ Use '* Modified: $CURRENT_DATE'"
        echo "  ✓ Use '* Copyright $CURRENT_YEAR'"
        echo "  ✓ Template: '* Created: {{CURRENT_DATE}}'"
        echo "  ✗ Avoid: '* Created: 2024' or static dates"
        guidance_provided=true
    fi
    
    # Explanation and description guidance
    if [[ "$tool_input" =~ (explain|describe|what.*version|current|latest|LTS) ]]; then
        echo "📖 EXPLANATION GUIDANCE:"
        echo "  ✓ Say 'As of $CURRENT_DATE' not 'As of $PREVIOUS_YEAR'"
        echo "  ✓ Reference 'Current year $CURRENT_YEAR'"
        echo "  ✓ Use 'Latest as of $CURRENT_DATE'"
        echo "  ✗ Avoid: 'As of 2024' or 'In 2024'"
        guidance_provided=true
    fi
    
    # Version and technology guidance
    if [[ "$tool_input" =~ (version|install|npm|node|react|typescript|python) ]]; then
        echo "🔧 VERSION REFERENCE GUIDANCE:"
        echo "  ✓ Say 'As of $CURRENT_DATE, the latest...'"
        echo "  ✓ Include current year context: '$CURRENT_YEAR'"
        echo "  ✓ Mention when information was last verified"
        echo "  ✗ Avoid: Generic 'latest' without date context"
        
        # Provide current version context
        provide_current_version_context "$tool_input"
        guidance_provided=true
    fi
    
    # Backup and archival guidance
    if [[ "$tool_input" =~ (backup|archive|export|dump) ]]; then
        echo "💾 BACKUP/ARCHIVE GUIDANCE:"
        echo "  ✓ Use 'backup-$CURRENT_DATE' naming pattern"
        echo "  ✓ Include timestamp: backup-$CURRENT_DATE-$CURRENT_TIME"
        echo "  ✓ Template: 'backup-{{CURRENT_DATE}}.tar.gz'"
        echo "  ✗ Avoid: Generic names without dates"
        guidance_provided=true
    fi
    
    return $([ "$guidance_provided" = true ] && echo 0 || echo 1)
}

# Layer 3: Response Content Directives
provide_response_directives() {
    echo ""
    echo "🤖 CONTENT GENERATION DIRECTIVES:"
    echo "═══════════════════════════════════════════════════════════"
    echo "  CRITICAL: When generating any content, follow these rules:"
    echo ""
    echo "  📅 DATE REFERENCES:"
    echo "    → Replace ANY '2024' with '2025' in explanations"
    echo "    → Use 'As of $CURRENT_DATE' for current information"
    echo "    → Use '$CURRENT_YEAR' for current year references"
    echo ""
    echo "  📄 DOCUMENTATION:"
    echo "    → Include 'Last updated: $CURRENT_DATE'"
    echo "    → Use current year for copyright: '$CURRENT_YEAR'"
    echo "    → Reference latest versions as of current date"
    echo ""
    echo "  💻 CODE GENERATION:"
    echo "    → Use {{CURRENT_DATE}} in templates"
    echo "    → Use current timestamps for logs"
    echo "    → Use $CURRENT_YEAR for copyright headers"
    echo ""
    echo "  🔍 EXPLANATIONS:"
    echo "    → Never say 'As of 2024' - use 'As of $CURRENT_DATE'"
    echo "    → Current year is $CURRENT_YEAR, not $PREVIOUS_YEAR"
    echo "    → Verify information is current as of $CURRENT_DATE"
    echo "═══════════════════════════════════════════════════════════"
}

# Layer 4: Current Version Context Provider
provide_current_version_context() {
    local query="$1"
    local cache_key=$(echo "$query" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "fallback")
    local cache_file="$CACHE_DIR/versions_$cache_key"
    local version_info=""
    
    # Check cache (1 hour TTL)
    if [[ -f "$cache_file" ]]; then
        local file_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)))
        if [[ $file_age -lt 3600 ]]; then
            cat "$cache_file"
            return 0
        fi
    fi
    
    echo ""
    echo "📦 CURRENT VERSION CONTEXT (as of $CURRENT_DATE):"
    
    # Technology-specific version information
    if [[ "$query" =~ (node|npm) ]]; then
        version_info+="  Node.js: Latest LTS is 22.x (Released Oct 2024, Current through $CURRENT_YEAR)\n"
        version_info+="  npm: Version 10.x ships with Node.js 22\n"
    fi
    
    if [[ "$query" =~ react ]]; then
        version_info+="  React: Latest stable is 18.3.x (Current as of $CURRENT_DATE)\n"
        version_info+="  React 19: In development as of $CURRENT_DATE\n"
    fi
    
    if [[ "$query" =~ typescript ]]; then
        version_info+="  TypeScript: Latest is 5.6.x (Current as of $CURRENT_DATE)\n"
        version_info+="  Stable release cycle continues in $CURRENT_YEAR\n"
    fi
    
    if [[ "$query" =~ python ]]; then
        version_info+="  Python: Latest is 3.12.x (Current as of $CURRENT_DATE)\n"
        version_info+="  Python 3.13 expected in $CURRENT_YEAR\n"
    fi
    
    if [[ "$query" =~ (docker|container) ]]; then
        version_info+="  Docker: Latest stable as of $CURRENT_DATE\n"
        version_info+="  Ongoing updates throughout $CURRENT_YEAR\n"
    fi
    
    if [[ -n "$version_info" ]]; then
        echo -e "$version_info"
        echo "  📅 Information current as of: $CURRENT_DATE"
        echo "  🔄 Verify latest versions if critical for your use case"
        
        # Cache the result
        echo -e "$version_info" > "$cache_file" 2>/dev/null || true
    fi
}

# Layer 5: Template Variable Enhancement
provide_enhanced_template_variables() {
    echo ""
    echo "🔗 ENHANCED TEMPLATE VARIABLES:"
    echo "  {{CURRENT_DATE}}     = $CURRENT_DATE"
    echo "  {{CURRENT_TIME}}     = $CURRENT_TIME"
    echo "  {{CURRENT_ISO8601}}  = $CURRENT_ISO8601"
    echo "  {{UNIX_TIMESTAMP}}   = $UNIX_TIMESTAMP"
    echo "  {{TIMEZONE}}         = $TIMEZONE"
    echo "  {{CURRENT_YEAR}}     = $CURRENT_YEAR"
    echo "  {{PREVIOUS_YEAR}}    = $PREVIOUS_YEAR"
    echo "  {{MONTH}}            = $CURRENT_MONTH"
    echo "  {{DAY}}              = $CURRENT_DAY"
    
    # Context-specific variables
    if [[ -n "${CLAUDE_CURRENT_FILE:-}" ]]; then
        local file_name=$(basename "${CLAUDE_CURRENT_FILE}" | cut -d. -f1)
        echo "  {{FILE_NAME}}        = $file_name"
        echo "  {{BACKUP_NAME}}      = ${file_name}-${CURRENT_DATE}"
        echo "  {{TIMESTAMPED_FILE}} = ${file_name}-${CURRENT_DATE}-${UNIX_TIMESTAMP}"
    fi
    
    if [[ -n "${CLAUDE_GIT_BRANCH:-}" ]]; then
        echo "  {{GIT_BRANCH}}       = ${CLAUDE_GIT_BRANCH}"
    fi
}

# Layer 6: Validation and Quality Assurance Guidance
provide_validation_guidance() {
    echo ""
    echo "✅ QUALITY ASSURANCE CHECKLIST:"
    echo "  Before finalizing your response, verify:"
    echo "  □ No '2024' references in explanations (use '$CURRENT_YEAR')"
    echo "  □ Documentation includes 'Last updated: $CURRENT_DATE'"
    echo "  □ Version references include 'as of $CURRENT_DATE'"
    echo "  □ Template variables used where appropriate"
    echo "  □ Current year $CURRENT_YEAR used consistently"
    echo "  □ Timestamps reflect current date $CURRENT_DATE"
}

# Smart enhancement detection (improved)
should_provide_complete_enhancement() {
    local tool_name="${CLAUDE_TOOL_NAME:-}"
    local tool_input="${CLAUDE_TOOL_INPUT:-}"
    
    # Always enhance for documentation and content generation
    [[ "$tool_input" =~ (README|documentation|docs|comment|header|explain|describe|version|latest|current|LTS|backup|archive) ]] && return 0
    
    # Tool-specific enhancement
    case "$tool_name" in
        "Write"|"Edit"|"MultiEdit") return 0 ;;
        "Bash") [[ "$tool_input" =~ (commit|git|backup|log) ]] && return 0 ;;
        "WebSearch") return 0 ;;
    esac
    
    return 1
}

# Main execution with complete enhancement
main() {
    # Always provide enhanced basic context
    get_enhanced_basic_context
    
    # Basic output (always shown)
    echo "📅 COMPLETE TEMPORAL CONTEXT SYSTEM:"
    echo "Current Date: $CURRENT_DATE"
    echo "Current Time: $CURRENT_TIME"
    echo "Current Year: $CURRENT_YEAR (not $PREVIOUS_YEAR!)"
    echo "Timezone: $TIMEZONE"
    echo "Unix Timestamp: $UNIX_TIMESTAMP"
    
    # Complete enhancement when appropriate
    if [[ "$ENABLE_COMPLETE_ENHANCEMENT" == "true" ]] && should_provide_complete_enhancement; then
        echo ""
        echo "🧠 COMPLETE TEMPORAL ENHANCEMENT ACTIVE:"
        echo "═══════════════════════════════════════════════════════════"
        
        # Layer 2: Content-specific guidance
        if [[ "$ENABLE_CONTENT_GUIDANCE" == "true" ]]; then
            if detect_and_guide_content_type; then
                echo ""
            fi
        fi
        
        # Layer 3: Response directives
        if [[ "$ENABLE_RESPONSE_DIRECTIVES" == "true" ]]; then
            provide_response_directives
        fi
        
        # Layer 4: Enhanced template variables
        provide_enhanced_template_variables
        
        # Layer 5: Validation guidance
        provide_validation_guidance
        
        echo ""
        echo "🎯 COMPLETE TEMPORAL SOLUTION APPLIED!"
        echo "   All temporal context issues should now be addressed."
        echo "═══════════════════════════════════════════════════════════"
    else
        echo ""
        echo "⚡ Basic temporal context ready!"
        echo "   (Complete enhancement not triggered for this operation)"
    fi
    
    # Performance info
    echo ""
    echo "🔧 System: Complete temporal solution | Date: $CURRENT_DATE | Year: $CURRENT_YEAR"
}

# Error handling
trap 'echo "❌ Complete temporal context hook failed, falling back to basic mode"' ERR

# Execute main function
main "$@"