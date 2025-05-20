#!/bin/bash
LOGFILE="/var/log/first_boot.log"
exec > >(tee -a "$LOGFILE") 2>&1

STATUS_LOG="/tmp/firstboot_status.log"
WEBHOOK_URL="<YOUR_DISCORD_WEBHOOK_URL>"  # <-- Set this to your Discord webhook or leave blank to disable

report_step() {
  local msg="$1"
  local code=$2
  if [[ $code -eq 0 ]]; then
    echo "✅ $msg" >> "$STATUS_LOG"
  else
    echo "❌ $msg (exit code $code)" >> "$STATUS_LOG"
    report_summary "ERROR: $msg (exit code $code)"
  fi
}

report_summary() {
  local status=$(cat "$STATUS_LOG")
  local hostname=$(hostname -f)
  local ip=$(hostname -I | awk '{print $1}')
  local now=$(date)
  local error_msg="$1"

  local payload=$(jq -n \
    --arg title "First Boot Summary: $hostname" \
    --arg desc "$status" \
    --arg ip "$ip" \
    --arg time "$now" \
    --arg error "$error_msg" \
    '{
      username: "Ansible First Boot",
      embeds: [{
        title: $title,
        color: ($error == "" ? 3447003 : 15158332),
        description: "```\($desc)```\n\($error)",
        footer: { text: $time }
      }]
    }')

  if [[ -n "$WEBHOOK_URL" ]]; then
    curl -s -X POST -H "Content-Type: application/json" \
      -d "$payload" "$WEBHOOK_URL"
  fi
}

# 1. Set hostname
if [[ -f /etc/new_hostname ]]; then
  HOSTNAME_FILE=$(cat /etc/new_hostname)
  hostnamectl set-hostname "$HOSTNAME_FILE"
  cat > /etc/hosts <<EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME_FILE $HOSTNAME_FILE
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF
  rm -f /etc/new_hostname
  report_step "Hostname set to $HOSTNAME_FILE and /etc/hosts updated" $?
else
  report_step "Hostname file missing, skipped hostname update" 1
fi

# 2. System update
apt update && apt full-upgrade -y
report_step "System upgraded" $?

# 3. Install required packages
apt install -y jq realmd sssd adcli oddjob oddjob-mkhomedir packagekit samba-common-bin \
  sudo libnss-sss libpam-sss sssd-tools ufw curl
report_step "Required packages installed" $?

# 4. Enable UFW and allow SSH
ufw allow OpenSSH
ufw --force enable
report_step "UFW enabled and SSH allowed" $?

# 5. Disable and remove this firstboot service
systemctl disable firstboot.service
rm -f /etc/systemd/system/firstboot.service /usr/local/bin/first_boot.sh
report_step "Firstboot service disabled and cleaned up" $?

# 6. Discord notification
report_summary

# 7. Domain join will follow after Ansible resumes — no reboot needed
report_step "Firstboot complete — system ready for domain join" $?
