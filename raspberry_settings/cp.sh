#!/bin/bash
cp /home/maxat/Projects/Agrarka/scales-installer/raspberry_settings/setup_bullseye.sh /media/maxat/rootfs/home/pi/
cp /home/maxat/Projects/Agrarka/scales-installer/raspberry_settings/wpa_supplicant.conf /media/maxat/bootfs/wpa_supplicant.conf
cp -rp /home/maxat/Projects/Agrarka/scales-installer/raspberry_settings/getty@tty1.service.d /media/maxat/rootfs/etc/systemd/system/
cp /home/maxat/Projects/Agrarka/scales-installer/raspberry_settings/config.txt /media/maxat/bootfs/