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

# List of SMB users to change passwords for
declare -A SMB_USERS
SMB_USERS=("charmander" "squirtle" "bulbasaur")

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

# Create a secure temporary file
temp_file=$(mktemp /tmp/tmp.XXXXXX)
chmod 600 "$temp_file"

# Trap to ensure cleanup
trap 'rm -f "$temp_file"; for user in "${!SMB_USERS[@]}"; do secure_clear "pwd_$user"; done' EXIT

# Temporarily disable history
HISTSIZE=0
HISTFILESIZE=0
set +o history

# Prompt for Samba root password
#read -s -p "Enter Samba root password: " SAMBA_PASSWORD
#echo ""

# Write header with hostname and timestamp to the temp file
hostname=$(hostname -f 2>/dev/null || hostname)
{
    echo "SMB Password Change Report"
    echo "====================="
    echo "Hostname: ${hostname}"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "====================="
    echo
} >> "$temp_file"

echo "Changing passwords for SMB users..."
echo "Passwords will be displayed ONCE. Note them down securely!"

# Loop through the users and change passwords
for user in "${!SMB_USERS[@]}"; do
    # Generate random password for each user
    pwd_var="pwd_$user"
    declare "$pwd_var"="$(dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 | head -c 16)"

    # Change password using smbpasswd
    echo -e "${!pwd_var}\n${!pwd_var}" | sudo smbpasswd -s -a "$user" >/dev/null 2>&1

    # Check if the password change was successful
    if [ $? -eq 0 ]; then
        # Write to secure temp file instead of displaying on screen
        echo "User: $user | New Password: ${!pwd_var}" >> "$temp_file"
    else
        echo "Failed to change password for $user" >&2
        secure_clear "$pwd_var"
        continue
    fi

    # Immediately clear the password variable
    secure_clear "$pwd_var"
done

# Display passwords from temp file using less for controlled viewing
less "$temp_file"

# Wipe and remove temp file
shred -u "$temp_file"

# Clear screen and bash history
history -c
history -w
clear

# Re-enable history
set -o history

echo "All passwords changed."
