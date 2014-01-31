#!/bin/bash
#
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
		    get_ip
		elif [[ $REPLY =~ ^[Nn]$ ]]
		then
			IFS=' ' read -a routers <<< "$edge"
			IFS=' ' read -a snmpc <<< "$var_snmp"
			echo "A total of ${#routers[@]} edge routers will be checked. SNMP: ${#snmpc[@]}"
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

function check_routers() {
get_ip
n=0
for r in ${routers[@]}; do
	echo -e "$r ${snmpc[$n]}"
	n=$(( $n + 1 ))
done
}