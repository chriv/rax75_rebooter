# Automated Rebooter for RAX75 Series Routers

A Bash-based systemd service to automatically reboot RAX75 (AX5400) routers on a schedule. This script handles authentication against the web interface (which uses a multi-step challenge), triggers the reboot, and verifies the result.

## Prerequisites

Before installing, ensure your environment is configured to talk to the router securely.

### 1. DNS Configuration
The web interface expects to be accessed via `www.routerlogin.net`.
* **Option A (Internal DNS):** Add an A record on your local DNS server for `www.routerlogin.net` pointing to your router's IP (e.g., `192.168.1.1`).
* **Option B (/etc/hosts):** Add the entry manually to the machine running this script:
    ```text
    192.168.1.1  www.routerlogin.net
    192.168.1.1  routerlogin.net
    ```

### 2. SSL Certificate Trust
The router uses a self-signed certificate for `www.routerlogin.net`. If you set `INSECURE=0` in the config (recommended), you must trust this certificate.

**To install the certificate on Ubuntu/Debian:**
```bash
# 1. Fetch the certificate
echo -n | openssl s_client -connect www.routerlogin.net:443 -servername www.routerlogin.net \
    | openssl x509 -outform PEM > /usr/local/share/ca-certificates/rax75_web.crt

# 2. Update the trust store
sudo update-ca-certificates
```

## Installation

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/YOUR_USERNAME/rax75-rebooter.git](https://github.com/YOUR_USERNAME/rax75-rebooter.git)
    cd rax75-rebooter
    ```

2.  **Configure credentials:**
    Copy the sample config and edit it with your router password.
    ```bash
    cp config.env.sample config.env
    nano config.env
    ```
    *Note: `config.env` is excluded from git to protect your password.*

3.  **Run the installer:**
    ```bash
    chmod +x setup.sh rebootrax75.sh
    sudo ./setup.sh
    ```

The installer will:
* Perform a "Dry Run" to verify connectivity and credentials.
* Install the script to `/usr/local/bin/rebootrax75`.
* Install the config to `/etc/rebootrax75/config.env` (Permissions 0600).
* Enable and start the systemd timer.

## Usage

**Check Status:**
```bash
systemctl list-timers --all | grep rebootrax75
```

**Manual Run:**
```bash
sudo systemctl start rebootrax75.service
```

**View Logs:**
```bash
journalctl -u rebootrax75.service
```
