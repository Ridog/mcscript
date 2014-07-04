#!/bin/bash
 # /etc/init.d/minecraft
 # version 0.3.9 2012-08-13 (YYYY-MM-DD)
 
 ### BEGIN INIT INFO
 # Provides:   Minecraft Server Management
 # Required-Start: $local_fs $remote_fs screen-cleanup
 # Required-Stop:  $local_fs $remote_fs
 # Should-Start:   $network
 # Should-Stop:    $network
 # Default-Start:  2 3 4 5
 # Default-Stop:   0 1 6
 # Short-Description:    Minecraft Server Manager
 # Description:    Manages Minecraft Servers' backups, startup, and more.
 ### END INIT INFO
 
 #Load values from mcscript.cfg
 . /mcscript.cfg
 
 ME=`whoami`
 as_user() {
   if [ $ME == $USERNAME ] ; then
     bash -c "$1"
   else
     su - $USERNAME -c "$1"
   fi
 }
 
 mc_start() {
   if  pgrep -u $USERNAME -f $SERVICE > /dev/null
   then
     echo "$SERVICE is already running!"
   else
     echo "Starting $SERVICE..."
     cd $MCPATH
     as_user "cd $MCPATH && screen -h $HISTORY -dmS $SCREENNAME $INVOCATION"
     sleep 30
     if pgrep -u $USERNAME -f $SERVICE > /dev/null
     then
       echo "$SERVICE is now running."
     else
       echo "Error! Could not start $SERVICE!"
     fi
   fi
 }
 
 mc_saveoff() {
   if pgrep -u $USERNAME -f $SERVICE > /dev/null
   then
     echo "$SERVICE is running... suspending saves"
     as_user "screen -p 0 -S minecraft -X eval 'stuff \"say SERVER BACKUP STARTING. Server going to read only mode...\"\015'"
     as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-off\"\015'"
     as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-all\"\015'"
     sync
     sleep 10
   else
     echo "$SERVICE is not running. Not suspending saves."
   fi
 }
 
 mc_saveon() {
   if pgrep -u $USERNAME -f $SERVICE > /dev/null
   then
     echo "$SERVICE is running... re-enabling saves"
     as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-on\"\015'"
     as_user "screen -p 0 -S minecraft -X eval 'stuff \"say SERVER BACKUP ENDED. Server going back to read-write mode...\"\015'"
   else
     echo "$SERVICE is not running. Not resuming saves."
   fi
 }
 
 mc_stop() {
   if pgrep -u $USERNAME -f $SERVICE > /dev/null
   then
     echo "Stopping $SERVICE"
     as_user "screen -p 0 -S minecraft -X eval 'stuff \"broadcast SERVER SHUTDOWN IN 10 SECONDS. Saving map...\"\015'"
     as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-all\"\015'"
     sleep 10
     as_user "screen -p 0 -S minecraft -X eval 'stuff \"stop\"\015'"
     sleep 10
   else
     echo "$SERVICE was not running."
   fi
   if pgrep -u $USERNAME -f $SERVICE > /dev/null
   then
     echo "Error! $SERVICE could not be stopped."
   else
     echo "$SERVICE is stopped."
   fi
 } 
 
 mc_backup() {
    mc_saveoff
    
    NOW=`date "+%Y-%m-%d_%Hh%M"`
    BACKUP_FILE="$BACKUPPATH/${WORLD}_${NOW}.tar"
    echo "Backing up minecraft world..."
    #as_user "cd $MCPATH && cp -r $WORLD $BACKUPPATH/${WORLD}_`date "+%Y.%m.%d_%H.%M"`"
    as_user "tar -C \"$MCPATH\" -cf \"$BACKUP_FILE\" $WORLD"
 
    echo "Backing up $SERVICE"
    as_user "tar -C \"$MCPATH\" -rf \"$BACKUP_FILE\" $SERVICE"
    #as_user "cp \"$MCPATH/$SERVICE\" \"$BACKUPPATH/minecraft_server_${NOW}.jar\""
 
    mc_saveon
 
    echo "Compressing backup..."
    as_user "gzip -f \"$BACKUP_FILE\""
    echo "Done."
 }
 
 mc_command() {
   command="$1";
   if pgrep -u $USERNAME -f $SERVICE > /dev/null
   then
     pre_log_len=`wc -l "$MCPATH/logs/latest.log" | awk '{print $1}'`
     echo "$SERVICE is running... executing command"
     as_user "screen -p 0 -S minecraft -X eval 'stuff \"$command\"\015'"
     sleep .5 # assumes that the command will run and print to the log file in less than .1 seconds
     # print output
     tail -n $[`wc -l "$MCPATH/logs/latest.log" | awk '{print $1}'`-$pre_log_len] "$MCPATH/logs/latest.log"
   fi
 }
 
 #Start-Stop here
 case "$1" in
   start)
     mc_start
     ;;
   stop)
     mc_stop
     ;;
   restart)
     mc_stop
     mc_start
     ;;
   backup)
     mc_backup
     ;;
   status)
     if pgrep -u $USERNAME -f $SERVICE > /dev/null
     then
       echo "$SERVICE is running."
     else
       echo "$SERVICE is not running."
     fi
     ;;
   command)
     if [ $# -gt 1 ]; then
       shift
       mc_command "$*"
     else
       echo "Must specify server command (try 'help'?)"
     fi
     ;;
 
   *)
   echo "Usage: $0 {start|stop|backup|status|restart|command \"server command\"}"
   exit 1
   ;;
 esac
 
 exit 0