#!/bin/bash

# Firewall Setup Script with SSH Access
# Preserves ports 8000, 9997

# Function to check if a service is active
is_service_active() {
    systemctl is-active --quiet "$1" && echo "yes" || echo "no"
}

echo "Starting firewall configuration with SSH access..."

# Flush existing rules
echo "Flushing existing firewall rules..."
sudo iptables -F
sudo iptables -X
sudo iptables -Z

# Set default policies
echo "Setting default policies..."
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Allow loopback
echo "Allowing loopback interface..."
sudo iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
echo "Allowing established and related connections..."
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Competition-required ports
echo "Allowing competition-required ports..."
sudo iptables -A INPUT -p tcp --dport 8000 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9997 -j ACCEPT

# SSH Access (customizable)
echo "Configuring SSH access..."
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Service detection and configuration
# Apache
if [[ "$(is_service_active apache2)" == "yes" || "$(is_service_active httpd)" == "yes" ]]; then
    echo "Apache detected..."
    sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
fi

# MySQL/MariaDB
if [[ "$(is_service_active mysql)" == "yes" || "$(is_service_active mariadb)" == "yes" ]]; then
    echo "MySQL/MariaDB detected..."
    sudo iptables -A INPUT -p tcp --dport 3306 -j ACCEPT
fi

# SMB Service
if [[ "$(is_service_active smbd)" == "yes" ]]; then
    echo "SMB detected..."
    # NetBIOS Name Service
    sudo iptables -A INPUT -p tcp --dport 137 -j ACCEPT
    sudo iptables -A INPUT -p udp --dport 137 -j ACCEPT
    # NetBIOS Datagram Service
    sudo iptables -A INPUT -p tcp --dport 138 -j ACCEPT
    sudo iptables -A INPUT -p udp --dport 138 -j ACCEPT
    # NetBIOS Session Service
    sudo iptables -A INPUT -p tcp --dport 139 -j ACCEPT
    # Microsoft DS
    sudo iptables -A INPUT -p tcp --dport 445 -j ACCEPT
fi

# Allow ICMP
echo "Allowing ICMP..."
sudo iptables -A INPUT -p icmp -j ACCEPT

# Log dropped packets for analysis
echo "Configuring logging for dropped packets..."
sudo iptables -A INPUT -j LOG --log-prefix "DROPPED_PACKET: " --log-level 4

# Save rules
echo "Saving firewall rules..."
sudo iptables-save | sudo tee /etc/iptables.rules

echo "Firewall w/ SSH done"