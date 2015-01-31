#!/bin/bash
# BTSync Installer Script for Linux, v1.01
# Copyright 2014 vinadoros; Distributed under the LGPL v2.1
# All external code/work is copyrighted, and subject to the respective author's licenses.
# See thread at: http://forum.bittorrent.com/topic/26521-btsync-installer-script-for-linux/


# causing bug on download bit.# Exit if there is any error in the program.
#set -e


###############################################################################
###########################        Variables        ###########################
###############################################################################

# Set home folder for current user.
HOMEFOLDER=~
SCRIPT_NAME=install_btsync
# URL's from http://forum.bittorrent.com/topic/24781-latest-1282-build/
btsyncdownurl=http://getsync.com/download

########################################
###########  Functions   ###############

function check_package {
	PACKAGE=$1
	dpkg --get-selections | grep -qw $PACKAGE
	if [ $? -ne 0 ]; then echo "$PACKAGE not installed"; return 1
	else echo "$PACKAGE already installed"; return 0
	fi
}
function inst {
	PACKAGE=$1
        check_package $PACKAGE
        if [ $? -ne 0 ]; then echo; echo "install $PACKAGE"; sudo apt-get install -y $PACKAGE; return $?
 	else return 1
	fi
}

inst curl

# Test the btsyncdownurl to see if it works.
test2_url=`curl --silent -Is $btsyncdownurl | head -n 1 | sed -r 's/.* ([0-9]*) .*/\1/'`
echo "$test2_url"
if [ "$test2_url" != "200" ]; then
    echo version $1 not found.
    # exit 1
else echo "btsync file found"; fi

# Get the BTSync download page, and then read the version number.
wget -P ~/ $btsyncdownurl
version=$(perl -ne 'print $1 if s/.*Linux i386.glibc 2.3.<.a>.*<span>([\.\d]+)<.span>.*/\1/;' ~/download)
echo "\$version is $version"
# cat ~/download
rm ~/download

BTSYNC_ARMURL=http://download.getsyncapp.com/endpoint/btsync/os/linux-arm/track/stable
BTSYNC_64BITURL=http://download-new.utorrent.com/endpoint/btsync/os/linux-x64/track/stable
BTSYNC_32BITURL=http://download-new.utorrent.com/endpoint/btsync/os/linux-i386/track/stable

# Set the version of BTSYNC to use, based on 32bit or 64bit machine. Currently only works for x86 and x86_64 architectures.
MACHINEARCH=$(uname -m)
if [ "${MACHINEARCH}" = "x86_64" ]; then
    url=$BTSYNC_64BITURL; echo "64 bit architecture detected"
elif [ "${MACHINEARCH}" = "armv6l" ]; then
    url=$BTSYNC_ARMURL; echo "ARM architecture detected"
else
    url=$BTSYNC_32BITURL; echo "32 bit architecture detected"
fi

# Port number for BTSync web-ui
BTPORTNUMBER=8888

echo "here3"
###############################################################################
##########################        Root Check        ###########################
###############################################################################

# This code checks to see if you are running as root/sudo. Script is not designed to run as root, however it can be done. When you go to uninstall the program, you must also run the script as root again.

if [ "$(id -u)" == "0" ]; then
    while true; do
        read -p "I have noticed you are root, or have run the script as sudo. The script is designed to run as a normal user. Only do this if you are sure you want to use the root user for BTSync. Are you sure you want to do this? Answer no if you are unsure. (y/n)" ROOTQUESTION
        case $ROOTQUESTION in
        
        [Yy]* ) 
    	echo "You asked to install BTSync as superuser/root."
    	
    	break;;
    	
    	[Nn]* ) 
    	echo "You asked not to install BTSync as superuser/root. Please exit superuser, or login as a normal user."
    	exit 1;
    	break;;
    	
    	* ) echo "Please input y (yes), or n (no).";;
        esac
    done
fi



echo "here4"
###############################################################################
###########################        Functions        ###########################
###############################################################################


###############################################################################
# Function wgetbtsync: Get the btsync tarball and install BTSync.
###############################################################################
function wgetbtsync () {
    # First check if architecture is correct
    while true; do
	read -p "is the architecture detected correct? " YN
	case $YN in
		[Yy]* ) echo "OK."; break;;
		[Nn]* ) exit 1 ;;
		* ) echo "Please answer yes or no.";;
	esac
    done
    echo "here1"
    # Second test if the URL is valid.
    test_url=`curl --silent -Is $url | head -n 1 | sed -r 's/.* ([0-9]*) .*/\1/'`
    if [ "$test_url" != "200" ]; then
        echo version $1 not found.
        exit 1
    fi
    
    # If the URL is valid, get the version, and untar it.
    echo "Installing btsync from $url."
    wget --quiet $url -O - | sudo tar -C /usr/local/bin -zxv btsync
    
    }

echo "here5"
###############################################################################
# Function installbtsyncconfig: Install local btsync configuration file.
###############################################################################
function installbtsyncconfig () {
    if [ ! -d $HOMEFOLDER/.sync/ ]; then
        echo "Creating $HOMEFOLDER/.sync/"
        mkdir $HOMEFOLDER/.sync/
    else
        echo "$HOMEFOLDER/.sync/ already exists."
    fi

    if [ ! -f $HOMEFOLDER/.sync/sync.conf ]; then
        echo "Creating $HOMEFOLDER/.sync/sync.conf"

        # Dump a sync.conf in the user folder. It will overwrite any existing content in the sync.conf.
        cat >>$HOMEFOLDER/.sync/sync.conf <<EOL
{
  "device_name": "$(uname -n)",
  "listening_port" : 0,                       // 0 - randomize port

/* storage_path dir contains auxilliary app files
   if no storage_path field: .sync dir created in the directory 
   where binary is located.
   otherwise user-defined directory will be used 
*/
  "storage_path" : "$HOMEFOLDER/.sync",

  "check_for_updates" : true, 
/*  "use_upnp" : true,                              // use UPnP for port mapping
*/

/* limits in kB/s
   0 - no limit
*/
/*  "download_limit" : 0,
  "upload_limit" : 0, */

/* remove "listen" field to disable WebUI
   remove "login" and "password" fields to disable credentials check
*/
  "webui" :
  {
    "listen" : "0.0.0.0:$BTPORTNUMBER"
/*    ,"login" : "btsync",
    "password" : "sync79"    */
  }

/* !!! if you set shared folders in config file WebUI will be DISABLED !!!
   shared directories specified in config file
   override the folders previously added from WebUI.
*/


// Advanced preferences can be added to config file.
// Info is available in BitTorrent Sync User Guide.

}
EOL
    
    else
        echo "$HOMEFOLDER/.sync/sync.conf already exists, will not recreate."
    
    fi    

    }   

 echo "here6"   
###############################################################################
# Function installbtsyncstartup: Install btsync to run on startup as the current user.
###############################################################################
function installbtsyncstartup () {
    
    # Create the init.d script.
    echo "installbtsyncstartup ()"
    if [ ! -f /etc/init.d/btsync ]; then
      sudo touch /etc/init.d/btsync
      sudo sh -c "cat >>/etc/init.d/btsync" <<'EOL'  
#!/bin/sh    
### BEGIN INIT INFO        
# Provides: btsync  
# Required-Start: $local_fs $remote_fs       
# Required-Stop: $local_fs $remote_fs 
# Should-Start: $network 
# Should-Stop: $network     
# Default-Start: 2 3 4 5                       
# Default-Stop: 0 1 6                  
# Short-Description: Multi-user daemonized version of btsync. 
# Description: Starts the btsync daemon for all registered users.           
### END INIT INFO  
   
EOL
                                                                                                           
echo "# Replace with linux users you want to run BTSync clients for                                              
BTSYNC_USERS=\"$USER\"
DAEMON=/usr/local/bin/btsync" | sudo tee /etc/init.d/btsync

sudo sh -c "cat >>/etc/init.d/btsync" <<'EOL'
start() {
for btsuser in $BTSYNC_USERS; do
  HOMEDIR=`getent passwd $btsuser | cut -d: -f6`
  echo "\"\$btsuser\" is $btsuser"
  echo "\"\$HOMEDIR\" is $HOMEDIR"
  config=$HOMEDIR/.sync/sync.conf
  if [ -f $config ]; then
    port=`cat $config | grep 'listen" : "'| cut -d':' -f3 | cut -d'"' -f1`
    echo "Starting BTSync for $btsuser on port \"$port\""
    sudo -u $btsuser $DAEMON --config $config
  else
  echo "Couldn't start BTSync for $btsuser (no $config found)"
  fi
done
}

stop() {
for btsuser in $BTSYNC_USERS; do
  dbpid=`pgrep -fu $btsuser $DAEMON`
  if [ ! -z "$dbpid" ]; then
    echo "Stopping btsync for $btsuser"
    kill $dbpid
    #pkill -u $btsuser -x $DAEMON
  fi
done
}

status() {
for btsuser in $BTSYNC_USERS; do
  dbpid=`pgrep -fu $btsuser $DAEMON`
  if [ -z "$dbpid" ]; then
    echo "btsync for USER $btsuser: not running."
  else
    echo "btsync for USER $btsuser: running (pid $dbpid)"
  fi
done
}

case "$1" in
start)
  start
  ;;
stop)
  stop
  ;;
restart|reload|force-reload)
  stop
  start
  ;;
status)
  status
  ;;
*)
  echo "Usage: /etc/init.d/btsync {start|stop|reload|force-reload|restart|status}"
  exit 1
esac

exit 0


EOL


#sudo mv $HOMEFOLDER/btsync.tmp /etc/init.d/btsync; 
	sudo chmod a+x /etc/init.d/btsync
    fi
    
    # Enable the systemd service as the current user, and start it.
    sudo update-rc.d btsync defaults
    sudo /etc/init.d/btsync start

    }


echo "here7"
###############################################################################
# Function removebtsync: Remove all traces of BTSync produced by this script.
###############################################################################
function removebtsync () {
    while true; do
        read -p "Are you sure you want to completely remove BTSync? (y/n)?: " RMQUESTION
        case $RMQUESTION in
        
        [Yy]* ) 
        echo "You asked to remove BTSync."

        if [ -d $HOMEFOLDER/.sync/ ]; then    
            while true; do
            read -p "Do you want to remove your existing BTSync Configuration files in your home folder? (y/n)?: " BTCONFQUESTION
            case $BTCONFQUESTION in
        
            [Yy]* ) 
            echo "You asked to remove the config files. I will delete $HOMEFOLDER/.sync"
            rm -rf $HOMEFOLDER/.sync
            break;;
            
            [Nn]* ) 
            echo "You asked not to remove the config files."
            break;;
            
            * ) echo "Please input y (yes) or n (no).";;
	        
	    esac
            done
 	fi   
        echo "Deleting init.d startup info."  
        #if [ -f /etc/systemd/system/btsync@.service ]; then
         #   sudo systemctl stop btsync@$USER.service
         #   sudo systemctl disable btsync@$USER.service
         #   sudo rm /etc/systemd/system/btsync@.service
        #fi
   	
	if [ -f /etc/init.d/btsync ]; then
            sudo update-rc.d -f btsync remove
	    sudo rm /etc/init.d/btsync
        fi
        
        echo "Deleting BTSync."  
        if [ -f /usr/local/bin/btsync ]; then
            sudo rm /usr/local/bin/btsync
        fi

        # Delete the application icon and desktop file too.
        echo "Deleting BTSync shortcuts." 
        if [ -f /usr/share/applications/btsync-user.desktop ]; then
            sudo rm /usr/share/applications/btsync-user.desktop
        fi
        if [ -f /usr/share/icons/hicolor/16x16/apps/btsync-user.png ]; then
            sudo rm /usr/share/icons/hicolor/16x16/apps/btsync-user.png
        fi
        if [ -f /usr/share/icons/hicolor/32x32/apps/btsync-user.png ]; then
            sudo rm /usr/share/icons/hicolor/32x32/apps/btsync-user.png
        fi
        if [ -f /usr/share/icons/hicolor/48x48/apps/btsync-user.png ]; then
            sudo rm /usr/share/icons/hicolor/48x48/apps/btsync-user.png
        fi
        if [ -f /usr/share/icons/hicolor/96x96/apps/btsync-user.png ]; then
            sudo rm /usr/share/icons/hicolor/96x96/apps/btsync-user.png
        fi
        
        break;;

        [Nn]* ) 
        echo "You asked not to remove BTSync."
        break;;
        
        * ) echo "Please input y (yes) or n (no).";;
    esac
    done

    }

function stopbtsync () {
echo "Stop the BTSync service"
	while pkill -x btsync; do
	   echo "waiting for btsync to die . ."; sleep 1 ; sudo pkill -x btsync
	done
	echo "dead."
}

###############################################################################
##########################        Main Program       ##########################
###############################################################################
echo "here2"
case "$1" in
    
        '--install') 
        echo "You asked to install BTSync for the first time on this machine."
        
        if [ -f "/etc/init.d/btsync" -o -f "/usr/local/bin/btsync" -o -f "/usr/share/applications/btsync-user.desktop" ]; then
            echo "I have detected existing BTSync files. You will now be asked if you want to remove any previous BTSync files."
            removebtsync
        fi
        
        wgetbtsync
        installbtsyncconfig
        installbtsyncstartup
        ;;
        
        '--update') 
        echo "You asked to update BTSync."
        # Stop the BTSync service, update BTSync, start it again.
        stopbtsync
        wgetbtsync
        /etc/init.d/btsync start
        ;;
        
        '--remove') 
        echo "You asked to remove BTSync."
	stopbtsync
        removebtsync
        ;;
        
        *) 
        echo; echo "$SCRIPT_NAME.sh"; echo "You asked not to install, update, or remove BTSync."; echo
        echo "use: install_btsync.sh <switch>"; echo
	echo " --install     Will install btsync on machine"
	echo " --remove      Will remove btsync from machine"
	echo " --update      Will update btsync to latest version"
esac


exit 0

# Changelog
#
# 1.03 - (Dec 2014) bug fix for user in init.d file
# 1.02 - (Sept 2014) Updated BTSync url again - glacian79.
# 1.01 - Updated to add version detection of the BTSync url, as suggested by JimH44 on the BTSync forums.
# 1.0 - Initial Release






# Depreciated code

 #This section of the code creates a .desktop file so you can access the web interface through a shortcut.
    
    # Check to see if the entire folder is there.
    if [ ! -d /usr/share/applications ]; then
        echo "Creating /usr/share/applications"
        mkdir /usr/share/applications
    else
        echo "/usr/share/applications already exists. Will not create."
    fi
    
    # Check to see if btsync-user.desktop exists.
    if [ ! -f /usr/share/applications/btsync-user.desktop ]; then
        echo "Creating /usr/share/applications/btsync-user.desktop"
        
        
        # Create a desktop file in the global application entries folder. This file was modified from a version taken from https://github.com/tuxpoldo/btsync-deb/blob/master/btsync-user/scripts/btsync-user.desktop. Credit goes to tuxpoldo on github, and any other authors/contributors related.
        sudo sh -c "cat >>/usr/share/applications/btsync-user.desktop" <<EOL
[Desktop Entry]
Name=BitTorrent Sync Web UI
Comment=BitTorrent Sync management interface
Exec=xdg-open http://127.0.0.1:$BTPORTNUMBER
Icon=btsync-user
Terminal=false
Type=Application
Categories=Network
EOL
    fi
    
    
    # Get an icon as well. This file was taken from https://github.com/tuxpoldo/btsync-deb/tree/master/btsync-user/icons/. Credit goes to tuxpoldo on github, and any other authors/contributors related.
    if [ ! -f /usr/share/icons/hicolor/16x16/apps/btsync-user.png ]; then
        echo "Retreiving /usr/share/icons/hicolor/16x16/apps/btsync-user.png"
        sudo wget https://raw2.github.com/tuxpoldo/btsync-deb/master/btsync-user/icons/16/btsync-user.png -O /usr/share/icons/hicolor/16x16/apps/btsync-user.png
    fi
    if [ ! -f /usr/share/icons/hicolor/32x32/apps/btsync-user.png ]; then
        echo "Retreiving /usr/share/icons/hicolor/32x32/apps/btsync-user.png"
        sudo wget https://raw2.github.com/tuxpoldo/btsync-deb/master/btsync-user/icons/32/btsync-user.png -O /usr/share/icons/hicolor/32x32/apps/btsync-user.png
    fi
    if [ ! -f /usr/share/icons/hicolor/48x48/apps/btsync-user.png ]; then
        echo "Retreiving /usr/share/icons/hicolor/48x48/apps/btsync-user.png"
        sudo wget https://raw2.github.com/tuxpoldo/btsync-deb/master/btsync-user/icons/48/btsync-user.png -O /usr/share/icons/hicolor/48x48/apps/btsync-user.png
    fi
    if [ ! -f /usr/share/icons/hicolor/96x96/apps/btsync-user.png ]; then
        echo "Retreiving /usr/share/icons/hicolor/96x96/apps/btsync-user.png"
        sudo wget https://raw2.github.com/tuxpoldo/btsync-deb/master/btsync-user/icons/96/btsync-user.png -O /usr/share/icons/hicolor/96x96/apps/btsync-user.png; echo "rtrved"
    fi


    }
