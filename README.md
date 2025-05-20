# Automated Debian/Ubuntu VM Provisioning & Active Directory Domain Join with Ansible

A step-by-step, production-ready Ansible solution for provisioning Debian/Ubuntu VMs, performing first-boot configuration, and joining them to Active Directory Domain, with Discord notifications. Designed for vSphere (VMware) environments.



---

## Table of Contents
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration: What to Edit](#configuration-what-to-edit)
- [Step-by-Step Usage](#step-by-step-usage)
- [Customization](#customization)
- [Versioning](#versioning)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Features
- **Automated VM Provisioning:** Clone VMs from a template using vSphere.
- **First Boot Automation:** Set hostname, update system, install packages, configure firewall, and send notifications.
- **Active Directory Join:** Securely join VMs to AD and configure SSSD for domain logins.
- **Domain Admin Sudo:** Domain Admins get passwordless sudo.
- **Discord Notifications:** Real-time deployment and join status updates.

---

## Prerequisites

**On your vCenter template VM:**
- OS: Debian 11/12 or Ubuntu 20.04/22.04
- Hostname: `localhost` (will be changed by Ansible)
- Network: DHCP enabled, network accessible from Ansible control node
- SSH enabled, with a user that has passwordless sudo
  - To create a user with passwordless sudo:
    ```sh
    sudo adduser ansible
    sudo usermod -aG sudo ansible
    echo 'ansible ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/ansible
    sudo chmod 0440 /etc/sudoers.d/ansible
    ```
- Cloud-init disabled (if using static customization)
  - To disable cloud-init:
    ```sh
    sudo touch /etc/cloud/cloud-init.disabled
    ```
- Packages pre-installed: `python3`, `openssh-server`, `docker` (if needed), etc.
  - To install required packages:
    ```sh
    sudo apt update
    sudo apt install -y python3 openssh-server docker.io
    ```
- VM powered off and converted to template
  - In vCenter, right-click the VM and select "Convert to Template".

**On your Ansible control node:**
- Ansible (v2.9+)
- Python 3.x
- Access to vCenter/vSphere with permissions to clone VMs
- Active Directory account with join rights
  - It is recommended to create a dedicated service account in AD for domain join (e.g., `svc_vmjoin`).
- Discord webhook URL (optional)

---

## Quick Start

1. **Clone this repository:**
   ```sh
   git clone https://github.com/YOURUSER/ansible_public.git
   cd ansible_public
   ```

2. **Install Ansible and set up a Python virtual environment:**

   ### On macOS or Linux
   ```sh
   python3 -m venv venv
   source venv/bin/activate
   pip install --upgrade pip
   pip install ansible
   ```
   - To activate the virtual environment later, run:
     ```sh
     source venv/bin/activate
     ```
   - To deactivate when finished:
     ```sh
     deactivate
     ```

   ### On Windows (using Command Prompt)
   ```bat
   python -m venv venv
   venv\Scripts\activate
   python -m pip install --upgrade pip
   pip install ansible
   ```
   - To activate later: `venv\Scripts\activate`
   - To deactivate: `deactivate`

   ### On Windows (using PowerShell)
   ```powershell
   python -m venv venv
   .\venv\Scripts\Activate.ps1
   python -m pip install --upgrade pip
   pip install ansible
   ```
   - To activate later: `.\venv\Scripts\Activate.ps1`
   - To deactivate: `deactivate`

---

## Configuration: What to Edit

Before running, edit the following files and replace all placeholder values (marked with `CHANGE_ME` or similar comments):

- `inventory.ini`:  
  - Set your vCenter server, template name, datacenter, cluster, and credentials.
- `01_provision_vm.yaml`:  
  - Check and update VM template, network, and customization settings.
- `02_domain_join.yaml`:  
  - Set your AD domain, OU, and join account (use Ansible Vault for passwords).
- `files/first_boot.sh` and `files/domain_join.sh`:  
  - Update domain, user, and webhook placeholders.
- `files/firstboot.service` and `files/domainjoin.service`:  
  - No changes needed unless customizing service names.

**All files have inline comments to guide you.**

---

## Step-by-Step Usage

1. **Provision and configure a new VM:**
   ```zsh
   ansible-playbook -i inventory.ini 01_provision_vm.yaml
   ```
   - Enter vCenter password and VM short name when prompted.

2. **Wait for first boot to complete** (watch for Discord notification, if enabled).

3. **Join the VM to Active Directory:**
   ```zsh
   ansible-playbook -i inventory.ini --extra-vars "domain_password=YOUR_DOMAIN_PASSWORD" 02_domain_join.yaml
   ```
   - Replace `YOUR_DOMAIN_PASSWORD` with your AD join account password.

4. **Login to the VM:**
   - Use your domain credentials (e.g., `user@domain.com`).
   - Domain Admins have passwordless sudo.

---

## Customization

- Edit playbooks and scripts in `files/` to match your environment.
- Adjust inventory and group variables as needed.
- Use [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html) for sensitive data.

---

## Versioning

This repository uses [git tags](https://git-scm.com/book/en/v2/Git-Basics-Tagging) for versioning. Releases are available in the GitHub Releases section.

---

## Troubleshooting

- Ensure your template VM meets all prerequisites.
- Check Ansible output for errors.
- Review logs on the VM: `/var/log/first_boot.log`, `/var/log/domain_join.log`
- For Discord issues, verify your webhook URL.

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

**For questions or improvements, open an issue or pull request.**

---

### SEO/Discoverability Tips

- Use common keywords in your README and repo description (see above).
- In GitHub, add topics/tags like: `ansible`, `debian`, `ubuntu`, `vmware`, `active-directory`, `automation`, `provisioning`.
- Write a concise project description in GitHub settings.
- Share your repo on relevant forums or communities.

- **Keywords:** ansible, debian, ubuntu, vmware, vsphere, active directory, domain join, automation, discord, sssd, devops, provisioning
