#!/sbin/sh
# workaround script by steadfasterX to ensure time is correct

LOG=/tmp/recovery.log
F_LOG(){
   MSG="$1"
   echo "I:$TAG: $(date +%F_%T) - $MSG" >> $LOG
}
F_ELOG(){
   MSG="$1"
   echo "E:$TAG: $(date +%F_%T) - $MSG" >> $LOG
}

TAG="READTIME"
F_LOG "Starting $0"
F_LOG "timeadjust before setprop: >$(getprop persist.sys.timeadjust)<"
if [ -r /data/property/persist.sys.timeadjust ];then
    setprop persist.sys.timeadjust $(cat /data/property/persist.sys.timeadjust)
    F_LOG "setting persist.sys.timeadjust ended with $?"
    # trigger the timekeep daemon
    setprop twrp.timeadjusted 1
else
    FSTABHERE=0
    F_LOG "checking /data"
    mount |grep -q "/data"
    MNTERR=$?
    F_LOG "No /data in fstab yet! will wait until its there.."
    while [ "$FSTABHERE" -eq 0 ];do
        sleep 2
        grep -q "/data" /etc/fstab && FSTABHERE=1
    done
    F_LOG "/data detected: >$(grep "/data" /etc/fstab)<"

    if [ -d /data/property ];then
        F_LOG "skipping mount /data as it is already mounted"
    else
        F_LOG "mounting /data to access time offset from ROM"
        mount /data >>$LOG 2>&1
        F_LOG "mounting /data ended with <$?>"
    fi

    # if we detect the proprietary time_daemon file ats_2 we start the qcom time_daemon
    # but when not we assume the open source timekeep daemon and starting that instead
    # That also means: 
    # When you switch between e.g. CM and STOCK ROMs you may get not the expected results.
    # The reason is that you have to do a factory reset after switching the ROM base
    # OR delete either: 
    #    - /data/system/time/ats_2 or /data/time/ats_2 (when switching from STOCK to CM/AOSP/..) 
    # OR:
    #    - /data/property/persist.sys.timeadjust (when switching from CM/AOSP/... to STOCK)
    if [ -r /data/time/ats_2 ]||[ -r /data/system/time/ats_2 ];then
        F_LOG "proprietary qcom time-file detected! Will start qcom time_daemon instead of timekeep!"
        F_LOG "if you feel this is an error you may have switched from STOCK to CM/AOSP without wiping data. Delete /data/system/time/ats_2 or /data/time/ats_2 manually if that is the case"
        # trigger time_daemon
        setprop twrp.timedaemon 1
    else
        if [ -r /data/property/persist.sys.timeadjust ];then
            setprop persist.sys.timeadjust $(cat /data/property/persist.sys.timeadjust)
            F_LOG "setting persist.sys.timeadjust ended with $?"
            # trigger timekeep daemon
            setprop twrp.timeadjusted 1
        else
            F_ELOG "/data/property/persist.sys.timeadjust not accessible!"
        fi
     fi
fi
F_LOG "timeadjust after setprop: >$(getprop persist.sys.timeadjust)<"
F_LOG "$0 finished"
