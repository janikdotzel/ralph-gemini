#!/bin/bash
# vm.sh - VM management for GCP and self-hosted SSH
# Source this file: source lib/vm.sh
#
# Supports: gcloud (Google Cloud) and ssh (self-hosted)
# Config stored in .ralph/config.json

CONFIG_FILE="${RALPH_CONFIG:-.ralph/config.json}"

# Read config value
_vm_config() {
    local key="$1"
    jq -r ".$key // empty" "$CONFIG_FILE" 2>/dev/null
}

# Get execution type from config
vm_execution() {
    _vm_config "execution"
}

# Get VM name from config
vm_name() {
    _vm_config "vm_name"
}

# Get VM IP from config
vm_ip() {
    _vm_config "vm_ip"
}

# Get VM user from config
vm_user() {
    _vm_config "user" || echo "$USER"
}

# Get GCP project from config
vm_project() {
    _vm_config "project"
}

# Get GCP zone from config
vm_zone() {
    _vm_config "zone"
}

# Check if CLI is installed
vm_check_cli() {
    local execution="${1:-$(vm_execution)}"
    case "$execution" in
        gcp)    which gcloud >/dev/null 2>&1 ;;
        ssh)    which ssh >/dev/null 2>&1 ;;
        docker) which docker >/dev/null 2>&1 ;;
        *)      return 1 ;;
    esac
}

# SSH to VM
vm_ssh() {
    local cmd="$1"
    local execution=$(vm_execution)
    local name=$(vm_name)
    local ip=$(vm_ip)
    local user=$(vm_user)

    case "$execution" in
        gcp)
            local zone=$(vm_zone)
            local project=$(vm_project)
            if [ -n "$cmd" ]; then
                gcloud compute ssh "$user@$name" --zone="$zone" --project="$project" --command="$cmd"
            else
                gcloud compute ssh "$user@$name" --zone="$zone" --project="$project"
            fi
            ;;
        ssh)
            if [ -n "$cmd" ]; then
                ssh "$user@$ip" "$cmd"
            else
                ssh "$user@$ip"
            fi
            ;;
        *)
            echo "[vm] Unknown execution type: $execution"
            return 1
            ;;
    esac
}

# SCP to VM
vm_scp_to() {
    local src="$1"
    local dest="$2"
    local execution=$(vm_execution)
    local name=$(vm_name)
    local ip=$(vm_ip)
    local user=$(vm_user)

    case "$execution" in
        gcp)
            local zone=$(vm_zone)
            local project=$(vm_project)
            gcloud compute scp --recurse "$src" "$user@$name:$dest" --zone="$zone" --project="$project"
            ;;
        ssh)
            scp -r "$src" "$user@$ip:$dest"
            ;;
    esac
}

# SCP from VM
vm_scp_from() {
    local src="$1"
    local dest="$2"
    local execution=$(vm_execution)
    local name=$(vm_name)
    local ip=$(vm_ip)
    local user=$(vm_user)

    case "$execution" in
        gcp)
            local zone=$(vm_zone)
            local project=$(vm_project)
            gcloud compute scp --recurse "$user@$name:$src" "$dest" --zone="$zone" --project="$project"
            ;;
        ssh)
            scp -r "$user@$ip:$src" "$dest"
            ;;
    esac
}

# Start VM
vm_start() {
    local execution=$(vm_execution)
    local name=$(vm_name)

    echo "[vm] Starting $name..."

    case "$execution" in
        gcp)
            local zone=$(vm_zone)
            local project=$(vm_project)
            gcloud compute instances start "$name" --zone="$zone" --project="$project"
            ;;
        ssh)
            echo "[vm] Self-hosted VM - start manually"
            return 1
            ;;
    esac
}

# Stop VM
vm_stop() {
    local execution=$(vm_execution)
    local name=$(vm_name)

    echo "[vm] Stopping $name..."

    case "$execution" in
        gcp)
            local zone=$(vm_zone)
            local project=$(vm_project)
            gcloud compute instances stop "$name" --zone="$zone" --project="$project"
            ;;
        ssh)
            echo "[vm] Self-hosted VM - stop manually"
            return 1
            ;;
    esac

    echo "[vm] Stopped (saves money!)"
}

# Get VM status
vm_status() {
    local execution=$(vm_execution)
    local name=$(vm_name)

    case "$execution" in
        gcp)
            local zone=$(vm_zone)
            local project=$(vm_project)
            gcloud compute instances describe "$name" --zone="$zone" --project="$project" --format="value(status)"
            ;;
        ssh)
            # Try to ping
            if vm_ssh "echo ok" >/dev/null 2>&1; then
                echo "running"
            else
                echo "unknown"
            fi
            ;;
    esac
}

# Create VM (shows command)
vm_create() {
    local execution=$(vm_execution)
    local name=$(vm_name)
    local zone=$(vm_zone)
    local project=$(vm_project)

    echo "[vm] Create command for $execution:"
    echo ""

    case "$execution" in
        gcp)
            echo "gcloud compute instances create $name \\"
            echo "  --zone=$zone \\"
            echo "  --machine-type=e2-medium \\"
            echo "  --image-family=ubuntu-2404-lts \\"
            echo "  --image-project=ubuntu-os-cloud \\"
            echo "  --project=$project \\"
            echo "  --boot-disk-size=50GB"
            ;;
        ssh)
            echo "# Self-hosted VM - set up manually"
            echo "# Then update .ralph/config.json with:"
            echo "#   vm_ip: <your-vm-ip>"
            echo "#   user: <your-ssh-user>"
            ;;
    esac

    echo ""
    echo "Run this command to create the VM, then update .ralph/config.json"
}
