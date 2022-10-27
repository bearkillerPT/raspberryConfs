printf -v currentDate '%(%d%m%Y)T' ;
ssh pi@bearkillerpt.xyz 'sudo dd if=/dev/mmcblk0 bs=1M | gzip -' | dd of="/mnt/Users/gil-t/Desktop/pi/backup${currentDate}.gz" status=progress
