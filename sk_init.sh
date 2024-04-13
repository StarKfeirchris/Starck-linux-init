#!/bin/bash

# Setting the execution environment, always open.
set -eo pipefail

# Definition color; E = Color end
R="\e[1;91m"
G="\e[1;92m"
Y="\e[1;93m"
B="\e[1;96m"
E="\e[0m"

# Select feature
read -p "
$(echo -e "${Y}1${E} > ${G}Update mainline kernel (latest; ${E}${R}Only Rocky Linux${E}${G})${E}")
$(echo -e "${Y}2${E} > ${G}Update longterm kernel (5.4.x; ${E}${R}Only Rocky Linux${E}${G})${E}")
$(echo -e "${Y}3${E} > ${G}Run redhat_init (for Rocky Linux 8 & Fedora 34+ and later )${E}")
$(echo -e "${Y}4${E} > ${G}Run ubuntu_init (for Ubuntu 16.04 and later)${E}")
$(echo -e "${Y}5${E} > ${G}Verify redhat_init or ubuntu_init result${E}")
$(echo -e "${Y}Q/q${E} > ${G}Quit${E}")

$(echo -e "${B}What do you want to do this time?(Enter number) >${E}") " feature_choose
echo

# For quit feature.
if [[ ${feature_choose} == Q || ${feature_choose} == q ]];
then
	exit 0
fi

# Install redhat lsb pakage.
redhat_lsb=$(cat /etc/os-release | grep ID | head -n1 | cut -f2 -d"=")
if [[ ${redhat_lsb} == ubuntu ]];
then
	true
else
	lsb_installed=$(rpm -qa | grep redhat-lsb-core || true)
	if [[ ${lsb_installed} == '' ]];
	then
		dnf install -y redhat-lsb --skip-broken
	fi
fi

# Get system version.
os=$(lsb_release -irs | xargs)

# Check elrepo source.
if [[ ${os} == 'Rocky '* ]];
then
	check_elrepo=$(ls /etc/yum.repos.d/ | grep elrepo || true)
fi

case ${feature_choose} in
	1 )
		if [[ ${os} == 'Rocky '* ]];
		then
			true
		else
			echo -e "${R}This system is not Rocky Linux! please check your system.${E}"
			exit 0
		fi

		if [[ ${check_elrepo} == '' ]];
		then
			echo -e "${R}You are not run redhat_init, please run first.${E}"
			exit 0
		else
			dnf --exclude=kernel-* update -y
			dnf --exclude=kernel-* upgrade -y

			# Update mainline kernel
			dnf -y --enablerepo=elrepo-kernel install kernel-ml
			grub2-set-default 0
		fi

		echo -e "${G}Mainline kernel update succeed.${E}"
		
		true
		;;

	2 )
		if [[ ${os} == 'Rocky '* ]];
		then
			true
		else
			echo -e "${R}This system is not Rocky Linux! please check your system.${E}"
			exit 0
		fi
		
		if [[ ${check_elrepo} == '' ]];
		then
			echo -e "${R}You are not run redhat_init, please run first.${E}"
			exit 0
		else
			dnf --exclude=kernel-* update -y
			dnf --exclude=kernel-* upgrade -y

			# Update mainline kernel
			dnf -y --enablerepo=elrepo-kernel install kernel-lt
			grub2-set-default 0
		fi

		echo -e "${G}Longterm kernel update succeed.${E}"
		true
		;;

	3 )
		if [[ ${os} == 'Rocky '* || ${os} == 'Fedora '* ]];
		then
			# Disable SELinux.
			sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

			# Backup bashrc file.
			bashrc_backup=$(ls /etc | grep -E 'bashrc.bak|bashrc.original' || true)
			if [[ ${bashrc_backup} == '' ]];
			then
				\cp -f /etc/bashrc /etc/bashrc.original
			fi

			first_run=$(cat /etc/bashrc | grep '0;94m' | cut -f13 -d'[' | cut -f1 -d'\' || true)
			if [[ ${first_run} == '' ]];
			then
				# Execute command for different system versions.
				# Disable firewall. (Default not disable)
				# Backup & setup prompt config.
				# Update system & install EPEL repo. (Rocky Linux only)
				# Upgrade kernel to mainline.
				if [[ ${os} == 'Rocky 8.'* ]];
				then
					# If you need close firewall, remove comment.
					#systemctl disable firewalld
					sed -i '45 s/  /  #/g' /etc/bashrc
					sed -i '45a [ "$PS1" = "\\\\\s-\\\\\/v\\\\\\$ " ] && PS1="\\[\\e[0;91m\\][\\[\\e[0m\\]\\[\\e[0;92m\\]\\u\\[\\e[0m\\]\\[\\e[0;94m\\]@\\h\\[\\e[0m\\] \\[\\e[0;93m\\]\\W/\\[\\e[0m\\]\\[\\e[0;91m\\]]\\[\\e[0m\\]\\[\\e[0;93m\\]\\\\\$\\[\\e[0m\\] "' /etc/bashrc
					sed -i '46 s/^/   /' /etc/bashrc
					sed -i '46 s/\/v/v/' /etc/bashrc

					# Update system
					dnf install -y epel-release
					dnf update -y
					dnf upgrade -y

					# Install Rocky Linux 8 elrepo & public key
					dnf install -y https://www.elrepo.org/elrepo-release-8.0-2.el8.elrepo.noarch.rpm || true
					rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org || true

					# Install mainline kernel
					dnf --enablerepo=elrepo-kernel install -y kernel-ml
					grub2-set-default 0

				elif [[ ${os} == 'Fedora '* ]];
				then
					sed -i '45 s/  /   #/g' /etc/bashrc
					sed -i '45a [ "$PS1" = "\\\\\s-\\\\\/v\\\\\\$ " ] && PS1="\\[\\e[0;91m\\][\\[\\e[0m\\]\\[\\e[0;92m\\]\\u\\[\\e[0m\\]\\[\\e[0;94m\\]@\\h\\[\\e[0m\\] \\[\\e[0;93m\\]\\W/\\[\\e[0m\\]\\[\\e[0;91m\\]]\\[\\e[0m\\]\\[\\e[0;93m\\]\\\\\$\\[\\e[0m\\] "' /etc/bashrc
					sed -i '46 s/^/    /' /etc/bashrc
					sed -i '46 s/\/v/v/' /etc/bashrc
					echo '
#!/bin/bash
# THIS FILE IS ADDED FOR COMPATIBILITY PURPOSES
#
# It is highly advisable to create own systemd services or udev rules
# to run scripts during boot instead of using this file.
#
# In contrast to previous versions due to parallel execution during boot
# this script will NOT be run after all other services.
#
# Please note that you must run 'chmod +x /etc/rc.d/rc.local' to ensure
# that this script will be executed during boot.

					' >> /etc/rc.d/rc.local
					# If you need close firewall, remove comment.
					#systemctl disable firewalld
					#chmod +x /etc/rc.d/rc.local
					#echo "systemctl stop firewalld" >> /etc/rc.d/rc.local
					dnf update -y
					dnf upgrade -y

				fi
			fi

			# Remove ntpd (If installed)
			dnf remove -y ntp

			# Install pakage.
			dnf install -y vim bash-completion net-tools wget screen chrony

			# Add chrony configuration.
			chronyd_conf=$(cat /etc/chrony.conf | grep 'stdtime' | cut -f2 -d'.' | uniq -d || true)
			if [[ ${chronyd_conf} == '' ]];
			then
				sed -i 's/pool /#pool /g' /etc/chrony.conf
				sed -i '2a server ntp2.ntu.edu.tw prefer' /etc/chrony.conf
				sed -i '2a server clock.stdtime.gov.tw prefer' /etc/chrony.conf
				sed -i '2a server ntp.ntu.edu.tw prefer' /etc/chrony.conf
				sed -i '2a server time.stdtime.gov.tw prefer' /etc/chrony.conf

				systemctl enable chronyd
				systemctl start chronyd
			fi

			# Add history time.
			# Only the first run will be written, other not.
			his_time_conf=$(cat /etc/bashrc | grep 'History Time' | cut -f2-3 -d' ' || true)
			if [[ ${his_time_conf} == '' ]];
			then
				echo '

######################## History Time ########################
# History time
#(%m=month %d=day %y=year %H=hour,00..23 %M=minute,00..59 %S=second,00..60)
#(%a=weekday name,e.g.fri %w=day for week,0..6, 0 is sunday)
export HISTTIMEFORMAT="%m/%d/%y %a %H:%M:%S -> "
#export HISTTIMEFORMAT="%m/%d/%y %w %H:%M:%S -> "
#History file size
#export HISTFILESIZE=1000000
#History saved commad line
export HISTSIZE=20000
##############################################################
				' >> /etc/bashrc
			fi

			# Add TCP BBR config
			sysctl_config=$(cat /etc/sysctl.conf | grep BBR | cut -f2 -d' ' || true)
			if [[ ${sysctl_config} == '' ]];
			then
				echo '

# BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
				' >> /etc/sysctl.conf
			fi

		else
			echo -e "${R}This system is not Rocky Linux or Fedora! please check your system.${E}"
			exit 0
		fi
		;;

	4 )
		if [[ ${os} == 'Ubuntu '* ]];
		then
			# This line is avoid the "sudo: unable to resolve host xxx" issue.
			# "${HOSTNAME}" is the system default variable.
			hosts_conf=$(sudo cat /etc/hosts | grep ${HOSTNAME} || true)
			if [[ ${hosts_conf} == '' ]];
			then
				sudo sed -i "1i 127.0.0.1 ${HOSTNAME}" /etc/hosts
			fi

			ubuntu_release=$(lsb_release -rs)
			if [[ ${ubuntu_release} = 18.04 ]];
			then
				sudo add-apt-repository universe
			fi

			sudo apt update
			apt list --upgradable

			echo -e "${B}Setup ${E}${Y}Root ${E}${B}password:${E}"
			sudo passwd root

			if [[ ${ubuntu_release} = 18.04 ]];
			then
				sudo sed -i 's/^#PermitRootLogin .*/PermitRootLogin yes/g' /etc/ssh/sshd_config
			else
				sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/g' /etc/ssh/sshd_config
			fi

			sudo systemctl restart ssh

			sudo apt install -y vim bash-completion wget screen chrony

			# Add chrony configuration.
			chronyd_conf=$(cat /etc/chrony/chrony.conf | grep 'stdtime' | cut -f2 -d'.' | uniq -d || true)

			if [[ ${chronyd_conf} == '' ]];
			then
				sudo sed -i 's/pool /#pool /g' /etc/chrony/chrony.conf
				sudo sed -i 's/^server \([0-3]\).ubuntu/#\0.ubuntu/' /etc/chrony/chrony.conf
				sudo sed -i '16a server ntp2.ntu.edu.tw prefer' /etc/chrony/chrony.conf
				sudo sed -i '16a server clock.stdtime.gov.tw prefer' /etc/chrony/chrony.conf
				sudo sed -i '16a server ntp.ntu.edu.tw prefer' /etc/chrony/chrony.conf
				sudo sed -i '16a server time.stdtime.gov.tw prefer' /etc/chrony/chrony.conf

				sudo systemctl enable chrony
				sudo systemctl restart chrony

			fi

			# Backup bashrc file
			bashrc_conf=$(ls /etc | grep -E 'bash.bashrc.original' || true)
			if [[ ${bashrc_conf} == '' ]];
			then
				sudo \cp -f /etc/bash.bashrc /etc/bash.bashrc.original
				sudo \cp -f .bashrc .bashrc.original
				sudo \cp -f /root/.bashrc /root/.bashrc.original

				# Add root history time
				sudo sed -i '16 s/HISTSIZE=1000/HISTSIZE=1000000/g' /root/.bashrc
				sudo sed -i '17 s/HISTFILESIZE=2000/HISTFILESIZE=200000/g' /root/.bashrc

				# Add user history time
				sudo sed -i '19 s/HISTSIZE=1000/HISTSIZE=1000000/g' .bashrc
				sudo sed -i '20 s/HISTFILESIZE=2000/HISTFILESIZE=200000/g' .bashrc

				# Add global history time
				sudo sed -i '11 G' /etc/bash.bashrc
				sudo sed -i '12a # History time' /etc/bash.bashrc
				sudo sed -i '13a HISTTIMEFORMAT="%m/%d/%y %a %H:%M:%S -> "' /etc/bash.bashrc

				# Add root prompt color
				sudo sed -i '52 s/^/#/g' /root/.bashrc
				sudo sed -i '53 s/^/#/g' /root/.bashrc
				sudo sed -i '54 s/^/#/g' /root/.bashrc
				sudo sed -i '55 s/^/#/g' /root/.bashrc
				sudo sed -i '56 s/^/#/g' /root/.bashrc
				sudo sed -i '57 s/^/#/g' /root/.bashrc
				sudo sed -i '57 G' /root/.bashrc
				sudo sed -i '58a 'PS1="'\\\[\\\e[0;92m\\\]\\\u\\\[\\\e[0m\\\]\\\[\\\e[0;94m\\\]@\\\h\\\[\\\e[0m\\\]:\\\[\\\e[0;93m\\\]\\\w\\\[\\\e[0m\\\]\\\[\\\e[0;91m\\\]\\\\$\\\[\\\e[0m\\\] '"'' /root/.bashrc
				sudo sed -i '59a set color_prompt force_color_prompt' /root/.bashrc
			fi

			# Add TCP BBR config
			sysctl_config=$(cat /etc/sysctl.conf | grep BBR | cut -f2 -d' ' || true)
			if [[ ${sysctl_config} == '' ]];
			then
				sudo sh -c "echo '
					
# BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
				' >> /etc/sysctl.conf"
			fi

		else
			echo -e "${R}This system is not Ubuntu! please check your system.${E}"
			exit 0
		fi
		;;

	5 )
		echo -e "${B}System infomation:${E}"
		if [[ ${os} == 'Rocky '* || ${os} == 'Fedora '* ]];
		then
			cat /etc/system-release
		else
			lsb_release -ds
		fi

		echo
		uname -snr
		echo
		date
		echo
		ip a | grep -E "eth0|eth1|eno|enp|ens|em1|em2"
		echo

		if [[ ${os} == 'Rocky '* || ${os} == 'Fedora '* ]];
		then
			echo -e "${B}Firewall status:${E}"
			echo -e "${G}(Default active.)${E}"

			# Execute command for different system versions. 
			# show firewall status.
			systemctl status firewalld | grep -B2 --color=auto -E "running|dead|activating" || true
			echo

			echo -e "${B}Check SELinux:${E}"
			sestatus | grep "SELinux status:"
			echo

			echo -e "${B}Check EPEL repo:${E}"
			echo -e "${B}(Fedora is null.)${E}"
			rpm -qa | grep epel || true
			echo

			echo -e "${B}Check bash-completion${E}"
			rpm -qa | grep bash-completion || true
			echo

			echo -e "${B}Check VIM:${E}"
			rpm -qa | grep vim-enhanced || true
			echo

			echo -e "${B}Check wget:${E}"
			rpm -qa | grep wget || true
			echo

			echo -e "${B}Check screen:${E}"
			rpm -qa | grep screen || true
			echo

			echo -e "${B}Check net-tools:${E}"
			rpm -qa | grep net-tools || true
			echo

			echo -e "${B}Check chrony status:${E}"
			systemctl status chronyd | grep -B2 --color=auto -E "running|dead|activating" || true
			echo

			echo -e "${B}Check history time config:${E}"
			tail -n12 /etc/bashrc
			echo

			echo -e "${B}Check TCP BBR config:${E}"
			bbr_1=$(sysctl -n net.ipv4.tcp_congestion_control || true)
			bbr_2=$(lsmod | grep bbr || true)
			echo '1. '$bbr_1 '(print screen message should be "bbr")'
			echo '2. '$bbr_2 '(print screen message like "tcp_bbr 20480 5")'
			echo
			exit 0

		elif [[ ${os} == 'Ubuntu '* ]];
		then
			echo -e "${B}Check root login configuration:${E}"
			sudo cat /etc/ssh/sshd_config | grep "PermitRootLogin" | head -n1 | grep --color=auto -E "yes|prohibit-password|without-password"
			echo

			echo -e "${B}Check bash-completion${E}"
			dpkg -l | grep bash-completion || true
			echo

			echo -e "${B}Check VIM:${E}"
			dpkg -l | grep vim | head -n1 || true
			echo

			echo -e "${B}Check wget:${E}"
			dpkg -l | grep wget || true
			echo

			echo -e "${B}Check screen:${E}"
			dpkg -l | grep screen | tail -n1 || true
			echo

			echo -e "${B}Check chrony status:${E}"
			systemctl status chrony | grep -B2 Active | grep -B2 --color=auto -E "running|dead|activating" || true
			echo

			echo -e "${B}Check history time config:${E}"
			sudo cat /etc/bash.bashrc | grep HISTTIME || true
			echo

			echo -e "${B}Check TCP BBR config:${E}"
			if [[ ${os} == 'Ubuntu 18.04' ]];
			then
				bbr_1=$(sysctl -n net.ipv4.tcp_congestion_control || true)
				bbr_2=$(lsmod | grep bbr || true)
				echo '1. '$bbr_1 '(print screen message should be "bbr")'
				echo '2. '$bbr_2 '(print screen  message like "tcp_bbr 20480 5")'
				echo
			else
				echo -e "${Y}Your system is not support TCP BBR.${E}"
				echo
			fi
			exit 0

		else
			echo -e "${R}This system is not Ubuntu! please check your system.${E}"
			exit 0
		fi
		;;
esac

while read -p "$(echo -e "${B}Do you want to reboot? (Y/N)${E}") " reboot
do
	if [[ ${reboot} == y || ${reboot} == Y ]];
	then
		sudo init 6
	elif [[ ${reboot} == n || ${reboot} == N ]];
	then
		echo -e "${B}Okay, bye~${E}"
		break
	else
		echo -e "${Y}Please enter Y or N, or Ctrl + C exit.${E}"
	fi
	
	continue
done

