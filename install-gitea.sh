#!/bin/bash

# Variables
GITEA_VERSION="1.23.1"
GITEA_USER="git"
GITEA_GROUP="git"
GITEA_HOME="/home/$GITEA_USER"
GITEA_WORK_DIR="/var/lib/gitea"
GITEA_CUSTOM="/etc/gitea"
GITEA_BINARY="/usr/local/bin/gitea"
GITEA_SERVICE="/etc/systemd/system/gitea.service"
DOWNLOAD_URL="https://dl.gitea.com/gitea/$GITEA_VERSION/gitea-$GITEA_VERSION-linux-amd64"
GPG_KEY="7C9E68152594688862D62AF62D9AE806EC1592E2"

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Install necessary dependencies
apt-get update
apt-get install -y wget git gpg

# Create a system user for Gitea
adduser \
    --system \
    --shell /bin/bash \
    --gecos 'Git Version Control' \
    --group \
    --disabled-password \
    --home "$GITEA_HOME" \
    "$GITEA_USER"

# Create required directory structure
mkdir -p "$GITEA_WORK_DIR"/{custom,data,log}
chown -R "$GITEA_USER":"$GITEA_GROUP" "$GITEA_WORK_DIR"
chmod -R 750 "$GITEA_WORK_DIR"
mkdir -p "$GITEA_CUSTOM"
chown root:"$GITEA_GROUP" "$GITEA_CUSTOM"
chmod 770 "$GITEA_CUSTOM"

# Download Gitea binary
wget -O "$GITEA_BINARY" "$DOWNLOAD_URL"
chmod +x "$GITEA_BINARY"

# Verify GPG signature
wget -O "$GITEA_BINARY.asc" "$DOWNLOAD_URL.asc"
gpg --keyserver keys.openpgp.org --recv "$GPG_KEY" || {
    echo "Failed to fetch GPG key from server. Exiting."
    exit 1
}
gpg --verify "$GITEA_BINARY.asc" "$GITEA_BINARY"
if [ $? -ne 0 ]; then
    echo "GPG verification failed."
    exit 1
fi

# Create systemd service file for Gitea
cat <<EOF > "$GITEA_SERVICE"
[Unit]
Description=Gitea (Git with a cup of tea)
After=network.target

[Service]
User=$GITEA_USER
Group=$GITEA_GROUP
WorkingDirectory=$GITEA_WORK_DIR
ExecStart=$GITEA_BINARY web --config $GITEA_CUSTOM/app.ini
Restart=always
Environment=USER=$GITEA_USER HOME=$GITEA_HOME GITEA_WORK_DIR=$GITEA_WORK_DIR

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start Gitea service
systemctl daemon-reload
systemctl enable --now gitea

# Fetch current system IP
SYSTEM_IP=$(hostname -I | awk '{print $1}')

echo "Gitea installation and service setup complete."
echo "GPG key auto-verified successfully."
echo "Access Gitea at http://$SYSTEM_IP:3000"
