#!/bin/bash

VM_IP_FILE=".vm_ip"
AWS_REGION="${AWS_REGION:-}"

# If no argument, boot the VM
if [ -z "$1" ]; then
    #read -p "RHEL subscription username: " RHEL_USER
    #read -sp "RHEL subscription password: " RHEL_PASS
    #ansible-playbook ec2_boot_playbook.yml -e "rhel_username=${RHEL_USER}" -e "rhel_password=${RHEL_PASS}"

    ansible-playbook ec2_boot_playbook.yml

    if [ ! -f "$VM_IP_FILE" ]; then
        echo "Error: .vm_ip was not created by the playbook"
        exit 1
    fi

    echo "VM IP saved: $(cat "$VM_IP_FILE")"
    exit 0
fi

# Get VM IP from saved file or query AWS
if [ -f "$VM_IP_FILE" ]; then
    VM_IP=$(cat "$VM_IP_FILE")
else
    # Find the most recently launched matching instance by Name tag
    INSTANCE_ID=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=rhel-hardened-*" "Name=instance-state-name,Values=running" \
        --query 'Instances[*].[InstanceId,LaunchTime]' \
        --output text 2>/dev/null | sort -k2 | tail -1 | awk '{print $1}')

    if [ -n "$INSTANCE_ID" ]; then
        VM_IP=$(aws ec2 describe-instances \
            --region "$AWS_REGION" \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress]' \
            --output text 2>/dev/null | awk '{print ($1 != "None") ? $1 : $2}')
    fi
fi

if [ -z "$VM_IP" ]; then
    echo "Error: Could not find VM IP. Is the instance running?"
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
        ansible-playbook -i "$VM_IP", support/customize.yml
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
    customize)
        ansible-playbook -i "$VM_IP", support/customize.yml
        ;;
    check_oscap)
        ansible-playbook -i "$VM_IP", support/scap_stig_scan.yml
        if [ -f ".oscap_score" ]; then
            echo "OSCAP STIG compliance score: $(cat .oscap_score)%"
        fi
        ;;

    create_ami)
        INSTANCE_ID_FILE=".vm_instance_id"
        if [ -f "$INSTANCE_ID_FILE" ]; then
            INSTANCE_ID=$(cat "$INSTANCE_ID_FILE")
        else
            # Fall back to resolving instance ID from the VM IP
            INSTANCE_ID=$(aws ec2 describe-instances \
                --region "$AWS_REGION" \
                --filters "Name=ip-address,Values=$VM_IP" "Name=instance-state-name,Values=running" \
                --query 'Reservations[0].Instances[0].InstanceId' \
                --output text 2>/dev/null)
            if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
                INSTANCE_ID=$(aws ec2 describe-instances \
                    --region "$AWS_REGION" \
                    --filters "Name=private-ip-address,Values=$VM_IP" "Name=instance-state-name,Values=running" \
                    --query 'Reservations[0].Instances[0].InstanceId' \
                    --output text 2>/dev/null)
            fi
        fi

        if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
            echo "Error: Could not resolve instance ID for VM IP $VM_IP"
            exit 1
        fi

        AMI_NAME="rhel-hardened-ami-$(date +%Y%m%d%H%M%S)"

        echo "About to create an AMI from instance: $INSTANCE_ID (IP: $VM_IP)"
        echo "AMI name: $AMI_NAME"
        read -p "Proceed with AMI creation? [y/N] " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
            echo "AMI creation cancelled."
            exit 0
        fi

        AMI_ID=$(aws ec2 create-image \
            --region "$AWS_REGION" \
            --instance-id "$INSTANCE_ID" \
            --name "$AMI_NAME" \
            --description "Hardened RHEL10 image created from $INSTANCE_ID on $(date)" \
            --query 'ImageId' --output text)

        if [ -z "$AMI_ID" ] || [ "$AMI_ID" = "None" ]; then
            echo "Error: AMI creation failed"
            exit 1
        fi

        echo "AMI creation started: $AMI_ID"
        echo "Waiting for AMI to become available (this can take several minutes)..."
        aws ec2 wait image-available --region "$AWS_REGION" --image-ids "$AMI_ID"
        echo "AMI ready: $AMI_ID"
        echo "$AMI_ID" > .vm_ami_id
        ;;

    *)
        echo "Usage: $0 [boot|hardening|ssh|accounts|audit|selinux|filesystem|kernel|network|software|session|time|integrity|identity|uncategorized|customize|check_oscap|create_ami]"
        echo ""
        echo "  $0              - Boot the EC2 instance"
        echo "  $0 hardening    - Run all hardening playbooks"
        echo "  $0 ssh          - Run SSH hardening only"
        echo "  $0 accounts     - Run accounts and PAM hardening only"
        echo "  $0 check_oscap  - Run OpenSCAP STIG compliance scan"
        echo "  $0 create_ami   - Create an AMI from the instance (asks for confirmation)"
        echo "  ... and so on for each hardening module"
        exit 1
        ;;
esac
