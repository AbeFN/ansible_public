#!/bin/bash
# domain_join.sh - Public template (fill in your domain details)

DOMAIN_PASSWORD="${DOMAIN_PASSWORD:-$1}"
FQDN_HOSTNAME="${FQDN_HOSTNAME:-$2}"

LOGFILE="/var/log/domain_join.log"
DOMAIN="yourdomain.com"  # <-- Set your domain
REALM_USER="youruser@YOURDOMAIN.COM"  # <-- Set your domain join user
WEBHOOK_URL="<YOUR_DISCORD_WEBHOOK_URL>"  # <-- Set or leave blank

# Ensure jq is installed before any webhook usage
if ! command -v jq >/dev/null 2>&1; then
  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y jq
fi

exec > >(tee -a "$LOGFILE") 2>&1

send_webhook() {
  local status="$1"
  local color="$2"
  local hostname=$(hostname -f)
  local ip=$(hostname -I | awk '{print $1}')
  local now=$(date)
  local payload=$(jq -n \
    --arg title "Domain Join: $hostname" \
    --arg desc "$status" \
    --arg ip "$ip" \
    --arg time "$now" \
    '{
      username: "Ansible Domain Join",
      embeds: [{
        title: $title,
        color: '$color',
        description: "```\($desc)```",
        footer: { text: $time }
      }]
    }')
  if [[ -n "$WEBHOOK_URL" ]]; then
    curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$WEBHOOK_URL"
  fi
}

trap 'send_webhook "Domain join script failed. See $LOGFILE for details." 15158332' ERR

send_webhook "Domain join script started." 3447003

# Install required packages
apt update
DEBIAN_FRONTEND=noninteractive apt install -y realmd sssd sssd-tools adcli oddjob oddjob-mkhomedir packagekit jq || { send_webhook "Failed to install required packages." 15158332; exit 1; }

dpkg --configure -a

# Ensure SSSD runtime directories exist
mkdir -p /var/lib/sss/db
mkdir -p /var/lib/sss/pipes/private
mkdir -p /var/lib/sss/pipes/public
chown -R root:root /var/lib/sss
chmod 700 /var/lib/sss/db
chmod 700 /var/lib/sss/pipes/private
chmod 755 /var/lib/sss/pipes/public

# Set hostname to FQDN if provided
if [[ -n "$FQDN_HOSTNAME" ]]; then
  hostnamectl set-hostname "$FQDN_HOSTNAME" || { send_webhook "Failed to set hostname." 15158332; exit 1; }
fi

# Update PAM for mkhomedir
sed -i '/pam_mkhomedir.so/d' /etc/pam.d/common-session
echo "session required pam_mkhomedir.so skel=/etc/skel umask=0022" >> /etc/pam.d/common-session

# Use full path for realm to ensure it is found (typically /usr/sbin/realm)
REALM_BIN="/usr/sbin/realm"

# Only join domain and start SSSD if not already joined and keytab is missing
if [ ! -f /etc/krb5.keytab ]; then
  echo "[INFO] Keytab missing, forcing domain re-join..."
  echo "$DOMAIN_PASSWORD" | $REALM_BIN leave || true
  if ! echo "$DOMAIN_PASSWORD" | $REALM_BIN join -U "${REALM_USER^^}" "${DOMAIN^^}" --install=/; then
    send_webhook "Failed to join domain." 15158332
    exit 1
  fi
fi

# Always overwrite /etc/sssd/sssd.conf with the correct config before restarting SSSD
cat > /etc/sssd/sssd.conf <<EOF
[sssd]
domains = yourdomain.com
config_file_version = 2
services = nss

[domain/yourdomain.com]
default_shell = /bin/bash
krb5_store_password_if_offline = True
cache_credentials = True
krb5_realm = YOURDOMAIN.COM
realmd_tags = manages-system joined-with-adcli
id_provider = ad
fallback_homedir = /home/%u@%d
ad_domain = yourdomain.com
use_fully_qualified_names = True
ldap_id_mapping = True
access_provider = ad
ad_gpo_access_control = permissive
ad_gpo_ignore_unreadable = true
ad_access_filter = memberOf=CN=Domain Admins,CN=Users,DC=yourdomain,DC=com
EOF
chown root:root /etc/sssd/sssd.conf
chmod 600 /etc/sssd/sssd.conf
echo "[DEBUG] /etc/sssd/sssd.conf contents after write:" >> "$LOGFILE"
cat /etc/sssd/sssd.conf >> "$LOGFILE"

# Only start SSSD if keytab and config exist
if [ -f /etc/sssd/sssd.conf ] && [ -f /etc/krb5.keytab ]; then
  echo "[INFO] Restarting SSSD..."
  systemctl restart sssd
  SSSD_STATUS=$?
else
  echo "[ERROR] Missing sssd.conf or krb5.keytab, cannot start SSSD."
  send_webhook "Missing sssd.conf or krb5.keytab, cannot start SSSD." 15158332
  exit 1
fi

# Sudo access for domain admins
# Edit the group and domain as needed for your environment
# Example below grants sudo to Domain Admins
# echo "%domain\\ admins@yourdomain.com ALL=(ALL:ALL) ALL" > /etc/sudoers.d/domain_admins
# chmod 440 /etc/sudoers.d/domain_admins

# Discord summary
HOSTNAME=$(hostname)
IP=$(hostname -I | awk '{print $1}')
JOIN_STATUS="SUCCESS"
[ $SSSD_STATUS -ne 0 ] && JOIN_STATUS="SSSD_RESTART_FAILED"

DISCORD_MSG=$(cat <<EOF
**Domain Join Status for \`$HOSTNAME\`**
- **IP**: \`$IP\`
- **Join Result**: \`$JOIN_STATUS\`
EOF
)

if [[ -n "$WEBHOOK_URL" ]]; then
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "$(jq -n --arg content "$DISCORD_MSG" '{content: $content}')" \
       "$WEBHOOK_URL"
fi

# At the end, send a success webhook
send_webhook "Domain join script completed successfully." 3447003

echo "[INFO] Domain join script completed."
