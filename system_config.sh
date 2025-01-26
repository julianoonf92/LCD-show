#!/bin/bash

big_version=`lsb_release -r | awk -F ' '  '{printf $NF}'`
deb_version=`cat /etc/debian_version | tr -d '\n'`
hw_result=`tr -d '\0' < /proc/device-tree/model`

if [ $(getconf WORD_BIT) = '32' ] && [ $(getconf LONG_BIT) = '64' ] ; then
    hardware_arch=64
else
    hardware_arch=32
fi

if [[ $hw_result == *"Raspberry Pi 5"* ]]; then
    hardware_model=5
else
    hardware_model=255
fi

# Ensure Wayland is enabled
sudo raspi-config nonint do_wayland W1

# Determine the correct config.txt location
if [ -f /boot/firmware/config.txt ]; then
    CONFIG_PATH="/boot/firmware/config.txt"
else
    CONFIG_PATH="/boot/config.txt"
fi

# Backup the original config.txt
sudo cp -rf "$CONFIG_PATH" "$CONFIG_PATH.bak"

# Apply the appropriate config based on architecture and version
if [ $hardware_arch -eq 32 ]; then
    if [ $(($big_version)) -lt 10 ]; then
        sudo cp -rf ./boot/config-wayland-10.9-32.txt "$CONFIG_PATH"
    else
        if [[ "$deb_version" < "10.9" ]] || [[ "$deb_version" = "10.9" ]]; then
            sudo cp -rf ./boot/config-wayland-10.9-32.txt "$CONFIG_PATH"
        elif [[ "$deb_version" < "12.1" ]]; then
            sudo cp -rf ./boot/config-wayland-11.4-32.txt "$CONFIG_PATH"
        else
            sudo cp -rf ./boot/config-wayland-12.1-32.txt "$CONFIG_PATH"
        fi
    fi
elif [ $hardware_arch -eq 64 ]; then
    sudo cp -rf ./boot/config-wayland-11.4-64.txt "$CONFIG_PATH"
fi

# Configure Wayland
if [ ! -d "/etc/xdg/weston" ]; then
    sudo mkdir -p /etc/xdg/weston
fi

# Create or update Weston configuration
cat << EOF | sudo tee /etc/xdg/weston/weston.ini
[core]
backend=drm-backend.so
idle-time=0

[shell]
locking=false
EOF

# Ensure the display manager is set to use Wayland
if [ -f /etc/lightdm/lightdm.conf ]; then
    sudo sed -i 's/^#\?user-session=.*/user-session=wayland/' /etc/lightdm/lightdm.conf
fi

echo "System configured for Wayland. Please reboot for changes to take effect."