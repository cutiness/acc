# Busybox Setup
# Copyright (c) 2019-2020, VR25 (xda-developers)
# License: GPLv3+

if [ -d /sbin/.magisk/busybox ]; then
  [[ $PATH == /sbin/.magisk/busybox:* ]] || PATH=/sbin/.magisk/busybox:$PATH
else
  mkdir -p -m 700 /dev/.busybox
  [[ $PATH == /dev/.busybox:* ]] || PATH=/dev/.busybox:$PATH
  if [ ! -x /dev/.busybox/busybox ]; then
    if which busybox > /dev/null; then
      busybox --install -s /dev/.busybox
    elif [ -f /data/adb/busybox ]; then
      chmod 700 /data/adb/busybox
      /data/adb/busybox --install -s /dev/.busybox
    else
      echo "(!) Install busybox binary first"
      exit 3
    fi
  fi
fi