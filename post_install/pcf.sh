# !/bin/bash
#
# portalconfig.sh
#
# SSZ was here
# PORTAL_CONFIG should be moved to /etc/asterisk
PORTAL_CONFIG=/etc/portal-config
CONFIGS=/etc/asterisk
ORIGCONFIGS=/etc/asterisk-original
TMP=/tmp/allstar-install
CFG=$TMP/cfg-list
TMPPORT=$TMP/portal-config
BASEURL=https://config.allstarlink.org
URL1=$BASEURL/portal/_config/get_available_configs.php
URL2=$BASEURL/portal/_config/get_config.php

function die {
	echo "Fatal error: $1"
	exit 255
}

function promptnum
{
	ANSWER=""
	while [ -z $ANSWER  ] || [[ ! $ANSWER =~ [0-9]{1,}$ ]]
	do
        	echo -n "$1: "
        	read ANSWER
	done
}

function promptstr
{
	ANSWER=""
	while [ -z $ANSWER  ] || [[ ! $ANSWER =~ [\/,0-9,a-z,A-Z]{3,}$ ]]
	do
        	echo -n "$1: "
        	read ANSWER
	done
}

function promptpswd
{
	ANSWER=""
	while [ -z $ANSWER  ] || [[ ! $ANSWER =~ [\/,0-9,a-z,A-Z]{3,}$ ]]
	do
        	echo -n "$1: "
        	read -s ANSWER
	done
	echo ""
}

function promptyn
{
        echo -n "$1 [y/N]? "
        read ANSWER
	if [ ! -z $ANSWER ]
	then
       		if [ $ANSWER = Y ] || [ $ANSWER = y ]
      		then
                	ANSWER=Y
        	else
                	ANSWER=N
        	fi
	else
		ANSWER=N
	fi
}

function promptny
{
        echo -n "$1 [Y/n]? "
        read ANSWER
	if [ ! -z $ANSWER ]
	then
       		if [ $ANSWER = N ] || [ $ANSWER = n ]
      		then
                	ANSWER=N
        	else
                	ANSWER=Y
        	fi
	else
		ANSWER=Y
	fi
}

# Function calculates number of bit in a netmask
#
mask2cidr() {
    nbits=0
    IFS=.
    for dec in $1 ; do
        case $dec in
            255) let nbits+=8;;
            254) let nbits+=7;;
            252) let nbits+=6;;
            248) let nbits+=5;;
            240) let nbits+=4;;
            224) let nbits+=3;;
            192) let nbits+=2;;
            128) let nbits+=1;;
            0);;
            *) echo "0"; exit 1
        esac
    done
    echo "$nbits"
}

ISDEBX=0
if [ -r /etc/debian_version ]
then
	uname -omv | grep -E 'Debian' > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
                ISDEBX=1
        fi
fi

ISLIMEY=0
if [ -r /etc/sysinfo ]
then
	grep LLVERS /etc/sysinfo > /dev/null 2>&1
	if [ $? -eq 0 ]
	then
		ISLIMEY=1
	fi
fi

ISBEAGLE=0
ISBBB=0
if [ `uname -m` = 'armv7lx' ]
then
	if [ -f /etc/bbb_allstar_version ]
	then
		ISBBB=1
	else
		ISBEAGLE=1
	fi
fi

AUTOMAGIC=0
if [ ! -z $1 ]
then
	AUTOMAGIC=1
fi

rm -rf $TMP > /dev/null 2>&1
mkdir -p $TMP

if [ $AUTOMAGIC -eq 0 ]
then
	echo "*********************************************"
	echo "*     Allstar Portal Node Setup Script      *"
	echo "*********************************************"
	echo
fi

# see if we already have a portal config file
if [ -r $PORTAL_CONFIG ]
then
	U=`grep USERID $PORTAL_CONFIG | cut -f2 -d=`
	if [ $AUTOMAGIC -eq 0 ]
	then
		promptny "Do you wish to use the pre-configured user information (user $U)"
	else
		ANSWER=Y
	fi
	if [ $ANSWER = 'Y' ]
	then
		USERID=$U
		PSWD=`grep PASSWORD $PORTAL_CONFIG | cut -f2 -d=`
	fi
else
	if [ $AUTOMAGIC -eq 1 ]
	then
		echo "Sorry, Can not find pre-configuration file"
		rm -rf $TMP
		exit 1
	fi
fi

if [ -z $USERID ] || [ -z $PSWD ]
then
	promptstr "Enter your Allstar Portal user id"
	USERID=$ANSWER
	promptpswd "Enter your Allstar Portal password"
	PSWD=$ANSWER
fi

rm -f $CFG
curl -sk -m 15 --retry 1 $URL1?username=$USERID\&password=$PSWD > $CFG
if [ $? -ne 0 ]
then
	echo "Failed to download configuration list"
	rm -rf $TMP
	exit 1;
fi

grep \< $CFG > /dev/null 2>&1
if [ $? -eq 0 ]
then
	echo "Invalid username or password"
	rm -rf $TMP
	exit 1;
fi

echo "#Allstar Portal Configuration file" > $TMPPORT
echo "#Written at "`date` >> $TMPPORT
echo "# *** NOTE: THIS FILE IS AUTOMATICALLY GENERATED ***" >> $TMPPORT
echo >> $TMPPORT
echo "USERID=$USERID" >> $TMPPORT
echo "PASSWORD=$PSWD" >> $TMPPORT

N=`wc -l $CFG | awk ' { print $1; } '`
SEL=`cat $CFG | cut -f2 -d','`
CFGID=`cat $CFG | cut -f1 -d','`


if [ $N -lt 1 ]
then
	echo "No valid configurations found"
	rm -rf $TMP
	exit 1
fi

if [ $AUTOMAGIC -eq 0 ]
then
	echo
fi

if [ $N -gt 1 ]
then
	if [ $AUTOMAGIC -eq 1 ]
	then
		SEL=`grep SERVER $PORTAL_CONFIG | cut -f2 -d=`
		CFGID=`grep CFGID $PORTAL_CONFIG | cut -f2 -d=`
		if [ -z $SEL ] || [ -z $CFGID ]
		then
			echo "Unable to determine Server info from preconfiguration file"
			rm -rf $TMP
			exit 1
		fi
		GOTANS=1
	else
		GOTANS=0
	fi
	while [ $GOTANS -eq 0 ]
	do
		echo "Please select one of the following servers"
		echo
		I=1
		while [ $I -le $N ]
		do
			read LINE
			S=`echo $LINE | cut -f2 -d,`
			echo "$I)  $S"
			let I="$I+1"
		done < $CFG
		echo
		promptnum "Please make your selection (1-$N)"
		if [ $ANSWER -lt 1 ] || [ $ANSWER -gt $N ]
		then
			echo "Im sorry, that selection is invalid"
			echo
		else
			GOTANS=1
			GOTIT=0
			I=1
			while [ $I -le $ANSWER ]
			do
				read LINE
				S=`echo $LINE | cut -f2 -d,`
				C=`echo $LINE | cut -f1 -d,`
				let I="$I+1"
			done < $CFG
			NS=`echo -n $S | wc -c`
			NC=`echo -n $C | wc -c`
			SEL=$S
			CFGID=$C
			if [ $NS -lt 1 ] || [ $NC -lt 1 ]
			then
				echo "Internal error - cannot find configuration"
				rm -rf $TMP
				exit 1
			fi
		fi
	done
fi

rm -f $CFG

if [ $AUTOMAGIC -eq 0 ]
then
	echo
	promptny "Okay to download config for server $SEL"
	if [ $ANSWER = 'N' ]
	then
		exit 0
	fi

	echo
	echo "Downloading server $SEL..."
fi

curl -sk -m 15 --retry 1 $URL2?config_id=$CFGID | tar xz -C $TMP --touch > /dev/null 2>&1
if [ $? -ne 0 ]
then
	echo "Failed to download and unpack configuration files"
	rm -rf $TMP
	exit 1;
fi

echo "SERVER=$SEL" >> $TMPPORT
echo "CFGID=$CFGID" >> $TMPPORT
mv -f $TMPPORT $PORTAL_CONFIG

if [ $ISLIMEY -eq 1 ]
then
	mv $TMP/limey-rpt.conf $TMP/rpt.conf
	rm -f $TMP/acid-rpt.conf
else
	mv $TMP/acid-rpt.conf $TMP/rpt.conf
	rm -f $TMP/limey-rpt.conf
fi

if [ ! -r $TMP/system.conf ]
then
	echo "Problem with Portal setup!"
	rm -rf $TMP
	exit 1
fi

TMPF=$TMP/sysconf.sh
sed 's/;/#/g' < $TMP/system.conf > $TMPF
chmod +x $TMPF
source $TMPF

RESOLVPATH=/etc/resolv.conf

if [ $ISBBB -eq 1 ]
then
	INTPATH=/etc/netctl/eth0

	if [ ! -f $INTPATH ]
	then
		echo "Problem with BBB Linux networking setup!"
		rm -rf $TMP
		exit 1
	fi

	if [ ! -z $Hostname ]
	then
		if [ $AUTOMAGIC -eq 0 ]
		then
			echo "Setting Host Name to $Hostname"
		fi
		echo $Hostname > /etc/hostname
	fi

	if [ $ifconfig_type = 'dhcp' ]
	then

		if [ $AUTOMAGIC -eq 0 ]
		then
			echo "Setting network address mode to DHCP"
		fi

                echo "Description='A basic static or dhcp Ethernet connection'" > $INTPATH
                echo "Interface=eth0" >> $INTPATH
                echo "Connection=ethernet" >> $INTPATH
                echo "#" >> $INTPATH
                echo "## Uncomment either (not both) DHCP or Static IP lines" >> $INTPATH
                echo "## Uncomment the following lines for dhcp IP" >> $INTPATH
                echo "IP=dhcp" >> $INTPATH
                echo "" >> $INTPATH
                echo "## IP6 not normally used leave following lines commented" >> $INTPATH
                echo "## for DHCPv6" >> $INTPATH
                echo "#IP6=dhcp" >> $INTPATH
                echo "## for IPv6 autoconfiguration" >> $INTPATH
                echo "#IP6=stateless" >> $INTPATH
                echo "## END dhcp" >> $INTPATH
                echo "" >> $INTPATH
                echo "## Uncomment the following 5 lines for static IP" >> $INTPATH
                echo "## and change to your local parameters" >> $INTPATH
                echo "#AutoWired=yes" >> $INTPATH
                echo "#IP=static" >> $INTPATH
                echo "#Address=('192.168.0.132/24')" >> $INTPATH
                echo "#Gateway='192.168.0.9'" >> $INTPATH
                echo "#DNS=('192.168.0.9')" >> $INTPATH
                echo "" >> $INTPATH
                echo "## Routes not normally used - leave commented unless you have reason not to" >> $INTPATH
                echo "#Routes=('192.168.0.0/24 via 192.168.1.2')" >> $INTPATH
                echo "" >> $INTPATH
                echo "## IPV6 not normally used - leave following lines commented" >> $INTPATH
                echo "## For IPv6 autoconfiguration" >> $INTPATH
                echo "#IP6=stateless" >> $INTPATH
                echo "## For IPv6 static address configuration" >> $INTPATH
                echo "#IP6=static" >> $INTPATH
                echo "#Address6=('1234:5678:9abc:def::1/64' '1234:3456::123/96')" >> $INTPATH
                echo "#Routes6=('abcd::1234')" >> $INTPATH
                echo "#Gateway6='1234:0:123::abcd'" >> $INTPATH
                echo "## END static IP" >> $INTPATH
		# write resolv.conf with nameserver addresses
		rm -f $RESOLVPATH
		echo "nameserver 8.8.8.8" > $RESOLVPATH
		echo "nameserver 8.8.4.4" > $RESOLVPATH
	fi


        if [ $ifconfig_type = 'static' ]
        then
                if [ -z $ipaddress ] || [ -z $netmask ] || [ -z $gateway ] || [ -z $dns1$dns2 ]
                then
                        echo "Static IP information incomplete"
                        rm -rf $TMP
                        exit 1
                fi

                NBITS=$(mask2cidr $netmask)
                if [ $NBITS -lt 1 ]
                then
                        echo "$netmask is not a valid Netmask!!"
                        rm -rf $TMP
                        exit 1
                fi

		if [ ! -z $dns1 ]
		then
			PDNS=$dns1
		elif [ ! -z $dns2 ]
		then
			PDNS=$dns2
		fi
                if [ $AUTOMAGIC -eq 0 ]
                then
                        echo "Setting network interface to static addressing"
                fi

                echo "Description='A basic static or dhcp Ethernet connection'" > $INTPATH
                echo "Interface=eth0" >> $INTPATH
                echo "Connection=ethernet" >> $INTPATH
                echo "#" >> $INTPATH
                echo "## Uncomment either (not both) DHCP or Static IP lines" >> $INTPATH
                echo "## Uncomment the following lines for dhcp IP" >> $INTPATH
                echo "#IP=dhcp" >> $INTPATH
                echo "" >> $INTPATH
                echo "## IP6 not normally used leave following lines commented" >> $INTPATH
                echo "## for DHCPv6" >> $INTPATH
                echo "#IP6=dhcp" >> $INTPATH
                echo "## for IPv6 autoconfiguration" >> $INTPATH
                echo "#IP6=stateless" >> $INTPATH
                echo "## END dhcp" >> $INTPATH
                echo "" >> $INTPATH
                echo "## Uncomment the following 5 lines for static IP" >> $INTPATH
                echo "## and change to your local parameters" >> $INTPATH
                echo "AutoWired=yes" >> $INTPATH
                echo "IP=static" >> $INTPATH
                echo "Address=('$ipaddress/$NBITS')" >> $INTPATH
                echo "Gateway='$gateway'" >> $INTPATH
                echo "DNS=('$PDNS')" >> $INTPATH
                echo "" >> $INTPATH
                echo "## Routes not normally used - leave commented unless you have reason not to" >> $INTPATH
                echo "#Routes=('192.168.0.0/24 via 192.168.1.2')" >> $INTPATH
                echo "" >> $INTPATH
                echo "## IPV6 not normally used - leave following lines commented" >> $INTPATH
                echo "## For IPv6 autoconfiguration" >> $INTPATH
                echo "#IP6=stateless" >> $INTPATH
                echo "## For IPv6 static address configuration" >> $INTPATH
                echo "#IP6=static" >> $INTPATH
                echo "#Address6=('1234:5678:9abc:def::1/64' '1234:3456::123/96')" >> $INTPATH
                echo "#Routes6=('abcd::1234')" >> $INTPATH
                echo "#Gateway6='1234:0:123::abcd'" >> $INTPATH
                echo "## END static IP" >> $INTPATH
		# write resolv.conf with nameserver addresses
		rm -f $RESOLVPATH
		touch $RESOLVPATH
		if [ ! -z $dns1 ]
		then
			echo "nameserver $dns1" >> $RESOLVPATH
		fi
		if [ ! -z $dns2 ]
		then
			echo "nameserver $dns2" >> $RESOLVPATH
		fi
	fi
	if [ $ifconfig_type = 'custom' ] && [ $AUTOMAGIC -eq 0 ]
	then
		echo "Not changing network configurarion (as requested)"
	fi
elif [ $ISBEAGLE -eq 1 ]
then

exit 1

	INTPATH=/etc/network/interfaces
	IFUPDPATH=/etc/network/if-up.d/touchfile

	if [ ! -f $INTPATH ] || [ ! -f $IFUPDPATH ]
	then
		echo "Problem with Pickle Linux networking setup!"
		rm -rf $TMP
		exit 1
	fi

	if [ ! -z $Hostname ]
	then
		if [ $AUTOMAGIC -eq 0 ]
		then
			echo "Setting Host Name to $Hostname"
		fi
		echo $Hostname > /etc/hostname
	fi

	if [ $ifconfig_type = 'dhcp' ]
	then

		if [ $AUTOMAGIC -eq 0 ]
		then
			echo "Setting network address mode to DHCP"
		fi
		# write Debian style interfaces file
		echo "# DHCP IP configuration" > $INTPATH
                echo "auto lo" >> $INTPATH
                echo "auto usb0" >> $INTPATH
                echo "iface lo inet loopback" >> $INTPATH
		echo "iface usb0 inet dhcp" >> $INTPATH
		# write code to indicate interface is up
		echo "#! /bin/sh" > $IFUPDPATH
		echo "" >> $IFUPDPATH
		echo "touch /var/run/network-up" >> $IFUPDPATH
		echo "exit" >> $IFUPDPATH
		chmod +x $IFUPDPATH
	fi

	if [ $ifconfig_type = 'static' ]
	then
		if [ -z $ipaddress ] || [ -z $netmask ] || [ -z $gateway ] || [ -z $dns1$dns2 ]
		then
			echo "Static IP information incomplete"
			rm -rf $TMP
			exit 1
		fi
		if [ $AUTOMAGIC -eq 0 ]
		then
			echo "Setting network interface to static addressing"
		fi
		# write Debian style interfaces file
		echo "#Static IP configuration" > $INTPATH
		echo "auto lo" >> $INTPATH
		echo "auto usb0" >> $INTPATH
		echo "iface lo inet loopback" >> $INTPATH
		echo "iface usb0 inet static" >> $INTPATH
		echo "address $ipaddress" >> $INTPATH
		echo "netmask $netmask" >> $INTPATH
		echo "gateway $gateway" >> $INTPATH
		# write code to indicate interface is up
		echo "#! /bin/sh" > $IFUPDPATH
		echo "" >> $IFUPDPATH
		echo "touch /var/run/network-up" >> $IFUPDPATH
		echo "exit" >> $IFUPDPATH
		chmod +x $IFUPDPATH
		# write resolv.conf with nameserver addresses
		rm -f $RESOLVPATH
		touch $RESOLVPATH
		if [ ! -z $dns1 ]
		then
			echo "nameserver $dns1" >> $RESOLVPATH
		fi
		if [ ! -z $dns2 ]
		then
			echo "nameserver $dns2" >> $RESOLVPATH
		fi
	fi

	if [ $ifconfig_type = 'custom' ] && [ $AUTOMAGIC -eq 0 ]
	then
		echo "Not changing network configurarion (as requested)"
	fi
elif [ $ISLIMEY -eq 1 ]
then

	INTPATH=/etc/network/interfaces
	IFUPDPATH=/etc/network/if-up.d/touchfile

	if [ ! -f $INTPATH ] || [ ! -f $IFUPDPATH ]
	then
		echo "Problem with Limey Linux networking setup!"
		rm -rf $TMP
		exit 1
	fi

	if [ ! -z $Hostname ]
	then
		if [ $AUTOMAGIC -eq 0 ]
		then
			echo "Setting Host Name to $Hostname"
		fi
		echo $Hostname > /etc/hostname
	fi

	if [ $ifconfig_type = 'dhcp' ]
	then

		if [ $AUTOMAGIC -eq 0 ]
		then
			echo "Setting network address mode to DHCP"
		fi
		# write Debian style interfaces file
		echo "# DHCP IP configuration" > $INTPATH
                echo "auto lo" >> $INTPATH
                echo "auto eth0" >> $INTPATH
                echo "iface lo inet loopback" >> $INTPATH
		echo "iface eth0 inet dhcp" >> $INTPATH
		# write code to indicate interface is up
		echo "#! /bin/sh" > $IFUPDPATH
		echo "" >> $IFUPDPATH
		echo "touch /var/run/network-up" >> $IFUPDPATH
		echo "exit" >> $IFUPDPATH
		chmod +x $IFUPDPATH
	fi

	if [ $ifconfig_type = 'static' ]
	then
		if [ -z $ipaddress ] || [ -z $netmask ] || [ -z $gateway ] || [ -z $dns1$dns2 ] 
		then
			echo "Static IP information incomplete"
			rm -rf $TMP
			exit 1
		fi
		if [ $AUTOMAGIC -eq 0 ]
		then
			echo "Setting network interface to static addressing"
		fi
		# write Debian style interfaces file
		echo "#Static IP configuration" > $INTPATH
		echo "auto lo" >> $INTPATH
		echo "auto eth0" >> $INTPATH
		echo "iface lo inet loopback" >> $INTPATH
		echo "iface eth0 inet static" >> $INTPATH
		echo "address $ipaddress" >> $INTPATH
		echo "netmask $netmask" >> $INTPATH
		echo "gateway $gateway" >> $INTPATH
		# write code to indicate interface is up
		echo "#! /bin/sh" > $IFUPDPATH
		echo "" >> $IFUPDPATH
		echo "touch /var/run/network-up" >> $IFUPDPATH
		echo "exit" >> $IFUPDPATH
		chmod +x $IFUPDPATH
		# write resolv.conf with nameserver addresses
		rm -f $RESOLVPATH
		touch $RESOLVPATH
		if [ ! -z $dns1 ]
		then
			echo "nameserver $dns1" >> $RESOLVPATH
		fi
		if [ ! -z $dns2 ]
		then
			echo "nameserver $dns2" >> $RESOLVPATH
		fi
	fi

	if [ $ifconfig_type = 'custom' ] && [ $AUTOMAGIC -eq 0 ]
	then
		echo "Not changing network configurarion (as requested)"
	fi

#################
#################

elif [ $ISDEBX -eq 1 ]
then

	INTPATH=/etc/hostname
	IFUPDPATH=/etc/hosts

	# replace Zap with DAHDI
	sed -i 's/Zap\//DAHDI\//g' $TMP/rpt.conf

# rpt.conf
# rxchannel=Radio/usb
# rxchannel = SimpleUSB/usb

# /etc/asterisk/modules.conf
# load => chan_simpleusb.so ;                     Simple USB Radio Interface Channel Drive
# noload => chan_usbradio.so ;                    USB Console Channel Driver

        RXCHAN=`grep 'rxchannel=Radio' $TMP/rpt.conf`
        if [ -z $RXCHAN ]
                then
                        # rxchannel=SimpleUSB/usb chan_simpleusb
                        sed -i 's/noload => chan_simpleusb.so/load => chan_simpleusb.so/g' /etc/asterisk/modules.conf
                        sed -i 's/load => chan_usbradio.so/noload => chan_usbradio.so/g' /etc/asterisk/modules.conf
        else
                        # rxchannel=Radio/usb chan_usbradio
                        sed -i 's/load => chan_simpleusb.so/noload => chan_simpleusb.so/g' /etc/asterisk/modules.conf
                        sed -i 's/noload => chan_usbradio.so/load => chan_usbradio.so/g' /etc/asterisk/modules.conf

        fi

IP=$(grep Address= /etc/systemd/network/eth0.network | awk -F'=' '{print $2}' | awk -F'/' '{print $1}')
        if [ -z $IP ]
                then IP=DHCP
        fi

HOSTN=$(cat /etc/hostname)
FQDN=$(hostname -f)
DOMN=$(hostname -d)
HOSTNAME=`echo $FQDN |awk -F. '{ print $1 }'`
echo ""
echo "Existing hostname is $HOSTN"
echo "Existing Domain Name is $DOMN"
echo "Existing FQDN is $FQDN"
echo "Address is $IP"
echo ""
echo "New hostname is $Hostname"
echo "New IP is $ipaddress"
echo "New Netmask is $netmask"
echo "New Gateway is $gateway"
echo "New DNS 1 is $dns1"
echo "New DNS 2 is $dns2"
FQDN="$Hostname.$DOMN"
echo "New FQDN is $FQDN"
echo ""

	if [ ! -f $INTPATH ] || [ ! -f $IFUPDPATH ]
	then
		echo "Problem with Debian Linux networking setup!"
		rm -rf $TMP
		exit 1
	fi

	if [ ! -z $Hostname ]
	then
		if [ $AUTOMAGIC -eq 0 ]
		then
			echo "Setting Host Name to $Hostname"
		fi
		echo $Hostname > /etc/hostname
	fi

	if [ $ifconfig_type = 'dhcp' ]
	then

		if [ $AUTOMAGIC -eq 0 ]
		then
			echo "Setting network address mode to DHCP"
		fi
                # write systemd style network file to /etc/systemd/network/eth0.network
                echo "[Match]" >/etc/systemd/network/eth0.network
                echo "Name=eth0" >>/etc/systemd/network/eth0.network
                echo >>/etc/systemd/network/eth0.network
                echo "[Network]" >>/etc/systemd/network/eth0.network
                echo "DHCP=v4" >>/etc/systemd/network/eth0.network
                echo "" >>/etc/systemd/network/eth0.network
                echo >>/etc/systemd/network/eth0.network

                # create /etc/hosts for DHCP
                echo "127.0.0.1         localhost" >/etc/hosts
                echo "127.0.0.1         $FQDN   $Hostname" >>/etc/hosts
                echo >>/etc/hosts
                echo "# The following lines are desirable for IPv6 capable hosts" >>/etc/hosts
                echo "::1     localhost ip6-localhost ip6-loopback" >>/etc/hosts
                echo "ff02::1 ip6-allnodes" >>/etc/hosts
                echo "ff02::2 ip6-allrouters" >>/etc/hosts
                echo >>/etc/hosts

                # enable and start systemd DHCP
                systemctl enable systemd-resolved > /dev/null 2>&1
                systemctl start systemd-resolved > /dev/null 2>&1
                ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

	fi

	if [ $ifconfig_type = 'static' ]
	then
		if [ -z $ipaddress ] || [ -z $netmask ] || [ -z $gateway ] || [ -z $dns1$dns2 ]
		then
			echo "Static IP information incomplete"
			rm -rf $TMP
			exit 1
		fi
		if [ $AUTOMAGIC -eq 0 ]
		then
			echo "Setting network interface to static addressing"
		fi
                # write systemd style network file to /etc/systemd/network/eth0.network
                echo "[Match]" >/etc/systemd/network/eth0.network
                echo "Name=eth0" >>/etc/systemd/network/eth0.network
                echo >>/etc/systemd/network/eth0.network
                echo "[Network]" >>/etc/systemd/network/eth0.network
		numbits=$(mask2cidr $netmask)
                echo "Address=$ipaddress/$numbits" >>/etc/systemd/network/eth0.network
                echo "Gateway=$gateway" >>/etc/systemd/network/eth0.network
                echo "" >>/etc/systemd/network/eth0.network
                echo >>/etc/systemd/network/eth0.network
		# Setup resolv.conf
                rm -f $RESOLVPATH
                touch $RESOLVPATH
                if [ ! -z $dns1 ]
                then
                        echo "nameserver $dns1" >> $RESOLVPATH
                fi
                if [ ! -z $dns2 ]
                then
                        echo "nameserver $dns2" >> $RESOLVPATH
                fi

                # create /etc/hosts for static IP
                echo "127.0.0.1         localhost" >/etc/hosts
                echo "$ipaddress               $FQDN   $Hostname" >>/etc/hosts
                echo >>/etc/hosts
                echo "# The following lines are desirable for IPv6 capable hosts" >>/etc/hosts
                echo "::1     localhost ip6-localhost ip6-loopback" >>/etc/hosts
                echo "ff02::1 ip6-allnodes" >>/etc/hosts
                echo "ff02::2 ip6-allrouters" >>/etc/hosts
                echo >>/etc/hosts

                # Disable and stop systemd DHCP
                systemctl disable systemd-resolved > /dev/null 2>&1
                systemctl stop systemd-resolved > /dev/null 2>&1

	fi

	if [ $ifconfig_type = 'custom' ] && [ $AUTOMAGIC -eq 0 ]
	then
		echo "Not changing network configurarion (as requested)"
	fi

#################
################

else
	SCPATH=/etc/sysconfig

	if [ ! -f $SCPATH/network ]
	then
		echo "Problem with Centos networking setup!"

		rm -rf $TMP
		exit 1
	fi

	if [ -z $Hostname ]
	then
		echo "Problem with Hostname specification!"
		rm -rf $TMP
		exit 1
	fi

	if [ $AUTOMAGIC -eq 0 ]
	then
		echo "Setting Host Name to $Hostname"
	fi

	echo "NETWORKING=yes" > $SCPATH/network
	echo "NETWORKING_IPV6=no" >> $SCPATH/network
	echo "HOSTNAME=$Hostname" >> $SCPATH/network

	HWADDR=`ifconfig eth0 | awk ' { split($0,x," "); for (n in x) if (x[n] == "HWaddr") { print x[n + 1]; exit; } } '`

	if [ $ifconfig_type = 'dhcp' ]
	then

		if [ $AUTOMAGIC -eq 0 ]
		then
			echo "Setting network address mode to DHCP"
		fi
		echo "DEVICE=eth0" > $SCPATH/network-scripts/ifcfg-eth0
		echo "BOOTPROTO=dhcp" >> $SCPATH/network-scripts/ifcfg-eth0
		echo "DHCPCLASS=" >> $SCPATH/network-scripts/ifcfg-eth0
		if [ ! -z $HWADDR ]
		then
			echo "HWADDR=$HWADDR" >> $SCPATH/network-scripts/ifcfg-eth0
		fi
		echo "ONBOOT=yes" >> $SCPATH/network-scripts/ifcfg-eth0
		echo "DHCP_HOSTNAME=$Hostname" >> $SCPATH/network-scripts/ifcfg-eth0
	fi

	if [ $ifconfig_type = 'static' ]
	then
		if [ -z $ipaddress ] || [ -z $netmask ] || [ -z $gateway ] || [ -z $dns1$dns2 ]
		then
			echo "Static IP information incomplete"
			rm -rf $TMP
			exit 1
		fi
		if [ $AUTOMAGIC -eq 0 ]
		then
			echo "Setting network interface to static addressing"
		fi

		echo "DEVICE=eth0" > $SCPATH/network-scripts/ifcfg-eth0
		echo "BOOTPROTO=none" >> $SCPATH/network-scripts/ifcfg-eth0
		if [ ! -z $HWADDR ]
		then
			echo "HWADDR=$HWADDR" >> $SCPATH/network-scripts/ifcfg-eth0
		fi
		echo "ONBOOT=yes" >> $SCPATH/network-scripts/ifcfg-eth0
		echo "DHCP_HOSTNAME=$Hostname" >> $SCPATH/network-scripts/ifcfg-eth0
		echo "IPADDR=$ipaddress" >> $SCPATH/network-scripts/ifcfg-eth0
		echo "NETMASK=$netmask" >> $SCPATH/network-scripts/ifcfg-eth0
		echo "GATEWAY=$gateway" >> $SCPATH/network-scripts/ifcfg-eth0
		echo "TYPE=Ethernet" >> $SCPATH/network-scripts/ifcfg-eth0

		# write resolv.conf with nameserver addresses
		rm -f $RESOLVPATH
		touch $RESOLVPATH
		if [ ! -z $dns1 ]
		then
			echo "nameserver $dns1" >> $RESOLVPATH
		fi
		if [ ! -z $dns2 ]
		then
			echo "nameserver $dns2" >> $RESOLVPATH
		fi
	fi

	if [ $ifconfig_type = 'custom' ] && [ $AUTOMAGIC -eq 0 ]
	then
		echo "Not changing network configurarion (as requested)"
	fi
fi

if [ ! -d $ORIGCONFIGS ]
then
	mkdir $ORIGCONFIGS > /dev/null 2>&1
	cp -f $CONFIGS/*.conf $ORIGCONFIGS/
fi

if [ $ISBBB -eq 1 ]
then
	sed -i 's/Zap\//DAHDI\//g' $TMP/rpt.conf
fi

rm -f $CONFIGS/gps.conf $CONFIGS/echolink.conf $CONFIGS/usbradio.conf $CONFIGS/simpleusb.conf $CONFIGS/beagle.conf
mv -f $TMP/*.conf $CONFIGS
mv -f $TMP/allstar.pub /var/lib/asterisk/keys
rm -rf $TMP

if [ $ISLIMEY -eq 1 ]
then
	if [ $AUTOMAGIC -eq 0 ]
	then
		echo "Saving system configuration to flash"
		svcfg > /dev/null
	else
		svcfg > /dev/null 2>&1
	fi
fi

if [ $AUTOMAGIC -eq 0 ]
then
	echo "Done"
fi

exit 0
