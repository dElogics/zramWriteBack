# zramWriteBack
Script to write to the backing_dev in zram at custom regular intervals.

This script will monitor for memory utilization (excluding the utilization of space as used in the backing_dev) of the zram device and as soon as it reaches the --warnth (a percentage value compared to the total size of the disk) this will start flushing the old data (if it's older than -t seconds) to backing_dev. To do this, this will first write 'all' to idle, then after waiting for -t (defaults to 300s), will write 'idle' to the writeback file.

This script also takes a --criticalth (a percentage value compared to the total size of the disk) and if it sees that the current zram memory utilization is more than equal to --criticalth, it will set -t to 1 until percentage zram memory utilization reaches below the --criticalth.

For zram memory utilization between --warnth and --criticalth, the value of -t will reduce as the zram memory utilization increases (and it approaches --criticalth beyond which it will be set to 1). The difference between --warnth and --criticalth is taken and -t it is divided by this difference and rounded off; the value of -t is reduced by this much for each percentage of zram memory utiliation over --warnth. Of course, -t will return to normal values as soon as it the zram memory utilization is under control.

For e.g. --criticalth is 90 (default value) and --warnth is 60 (defaults), their difference is 30 and -t is set to 300 (Defaults). If the current zram memory utilization is 72%, then -- 
Difference between --criticalth and --warnth = 30
reduction in -t for zram memory utilization above 60 and upto 90 = 300/30 = 10. That is for each percentage zram memory utilization above 60, the -t will be reduced by 10 seconds.
For 72% zram memory utilization (which is 12% over the --warnth), this reduction will be 120 seconds or the actual -t will become 180.

This script will do all the above each second (will loop over till eternity). This is a daemon program.

# setup
The directory structure of this repository resembles that of a rootfs. Put the corresponding files in the corresponding places on your machine to set this up.
If you've setup the zram device as '0', the start the service as -- 
```# systemctl daemon-reload; systemctl start zramWriteBack@0.service```
