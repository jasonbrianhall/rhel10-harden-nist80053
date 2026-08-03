#!/bin/bash

VM_IP_FILE=".vm_ip"

# If no argument, boot the VM
if [ -z "$1" ]; then
    ansible-playbook kvm_boot_playbook.yml --ask-become-pass -e "save_ip_file=$VM_IP_FILE"
    
    if [ -z "$VM_IP" ]; then
        echo "Error: Could not extract VM IP from playbook output"
        exit 1
    fi
    
    # Save it for hardening commands
    echo "$VM_IP" > "$VM_IP_FILE"
    echo "VM IP saved: $VM_IP"
    exit $?
fi

# Get VM IP from saved file or query virsh
if [ -f "$VM_IP_FILE" ]; then
    VM_IP=$(cat "$VM_IP_FILE")
else
    # Get VM IP from the last VM created
    VM_NAME=$(virsh list --all | grep rhel-hardened | tail -1 | awk '{print $2}')
    VM_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep ipv4 | awk '{print $4}' | cut -d'/' -f1)
fi

if [ -z "$VM_IP" ]; then
    echo "Error: Could not find VM IP. Is the VM running?"
    exit 1
fi

echo "Using VM IP: $VM_IP"

# Run hardening playbooks based on argument
case "$1" in
    hardening)
        # Run all hardening playbooks
        ansible-playbook -i "$VM_IP", support/ssh.yml
        ansible-playbook -i "$VM_IP", support/accounts_and_pam.yml
        ansible-playbook -i "$VM_IP", support/audit_and_logging.yml
        ansible-playbook -i "$VM_IP", support/selinux.yml
        ansible-playbook -i "$VM_IP", support/filesystem_and_mounts.yml
        ansible-playbook -i "$VM_IP", support/kernel_and_bootloader.yml
        ansible-playbook -i "$VM_IP", support/network_and_firewall.yml
        ansible-playbook -i "$VM_IP", support/software_and_services.yml
        ansible-playbook -i "$VM_IP", support/session_and_display.yml
        ansible-playbook -i "$VM_IP", support/time_sync_and_mail.yml
        ansible-playbook -i "$VM_IP", support/file_integrity.yml
        ansible-playbook -i "$VM_IP", support/identity_and_smartcard.yml
        ansible-playbook -i "$VM_IP", support/uncategorized.yml
        ;;
    ssh)
    	ansible-playbook -i "$VM_IP", support/ssh.yml
        ;;
    accounts)
        ansible-playbook -i "$VM_IP", support/accounts_and_pam.yml
        ;;
    audit)
        ansible-playbook -i "$VM_IP", support/audit_and_logging.yml
        ;;
    selinux)
        ansible-playbook -i "$VM_IP", support/selinux.yml
        ;;
    filesystem)
        ansible-playbook -i "$VM_IP", support/filesystem_and_mounts.yml
        ;;
    kernel)
        ansible-playbook -i "$VM_IP", support/kernel_and_bootloader.yml
        ;;
    network)
        ansible-playbook -i "$VM_IP", support/network_and_firewall.yml
        ;;
    software)
        ansible-playbook -i "$VM_IP", support/software_and_services.yml
        ;;
    session)
        ansible-playbook -i "$VM_IP", support/session_and_display.yml
        ;;
    time)
        ansible-playbook -i "$VM_IP", support/time_sync_and_mail.yml
        ;;
    integrity)
        ansible-playbook -i "$VM_IP", support/file_integrity.yml
        ;;
    identity)
        ansible-playbook -i "$VM_IP", support/identity_and_smartcard.yml
        ;;
    uncategorized)
        ansible-playbook -i "$VM_IP", support/uncategorized.yml
        ;;
    *)
        echo "Usage: $0 [boot|hardening|ssh|accounts|audit|selinux|filesystem|kernel|network|software|session|time|integrity|identity|uncategorized]"
        echo ""
        echo "  $0              - Boot the VM"
        echo "  $0 hardening    - Run all hardening playbooks"
        echo "  $0 ssh          - Run SSH hardening only"
        echo "  $0 accounts     - Run accounts and PAM hardening only"
        echo "  ... and so on for each hardening module"
        exit 1
        ;;
esac
