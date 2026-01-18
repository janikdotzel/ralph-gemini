#!/bin/bash
# security.sh - DevSecOps checks for Ralph VM
#
# Run before first execution to secure VM
# Exit 0 = OK, Exit 1 = Error

set -e

echo "DevSecOps Security Check"
echo "========================"
echo ""

WARNINGS=0
ERRORS=0

# 1. SSH configuration
echo "1. SSH Security..."
if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
    echo "   OK: Password auth disabled"
else
    echo "   WARN: Password auth may be enabled - should be disabled"
    WARNINGS=$((WARNINGS + 1))
fi

if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
    echo "   OK: Root login disabled"
else
    echo "   WARN: Root login may be allowed"
    WARNINGS=$((WARNINGS + 1))
fi

# 2. Firewall
echo "2. Firewall..."
if command -v ufw &> /dev/null; then
    if ufw status | grep -q "Status: active"; then
        echo "   OK: UFW active"
        if ufw status | grep -q "22/tcp"; then
            echo "   OK: SSH (22) open"
        fi
    else
        echo "   WARN: UFW installed but not active"
        WARNINGS=$((WARNINGS + 1))
    fi
elif command -v firewall-cmd &> /dev/null; then
    if firewall-cmd --state 2>/dev/null | grep -q "running"; then
        echo "   OK: Firewalld active"
    else
        echo "   WARN: Firewalld not active"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "   WARN: No firewall found (ufw/firewalld)"
    WARNINGS=$((WARNINGS + 1))
fi

# 3. User & permissions
echo "3. User..."
if id ralph &>/dev/null; then
    echo "   OK: ralph user exists"

    # Check that ralph has limited sudo
    if sudo -l -U ralph 2>/dev/null | grep -q "ALL"; then
        echo "   WARN: ralph has full sudo - should be limited"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "   OK: ralph has limited sudo"
    fi
else
    echo "   ERROR: ralph user missing"
    ERRORS=$((ERRORS + 1))
fi

# 4. Updates
echo "4. System Updates..."
if command -v apt &> /dev/null; then
    UPDATES=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
    if [ "$UPDATES" -gt 10 ]; then
        echo "   WARN: $UPDATES packages can be updated"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "   OK: System relatively up to date"
    fi
elif command -v dnf &> /dev/null; then
    UPDATES=$(dnf check-update --quiet 2>/dev/null | wc -l || echo "0")
    if [ "$UPDATES" -gt 10 ]; then
        echo "   WARN: $UPDATES packages can be updated"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "   OK: System relatively up to date"
    fi
fi

# 5. Secrets
echo "5. Secrets..."
if [ -f "$HOME/.env" ]; then
    echo "   WARN: .env in home folder - move to project"
    WARNINGS=$((WARNINGS + 1))
else
    echo "   OK: No .env in home"
fi

# Check for API keys in bash_history
if grep -qiE "(api_key|secret|token|password)=" "$HOME/.bash_history" 2>/dev/null; then
    echo "   WARN: Possible secrets in bash_history"
    WARNINGS=$((WARNINGS + 1))
else
    echo "   OK: No obvious secrets in history"
fi

# 6. Docker (if installed)
echo "6. Docker..."
if command -v docker &> /dev/null; then
    if docker info &>/dev/null; then
        echo "   OK: Docker running"

        # Check ralph is in docker group
        if groups ralph 2>/dev/null | grep -q docker; then
            echo "   OK: ralph in docker group"
        else
            echo "   WARN: ralph not in docker group"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        echo "   WARN: Docker installed but not running"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "   INFO: Docker not installed"
fi

# 7. Network exposure
echo "7. Network Exposure..."
LISTENING=$(ss -tlnp 2>/dev/null | grep LISTEN | wc -l)
echo "   INFO: $LISTENING services listening"

# Warn if something listens on 0.0.0.0 (all interfaces)
EXPOSED=$(ss -tlnp 2>/dev/null | grep "0.0.0.0:" | grep -v ":22" | wc -l)
if [ "$EXPOSED" -gt 0 ]; then
    echo "   WARN: $EXPOSED services exposed on all interfaces"
    ss -tlnp 2>/dev/null | grep "0.0.0.0:" | grep -v ":22"
    WARNINGS=$((WARNINGS + 1))
else
    echo "   OK: Only SSH exposed externally"
fi

# 8. Disk & resources
echo "8. Resources..."
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "   WARN: Disk ${DISK_USAGE}% full"
    WARNINGS=$((WARNINGS + 1))
else
    echo "   OK: Disk (${DISK_USAGE}%)"
fi

MEM_FREE=$(free -m | awk 'NR==2 {print $7}')
if [ "$MEM_FREE" -lt 500 ]; then
    echo "   WARN: Low free memory (${MEM_FREE}MB)"
    WARNINGS=$((WARNINGS + 1))
else
    echo "   OK: Memory (${MEM_FREE}MB free)"
fi

# Results
echo ""
echo "================================"
if [ $ERRORS -gt 0 ]; then
    echo "SECURITY CHECK FAILED ($ERRORS errors, $WARNINGS warnings)"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo "SECURITY CHECK: $WARNINGS warnings"
    exit 0
else
    echo "SECURITY CHECK OK"
    exit 0
fi
