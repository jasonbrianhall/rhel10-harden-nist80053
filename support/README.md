# RHEL 10 STIG remediation — split by functional area

Your original `rhel10-remediation.yml` (2,160 tasks) was split into separate
playbooks by what they touch, based on keyword matching against each task's
name and module arguments (a heuristic pass — skim before trusting the
boundary blindly, especially `uncategorized.yml`).

| File | Tasks | Dangerous-flagged | Covers |
|---|---:|---:|---|
| `ssh.yml` | 160 | 10 | sshd_config/ssh_config, ciphers, timeouts, root login over SSH |
| `accounts_and_pam.yml` | 372 | 83 | PAM stack, password policy, faillock/account lockout, sudoers, login.defs, user init files |
| `audit_and_logging.yml` | 437 | 35 | auditd rules/config, rsyslog, journald |
| `selinux.yml` | 4 | 3 | SELinux state and policy |
| `filesystem_and_mounts.yml` | 127 | 98 | fstab mount options, partitions, file/dir permissions |
| `kernel_and_bootloader.yml` | 150 | 31 | sysctl, kernel modules, GRUB/bootloader, core dumps |
| `network_and_firewall.yml` | 73 | 9 | firewalld, NetworkManager, IPv4/IPv6 hardening, wireless/bluetooth |
| `software_and_services.yml` | 486 | 42 | package install/removal, systemd service enable/disable/mask, fapolicyd, usbguard |
| `session_and_display.yml` | 61 | 5 | GNOME/dconf, screensaver, login banners, Ctrl-Alt-Del, session/idle timeouts |
| `time_sync_and_mail.yml` | 13 | 0 | chronyd/NTP, postfix, tftp |
| `file_integrity.yml` | 28 | 3 | AIDE |
| `identity_and_smartcard.yml` | 13 | 0 | SSSD, smartcard/PKI |
| `uncategorized.yml` | 236 | 7 | Didn't match a functional keyword — review manually |
| `main.yml` | — | — | imports all of the above in order |

**2,160 tasks total, 326 flagged `dangerous`.**

## Dangerous-task flagging

Within every file (not as a separate file), tasks that can lock you out,
remove software, disable a service, or otherwise change system behavior in a
breaking way — e.g. root login restriction, account lockout policy, package
removal, service masking, `noexec`/`nosuid`/`nodev` mount options, SELinux
enforcing, FIPS crypto policy, GRUB changes — get:

- an extra `dangerous` Ansible tag
- a `# DANGEROUS:` comment directly above the task

Use that tag to control what actually runs:

```bash
# Run everything except dangerous tasks, area by area or all at once
ansible-playbook ssh.yml --skip-tags dangerous
ansible-playbook main.yml --skip-tags dangerous

# Run ONLY the dangerous tasks, once you've reviewed them
ansible-playbook filesystem_and_mounts.yml --tags dangerous
```

## Running it

Each file is a standalone, runnable playbook (`hosts: all`, its own `vars:`
containing only the variables its tasks reference):

```bash
ansible-playbook -i inventory.ini ssh.yml
ansible-playbook -i inventory.ini accounts_and_pam.yml
# ...or all areas together
ansible-playbook -i inventory.ini main.yml
```

## Before running anything tagged `dangerous`

- Test on a snapshot/non-prod VM first.
- Confirm console/iDRAC/iLO/IPMI access independent of SSH — root login
  restrictions, account lockout, and SSH hardening can all lock out remote
  access if misconfigured.
- `accounts_and_pam.yml`: check `var_accounts_passwords_pam_faillock_deny`
  (3 attempts) and `var_accounts_passwords_pam_faillock_unlock_time` (0 =
  indefinite, requires manual unlock) against your actual admin workflow.
- `kernel_and_bootloader.yml` / `selinux.yml`: FIPS crypto policy and
  SELinux-enforcing can break apps relying on non-FIPS algorithms or with
  SELinux policy gaps — test app functionality, not just SSH, afterward.
  GRUB tasks can affect boot if interrupted mid-run.
- `software_and_services.yml`: package-removal and service-mask tasks assume
  nothing else on the box depends on that package/service.

## Notes

- Classification is name/module-argument pattern matching, run once against
  the source file — not a live dependency. Re-run `split_by_function.py` (also
  included) if you edit the source and need to regenerate.
- `community.general.ini_file` (and similar) tasks require the
  `community.general` collection on your control node — same requirement as
  the original playbook.
