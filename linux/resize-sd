#!/usr/bin/env bash
# Resize root partition to use the entire disk
# See https://karelzak.blogspot.com/2015/05/resize-by-sfdisk.html
echo ", +" | sfdisk --force -N 2 /dev/mmcblk0
echo "Reboot required. Reboot using 'reboot'"
