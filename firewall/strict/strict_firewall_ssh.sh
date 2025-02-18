#!/bin/bash

# Strict Firewall Setup Script w/ SSH
# Preserves ports 8000, 9997
# Strict bidirectional traffic control - no automatic ESTABLISHED/RELATED rules

# Function to check if a service is active
is_service_active() {
    systemctl is-active --quiet "$1" && echo "yes" || echo "no"
}

echo "Starting restrictive firewall configuration with SSH access..."

# Flush existing rules
echo "Flushing existing firewall rules..."
sudo iptables -F
sudo iptables -X
sudo iptables -Z

# Set default policies - strict
echo "Setting default policies to DROP..."
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Allow loopback
echo "Allowing loopback interface..."
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT

# Competition-required ports
echo "Allowing competition-required ports..."
sudo iptables -A INPUT -p tcp --dport 8000 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 8000 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9997 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 9997 -j ACCEPT

# SSH Access with explicit rules
echo "Configuring SSH access..."
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 22 -j ACCEPT

# Service detection and configuration
# Apache
if [[ "$(is_service_active apache2)" == "yes" || "$(is_service_active httpd)" == "yes" ]]; then
    echo "Apache detected..."
    # HTTP
    sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --sport 80 -j ACCEPT
    # HTTPS
    sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --sport 443 -j ACCEPT
fi

# MySQL/MariaDB
if [[ "$(is_service_active mysql)" == "yes" || "$(is_service_active mariadb)" == "yes" ]]; then
    echo "MySQL/MariaDB detected..."
    sudo iptables -A INPUT -p tcp --dport 3306 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --sport 3306 -j ACCEPT
fi

# SMB Service
if [[ "$(is_service_active smbd)" == "yes" ]]; then
    echo "SMB detected..."
    # NetBIOS Name Service
    sudo iptables -A INPUT -p tcp --dport 137 -j ACCEPT
    sudo iptables -A INPUT -p udp --dport 137 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --sport 137 -j ACCEPT
    sudo iptables -A OUTPUT -p udp --sport 137 -j ACCEPT
    
    # NetBIOS Datagram Service
    sudo iptables -A INPUT -p tcp --dport 138 -j ACCEPT
    sudo iptables -A INPUT -p udp --dport 138 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --sport 138 -j ACCEPT
    sudo iptables -A OUTPUT -p udp --sport 138 -j ACCEPT
    
    # NetBIOS Session Service
    sudo iptables -A INPUT -p tcp --dport 139 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --sport 139 -j ACCEPT
    
    # Microsoft DS
    sudo iptables -A INPUT -p tcp --dport 445 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --sport 445 -j ACCEPT
fi

# Allow DNS queries
echo "Allowing DNS queries..."
sudo iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
sudo iptables -A INPUT -p udp --sport 53 -j ACCEPT

# Allow ICMP with rate limiting
echo "Allowing rate-limited ICMP..."
sudo iptables -A INPUT -p icmp -m limit --limit 5/second -j ACCEPT
sudo iptables -A OUTPUT -p icmp -m limit --limit 5/second -j ACCEPT

# Logging for both dropped input and output
echo "Configuring logging..."
sudo iptables -A INPUT -j LOG --log-prefix "DROPPED_INPUT: " --log-level 4
sudo iptables -A OUTPUT -j LOG --log-prefix "DROPPED_OUTPUT: " --log-level 4

# Save rules
echo "Saving firewall rules..."
sudo iptables-save | sudo tee /etc/iptables.rules

echo "Strict Firewall w/ SSH done"