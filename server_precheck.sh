#!/bin/bash
#Author: Ion Prodan & Andriesh Rusnac
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/etc/local/bin:.:$PATH
ENV="env -i LANG=C PATH=/usr/local/bin:/usr/bin:/bin LC_MESSAGES=en_US"

#declare -a nflow=('Nflow' '2055')
#declare -a sflow=('Sflow' '6343')

whoissrv="v4.whois.cymru.com"
whoishead="AS\t| IP\t\t   | BGP Prefix\t\t | CC | AS Name"
pre_apps="rsync wget perl-CPAN make nano bc traceroute openssh-clients tcpdump wireshark mailx screen man mc net-snmp-utils"

function bold() {
echo -e "\033[1m$@\033[0m"
}


function get_ip2() {
	read -p "Enter edge router IP address: "  router
	if [[ $router =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
	echo -e "IP OK. \c"
	get_snmp
	edge="$router $edge"
	function get_ip_q() {
	read -p "Add another edge router? [y/n] " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
		    get_ip2
		elif [[ $REPLY =~ ^[Nn]$ ]]
		then
			IFS=' ' read -a routers <<< "$edge"
			IFS=' ' read -a snmpc <<< "$var_snmp"
			echo "A total of ${#routers[@]} edge routers will be checked."
		else
		get_ip_q
		fi
	}
	get_ip_q
	else echo "Incorrect IP specified!"; get_ip ; fi
}
function get_snmp() {
        read -p "Enter SNMP Community for $router: "  snmps
        if [[ ! `echo $strings | grep -q [^[:alpha:]]` ]]; then
        echo "SNMP community accepted."; var_snmp="$snmps $var_snmp"; else echo "Incorrect community specified!"; get_snmp ; fi
}

function get_snmp_proc() {
	echo -e "  Router Name:\t\t\c"
	router_snmp=`snmpwalk -Os -v2c -c ${snmpc[$n]} $r .1.3.6.1.2.1.1.5.0 2>/dev/null | awk -F" = " '{print $2}' |sed -e 's/STRING: //g' -e 's/OID: //g' -e 's/INTEGER: //g'`
	if [[ ! $router_snmp ]]; then echo SNMP error; else bold $router_snmp; fi
	echo -e "  Router Type:\t\t\c"
	router_type=`snmpwalk -Os -v2c -c ${snmpc[$n]} $r .1.3.6.1.2.1.1.1 l 2>/dev/null | awk -F" = " '{print $2}' |sed -e 's/STRING: //g' -e 's/OID: //g' -e 's/INTEGER: //g'`
	if [[ ! $router_type ]]; then echo SNMP error; else bold $router_type; fi
}

function check_routers() {
echo ""
n=0
for r in ${routers[@]}; do
	echo -e "SNMP results for edge router `bold $r`:"
	#echo -e "$r ${snmpc[$n]}"
	get_snmp_proc
	n=$(( $n + 1 ))
done
}

function get_snmp_old() {
        read -p "Enter Router SNMP Community: "  snmpc
        if [[ ! `echo $router | grep -q [^[:alpha:]]` ]]; then
        echo "SNMP community accepted"; else echo "Incorrect community specified!"; get_snmp ; fi
}
function get_flow_port() {
        read -p "Enter $1 port [$2]: "  fp
        var=`echo $1 |tr '[:upper:]' '[:lower:]'`
        if [[ $fp ]]; then
                vars="$1, $fp"
                IFS=', ' read -a "$1" <<< "$vars"
        else
                vars="$1, $2"
                IFS=', ' read -a "$1" <<< "$vars"
       	fi
}
function app_check() {
	echo -e "\n  Checking preinstalled apps:"
	line='----------------------------------------'
	for a in $@; do
	if [[ `rpm -qa $a` ]]; then
        app_status="\e[92m[Installed]\e[0m"
        printf "%s %s %b\n" $a ${line:${#a}} $app_status
	else
        app_status="\e[91m[Missing]\e[0m"
        printf "%s %s %b\n" $a ${line:${#a}} $app_status
        noapp="$a $noapp"
	fi
	done
	if [[ $noapp ]]; then echo -e "Install missing apps using the following command:\n\e[1m yum install $noapp\e[0m\n"; fi
}


get_ip2
get_flow_port Nflow 2055
get_flow_port Sflow 6343


function flow_ver() {
	tshark -i any -c 20 port $1 -d udp.port==$1,cflow -T fields -e cflow.version 2>/dev/null|sort |uniq
}

function asname() {
for fn in $traff; do whois -h $whoissrv " -c -p $fn" 2>/dev/null ; done | egrep -v "$whoissrv|AS Name"
}

function flow() {
	killall -9 tshark 2>/dev/null
	$(tshark -i any -n port $2 -c 20 2> /dev/null > /tmp/flow.out & 2> /dev/null)
	flow_pid=`pidof tshark`
	sleep 15
	kill -9 $flow_pid 2> /dev/null
	flow_src=`cat /tmp/flow.out |awk '{print $2}' | sort | uniq | tr '\n' ','`
	if [[ ! $flow_src ]]; then
		echo "no traffic detected"
	else
		bold ${flow_src%,}
		echo -e "  versions found:\t\c"
		bold `tshark -i any -c 20 port $2 -d udp.port==$2,cflow -T fields -e cflow.version 2>/dev/null |sort | uniq | tr '\n' ',' |sed -e 's/[","]*$//g'`
		echo -e "  ASNs detected from sample traffic: (this might take some time)"
		traff="`get_in_ips` `get_out_ips`"
		echo -e "$whoishead"
		asname
	fi
}



function get_out_ips() {
killall -9 tshark 2>/dev/null
tshark -ni any -c 100 port ${Nflow[1]} -d udp.port==${Nflow[1]},cflow -T fields -e ip.src 2> /dev/null \
| sed -e 's/\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)/\1.\2.\3.0/g'|sort|uniq |sort -rn|head
}

function get_in_ips() {
killall -9 tshark 2>/dev/null
tshark -i any -c 100 port ${Nflow[1]} -T fields -e cflow.srcaddr 2>/dev/null \
| sed -e 's/\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)/\1.\2.\3.0/g' |tr ',' '\n' |sort |uniq |sort -rn|head
}


bold_s='\033[1m'
bold_e='\033[0m'



function resolver() {

host1=google.com
host2=wikipedia.org

((ping -w5 -c3 $host1 || ping -w5 -c3 $host2) > /dev/null 2>&1) && echo "Configured" || (echo "Not configured" && exit 1)


}

function get_eth() {
vars=`ip address show | grep eth | grep inet | awk '{ print $7 "=>" $2 }' |egrep -v 'secondary' |tr '\n' ' '`
IFS=' ' read -a nets <<< $vars
        for ip in ${nets[@]}; do
        echo -e "\t\t\t`bold $ip`"
        done
} 

echo -e "\n  Server precheck details:"
echo -e "CPU:\t\t\t$bold_s`cat /proc/cpuinfo | grep "model name" | head -1 | awk -F ": " '{print $2}'` $bold_e"
echo -e "RAM:\t\t\t$bold_s`free -m | sed  -n -e '/^Mem:/s/^[^0-9]*\([0-9]*\) .*/\1/p'` MB $bold_e"
echo -e "HDD:\t\t\t$bold_s`df -h / | tail -n 1 | awk '{print $2 " -> " $4 " used"}'` $bold_e"
echo -e "NET:\c"
get_eth
echo -e "DNS:\t\t\t$bold_s`resolver` $bold_e"
echo -e "OS:\t\t\t$bold_s`head -1 /etc/issue |cut -d'\' -f1` `uname -m` $bold_e"
app_check $pre_apps
check_routers
echo -e "\n${Nflow[0]} sources: \t\t\c"
flow ${Nflow[*]}
echo -e "\n${Sflow[0]} sources: \t\t\c"
flow ${Sflow[*]}

