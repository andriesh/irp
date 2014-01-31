#!/bin/bash
#Author: Andriesh Rusnac
get_uid=`id -u`
if [[ $get_uid == 0 ]]; then
	echo "Program must NOT be run as root user. Exiting... "
	exit 2
fi

function bold() {
echo -e "\033[1m$@\033[0m"
}
username=`whoami`
cd ~
#1. Pull from SVN
function svnget() {
read -p "Enter your password for SVN: " -s password
cd ~
bold "\nWorking in `pwd`"
echo -e "Cleaning up old files ... \c"; rm -rf noction/; echo "OK"

svn co --username=$username --password=$password --non-interactive svn://vcs.remsys.net/devel/nagios-svn/hosts/noction
if [ "$?" != "0" ]; then
echo "Cannot continue..."
exit 2
fi
}

#2. Adding or removing host
function hoststate() {
read -p "Add or remove host? [a/r] " -n 1 -r
echo
if [[ $REPLY =~ ^[Aa]$ ]]
then
    echo "Adding host"
    hs="a"
    comm_s="Added"
    comm_e="to"
elif [[ $REPLY =~ ^[Rr]$ ]]
then
	echo "Removing host"
	hs="r"
	comm_s="Removing"
	comm_e="from"
else
hoststate
fi
}

#3. Getting brand name
function getbrand() {
read -p "Enter customer name: " brand
	brand=`echo $brand | tr '[:upper:]' '[:lower:]'`
	echo "Brandname entered: `bold $brand`"
	function brandq() {
		read -p "Are you sure you want to continue? [y/n] " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
		    b="y"
		elif [[ $REPLY =~ ^[Nn]$ ]]
		then
			b="n"
			getbrand
		else
		brandq
		fi
	}
	brandq
spand_settings="\ndefine service{\n\tuse\t\t\t\tgeneric-service;
\n\thost_name\t\t\tnoction-$brand
\n\tservice_description\t\tPROCS_IRPSPAND
\n\tis_volatile\t\t\t0
\n\tcheck_period\t\t\t24x7
\n\tmax_check_attempts\t\t2
\n\tnormal_check_interval\t\t3
\n\tretry_check_interval\t\t1
\n\tcontact_groups\t\t\tremsys,noction
\n\tnotification_interval\t\t120
\n\tnotification_period\t\t24x7
\n\tnotification_options\t\tc   
\n\tcheck_command\t\t\tcheck_nrpe!check_procs_irpspand\n}"
}

function createhost() {
	hostfile="noction/noction-$brand.cfg"
	cp noction/host.cfg.sample $hostfile
	host_name_h='ADJUSTME: Should be with prefix \"noction-\"'
	host_name_s='ADJUSTME: Should be same as in \"define host\"'
	host_ip='ADJUSTME: Server IP address'

	#echo $host_name_h
	#echo $host_name_s
	awk '{sub("customer.noction.com","'"$brand.noction.com"'"); print $0}' $hostfile > $hostfile.tmp && mv $hostfile.tmp $hostfile
	awk '{sub("'"$host_name_h"'","'"noction-$brand"'"); print $0}' $hostfile > $hostfile.tmp && mv $hostfile.tmp $hostfile
	awk '{sub("'"$host_name_s"'","'"noction-$brand"'"); print $0}' $hostfile > $hostfile.tmp && mv $hostfile.tmp $hostfile
	awk '{sub("'"$host_ip"'","'"$irpip"'"); print $0}' $hostfile > $hostfile.tmp && mv $hostfile.tmp $hostfile
	awk '{sub("frontend_password","'"$webpass"'"); print $0}' $hostfile > $hostfile.tmp && mv $hostfile.tmp $hostfile
	
	if [[ $sshport != 22 ]]; then
		awk '{sub("SSH","'"SSH_$sshport"'"); print $0}' $hostfile > $hostfile.tmp && mv $hostfile.tmp $hostfile
		awk '{sub("check_ssh","'"check_ssh_by_port!$sshport"'"); print $0}' $hostfile > $hostfile.tmp && mv $hostfile.tmp $hostfile
	fi
	if [[ $flowd == n ]]; then
		cat $hostfile | head -n -32 > $hostfile.tmp && mv $hostfile.tmp $hostfile
	fi
	if [[ $spand == y ]]; then
		echo -e $spand_settings >> $hostfile
	fi
	if [[ $irpmode == n ]]; then
		awk '{sub("24x7","l3_weekdays_working_hours"); print $0}' $hostfile > $hostfile.tmp && mv $hostfile.tmp $hostfile
	fi

}

function getsettings() {
	function get_irpip() {
		read -p "Enter IRP IP address: "  irpip
		if [[ $irpip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
			echo "IP address accepted"; else echo "Incorrect IP specified!"; get_irpip ; fi

	}
	function get_webpass() {
		read -p "Enter frontend password: "  webpass
		if [[ ! $webpass ]]; then
			echo "No password specified!"
			get_webpass
		fi
	}
	function get_sshport() {
		read -p "Enter SSH port [22]: "  sshport
		if [[ ! $sshport ]]; then
			echo "Using default port 22."
			sshport="22"
		elif [[ ! $sshport =~ ^[0-9]+$ ]]; then
			echo "This is not a number!"
			get_sshport
		fi
	}
	function get_irpmode() {
		read -p "Is IRP working in Intrusive mode [y/n]: " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
		    irpmode="y"
		elif [[ $REPLY =~ ^[Nn]$ ]]
		then
			irpmode="n"
		else
			get_irpmode
		fi
	}
	function get_flowd() {
		read -p "Is the FLOW collector enabled? [y/n]: " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
		    flowd="y"
		elif [[ $REPLY =~ ^[Nn]$ ]]
		then
			flowd="n"
		else
			get_flowd
		fi
	}
	function get_spand() {
		read -p "Is the SPAN collector enabled? [y/n]: " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
		    spand="y"
		elif [[ $REPLY =~ ^[Nn]$ ]]
		then
			spand="n"
		else
			get_spand
		fi
	}
	#Get all the parameters	
	get_irpip		#$irpip
	get_webpass		#$webpass
	get_sshport		#$sshport
	get_irpmode		#$irpmode
	get_flowd		#$flowd
	get_spand		#$spand
}

function set_all() {
	bold "\n  Configuration summary:"
	echo -e "Brandname:\t\t\t\c"
	bold $brand
	echo -e "IRP IP address:\t\t\t\c"
	bold $irpip
	echo -e "SSH port:\t\t\t\c"
	bold $sshport
	echo -e "IRP web password:\t\t\c"
	bold $webpass
	echo -e "Intrusive mode:\t\t\t\c"
	bold `if [[ $irpmode == y ]]; then	echo "Enabled";	else echo "Disabled"; fi`
	echo -e "FLOW protocol:\t\t\t\c"
	bold `if [[ $flowd == y ]]; then	echo "Enabled";	else echo "Disabled"; fi`
	echo -e "SPAN protocol:\t\t\t\c"
	bold `if [[ $spand == y ]]; then	echo "Enabled";	else echo "Disabled"; fi`
	function conf_check() {
		read -p "Is the configuration OK? [y/n] " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
			echo "Creating configuration file for $brand"
		    createhost
		elif [[ $REPLY =~ ^[Nn]$ ]]
		then
			worker
		else
			conf_check
		fi
	}
	conf_check
}

function apply_settings() {
	svn_a_cmd="svn add noction/noction-$brand.cfg\nsvn ci -m \"$comm_s noction-$brand $comm_e monitoring\""
	svn_r_cmd="svn mv noction/noction-$brand.cfg noction/noction-$brand.cfg.removed"
	read -p "New configuration will be commited. Proceed? [y/n] " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]] && [[ $hs == a ]]; then
		echo "Committing..."
		bold $svn_a_cmd
	elif [[ $REPLY =~ ^[Yy]$ ]] && [[ $hs == r ]]; then
		echo "Committing..."
		bold $svn_r_cmd
	elif [[ $REPLY =~ ^[Nn]$ ]] && [[ $hs == a ]]; then
		echo -e "You can commit the settings by manualy running the command: \n\n`bold ${svn_a_cmd}`\n"
	elif [[ $REPLY =~ ^[Nn]$ ]] && [[ $hs == r ]]; then
		echo -e "You can commit the settings by manualy running the command: \n\n`bold ${svn_r_cmd}`\n"
	else
		apply_settings
	fi
}

#===================================
#1. SVN
svnget
#2. Add/Remove host
hoststate
#CHECK IF ADD HOST
if [[ $hs == a ]]; then
#3. Get Brandname
function worker() {
	getbrand
	#4. Get configuration details
	getsettings
	#5. Validate settings and configure file
	set_all
	#6.a. Commit changes
	apply_settings
}
worker
elif [[ $hs == r ]]; then
	getbrand
	#echo "Removing host `bold $brand`"
	RESTORE='\033[0m'
	LRED='\033[01;31m'
	echo -e "${LRED}ATENTION!${RESTORE} Host `bold $brand` will be removed from monitoring."
	#6.b. Commit changes
	apply_settings
fi


