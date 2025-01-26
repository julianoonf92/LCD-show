#!/bin/bash
cur_dir=`pwd`
if [ ! -f $cur_dir/.have_installed ]; then
    echo "Please install the LCD driver first"
    echo "Usage: sudo ./xxx-show. xxx: MHS35,LCD35,MPI3508 etc."
    exit
fi

print_info()
{
    echo "Usage:sudo ./rotate.sh [0] [90] [180] [270] [360] [450]"
    echo "0-Screen rotation 0 degrees"
    echo "90-Screen rotation 90 degrees"
    echo "180-Screen rotation 180 degrees"
    echo "270-Screen rotation 270 degrees"
    echo "360-Screen flip horizontal(Valid only for HDMI screens)"
    echo "450-Screen flip vertical(Valid only for HDMI screens)"
}

if [ $# -eq 0 ]; then
    echo "Please input parameter:0,90,180,270,360,450"
    print_info
    exit
elif [ $# -eq 1 ]; then
    if [ ! -n "$(echo $1| sed -n "/^[0-9]\+$/p")" ]; then
        echo "Invalid parameter"
        print_info
        exit
    else
        if [ $1 -ne 0 ] && [ $1 -ne 90 ] && [ $1 -ne 180 ] && [ $1 -ne 270 ] && [ $1 -ne 360 ] && [ $1 -ne 450 ]; then
            echo "Invalid parameter"
            print_info
            exit
        fi
    fi
else
    echo "Too many parameters, only one parameter allowed"
    exit
fi

# Get screen parameter
tmp=`cat $cur_dir/.have_installed`
output_type=`cat $cur_dir/.have_installed | awk -F ':' '{printf $1}'`
touch_type=`cat $cur_dir/.have_installed | awk -F ':' '{printf $2}'`
device_id=`cat $cur_dir/.have_installed | awk -F ':' '{printf $3}'`
default_value=`cat $cur_dir/.have_installed | awk -F ':' '{printf $4}'`
width=`cat $cur_dir/.have_installed | awk -F ':' '{printf $5}'`
height=`cat $cur_dir/.have_installed | awk -F ':' '{printf $6}'`

# Determine config.txt location
if [ -f "/boot/firmware/config.txt" ]; then
    CONFIG_PATH="/boot/firmware/config.txt"
else
    CONFIG_PATH="/boot/config.txt"
fi

if [ $output_type = "hdmi" ]; then
    result=`grep -rn "^display_rotate=" $CONFIG_PATH | tail -n 1`
    line=`echo -n $result | awk -F: '{printf $1}'`
    str=`echo -n $result | awk -F: '{printf $NF}'`
    old_rotate_value=`echo -n $result | awk -F= '{printf $NF}'`
    if [ $old_rotate_value = "0x10000" ]; then
        old_rotate_value=4
    elif  [ $old_rotate_value = "0x20000" ]; then
        old_rotate_value=5
    fi
    if [ $1 -eq 0 ] || [ $1 -eq 90 ] || [ $1 -eq 180 ] || [ $1 -eq 270 ]; then
        new_rotate_value=$[(($default_value+$1)%360)/90]
    else
        new_rotate_value=$[$1/90]
    fi
elif [ $output_type = "gpio" ]; then
    result=`grep -rn "^dtoverlay=" $CONFIG_PATH | grep ":rotate=" | tail -n 1`
    line=`echo -n $result | awk -F: '{printf $1}'`
    str=`echo -n $result | awk -F: '{printf $NF}'`
    old_rotate_value=`echo -n $result | awk -F= '{printf $NF}'`
    if [ $1 -eq 0 ] || [ $1 -eq 90 ] || [ $1 -eq 180 ] || [ $1 -eq 270 ]; then
        new_rotate_value=$[($default_value+$1)%360]
    else
        echo "Invalid parameter: only for HDMI screens"
        exit
    fi
else
    echo "Invalid output type"
    exit
fi

if [ $old_rotate_value -eq $new_rotate_value ]; then
    if [ $output_type = "hdmi" ]; then
        if [ $1 -eq 0 ] || [ $1 -eq 90 ] || [ $1 -eq 180 ] || [ $1 -eq 270 ]; then
            old_rotate_value=$[($old_rotate_value*90+360-$default_value)%360]
        else
            old_rotate_value=$[$old_rotate_value*90]
        fi
    elif [ $output_type = "gpio" ]; then
        old_rotate_value=$[($old_rotate_value+360-$default_value)%360]
    fi
    echo "Current rotate value is $old_rotate_value"
    exit
fi

# Setting LCD rotate
if [ $output_type = "hdmi" ]; then
    if [ $new_rotate_value -eq 4 ]; then
        sudo sed -i --follow-symlinks -e ''"$line"'s/'"$str"'/display_rotate=0x10000/' $CONFIG_PATH
    elif  [ $new_rotate_value -eq 5 ]; then
        sudo sed -i --follow-symlinks -e ''"$line"'s/'"$str"'/display_rotate=0x20000/' $CONFIG_PATH
    else
        sudo sed -i --follow-symlinks -e ''"$line"'s/'"$str"'/display_rotate='"$new_rotate_value"'/' $CONFIG_PATH
    fi
    new_rotate_value=$[$new_rotate_value*90]
elif [ $output_type = "gpio" ]; then
    sudo sed -i --follow-symlinks -e ''"$line"'s/'"$str"'/rotate='"$new_rotate_value"'/' $CONFIG_PATH
    resultr=`grep -rn "^hdmi_cvt" $CONFIG_PATH | tail -n 1 | awk -F' ' '{print $1,$2,$3}'`
    if [ -n "$resultr" ]; then
        liner=`echo -n $resultr | awk -F: '{printf $1}'`
        strr=`echo -n $resultr | awk -F: '{printf $2}'`
        if [ $new_rotate_value -eq $default_value ] || [ $new_rotate_value -eq $[($default_value+180+360)%360] ]; then
            sudo sed -i --follow-symlinks -e ''"$liner"'s/'"$strr"'/hdmi_cvt '"$width"' '"$height"'/' $CONFIG_PATH
        elif [ $new_rotate_value -eq $[($default_value-90+360)%360] ] || [ $new_rotate_value -eq $[($default_value+90+360)%360] ]; then
            sudo sed -i --follow-symlinks -e ''"$liner"'s/'"$strr"'/hdmi_cvt '"$height"' '"$width"'/' $CONFIG_PATH
        fi
    fi
fi

# Setting touch screen rotate for Wayland
if [ $touch_type = "resistance" ] || [ $touch_type = "capacity" ]; then
    # Create or modify the Wayland input configuration file
    WAYLAND_CONFIG="/etc/xdg/weston/weston.ini"
    sudo mkdir -p /etc/xdg/weston
    
    if [ ! -f "$WAYLAND_CONFIG" ]; then
        echo "[libinput]" | sudo tee $WAYLAND_CONFIG
    fi

    # Remove any existing rotation configuration
    sudo sed -i '/^rotation=/d' $WAYLAND_CONFIG

    # Add new rotation configuration
    case $new_rotate_value in
        0)   echo "rotation=normal" | sudo tee -a $WAYLAND_CONFIG ;;
        90)  echo "rotation=90" | sudo tee -a $WAYLAND_CONFIG ;;
        180) echo "rotation=180" | sudo tee -a $WAYLAND_CONFIG ;;
        270) echo "rotation=270" | sudo tee -a $WAYLAND_CONFIG ;;
        360) echo "rotation=flipped" | sudo tee -a $WAYLAND_CONFIG ;;
        450) echo "rotation=flipped-270" | sudo tee -a $WAYLAND_CONFIG ;;
    esac

    echo "LCD rotate value is set to $1"
else
    echo "Invalid touch type"
    exit
fi

sudo sync
sudo sync

echo "reboot now"
sleep 1
sudo reboot