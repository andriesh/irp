#!/bin/bash
#Author: Andriesh Rusnac
if [[ `id -u` != 0 ]]; then
	echo "Are you running as root user?"
	exit 2
fi
function bold() {
echo -e "\033[1m$@\033[0m"
}

function get_customer() {
read -p "Enter customer name: " customer_name
	customer_name=`echo $customer_name | tr '[:upper:]' '[:lower:]'`
	echo "Customer name entered: `bold $customer_name`"
	hostname $customer_name.noction.com
}

function prompt_mod() {
	bashrc="/root/.bashrc"
	bashrc_fmt="export HISTTIMEFORMAT=\"%h/%d - %H:%M:%S \"\nHISTSIZE=1000\nHISTFILESIZE=1000"
	echo "export PS1=\"[\u@\h ($customer_name) \W]\\$ \"" >> $bashrc
	echo -e "$bashrc_fmt" >> $bashrc
}

function ssh_auth() {
	ssh_keyf="/root/.ssh/authorized_keys"
	ssh_key="from=\"178.236.176.169,::ffff:178.236.176.169,91.209.66.16,::ffff:91.209.66.16,195.22.228.156,::ffff:195.22.228.156\" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA4RsxK4NOPA3xU6MIgqJUePPnxsJmHB02hx99C1720nVb/5jsOLQhPuH6cOgwrd/I145hP46UFp7WvsqQmv7z+FTEdQefMdX5MRptgmIR6QXS0pQvy9rngObrUksAaltgwv5a1FqvhB9XpUwBy0OAlFMa5R5XsfQXZ+fihAgoDaxSBhe0PQsiORurD8OtEiQ56ZeyBzwxKrxZg3VFWUi+9sTi4XTjxk1Nj7UiGn/Y2Hqo3LqG+LJQANtU4G0rIVwcvRYSIcmfNWzh34SLx5KzHTr30ixXvjOdWNwl5jjxd+IUuXQlVIVUGYahk53ucxx13M667f4RKYbYI4voxwaVyQ== noction@noction.com
ssh-dss AAAAB3NzaC1kc3MAAACBAKY3uen/2Xh52WxGQWOaYtqhJTLY+pRNdL4jVQwWgnQcM5GWAiqe4A0HiV7klXN/MitJHZiLEJG8wzLlfbt1Jte0a7irALRX7dPJ+fmq8zFpledOKHB+TKDkAg+5EZHpFAXfwxwRWVauE8m9Bl1AwQHkAeWU5zb0ePqBzsmoncOHAAAAFQCFtVrOnf20ZLSlDX+rksLlUleMjwAAAIBrHks3UFs9UqQAxo4mi35mL0DTTFBqyrXMgpjm/HM1F7Y/f2Khy9qafGLf4VlSkKZaE6GW5UgUC3sx9DZo2ynd9RhW/GOtZwnYnG0PrbQrjwBWF0H0hgfxE7D0HUKRLAZv267/A3VuH2pUqlctrZrc4hQV+evzK1CicykbjxY2ZQAAAIEApCQhyArFnAzBZ1nr9xA9bEOXDUFR6mHWxq2IaVgE77Ohg0fEq+9BAc9ECVrcpK2/Pgr8Ffs/FffVTSWrBZ37Pz6ONNO22n61+W70VzzZYBc+dWkImVBKM0Fpk62XfFydiWsZe9X9i3PDHBhcfXCbjlTJjV/MzOlSCT1ulnNYnpw= root@gr"
	mkdir /root/.ssh 2>/dev/null
	echo $ssh_key >> $ssh_keyf
}

function repos() {
	echo "Preparing repositories:"
	echo -e "  Cleaning repo cache ... \c"
	yum clean all -q >/dev/null
	if [[ $? == 0 ]]; then echo "OK"; else echo ERROR; exit 2; fi
	echo -e "  Installing updates ... \c"
	yum -y update >/dev/null
	if [[ $? == 0 ]]; then echo "OK"; else echo ERROR; exit 2; fi
	echo -e "  Installing additional software ... \c"
	yum install rsync wget cpan make nano bc traceroute openssh-clients tcpdump wireshark mailx screen man net-snmp-utils mc -y -q >/dev/null
	if [[ $? == 0 ]]; then echo "OK"; else echo ERROR; exit 2; fi
}

function fw_setup() {
	ip_rules=''
	read -p "Enter additional single or multiple IP addresses delimited by spaces or commas: " ip_list
	ip_list=`echo "$ip_list" | tr ',' '+' | tr ' ' '+'`
	IFS='+' read -a fw_ips <<< "$ip_list"
	for ip in ${fw_ips[@]}; do
		if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
	 		ip_rules="$ip_rules\n-A INPUT -s $ip -j ACCEPT"
	 	else
	 		echo "IP `bold $ip` is not correct."
	 		fw_setup
	 	fi
	done
}

function fw_eth() {
	eth_rules=''
	if_list=`ip link |grep eth.: |awk '{print $2}' |tr -d ':' |tr '\n' ' '`
	echo "Network interfaces detected: `bold $if_list`"
	read -p "Enter additional interfaces for local network and/or SPAN: " eth_list
	eth_list=`echo "$eth_list" | tr ',' '+' | tr ' ' '+'`
	IFS='+' read -a fw_ifs <<< "$eth_list"
	for netif in ${fw_ifs[@]}; do
		if [[ $netif =~ ^eth[0-9]$ ]]; then
	 		eth_rules="$eth_rules\n-A INPUT -i $netif -j ACCEPT"
	 	else
	 		echo "Incorrect interface: `bold $netif`"
	 		fw_eth
	 	fi
	done
}

function irpflow() {
	read -p "Enter NetFlow port [2055]: " netflow
	if [[ ! $netflow ]]; then
		netflow="2055"
	fi
	read -p "Enter sFlow port [6343]: " sflow
	if [[ ! $sflow ]]; then
		sflow="6343"
	fi
}
function fw_iptables() {
	fw_file="/etc/sysconfig/iptables"
	fw_settings="*raw\n:PREROUTING ACCEPT [1773897708:180645170745]\n:OUTPUT ACCEPT [3690381522:120083511580]\n-A PREROUTING -p icmp -j NOTRACK \n-A OUTPUT -p icmp -j NOTRACK \n-A OUTPUT -p udp -m udp --dport 33434:33534 -j NOTRACK 
-A OUTPUT -p tcp -m tcp --dport 33434:33534 -j NOTRACK \nCOMMIT\n*filter\n:INPUT ACCEPT [0:0]\n:FORWARD ACCEPT [0:0]\n:OUTPUT ACCEPT [1288223784:41748724535]$ip_rules\n-A INPUT -p tcp -m tcp --sport 33434:33534 -j ACCEPT 
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT \n-A INPUT -p udp -m udp --sport 33434:33534 -j ACCEPT \n-A INPUT -p udp -m udp --dport $netflow -j ACCEPT\n-A INPUT -p udp -m udp --dport $sflow -j ACCEPT  
-A INPUT -s 146.120.112.20/32 -j ACCEPT \n-A INPUT -s 178.236.176.4/32 -j ACCEPT \n-A INPUT -s 178.236.176.169/32 -j ACCEPT \n-A INPUT -s 88.198.68.23/32 -j ACCEPT \n-A INPUT -s 88.198.68.8/32 -j ACCEPT 
-A INPUT -s 91.209.66.0/24 -j ACCEPT \n-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT \n-A INPUT -p icmp -j ACCEPT \n-A INPUT -i lo -j ACCEPT $eth_rules\n-A INPUT -j REJECT --reject-with icmp-host-prohibited 
-A FORWARD -j REJECT --reject-with icmp-host-prohibited \n-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT 
-A INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT \nCOMMIT"
echo -e "Setting iptables rules ... \c"
echo -e "$fw_settings" > $fw_file
if [[ $? == 0 ]]; then echo "OK"; else echo ERROR; exit 2; fi
/etc/init.d/iptables start
}

#
get_customer
prompt_mod
ssh_auth
repos
fw_setup
fw_eth
irpflow
fw_iptables

