#!/bin/bash

# Exit on any error
set -e

# Ensure secure permissions for this script
if [[ "$(stat -c %a $0)" != "700" ]]; then
    chmod 700 "$0"
fi

# Verify running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Function to securely clear variables
secure_clear() {
    local var="$1"
    # Overwrite variable content with random data before unsetting
    eval "$var=\"$(head -c 32 /dev/urandom | base64)\""
    eval "unset $var"
}

# Disable core dumps
ulimit -c 0

# Lock memory to prevent swapping
if command -v mlockall >/dev/null 2>&1; then
    mlockall
fi

# Create a secure temporary file to store the flag search results
temp_file=$(mktemp /tmp/tmp.XXXXXX)
chmod 600 "$temp_file"

# Trap to ensure cleanup
trap 'rm -f "$temp_file";' EXIT

# Temporarily disable history
HISTSIZE=0
HISTFILESIZE=0
set +o history

# Write header with hostname and timestamp to the temp file
hostname=$(hostname -f 2>/dev/null || hostname)
{
    echo "Flag Search Report"
    echo "====================="
    echo "Hostname: ${hostname}"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "====================="
    echo
} >> "$temp_file"

# Print the current directory
echo "Current directory: $(pwd)" >> "$temp_file"

# Search for files with FLAG{*} in filenames
echo "Searching for FLAG files by filename..."

# Find files with FLAG{*} in the filename
find / -type f -name 'FLAG{*}' 2>/dev/null | tee -a "$temp_file"

# Search for FLAG{*} contents in files
echo "Searching for FLAG contents in files..."

# Use grep to search for FLAG{*} in the content of files
grep -r --binary-files=without-match "FLAG{" / 2>/dev/null | tee -a "$temp_file"

# Display results from the temp file using less for controlled viewing
less "$temp_file"

# Wipe and remove temp file securely
shred -u "$temp_file"

# Clear screen and bash history
history -c
history -w
clear

# Re-enable history
set -o history

echo "Flag search completed."
