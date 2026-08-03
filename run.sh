#!/bin/bash
ANSIBLE_CONFIG=~/.ansible/ansible.cfg ansible-playbook kvm_boot_playbook.yml --ask-become-pass
