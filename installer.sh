#!/usr/bin/env bash
#
# Script Name: ConfigServer Auto Installer/Uninstaller
# Version: 1.0
# Author: Petal Host
# License: GPL v3
#
# Description:
#   Automated installer/uninstaller for ConfigServer products.
#   Supports multiple control panels and handles noexec /tmp environments safely.
#
# Supported Products:
#   - cmc
#   - cmm
#   - cmq
#   - cse
#   - csf
#
# Supported Panels:
#   - cPanel
#   - CWP
#   - CyberPanel
#   - DirectAdmin
#   - InterWorx
#   - Generic
#   - Vesta
#
# Repository:
#   https://github.com/petal-host/config-server-scripts
#

set -euo pipefail
IFS=$'\n\t'

echo "========================================="
echo "   ConfigServer Auto Installer"
echo "========================================="

#
# Select Control Panel
#

echo
echo "Select your control panel:"
echo "1) cpanel"
echo "2) cwp"
echo "3) cyberpanel"
echo "4) directadmin"
echo "5) interworx"
echo "6) generic"
echo "7) vesta"

read -r -p "Enter the number of your choice: " CP_OPT

case $CP_OPT in
    1) CP="cpanel" ;;
    2) CP="cwp" ;;
    3) CP="cyberpanel" ;;
    4) CP="directadmin" ;;
    5) CP="interworx" ;;
    6) CP="generic" ;;
    7) CP="vesta" ;;
    *)
        echo "Invalid control panel option."
        exit 1
        ;;
esac

#
# Select Product
#

echo
echo "Select the ConfigServer product:"
echo "1) cmc"
echo "2) cmm"
echo "3) cmq"
echo "4) cse"
echo "5) csf"

read -r -p "Enter the number of your choice: " PROD_OPT

case $PROD_OPT in
    1) PROD="cmc" ;;
    2) PROD="cmm" ;;
    3) PROD="cmq" ;;
    4) PROD="cse" ;;
    5) PROD="csf" ;;
    *)
        echo "Invalid product option."
        exit 1
        ;;
esac

#
# Install or Uninstall
#

echo
read -r -p "Do you want to install or uninstall? [i/u]: " ACTION

case $ACTION in
    i|I)
        MODE="install"
        ;;
    u|U)
        MODE="uninstall"
        ;;
    *)
        echo "Invalid action."
        exit 1
        ;;
esac

#
# Create Temporary Working Directory
#

TMP_DIR=$(mktemp -d 2>/dev/null || python3 -c "import tempfile; print(tempfile.mkdtemp())")

trap 'rm -rf "$TMP_DIR"' EXIT

cd "$TMP_DIR"

#
# Function: Detect noexec mount
#

is_noexec() {
    local dir="$1"

    local opts
    opts=$(findmnt -no OPTIONS --target "$dir" 2>/dev/null || true)

    if [[ "$opts" == *"noexec"* ]]; then
        return 0
    fi

    return 1
}

#
# Function: Execute script safely
#

execute_script_with_sudo() {
    local script_path="$1"

    if command -v bash >/dev/null 2>&1; then
        sudo bash "$script_path"
    else
        sudo /bin/sh "$script_path"
    fi
}

#
# INSTALL
#

if [[ "$MODE" == "install" ]]; then

    TGZ_URL="https://raw.githubusercontent.com/petal-host/config-server-scripts/main/${PROD}.tgz"

    echo
    echo "Downloading ${PROD} package..."
    echo "Source: ${TGZ_URL}"

    curl -fL -o "${PROD}.tgz" "$TGZ_URL"

    echo
    echo "Extracting package..."

    tar xzf "${PROD}.tgz"

    cd "$PROD"

    #
    # Determine installer script
    #

    if [[ "$PROD" == "csf" ]]; then
        SCRIPT="install.${CP}.sh"
    else
        SCRIPT="install.sh"
    fi

    #
    # Validate installer exists
    #

    if [[ ! -f "$SCRIPT" ]]; then
        echo
        echo "ERROR: Install script not found:"
        echo "$SCRIPT"
        exit 1
    fi

    echo
    echo "Running installer..."

    chmod a+r "$SCRIPT" || true

    #
    # Handle noexec environments
    #

    if is_noexec "$TMP_DIR"; then

        echo
        echo "Detected noexec temporary directory."
        echo "Copying installer to /usr/local/src/configserver_installer"

        sudo mkdir -p /usr/local/src/configserver_installer

        sudo cp -a . /usr/local/src/configserver_installer/

        TARGET="/usr/local/src/configserver_installer/$SCRIPT"

        execute_script_with_sudo "$TARGET"

    else

        execute_script_with_sudo "$PWD/$SCRIPT"

    fi

    echo
    echo "========================================="
    echo " Installation completed successfully."
    echo "========================================="

else

    #
    # UNINSTALL
    #

    if [[ "$PROD" == "csf" ]]; then

        URL="https://raw.githubusercontent.com/petal-host/config-server-scripts/main/uninstallers/csf/uninstall.${CP}.sh"

    else

        URL="https://raw.githubusercontent.com/petal-host/config-server-scripts/main/uninstallers/${PROD}/${PROD}_uninstall.sh"

    fi

    echo
    echo "Downloading uninstaller..."
    echo "Source: ${URL}"

    curl -fsSL "$URL" -o uninstall.tmp.sh

    chmod a+r uninstall.tmp.sh || true

    echo
    echo "Running uninstaller..."

    sudo bash uninstall.tmp.sh

    echo
    echo "========================================="
    echo " Uninstallation completed successfully."
    echo "========================================="

fi
