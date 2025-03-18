#!/bin/bash
# Exit on any error
set -e

# Help function
show_help() {
    echo "Usage: $0 [-a] [-u username]"
    echo "  -a: Change passwords for all users (except excluded ones)"
    echo "  -u: Specify user(s) to change password for (can be used multiple times)"
    echo
    echo "Example: $0 -u alex -u gavin"
    echo "         $0 -a"
    exit 0
}

# Verify running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Ensure permissions for this script
chmod 700 "$0"

# Function to clear variables
secure_clear() {
    local var="$1"
    eval "unset $var"
}

# Process command line arguments
SPECIFIC_USERS=()
ALL_USERS=false
EXCLUDE=("grey-team" "game-master") #exclude off-limit users

# Check if no arguments were provided
if [[ $# -eq 0 ]]; then
    show_help
fi

while getopts ":au:h" opt; do
    case ${opt} in
        a ) ALL_USERS=true ;;
        u ) SPECIFIC_USERS+=("$OPTARG") ;;
        h ) show_help ;;
        \? ) echo "Invalid option: $OPTARG" 1>&2; exit 1 ;;
    esac
done

# Get users to process
if [[ "$ALL_USERS" == true ]]; then
    # Get all non-system users (UID >= 1000)
    mapfile -t users < <(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
    
    # Filter out excluded users
    for exclude in "${EXCLUDE[@]}"; do
        users=(${users[@]/$exclude/})
    done
elif [[ ${#SPECIFIC_USERS[@]} -gt 0 ]]; then
    # Use specific users provided via command line
    users=("${SPECIFIC_USERS[@]}")
    
    # Check for excluded users
    for user in "${users[@]}"; do
        for exclude in "${EXCLUDE[@]}"; do
            if [[ "$user" == "$exclude" ]]; then
                echo "Cannot modify excluded user: $exclude" >&2
                exit 3
            fi
        done
    done
else
    # This should not happen now that we check for no arguments above
    show_help
fi

ulimit -c 0  # Disable core dumps

# Temporarily disable history
HISTSIZE=0
HISTFILESIZE=0
set +o history

# Create a temporary file with permissions
temp_file=$(mktemp)
chmod 600 "$temp_file"

# Use memory-based temporary file if available
if [[ -d "/dev/shm" ]]; then
    secure_temp=$(mktemp -p /dev/shm)
    chmod 600 "$secure_temp"
    # Move the temp file to memory
    mv "$temp_file" "$secure_temp"
    temp_file="$secure_temp"
fi

# Trap to ensure cleanup
trap 'rm -f "$temp_file"' EXIT INT TERM

# Get hostname securely
hostname=$(hostname -f 2>/dev/null || hostname)

# Write header with hostname and timestamp
{
    echo "Password Change Report"
    echo "====================="
    echo "Hostname: ${hostname}"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "====================="
    echo
} > "$temp_file"

echo "Changing passwords for users..."
echo "Processing ${#users[@]} user accounts..."

# Create associative array for passwords
declare -A passwords

# Generate passwords for all users
for user in "${users[@]}"; do
    passwords["$user"]="$(dd if=/dev/urandom bs=1 count=16 2>/dev/null | base64 | tr -d '+/' | head -c 16)"
done

# Change passwords and report results
for user in "${users[@]}"; do
    # Validate user exists
    if ! id -u "$user" >/dev/null 2>&1; then
        echo "User $user does not exist, skipping" >&2
        continue
    fi
    
    echo "$user:${passwords[$user]}" | chpasswd 2>/dev/null
    
    if [ $? -eq 0 ]; then
        # Write to temp file
        echo "User: $user | New Password: ${passwords[$user]}" >> "$temp_file"
    else
        echo "Failed to change password for $user" >&2
        continue
    fi
done

# Display passwords from temp file
less "$temp_file"

# Clean up
rm -f "$temp_file"

# Clear screen and bash history
history -c
history -w
clear

# Re-enable history
set -o history

echo "All passwords changed. Total users processed: ${#users[@]}"
echo "Script completion time: $(date '+%Y-%m-%d %H:%M:%S')"
