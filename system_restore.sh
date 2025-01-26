#!/bin/bash
# Just finished the system, no need to restore
if [ ! -d "./.system_backup" ]; then
    echo "The system is the original version and does not need to be restored"
    exit
fi

# Remove Wayland-specific configurations
if [ -d /etc/xdg/weston ]; then
    sudo rm -rf /etc/xdg/weston
fi

# Restore Wayland configuration if it existed
if [ -f ./.system_backup/weston.ini ]; then
    sudo mkdir -p /etc/xdg/weston
    sudo cp -rf ./.system_backup/weston.ini /etc/xdg/weston/
fi

# Check if /boot/firmware/config.txt exists
if [ -f "/boot/firmware/config.txt" ]; then
    CONFIG_PATH="/boot/firmware/config.txt"
else
    CONFIG_PATH="/boot/config.txt"
fi

# Remove any display-specific dtoverlay
result=`grep -rn "^dtoverlay=" "$CONFIG_PATH" | grep ":rotate=" | tail -n 1`
if [ $? -eq 0 ]; then
    str=`echo -n $result | awk -F: '{printf $2}' | awk -F= '{printf $NF}'`
    sudo rm -rf /boot/overlays/$str-overlay.dtb
    sudo rm -rf /boot/overlays/$str.dtbo
fi

# Restore dtb and dtbo files
ls -al ./.system_backup/*.dtb > /dev/null 2>&1 && sudo cp -rf ./.system_backup/*.dtb  /boot/overlays/
ls -al ./.system_backup/*.dtbo > /dev/null 2>&1 && sudo cp -rf ./.system_backup/*.dtbo  /boot/overlays/

# Restore cmdline.txt, config.txt, and rc.local
sudo cp -rf ./.system_backup/cmdline.txt /boot/
sudo cp -rf ./.system_backup/config.txt "$CONFIG_PATH"
sudo cp -rf ./.system_backup/rc.local /etc/
sudo cp -rf ./.system_backup/modules /etc/

# Restore inittab if it existed
if [ -f /etc/inittab ]; then
    sudo rm -rf /etc/inittab
fi
if [ -f ./.system_backup/inittab ]; then
    sudo cp -rf ./.system_backup/inittab  /etc
fi

# Remove fbtft.conf if it exists
if [ -f /etc/modprobe.d/fbtft.conf ]; then
    sudo rm -rf /etc/modprobe.d/fbtft.conf
fi
# Restore fbtft.conf if it existed in the backup
if [ -f ./.system_backup/fbtft.conf ]; then
    sudo cp -rf ./.system_backup/fbtft.conf  /etc/modprobe.d
fi

# Remove fbcp if it exists
type fbcp > /dev/null 2>&1
if [ $? -eq 0 ]; then
    sudo rm -rf /usr/local/bin/fbcp
fi
# Restore fbcp if it existed in the backup
if [ -f ./.system_backup/have_fbcp ]; then
    sudo install ./rpi-fbcp/build/fbcp /usr/local/bin/fbcp
fi

# Restore the display manager configuration to default
if [ -f /etc/lightdm/lightdm.conf ]; then
    sudo sed -i 's/^user-session=.*/user-session=LXDE-pi/' /etc/lightdm/lightdm.conf
fi

# Remove the .have_installed file if it exists
if [ -f ./.have_installed ]; then
    sudo rm -rf ./.have_installed
fi
# Restore .have_installed if it existed in the backup
if [ -f ./.system_backup/.have_installed ]; then
    sudo cp -rf ./.system_backup/.have_installed ./
fi

sudo sync
sudo sync

echo "The system has been restored"
echo "now reboot"
sleep 1

sudo reboot