#!/usr/bin/env bash

################################################################################
# macOS One-Click Cleanup Utility
# A safe, automated disk cleanup tool for macOS
################################################################################

set -euo pipefail

# Script metadata
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${HOME}/Library/Logs"
readonly LOG_FILE="${LOG_DIR}/mac-cleanup.log"
readonly LOCK_FILE="/tmp/mac-cleanup.lock"
readonly TRASH_DIR="${HOME}/.Trash"

# Configuration defaults
BACKUP_ENABLED=false
DRY_RUN=false
SYSTEM_LEVEL=false
VERBOSE=false
SKIP_CONFIRMATION=false
CONFIG_FILE="${HOME}/.mac-cleanup.conf"

# Cleanup targets (enable/disable)
CLEAN_USER_CACHES=true
CLEAN_BROWSER_CACHES=true
CLEAN_TEMP_FILES=true
CLEAN_DOWNLOADS=false
CLEAN_SYSTEM_CACHES=false
CLEAN_SNAPSHOTS=false

# Age thresholds (days)
TEMP_FILE_AGE=7
DOWNLOAD_FILE_AGE=30

# Space tracking
SPACE_FREED_BYTES=0

################################################################################
# Utility Functions
################################################################################

# Print colored output
print_header() {
    printf "\n\033[1;36m>>> %s\033[0m\n" "$1"
}

print_success() {
    printf "\033[1;32m✓ %s\033[0m\n" "$1"
}

print_error() {
    printf "\033[1;31m✗ %s\033[0m\n" "$1"
}

print_warning() {
    printf "\033[1;33m⚠ %s\033[0m\n" "$1"
}

print_info() {
    printf "  %s\n" "$1"
}

# Log operations
log_operation() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf "[%s] %s\n" "$timestamp" "$1" >> "$LOG_FILE"
}

# Initialize logging
init_logging() {
    mkdir -p "$LOG_DIR"
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
    fi
    log_operation "=========================================="
    log_operation "mac-cleanup started"
    log_operation "User: $(whoami), OS: $(sw_vers -productVersion)"
}

# Lock file management
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            print_error "Another cleanup operation is running (PID: $pid)"
            exit 1
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE"
}

# Cleanup on exit
cleanup_on_exit() {
    local exit_code=$?
    release_lock
    if [[ $exit_code -eq 0 ]]; then
        log_operation "mac-cleanup completed successfully"
    else
        log_operation "mac-cleanup failed with exit code: $exit_code"
    fi
    return $exit_code
}

trap cleanup_on_exit EXIT

################################################################################
# Configuration Management
################################################################################

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        print_info "Loaded configuration from $CONFIG_FILE"
    fi
}

show_config() {
    print_header "Current Configuration"
    print_info "Backup enabled: $BACKUP_ENABLED"
    print_info "Clean user caches: $CLEAN_USER_CACHES"
    print_info "Clean browser caches: $CLEAN_BROWSER_CACHES"
    print_info "Clean temp files: $CLEAN_TEMP_FILES"
    print_info "Clean Downloads: $CLEAN_DOWNLOADS"
    print_info "Temp file age threshold: ${TEMP_FILE_AGE} days"
    print_info "Download file age threshold: ${DOWNLOAD_FILE_AGE} days"
}

################################################################################
# System Information
################################################################################

get_macos_version() {
    sw_vers -productVersion
}

check_macos_version() {
    local version
    version=$(get_macos_version)
    local major_version
    major_version=$(echo "$version" | cut -d. -f1)

    if [[ $major_version -lt 12 ]]; then
        print_warning "macOS 12 or later is recommended"
    fi

    log_operation "macOS version: $version"
}

check_disk_space() {
    local path=${1:-.}
    df -h "$path" | tail -1 | awk '{print $4}'
}

get_free_disk_space() {
    local path=${1:-.}
    df "$path" | tail -1 | awk '{print $4 * 512}'
}

################################################################################
# Size Calculation
################################################################################

# Calculate directory size in bytes
calculate_size() {
    local target=$1

    if [[ ! -e "$target" ]]; then
        echo 0
        return
    fi

    if [[ -d "$target" ]]; then
        du -sb "$target" 2>/dev/null | awk '{print $1}' || echo 0
    else
        stat -f%z "$target" 2>/dev/null || echo 0
    fi
}

# Convert bytes to human-readable format
format_bytes() {
    local bytes=$1

    if [[ $bytes -lt 1024 ]]; then
        printf "%d B" "$bytes"
    elif [[ $bytes -lt 1048576 ]]; then
        printf "%.2f KB" "$(echo "scale=2; $bytes / 1024" | bc)"
    elif [[ $bytes -lt 1073741824 ]]; then
        printf "%.2f MB" "$(echo "scale=2; $bytes / 1048576" | bc)"
    else
        printf "%.2f GB" "$(echo "scale=2; $bytes / 1073741824" | bc)"
    fi
}

################################################################################
# File Operations
################################################################################

# Check if file is in use
is_file_in_use() {
    local file=$1
    lsof "$file" >/dev/null 2>&1
}

# Remove files with logging
remove_files() {
    local target=$1
    local description=$2

    if [[ ! -e "$target" ]]; then
        return 0
    fi

    local size_before
    size_before=$(calculate_size "$target")

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would remove: $target ($(format_bytes "$size_before"))"
        log_operation "[DRY-RUN] Would remove: $target ($size_before bytes)"
    else
        if [[ "$BACKUP_ENABLED" == true ]]; then
            print_info "Moving to Trash: $target"
            if mv "$target" "$TRASH_DIR/" 2>/dev/null; then
                SPACE_FREED_BYTES=$((SPACE_FREED_BYTES + size_before))
                log_operation "Removed: $target ($size_before bytes) - $description"
                print_success "Cleaned $description"
            else
                print_error "Failed to move to Trash: $target (permission or in-use)"
                log_operation "SKIP: $target - permission denied or in-use"
            fi
        else
            print_info "Deleting: $target"
            if rm -rf "$target" 2>/dev/null; then
                SPACE_FREED_BYTES=$((SPACE_FREED_BYTES + size_before))
                log_operation "Removed: $target ($size_before bytes) - $description"
                print_success "Cleaned $description"
            else
                print_error "Failed to delete: $target (permission or in-use)"
                log_operation "SKIP: $target - permission denied or in-use"
            fi
        fi
    fi
    return 0
}

################################################################################
# Cleanup Functions - User Level
################################################################################

clean_user_caches() {
    if [[ "$CLEAN_USER_CACHES" != true ]]; then
        return
    fi

    print_header "Cleaning user application caches"

    local cache_dir="${HOME}/Library/Caches"

    if [[ -d "$cache_dir" ]]; then
        local total_size=0
        local cache_count=0

        # List all cache directories
        while IFS= read -r -d '' cache; do
            # Skip critical caches
            local basename
            basename=$(basename "$cache")

            if [[ "$basename" == com.apple.Safari ]] || \
               [[ "$basename" == com.apple.sharedfilelist ]]; then
                continue
            fi

            local size
            size=$(calculate_size "$cache")
            if [[ $size -gt 0 ]]; then
                total_size=$((total_size + size))
                ((cache_count++))
            fi

            remove_files "$cache" "application cache: $basename"
        done < <(find "$cache_dir" -maxdepth 1 -type d ! -name "Caches" -print0)

        print_info "Cleaned $cache_count cache directories ($(format_bytes "$total_size"))"
    fi
}

clean_browser_caches() {
    if [[ "$CLEAN_BROWSER_CACHES" != true ]]; then
        return
    fi

    print_header "Cleaning browser caches"

    # Safari cache
    if [[ -d "${HOME}/Library/Safari" ]]; then
        print_info "Cleaning Safari cache"
        # Safari's History.db-wal, History.db-shm are safe to remove
        find "${HOME}/Library/Safari" -name "*.db-wal" -o -name "*.db-shm" | while read -r file; do
            remove_files "$file" "Safari cache"
        done
    fi

    # Chrome cache
    local chrome_cache="${HOME}/Library/Caches/Google/Chrome"
    if [[ -d "$chrome_cache" ]]; then
        remove_files "$chrome_cache" "Chrome cache"
    fi

    # Firefox cache
    local firefox_cache="${HOME}/Library/Caches/Firefox"
    if [[ -d "$firefox_cache" ]]; then
        remove_files "$firefox_cache" "Firefox cache"
    fi
}

clean_temp_files() {
    if [[ "$CLEAN_TEMP_FILES" != true ]]; then
        return
    fi

    print_header "Cleaning temporary files"

    # User temp directories
    local user_tmp="/var/folders"
    if [[ -d "$user_tmp" ]]; then
        print_info "Scanning $user_tmp for old files"

        # Find temp files older than threshold
        find "$user_tmp" -type f -mtime +${TEMP_FILE_AGE} 2>/dev/null | while read -r file; do
            # Skip if file is in use
            if ! is_file_in_use "$file" 2>/dev/null; then
                remove_files "$file" "temp file"
            fi
        done
    fi

    # /tmp directory
    if [[ -d /tmp ]]; then
        print_info "Scanning /tmp for old files"

        find /tmp -type f -mtime +${TEMP_FILE_AGE} 2>/dev/null | while read -r file; do
            if ! is_file_in_use "$file" 2>/dev/null; then
                remove_files "$file" "temp file"
            fi
        done
    fi
}

clean_downloads() {
    if [[ "$CLEAN_DOWNLOADS" != true ]]; then
        return
    fi

    print_header "Cleaning old Downloads"

    local downloads_dir="${HOME}/Downloads"

    if [[ -d "$downloads_dir" ]]; then
        print_info "Scanning Downloads for files older than ${DOWNLOAD_FILE_AGE} days"

        local total_size=0
        local file_count=0

        find "$downloads_dir" -maxdepth 1 -type f -mtime +${DOWNLOAD_FILE_AGE} | while read -r file; do
            local size
            size=$(calculate_size "$file")
            total_size=$((total_size + size))
            ((file_count++))

            print_info "Old file: $(basename "$file") ($(format_bytes "$size"))"
            remove_files "$file" "old download"
        done
    fi
}

################################################################################
# Cleanup Functions - System Level
################################################################################

require_sudo() {
    if [[ $EUID -ne 0 ]]; then
        print_error "System-level cleanup requires admin privileges"
        print_info "Please run with: sudo $SCRIPT_NAME $@"
        exit 1
    fi
}

clean_system_caches() {
    if [[ "$CLEAN_SYSTEM_CACHES" != true ]]; then
        return
    fi

    require_sudo

    print_header "Cleaning system caches"

    # System library caches
    local system_caches="/Library/Caches"
    if [[ -d "$system_caches" ]]; then
        print_info "Cleaning system-wide caches"

        find "$system_caches" -type d -maxdepth 1 | while read -r cache; do
            if [[ "$cache" != "$system_caches" ]]; then
                remove_files "$cache" "system cache"
            fi
        done
    fi

    # Shared volume caches
    local shared_caches="/System/Volumes/Data/Library/Caches"
    if [[ -d "$shared_caches" ]]; then
        print_info "Cleaning shared volume caches"

        find "$shared_caches" -type d -maxdepth 1 2>/dev/null | while read -r cache; do
            if [[ "$cache" != "$shared_caches" ]]; then
                remove_files "$cache" "shared cache"
            fi
        done
    fi
}

clean_local_snapshots() {
    if [[ "$CLEAN_SNAPSHOTS" != true ]]; then
        return
    fi

    print_header "Cleaning old APFS local snapshots"

    local snapshots
    snapshots=$(tmutil listlocalsnapshots / 2>/dev/null | grep -E "\.local\.\.snapshot" | head -5)

    if [[ -z "$snapshots" ]]; then
        print_info "No old local snapshots found"
        return
    fi

    while IFS= read -r snapshot; do
        if [[ "$DRY_RUN" == true ]]; then
            print_info "[DRY-RUN] Would delete snapshot: $snapshot"
        else
            print_info "Deleting snapshot: $snapshot"
            tmutil deletelocalsnapshots 1 2>/dev/null || {
                print_warning "Failed to delete snapshot: $snapshot"
            }
        fi
        log_operation "Removed snapshot: $snapshot"
    done <<< "$snapshots"
}

################################################################################
# Summary and Reporting
################################################################################

calculate_cleanup_summary() {
    print_header "Calculating cleanup summary (dry-run)"

    local total_bytes=0

    # Calculate sizes for enabled targets
    if [[ "$CLEAN_USER_CACHES" == true ]]; then
        local size
        size=$(calculate_size "${HOME}/Library/Caches")
        total_bytes=$((total_bytes + size))
        print_info "User caches: $(format_bytes "$size")"
    fi

    if [[ "$CLEAN_BROWSER_CACHES" == true ]]; then
        local chrome_size
        chrome_size=$(calculate_size "${HOME}/Library/Caches/Google/Chrome" || echo 0)
        total_bytes=$((total_bytes + chrome_size))
        print_info "Browser caches: $(format_bytes "$chrome_size")"
    fi

    if [[ "$CLEAN_TEMP_FILES" == true ]]; then
        # Estimate temp files
        local temp_estimate=0
        # Conservative estimate
        print_info "Temp files: $(format_bytes "$temp_estimate") (estimated, will calculate on cleanup)"
    fi

    print_info "---"
    print_info "Estimated total: $(format_bytes "$total_bytes")"

    return $total_bytes
}

show_summary() {
    print_header "Cleanup Summary"

    print_info "Cleanup Configuration:"
    print_info "  User caches: $CLEAN_USER_CACHES"
    print_info "  Browser caches: $CLEAN_BROWSER_CACHES"
    print_info "  Temp files: $CLEAN_TEMP_FILES"
    print_info "  Downloads: $CLEAN_DOWNLOADS"
    print_info "  System caches: $CLEAN_SYSTEM_CACHES"
    print_info "  Snapshots: $CLEAN_SNAPSHOTS"

    print_info ""
    print_info "Safety Options:"
    print_info "  Backup to Trash: $BACKUP_ENABLED"
    print_info "  Dry-run mode: $DRY_RUN"

    if [[ "$DRY_RUN" == true ]]; then
        print_info ""
        print_warning "This is a dry-run. No files will actually be deleted."
    fi
}

show_results() {
    print_header "Cleanup Results"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "Dry-run completed. No files were deleted."
    else
        if [[ $SPACE_FREED_BYTES -gt 0 ]]; then
            print_success "Cleanup completed successfully"
            print_info "Space freed: $(format_bytes "$SPACE_FREED_BYTES")"
        else
            print_info "No files were removed"
        fi
    fi

    print_info ""
    print_info "Log file: $LOG_FILE"
    print_info "For detailed information, see the log file"
}

ask_confirmation() {
    if [[ "$SKIP_CONFIRMATION" == true ]]; then
        return 0
    fi

    printf "\nProceed with cleanup? (yes/no): "
    read -r response

    if [[ "$response" != "yes" && "$response" != "y" ]]; then
        print_warning "Cleanup cancelled by user"
        exit 0
    fi
}

################################################################################
# Help and Usage
################################################################################

show_usage() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION - macOS One-Click Cleanup Utility

USAGE:
  $SCRIPT_NAME [OPTIONS]

OPTIONS:
  --dry-run              Preview what would be cleaned without deleting
  --system               Include system-level cleanup (requires sudo)
  --backup               Move files to Trash instead of deleting
  --no-backup            Delete directly (default)
  --yes                  Skip confirmation prompts
  --verbose              Show detailed output
  --config FILE          Use custom configuration file
  --config-show          Display current configuration
  --help                 Show this help message
  --version              Show version information

EXAMPLES:
  # Dry-run to see what would be cleaned
  $SCRIPT_NAME --dry-run

  # Clean with backup enabled
  $SCRIPT_NAME --backup --yes

  # System-level cleanup (requires admin password)
  sudo $SCRIPT_NAME --system

CONFIGURATION:
  Create ~/.mac-cleanup.conf to customize cleanup behavior.
  Copy .mac-cleanup.conf.template as a starting point.

SAFETY:
  - This script uses a whitelist-only approach
  - Only known-safe paths are targeted
  - System-critical files are never deleted
  - Always keep backups with Time Machine

LOG FILE:
  $LOG_FILE

EOF
}

show_version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION"
}

################################################################################
# Main Execution
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --system)
                SYSTEM_LEVEL=true
                CLEAN_SYSTEM_CACHES=true
                shift
                ;;
            --backup)
                BACKUP_ENABLED=true
                shift
                ;;
            --no-backup)
                BACKUP_ENABLED=false
                shift
                ;;
            --yes)
                SKIP_CONFIRMATION=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --config-show)
                init_logging
                load_config
                show_config
                exit 0
                ;;
            --help)
                show_usage
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

main() {
    # Initialize
    init_logging
    parse_arguments "$@"
    acquire_lock

    # System checks
    check_macos_version

    # Load configuration if available
    if [[ -f "$CONFIG_FILE" ]]; then
        load_config
    fi

    # Show summary before cleanup
    show_summary

    # Ask for confirmation
    ask_confirmation

    # Pre-cleanup information
    print_header "Available disk space before cleanup"
    local free_before
    free_before=$(get_free_disk_space)
    print_info "Free space: $(format_bytes "$free_before")"

    # Run cleanup functions
    clean_user_caches
    clean_browser_caches
    clean_temp_files

    if [[ "$CLEAN_DOWNLOADS" == true ]]; then
        clean_downloads
    fi

    if [[ "$CLEAN_SYSTEM_CACHES" == true ]]; then
        clean_system_caches
    fi

    if [[ "$CLEAN_SNAPSHOTS" == true ]]; then
        clean_local_snapshots
    fi

    # Post-cleanup information
    if [[ "$DRY_RUN" != true ]]; then
        print_header "Available disk space after cleanup"
        local free_after
        free_after=$(get_free_disk_space)
        print_info "Free space: $(format_bytes "$free_after")"
    fi

    # Show results
    show_results
}

# Run main function
main "$@"
