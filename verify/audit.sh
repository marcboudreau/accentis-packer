#!/bin/bash
set -e

failures=0

function report {
    skip_var=SKIP_$(echo $1 | tr '.' '_')
    if echo ${!SKIP_*} | grep -q $skip_var; then
        echo "$1 SKIPPED"
    else
        echo "$1 FAILED"
        failures=$(expr $failures + 1)
    fi
}

directory="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ -f $directory/verify.env ]; then
    . $directory/verify.env
fi

# CIS 1.1.1.1
(
    [ "$(modprobe -n -v cramfs | grep -E '(cramfs|install)')" = "install /bin/true " ]
    [ ! "$(lsmod | grep cramfs)" ]
) || report "1.1.1.1"

# CIS 1.1.1.2
(
    [ "$(modprobe -n -v freevxfs | grep -E '(freevxfs|install)')" = "install /bin/true " ]
    [ ! "$(lsmod | grep freevxfs)" ]
) || report "1.1.1.2"

# CIS 1.1.1.3
(
    [ "$(modprobe -n -v jffs2 | grep -E '(jffs2|install)')" = "install /bin/true " ] 
    [ ! "$(lsmod | grep jffs2)" ]
) || report "1.1.1.3"

# CIS 1.1.1.4
(
    [ "$(modprobe -n -v hfs | grep -E '(hfs|install)')" = "install /bin/true " ]
    [ ! "$(lsmod | grep hfs)" ]
) || report "1.1.1.4"

# CIS 1.1.1.5
(
    [ "$(modprobe -n -v hfsplus | grep -E '(hfsplus|install)')" = "install /bin/true " ]
    [ ! "$(lsmod | grep hfsplus)" ]
) || report "1.1.1.5"

# CIS 1.1.1.6
(
    [ "$(modprobe -n -v udf | grep -E '(udf|install)')" = "install /bin/true " ]
    [ ! "$(lsmod | grep udf)" ]
) || report "1.1.1.6"

# CIS 1.1.2
(
    mount | grep -q '\s/tmp\s'
    grep '\s/tmp\s' /etc/fstab | grep -v -q '^\s*#'  || \
        [ "$(systemctl is-enabled tmp.mount)" = "enabled" ]
) || report "1.1.2"

# CIS 1.1.3
(
    [ ! "$(mount | grep -E '\s/tmp\s' | grep -v nodev)" ]
) || report "1.1.3"

# CIS 1.1.4
(
    [ ! "$(mount | grep -E '\s/tmp\s' | grep -v nosuid)" ]
) || report "1.1.4"

# CIS 1.1.5
(
    [ ! "$(mount | grep -E '\s/tmp\s' | grep -v noexec)" ]
) || report "1.1.5"

# CIS 1.1.6
(
    mount | grep -q '\s/dev/shm\s'
    grep '\s/dev/shm\s' /etc/fstab | grep -v -q '^\s*#'
) || report "1.1.6"

# CIS 1.1.7
(
    [ ! "$(mount | grep -E '\s/dev/shm\s' | grep -v nodev)" ]
) || report "1.1.7"

# CIS 1.1.8
(
    [ ! "$(mount | grep -E '\s/dev/shm\s' | grep -v nosuid)" ]
) || report "1.1.8"

# CIS 1.1.9
(
    [ ! "$(mount | grep -E '\s/dev/shm\s' | grep -v noexec)" ]
) || report "1.1.9"

# CIS 1.1.12
(
    [ ! "$(mount | grep -E '\s/var/tmp\s' | grep -v nodev)" ]
) || report "1.1.12"

# CIS 1.1.13
(
    [ ! "$(mount | grep -E '\s/var/tmp\s' | grep -v nosuid)" ]
) || report "1.1.13"

# CIS 1.1.14
(
    [ ! "$(mount | grep -E '\s/var/tmp\s' | grep -v noexec)" ]
) || report "1.1.14"

# CIS 1.1.18
(
    [ ! "$(mount | grep -E '\s/home\s' | grep -v nodev)" ]
) || report "1.1.18"

# CIS 1.1.22
(
    [ ! "$(df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -type d \( -perm -0002 -a ! -perm -1000 \) 2>/dev/null)" ]
) || report "1.1.22"

# CIS 1.1.23
(
    [ "$(systemctl is-enabled autofs 2> /dev/null)" != "enabled" ]
    [ ! "$(dpkg -s autofs 2> /dev/null)" ]
) || report "1.1.23"

# CIS 1.1.24
(
    [ "$(modprobe -n -v usb-storage)" = "install /bin/true " ]
    [ ! "$(lsmod | grep usb-storage)" ]
) || report "1.1.24"

# CIS 1.3.1
(
    dpkg -s sudo > /dev/null 2>&1
) || report "1.3.1"

# CIS 1.3.2
(
    grep -E -i -q '^\s*Defaults\s+([^#]+,\s*)?use_pty(,\s+\S+\s*)*(\s+#.*)?$' /etc/sudoers /etc/sudoers.d/*
) || report "1.3.2"

# CIS 1.3.3
(
    grep -E -i -q '^\s*Defaults\s+logfile=\S+' /etc/sudoers /etc/sudoers.d/* 
) || report "1.3.3"

# 1.4.1
(
    dpkg -s aide 2> /dev/null | grep -q 'Status: install ok installed'
    dpkg -s aide-common 2> /dev/null | grep -q 'Status: install ok installed'
) || report "1.4.1"

# 1.4.2
(
    crontab -u root -l 2> /dev/null | grep -q aide ||
        [ "$(find /etc/cron.* /etc/crontab -name 'aide' -type f)" = "/etc/cron.daily/aide" ]
) || report "1.4.2"

# 1.5.1
(
    grep -q '^set superusers' /boot/grub/grub.cfg
    grep -q '^password' /boot/grub/grub.cfg
) || report "1.5.1"

# 1.5.2
(
    stat --format='%a %u/%U %g/%G' /boot/grub/grub.cfg | grep -q '400 0/root 0/root'
) || report "1.5.2"

# 1.5.3
(
    grep -q -v '^root:[*\!]:' /etc/shadow
) || report "1.5.3"

# 1.6.1
(
    journalctl | grep -q 'protection: active'
) || report "1.6.1"

# 1.6.2
(
    [ "$(sysctl kernel.randomize_va_space)" = "kernel.randomize_va_space = 2" ]
    grep -q '^\s*kernel\.randomize_va_space\s*=2\s*$' /etc/sysctl.conf /etc/sysctl.d/*
) || report "1.6.2"

# 1.6.3
(
    [ ! "$(dpkg -s prelink 2> /dev/null)" ]
) || report "1.6.3"

# 1.6.4
(
    grep -E -s '^(\*|\s).*hard.*core.*(\s+#.*)?$' /etc/security/limits.conf /etc/security/limits.d/* | sed 's~^/etc/security/limits\..*:~~' | grep -q '\*\s*hard\s*core\s*0'
    [ "$(sysctl fs.suid_dumpable)" = "fs.suid_dumpable = 0" ]
    grep -s 'fs.suid_dumpable' /etc/sysctl.conf /etc/sysctl.d/* | sed 's~^/etc/sysctl\..*:~~' | grep -q '^\s*fs.suid_dumpable\s*=\s*0\s*$'
) || report "1.6.4"

# 1.7.1.1
(
    dpkg -s apparmor > /dev/null 2>&1
) || report "1.7.1.1"

# 1.7.1.2
(
    [ ! "$(grep '^\s*linux' /boot/grub/grub.cfg | grep -v 'apparmor=1')" ]
    [ ! "$(grep '^\s*linux' /boot/grub/grub.cfg | grep -v 'security=apparmor')" ]
) || report "1.7.1.2"

# 1.7.1.3
(
    loaded=$(apparmor_status | grep profiles | grep 'profiles are loaded' | awk '{print $1}')
    enforce=$(apparmor_status | grep profiles | grep 'profiles are in enforce mode' | awk '{print $1}')
    complain=$(apparmor_status | grep profiles | grep 'profiles are in complain mode' | awk '{print $1}')
    [ "$(expr $enforce + $complain)" = "$loaded" ]
    [ "$(apparmor_status | grep processes | grep 'processes are unconfined but have a profile defined' | awk '{print $1}')" = "0" ]
) || report "1.7.1.3"

# 1.8.1.1
(
    [ ! "$(grep -E -i -s '(\\v|\\r|\\m|\\s|$(grep '^ID=' /etc/os-release | cut -d= -f2 | sed -e 's/\"//g'))' /etc/motd)" ]
) || report "1.8.1.1"

# 1.8.1.2
(
    [ ! "$(grep -E -i '(\\v|\\r|\\m|\\s|$(grep '^ID=' /etc/os-release | cut -d= -f2 | sed -e 's/\"//g'))' /etc/issue)" ]
) || report "1.8.1.2"

# 1.8.1.3
(
    [ ! "$(grep -E -i '(\\v|\\r|\\m|\\s|$(grep '^ID=' /etc/os-release | cut -d= -f2 | sed -e 's/\"//g'))' /etc/issue.net)" ]
) || report "1.8.1.3"

# 1.8.1.4
(
    if [ -f /etc/motd ]; then 
        stat --format='%a %u/%U %g/%G' /etc/motd | grep -q '644 0/root 0/root'
    fi
) || report "1.8.1.4"

# 1.8.1.5
(
    stat --format='%a %u/%U %g/%G' /etc/issue | grep -q '644 0/root 0/root'
) || report "1.8.1.5"

# 1.8.1.6
(
    stat --format='%a %u/%U %g/%G' /etc/issue.net | grep -q '644 0/root 0/root'
) || report "1.8.1.6"

# 1.10
(
    if dpkg -s gdm3 > /dev/null 2>&1; then
        grep -q 'banner-message-enable=true' /etc/gdm3/greeter.dconf-defaults
        grep -q 'banner-message-text=' /etc/gdm3/greeter.dconf-defaults
        grep -q 'disable-user-list=true' /etc/gdm3/greeter.dconf-defaults
    fi
) || report "1.10"

# 2.1.1
(
    [ ! "$(dpkg -s xinetd 2> /dev/null)" ]
) || report "2.1.1"

# 2.1.2
(
    [ ! "$(dpkg -s openbsd-inetd 2> /dev/null)" ]
) || report "2.1.2"

# 2.2.1.1
(
    if [ "$(systemctl is-enabled systemd-timesyncd 2> /dev/null)" != "enabled" ]; then
        [ "$(systemctl is-enabled systemd-timesyncd 2> /dev/null)" = "masked" ]
        dpkg -s chrony > /dev/null 2>&1 || dpkg -s npt > /dev/null 2>&1
    fi
) || report "2.2.1.1"

# 2.2.1.3
(
    if dpkg -s chrony > /dev/null 2>&1; then
        [ ! "$(dpkg -s ntp 2> /dev/null)" ]
        [ "$(systemctl is-enabled systemd-timesyncd 2> /dev/null)" = "masked" ]
        grep -E '^(server|pool)' /etc/chrony/chrony.conf | grep -q '^server'
        [ ! "$(ps -ef | grep chronyd | grep -v grep | grep -v '^_chrony')" ]
    fi
) || report "2.2.1.3"

# 2.2.1.4
(
    if dpkg -s ntp > /dev/null 2>&1; then
        [ ! "$(dpkg -s chrony 2> /dev/null)" ]
        [ "$(systemctl is-enabled systemd-timesyncd 2> /dev/null)" = "masked" ]
        grep '^restrict' /etc/ntp.conf | grep -q 'default\s.*kod.*'
        grep '^restrict' /etc/ntp.conf | grep -q 'default\s.*nomodify.*'
        grep '^restrict' /etc/ntp.conf | grep -q 'default\s.*notrap.*'
        grep '^restrict' /etc/ntp.conf | grep -q 'default\s.*nopeer.*'
        grep '^restrict' /etc/ntp.conf | grep -q 'default\s.*noquery.*'
        grep -E '^(server|pool)' /etc/ntp.conf | grep -q '^server'
        grep -q 'RUNASUSER=ntp' /etc/init.d/ntp
    fi
) || report "2.2.1.4"

# 2.2.2
(
    [ ! "$(dpkg -l xserver-xorg* 2> /dev/null)" ]
) || report "2.2.2"

# 2.2.3
(
    [ ! "$(dpkg -s avahi-daemon 2> /dev/null)"]
) || report "2.2.3"

# 2.2.4
(
    [ ! "$(dpkg -s cups 2> /dev/null)" ]
) || report "2.2.4"

# 2.2.5
(
    [ ! "$(dpkg -s isc-dhcp-server 2> /dev/null)" ]
) || report "2.2.5"

# 2.2.6
(
    [ ! "$(dpkg -s slapd 2> /dev/null)" ]
) || report "2.2.6"

# 2.2.7
(
    [ ! "$(dpkg -s nfs-kernel-server 2> /dev/null)" ]
) || report "2.2.7"

# 2.2.8
(
    [ ! "$(dpkg -s bind9 2> /dev/null)" ]
) || report "2.2.8"

# 2.2.9
(
    [ ! "$(dpkg -s vsftpd 2> /dev/null)" ]
) || report "2.2.9"

# 2.2.10
(
    [ ! "$(dpkg -s apache2 2> /dev/null)" ]
) || report "2.2.10"

# 2.2.11
(
    [ ! "$(dpkg -s dovecot-imapd dovecot-pop3d 2> /dev/null)" ]
) || report "2.2.11"

# 2.2.12
(
    [ ! "$(dpkg -s samba 2> /dev/null)" ]
) || report "2.2.12"

# 2.2.13
(
    [ ! "$(dpkg -s squid 2> /dev/null)" ]
) || report "2.2.13"

# 2.2.14
(
    [ ! "$(dpkg -s snmpd 2> /dev/null)" ]
) || report "2.2.14"

# 2.2.15
(
    [ ! "$(ss -lntu | grep -E ':25\s' | grep -E -v '\s(127.0.0.1|::1|\[::1\]):25\s')" ]
) || report "2.2.15"

# 2.2.16
(
    [ ! "$(dpkg -s rsync 2> /dev/null)" ]
) || report "2.2.16"

# 2.2.17 
(
    [ ! "$(dpkg -s nis 2> /dev/null)" ]
) || report "2.2.17"

# 2.3.1
(
    [ ! "$(dpkg -s nis 2> /dev/null)" ]
) || report "2.3.1"

# 2.3.2
(
    [ ! "$(dpkg -s rsh-client 2> /dev/null)" ]
) || report "2.3.2"

# 2.3.3
(
    [ ! "$(dpkg -s talk 2> /dev/null)" ]
) || report "2.3.3"

# 2.3.4
(
    [ ! "$(dpkg -s telnet 2> /dev/null)" ]
) || report "2.3.4"

# 2.3.5
(
    [ ! "$(dpkg -s ldap-utils 2> /dev/null)" ]
) || report "2.3.5"

# 2.3.6
(
    [ ! "$(dpkg -s rpcbind 2> /dev/null)" ]
) || report "2.3.6"

# 3.1.2
(
    if command -v nmcli > /dev/null 2>&1; then
        nmcli radio all | grep -Eq '\s*\S+\s+disabled\s+\S+\s+disabled\b'
    elif [ -n "$(find /sys/class/net/*/ -type d -name wireless)" ]; then
        t=0
        drivers=$(for driverdir in $(find /sys/class/net/*/ -type d -name wireless | xargs -0 dirname); do basename "$(readlink -f "$driverdir"/device/driver)";done | sort -u)
        for dm in $drivers; do
            grep -E -q "^\s*install\s+$dm\s+/bin/(true|false)" /etc/modprobe.d/*.conf
        done
    fi
) || report "3.1.2"

# 3.2.1
(
    [ "$(sysctl net.ipv4.conf.all.send_redirects)" = "net.ipv4.conf.all.send_redirects = 0" ]
    [ "$(sysctl net.ipv4.conf.default.send_redirects)" = "net.ipv4.conf.default.send_redirects = 0" ]
    grep -q -s '^\s*net\.ipv4\.conf\.all\.send_redirects\s=\s*0\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
    grep -q -s '^\s*net\.ipv4\.conf\.default\.send_redirects\s*=\s*0\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
) || report "3.2.1"

# 3.2.2
(
    [ "$(sysctl net.ipv4.ip_forward)" = "net.ipv4.ip_forward = 0" ]
    [ ! "$(grep -E -s '^\s*net\.ipv4\.ip_forward\s*=\s*1' /etc/sysctl.conf /etc/sysctl.d/*.conf /usr/lib/sysctl.d/*.conf /run/sysctl.d/*.conf)" ]

    if [ "$(grep '^\s*linux' /boot/grub/grub.cfg | grep -v 'ipv6.disable=1')" ]; then
        [ "$(sysctl net.ipv6.conf.all.forwarding)" = "net.ipv6.conf.all.forwarding = 0" ]
        [ ! "$(grep -E -s '^\s*net\.ipv6\.conf\.all\.forwarding\s*=\s*1' /etc/sysctl.conf /etc/sysctl.d/*.conf /usr/lib/systcl.d/*.conf /run/sysctl.d/*.conf)" ]
    fi
) || report "3.2.2"

# 3.3.1
(
    [ "$(sysctl net.ipv4.conf.all.accept_source_route)" = "net.ipv4.conf.all.accept_source_route = 0" ]
    [ "$(sysctl net.ipv4.conf.default.accept_source_route)" = "net.ipv4.conf.default.accept_source_route = 0" ]
    grep -q -s '^\s*net\.ipv4\.conf\.all\.accept_source_route\s*=\s*0\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
    grep -q -s '^\s*net\.ipv4\.conf\.default\.accept_source_route\s*=0\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf

    if [ "$(grep '^\s*linux' /boot/grub/grub.cfg | grep -v 'ipv6.disable=1')" ]; then
        [ "$(sysctl net.ipv6.conf.all.accept_source_route)" = "net.ipv6.conf.all.accept_source_route = 0" ]
        [ "$(sysctl net.ipv6.conf.default.accept_source_route)" = "net.ipv6.conf.default.accept_source_route = 0" ]
        grep -q -s '^\s*net\.ipv6\.conf\.all\.accept_source_route\s*=\s*0\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
        grep -q -s '^\s*net\.ipv6\.conf\.default\.accept_source_route\s*=\s*0\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
    fi
) || report "3.3.1"

# 3.3.2
(
    [ "$(sysctl net.ipv4.conf.all.accept_redirects)" = "net.ipv4.conf.all.accept_redirects = 0" ]
    [ "$(sysctl net.ipv4.conf.default.accept_redirects)" = "net.ipv4.conf.default.accept_redirects = 0" ]
    grep -q -s '^\s*net\.ipv4\.conf\.all\.accept_redirects\s*=\s*0\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
    grep -q -s '^\S*net\.ipv4\.conf\.default\.accept_redirects\s*=\s*0\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf

    if [ "$(grep '^\s*linux' /boot/grub/grub.cfg | grep -v 'ipv6.disable=1')" ]; then
        [ "$(sysctl net.ipv6.conf.all.accept_redirects)" = "net.ipv6.conf.all.accept_redirects = 0" ]
        [ "$(sysctl net.ipv6.conf.default.accept_redirects)" = "net.ipv6.conf.default.accept_redirects = 0" ]
        grep -q -s '^\s*net\.ipv6\.conf\.all\.accept_redirects\s*=\s*0\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
        grep -q -s '^\s*net\.ipv6\.conf\.default\.accept_redirects\s*=\s*0\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
    fi
) || report "3.3.2"

# 3.3.3
(
    [ "$(sysctl net.ipv4.conf.all.secure_redirects)" = "net.ipv4.conf.all.secure_redirects = 0" ]
    [ "$(sysctl net.ipv4.conf.default.secure_redirects)" = "net.ipv4.conf.default.secure_redirects = 0" ]
    grep -q -s '^\s*net\.ipv4\.conf\.all\.secure_redirects\s*=\s*0\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
    grep -q -s '^\s*net\.ipv4\.conf\.default\.secure_redirects\s*=\s*0\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
) || report "3.3.3"

# 3.3.4
(
    [ "$(sysctl net.ipv4.conf.all.log_martians)" = "net.ipv4.conf.all.log_martians = 1" ]
    [ "$(sysctl net.ipv4.conf.default.log_martians)" = "net.ipv4.conf.default.log_martians = 1" ]
    grep -q -s '^\s*net\.ipv4\.conf\.all\.log_martians\s*=\s*1\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
    grep -q -s '^\s*net\.ipv4\.conf\.default\.log_martians\s*=\s*1\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
) || report "3.3.4"

# 3.3.5
(
    [ "$(sysctl net.ipv4.icmp_echo_ignore_broadcasts)" = "net.ipv4.icmp_echo_ignore_broadcasts = 1" ]
    grep -q -s '^\s*net\.ipv4\.icmp_echo_ignore_broadcasts\s*=\s*1\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
) || report "3.3.5"

# 3.3.6
(
    [ "$(sysctl net.ipv4.icmp_ignore_bogus_error_responses)" = "net.ipv4.icmp_ignore_bogus_error_responses = 1" ]
    grep -q -s '^\s*net\.ipv4\.icmp_ignore_bogus_error_responses\s*=\s*1\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
) || report "3.3.6"

# 3.3.7
(
    [ "$(sysctl net.ipv4.conf.all.rp_filter)" = "net.ipv4.conf.all.rp_filter = 1" ]
    [ "$(sysctl net.ipv4.conf.default.rp_filter)" = "net.ipv4.conf.default.rp_filter = 1" ]
    grep -q -s '^\s*net\.ipv4\.conf\.all\.rp_filter\s*=\s*1\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
    grep -q -s '^\s*net\.ipv4\.conf\.default\.rp_filter\s*=\s*1\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
) || report "3.3.7"

# 3.3.8
(
    [ "$(sysctl net.ipv4.tcp_syncookies)" = "net.ipv4.tcp_syncookies = 1" ]
    grep -q -s '^\s*net\.ipv4\.tcp_syncookies\s*=\s*1\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
) || report "3.3.8"

# 3.3.9
(
    if [ "$(grep '^\s*linux' /boot/grub/grub.cfg | grep -v 'ipv6.disable=1')" ]; then
        [ "$(sysctl net.ipv6.conf.all.accept_ra)" = "net.ipv6.conf.all.accept_ra = 0" ]
        [ "$(sysctl net.ipv6.conf.default.accept_ra)" = "net.ipv6.conf.default.accept_ra = 0" ]
        grep -q -s '^\s*net\.ipv6\.conf\.all.accept_ra\s*=\s*0\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
        grep -q -s '^\s*net\.ipv6\.conf\.default.accept_ra\s*=\s*0\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf
    fi
) || report "3.3.9"

# 3.5.1.1
(
    dpkg -s ufw 2> /dev/null | grep -q 'Status: install ok installed'
) || report "3.5.1.1"

# 3.5.1.2
(
    if dpkg -s ufw 2> /dev/null | grep -q 'Status: install ok installed'; then
        [ ! "$(dpkg -s iptables-persistent 2> /dev/null)" ]
    fi
) || report "3.5.1.2"

# 3.5.1.3
(
    if dpkg -s ufw 2> /dev/null | grep -q 'Status: install ok installed'; then
        [ "$(systemctl is-enabled ufw)" = "enabled" ]
        ufw status | grep -q 'Status: active'
    fi
) || report "3.5.1.3"

# 3.5.1.4
(
    if dpkg -s ufw 2> /dev/null | grep -q 'Status: install ok installed'; then
        readarray -t rules <<<"$(ufw status verbose | tail +8)"

        expressions=("Anywhere on lo ALLOW IN Anywhere " "Anywhere DENY IN 127.0.0.0/8 " "Anywhere (v6) on lo ALLOW IN Anywhere (v6) " "Anywhere (v6) DENY IN ::1 " "Anywhere ALLOW OUT Anywhere on lo " "Anywhere (v6) ALLOW OUT Anywhere (v6) on lo ")
        expr_i=0
        rules_i=0

        while [ $rules_i -lt ${#rules[@]} ]; do
            if [ "$(echo "${rules[$rules_i]}" | sed 's/\s\s*/ /g')" = "${expressions[$expr_i]}" ]; then
                expr_i=$(expr $expr_i + 1)
            fi
            if [ $expr_i -eq ${#expressions[@]} ]; then
                break
            fi

            rules_i=$(expr $rules_i + 1)
        done
        [ $expr_i -eq ${#expressions[@]} ]
    fi
) || report "3.5.1.4"

# 3.5.1.5
(
    if dpkg -s ufw 2> /dev/null | grep -q 'Status: install ok installed'; then
        readarray -t rules <<<"$(ufw status verbose | tail +8)"

        expressions=("Anywhere ALLOW OUT Anywhere on all " "Anywhere (v6) ALLOW OUT Anywhere (v6) on all ")
        expr_i=0
        rules_i=0

        while [ $rules_i -lt ${#rules[@]} ]; do
            if [ "$(echo "${rules[$rules_i]}" | sed 's/\s\s*/ /g')" = "${expressions[$expr_i]}" ]; then
                expr_i=$(expr $expr_i + 1)
            fi
            if [ $expr_i -eq ${#expressions[@]} ]; then
                break
            fi

            rules_i=$(expr $rules_i + 1)
        done
        [ $expr_i -eq ${#expressions[@]} ]
    fi
) || report "3.5.1.5"

# 3.5.1.6
(
    if dpkg -s ufw 2> /dev/null | grep -q 'Status: install ok installed'; then
        tcp_ports=($(ss -4tln | grep -v '127\.0\.0\.' | tail +2 | awk '{print $4}' | cut -d: -f2))
        udp_ports=($(ss -4uln | grep -v '127\.0\.0\.' | tail +2 | awk '{print $4}' | cut -d: -f2))

        for tcp_port in ${tcp_ports[@]}; do
            ufw status | grep -q "$tcp_port/tcp\s\s*ALLOW"
            ufw status | grep -q "$tcp_port/tcp (v6)\s\s*ALLOW"
        done

        for udp_port in ${udp_ports[@]}; do
            ufw status | grep -q "$udp_port/udp\s\s*ALLOW"
            ufw status | grep -q "$udp_port/udp (v6)\s\s*ALLOW"
        done
    fi
) || report "3.5.1.6"

# 3.5.1.7
(
    if dpkg -s ufw 2> /dev/null | grep -q 'Status: install ok installed'; then
        ufw status verbose | grep Default | grep -q 'deny (incoming)'
        ufw status verbose | grep Default | grep -q 'deny (outgoing)'
        ufw status verbose | grep Default | grep -E -q '(deny|disabled|reject) \(routed\)'
    fi
) || report "3.5.1.7"

# 3.5.2.1
(
    dpkg-query -s nftables 2> /dev/null | grep -q 'Status: install ok installed'
) || report "3.5.2.1"

# 3.5.2.2
(
    if dpkg-query -s nftables 2> /dev/null | grep -q 'Status: install ok installed'; then
        if [ "$(dpkg-query -s ufw 2> /dev/null)" ]; then
            ufw status | grep -q '^Status: inactive'
        fi
    fi
) || report "3.5.2.2"

# 3.5.2.4
(
    if dpkg-query -s nftables 2> /dev/null | grep -q 'Status: install ok installed'; then
        [ $(nft list tables | wc -l) -ge 1 ]
    fi
) || report "3.5.2.4"

# 3.5.2.5
(
    if dpkg-query -s nftables 2> /dev/null | grep -q 'Status: install ok installed'; then
        nft list ruleset | grep -q 'hook input'
        nft list ruleset | grep -q 'hook forward'
        nft list ruleset | grep -q 'hook output'
    fi
) || report "3.5.2.5"

# 3.5.2.6
(
    if dpkg-query -s nftables 2> /dev/null | grep -q 'Status: install ok installed'; then
        nft list ruleset | awk '/hook input/,/}/' | grep -q 'iif "lo" accept'
        nft list ruleset | awk '/hook input/,/}/' | grep -q 'ip saddr 127\.0\.0\.0/8'

        if [ "$(grep '^\s*linux' /boot/grub/grub.cfg | grep -v 'ipv6.disable=1')" ]; then
            nft list ruleset | awk '/hook input/,/}/' | grep -q 'ip6 saddr ::1'
        fi
    fi
) || report "3.5.2.6"

# 3.5.2.7
(
    if dpkg-query -s nftables 2> /dev/null | grep -q 'Status: install ok installed'; then
        input_ruleset="$(nft list ruleset | awk '/hook input/,/}/' | grep -E 'ip protocol (tcp|udp|icmp) ct state')"
        echo $input_ruleset | grep -q 'ip protocol tcp ct state established accept'
        echo $input_ruleset | grep -q 'ip protocol udp ct state established accept'
        echo $input_ruleset | grep -q 'ip protocol icmp ct state established accept'

        output_ruleset="$(nft list ruleset | awk '/hook output/,/}/' | grep -E 'ip protocol (tcp|udp|icmp) ct state')"
        echo $output_ruleset | grep -q 'ip protocol tcp ct state established,related,new accept'
        echo $output_ruleset | grep -q 'ip protocol udp ct state established,related,new accept'
        echo $output_ruleset | grep -q 'ip protocol icmp ct state established,related,new accept'
    fi
) || report "3.5.2.7"

# 3.5.2.8
(
    if dpkg-query -s nftables 2> /dev/null | grep -q 'Status: install ok installed'; then
        nft list ruleset | grep 'hook input' | grep -q 'policy drop'
        nft list ruleset | grep 'hook forward' | grep -q 'policy drop'
        nft list ruleset | grep 'hook output' | grep -q 'policy drop'
    fi
) || report "3.5.2.8"

# 3.5.2.9
(
    if dpkg-query -s nftables 2> /dev/null | grep -q 'Status: install ok installed'; then
        [ "$(systemctl is-enabled nftables)" = "enabled" ]
    fi
) || report "3.5.2.9"

# 3.5.2.10
# Can't get this to work

# 3.5.3.1.1
(
    apt list iptables 2> /dev/null | grep -q installed
    apt list iptables-persistent 2> /dev/null | grep -q installed
) || report "3.5.3.1.1"

# 3.5.3.1.2
(
    if apt list iptables-persistent 2> /dev/null | grep -q installed ; then
        [ ! "$(dpkg -s nftables 2> /dev/null)" ]
    fi
) || report "3.5.3.1.2"

# 3.5.3.1.3
(
    if apt list iptables-persistent 2> /dev/null | grep -q installed ; then
        if dpkg-query -s ufw 2> /dev/null; then
            [ "$(ufw status)" = "Status: inactive" ]
            [ "$(systemctl is-enabled ufw)" = "masked" ]
        fi
    fi
) || report "3.5.3.1.3"

# 3.5.3.2.1
(
    if apt list iptables-persistent 2> /dev/null | grep -q installed ; then
        iptables -L | grep -q 'Chain INPUT (policy DROP)'
        iptables -L | grep -q 'Chain FORWARD (policy DROP)'
        iptables -L | grep -q 'Chain OUTPUT (policy DROP)'
    fi
) || report "3.5.3.2.1"

# 3.5.3.2.2
(
    if apt list iptables-persistent 2> /dev/null | grep -q installed ; then
        readarray -t rules <<<"$(iptables -L INPUT -v -n | tail +3 | sed 's/\s\s*/ /g' | cut -d' ' -f4-)"
        expressions=("ACCEPT all -- lo * 0.0.0.0/0 0.0.0.0/0 " "DROP all -- * * 127.0.0.0/8 0.0.0.0/0 ")

        rules_i=0
        expr_i=0

        while [ $rules_i -lt ${#rules[@]} ]; do
            if [ "${rules[$rules_i]}" = "${expressions[$expr_i]}" ]; then
                expr_i=$(expr $expr_i + 1)
            fi
            if [ $expr_i -eq ${#expressions[@]} ]; then
                break
            fi

            rules_i=$(expr $rules_i + 1)
        done
        [ $expr_i -eq ${#expressions[@]} ]

        readarray -t rules <<<"$(iptables -L OUTPUT -v -n | tail +3 | sed 's/\s\s*/ /g' | cut -d' ' -f4-)"
        expressions=("ACCEPT all -- * lo 0.0.0.0/0 0.0.0.0/0 ")

        rules_i=0
        expr_i=0

        while [ $rules_i -lt ${#rules[@]} ]; do
            if [ "${rules[$rules_i]}" = "${expressions[$expr_i]}" ]; then
                expr_i=$(expr $expr_i + 1)
            fi
            if [ $expr_i -eq ${#expressions[@]} ]; then
                break
            fi

            rules_i=$(expr $rules_i + 1)
        done
        [ $expr_i -eq ${#expressions[@]} ]
    fi
) || report "3.5.3.2.2"

# 3.5.3.2.4
(
    if apt list iptables-persistent 2> /dev/null | grep -q installed ; then
        tcp_ports=($(ss -4tln | grep -v '127\.0\.0\.' | tail +2 | awk '{print $4}' | cut -d: -f2))
        udp_ports=($(ss -4uln | grep -v '127\.0\.0\.' | tail +2 | awk '{print $4}' | cut -d: -f2))

        for tcp_port in ${tcp_ports[@]}; do
            iptables -L INPUT -n -v | grep -q "tcp dpt:$tcp_port"
        done

        for udp_port in ${udp_ports[@]}; do
            iptables -L INPUT -n -v | grep -q "udp dpt:$udp_port"
        done
    fi
) || report "3.5.3.2.4"

# 3.5.3.3.1
(
    if apt list iptables-persistent 2> /dev/null | grep -q installed ; then
        if [ "$(grep '^\s*linux' /boot/grub/grub.cfg | grep -v 'ipv6.disable=1')" ]; then
            ip6tables -L | grep -q 'Chain INPUT (policy DROP)'
            ip6tables -L | grep -q 'Chain FORWARD (policy DROP)'
            ip6tables -L | grep -q 'Chain OUTPUT (policy DROP)'
        fi
    fi
) || report "3.5.3.3.1"

# 3.5.3.3.2
(
    if apt list iptables-persistent 2> /dev/null | grep -q installed ; then
        if [ "$(grep '^\s*linux' /boot/grub/grub.cfg | grep -v 'ipv6.disable=1')" ]; then
            readarray -t rules <<<"$(ip6tables -L INPUT -v -n | tail +3 | sed 's/\s\s*/ /g' | cut -d' ' -f4-)"
            expressions=("ACCEPT all lo * ::/0 ::/0 " "DROP all * * ::1 ::/0 ")

            rules_i=0
            expr_i=0

            while [ $rules_i -lt ${#rules[@]} ]; do
                if [ "${rules[$rules_i]}" = "${expressions[$expr_i]}" ]; then
                    expr_i=$(expr $expr_i + 1)
                fi
                if [ $expr_i -eq ${#expressions[@]} ]; then
                    break
                fi

                rules_i=$(expr $rules_i + 1)
            done
            [ $expr_i -eq ${#expressions[@]} ]

            readarray -t rules <<<"$(ip6tables -L OUTPUT -v -n | tail +3 | sed 's/\s\s*/ /g' | cut -d' ' -f4-)"
            expressions=("ACCEPT all * lo ::/0 ::/0 ")

            rules_i=0
            expr_i=0

            while [ $rules_i -lt ${#rules[@]} ]; do
                if [ "${rules[$rules_i]}" = "${expressions[$expr_i]}" ]; then
                    expr_i=$(expr $expr_i + 1)
                fi
                if [ $expr_i -eq ${#expressions[@]} ]; then
                    break
                fi

                rules_i=$(expr $rules_i + 1)
            done
            [ $expr_i -eq ${#expressions[@]} ]
        fi
    fi
) || report "3.5.3.3.2"

# 4.2.1.1
(
    [ "$(dpkg -s rsyslog 2> /dev/null)" ]
) || report "4.2.1.1"

# 4.2.1.2
(
    [ "$(systemctl is-enabled rsyslog)" = "enabled" ]
) || report "4.2.1.2"

# 4.2.1.4
(
    grep -q -s '^\s*\$FileCreateMode 06[04]0' /etc/rsyslog.conf /etc/rsyslog.d/*.conf
) || report "4.2.1.4"

# 4.2.1.5
(
    grep -E '^[^#](\s*\S+\s*)\s*action\(' /etc/rsyslog.conf /etc/rsyslog.d/*.conf | grep -q 'target='
) || report "4.2.1.5"

# 4.2.2.1
(
    grep -q '^\s*ForwardToSyslog\s*=\s*yes\s*$' /etc/systemd/journald.conf
) || report "4.2.2.1"

# 4.2.2.2
(
    grep -q '^\s*Compress\s*=\s*yes\s*$' /etc/systemd/journald.conf
) || report "4.2.2.2"

# 4.2.2.3
(
    grep -q '^\s*Storage\s*=\s*persistent\s*$' /etc/systemd/journald.conf
) || report "4.2.2.3"

# 4.2.3
(
    [ ! "$(find /var/log -type f -print | xargs stat --format=%a | grep -v '.[04]0')" ]
) || report "4.2.3"

# 4.4
(
    [ ! "$(grep -E '^\s*create\s+\S+' /etc/logrotate.conf | grep -E -v '\s(0)?[0-6][04]0s')" ]
) || report "4.4"

# 5.1.1
(
    [ "$(systemctl is-enabled cron)" = "enabled" ]
    systemctl status cron | grep -q 'Active: active (running) '
) || report "5.1.1"

# 5.1.2
(
    stat --format='%a %u/%U %g/%G' /etc/crontab | grep -q '600 0/root 0/root'
) || report "5.1.2"

# 5.1.3
(
    stat --format='%a %u/%U %g/%G' /etc/cron.hourly | grep -q '700 0/root 0/root'
) || report "5.1.3"

# 5.1.4
(
    stat --format='%a %u/%U %g/%G' /etc/cron.daily | grep -q '700 0/root 0/root'
) || report "5.1.4"

# 5.1.5
(
    stat --format='%a %u/%U %g/%G' /etc/cron.weekly | grep -q '700 0/root 0/root'
) || report "5.1.5"

# 5.1.6
(
    stat --format='%a %u/%U %g/%G' /etc/cron.monthly | grep -q '700 0/root 0/root'
) || report "5.1.6"

# 5.1.7
(
    stat --format='%a %u/%U %g/%G' /etc/cron.d | grep -q '700 0/root 0/root'
) || report "5.1.7"

# 5.1.8
(
    [ ! "$(stat /etc/cron.deny 2> /dev/null)" ]
    stat --format='%a %u/%U %g/%G' /etc/cron.allow | grep -q '6[04]0 0/root 0/root'
) || report "5.1.8"

# 5.1.9
(
    [ ! "$(stat /etc/at.deny 2> /dev/null)" ]
    stat --format='%a %u/%U %g/%G' /etc/at.allow | grep -q '6[04]0 0/root 0/root'
) || report "5.1.9"

# 5.2.1
(
    stat --format='%a %u/%U %g/%G' /etc/ssh/sshd_config | grep -q '600 0/root 0/root'
) || report "5.2.1"

# 5.2.2
(
    [ ! "$(find /etc/ssh -xdev -type f -name 'ssh_host_*_key' | xargs stat --format='%a %u/%U %g/%G' | grep -v '600 0/root 0/root')" ]
) || report "5.2.2"

# 5.2.3
(
    [ ! "$(find /etc/ssh -xdev -type f -name 'ssh_host_*_key.pub' | xargs stat --format='%a %u/%U %g/%G' | grep -v '6[04][04] 0/root 0/root')" ]
) || report "5.2.3"

# 5.2.4
(
    sshd -T | grep -E -q 'loglevel (INFO|VERBOSE)'
) || report "5.2.4"

# 5.2.5
(
    sshd -T | grep -q 'x11forwarding no'
) || report "5.2.5"

# 5.2.6
(
    sshd -T | grep -q 'maxauthtries [1-4]$'
) || report "5.2.6"

# 5.2.7
(
    sshd -T | grep -q 'ignorerhosts yes'
) || report "5.2.7"

# 5.2.8
(
    sshd -T | grep -q 'hostbasedauthentication no'
) || report "5.2.8"

# 5.2.9
(
    sshd -T | grep -q 'permitrootlogin no'
) || report "5.2.9"

# 5.2.10
(
    sshd -T | grep -q 'permitemptypasswords no'
) || report "5.2.10"

# 5.2.11
(
    sshd -T | grep -q 'permituserenvironment no'
) || report "5.2.11"

# 5.2.12
(
    [ "$(sshd -T | grep 'ciphers' | grep -v '3des-cbc' | grep -v 'aes128-cbc' | grep -v 'aes192-cbc' | grep -v 'aes256-cbc')" ]
) || report "5.2.12"

# 5.2.13
(
    [ "$(sshd -T | grep 'macs' | grep -v 'hmac-md5' | grep -v 'hmac-md5-96' | grep -v 'hmac-ripemd160' | grep -v 'hmac-sha1' | grep -v 'hmac-sha1-96' | grep -v 'umac-64@openssh.com' | grep -v 'umac-128@openssh.com' | grep -v 'hmac-md5-etm@openssh.com' | grep -v 'hmac-md5-96-etm@openssh.com' | grep -v 'hmac-ripemd160-etm@openssh.com' | grep -v 'hmac-sha1-etm@openssh.com' | grep -v 'hmac-sha1-96-etm@openssh.com' | grep -v 'umac-64-etm@openssh.com' | grep -v 'umac-128-etm@openssh.com')" ]
) || report "5.2.13"

# 5.2.14
(
    [ "$(sshd -T | grep 'kexalgorithms' | grep -v 'diffie-hellman-group1-sha1' | grep -v 'diffie-hellman-group14-sha1' | grep -v 'diffie-hellman-group-exchange-sha1')" ]
) || report "5.2.14"

# 5.2.15
(
    [ $(sshd -T | grep 'clientaliveinterval' | awk '{print $2}') -ge 1 ]
    [ $(sshd -T | grep 'clientaliveinterval' | awk '{print $2}') -le 300 ]
    sshd -T | grep -q 'clientalivecountmax [1-3]$'
) || report "5.2.15"

# 5.2.16
(
    [ $(sshd -T | grep 'logingracetime' | awk '{print $2}') -ge 1 ]
    [ $(sshd -T | grep 'logingracetime' | awk '{print $2}') -le 60 ]
) || report "5.2.16"

# 5.2.17
(
    sshd -T | grep -q 'allowusers' || sshd -T | grep -q 'allowgroups' || sshd -T | grep -q 'denyusers' || sshd -T | grep -q 'denygroups'
) || report "5.2.17"

# 5.2.18
(
    sshd -T | grep -q 'banner /etc/issue.net'
) || report "5.2.18"

# 5.2.19
(
    sshd -T | grep -q 'usepam yes'
) || report "5.2.19"

# 5.2.21
(
    start=$(sshd -T | grep 'maxstartups' | awk '{print $2}' | cut -d: -f1)
    rate=$(sshd -T | grep 'maxstartups' | awk '{print $2}' | cut -d: -f2)
    full=$(sshd -T | grep 'maxstartups' | awk '{print $2}' | cut -d: -f3)
    [ $start -le 10 ]
    [ $rate -ge 30 ]
    [ $full -le 60 ]
) || report "5.2.21"

# 5.2.22
(
    [ $(sshd -T | grep 'maxsessions' | awk '{print $2}') -le 10 ]
) || report "5.2.22"

# 5.3.1
(
    [ $(grep -s '^\s*minlen\s*' /etc/security/pwquality.conf | awk '{print $3}') -ge 14 ]
    grep -q '^\s*minclass\s*=\s*4' /etc/security/pwquality.conf || grep -E -q '^\s*[duol]credit\s*=\s*-[1-9].*'
    grep -E -q '^\s*password\s+(requisite|required)\s+pam_pwquality\.so\s+(\S+\s+)*retry=[1-3]\s*(\s+\S+\s*)*(\s+#.*)?$' /etc/pam.d/common-password
) || report "5.3.1"

# 5.3.2
(
    grep 'pam_tally2' /etc/pam.d/common-auth | grep -q -E '(required|requisite)'
    grep 'pam_tally2' /etc/pam.d/common-auth | grep -q '\sdeny=[1-5]\s'
    grep 'pam_tally2' /etc/pam.d/common-auth | grep -q '\saudit\s'
    grep 'pam_tally2' /etc/pam.d/common-auth | grep -q -E '\sunlock_time=(9[0-9][0-9]+|[1-9][0-9][0-9][0-9]+)'
    grep 'pam_tally2\.so' /etc/pam.d/common-account | grep -E -q '(required|requisite)'
    grep 'pam_deny\.so' /etc/pam.d/common-account | grep -E -q '(required|requisite)'
) || report "5.3.2"

# 5.3.3
(
    [ "$(grep -E '^password\s+required\s+pam_pwhistory.so' /etc/pam.d/common-password | sed 's/^.*remember=//' | grep -v '^[1-4]$')" ]
) || report "5.3.3"

# 5.3.4
(
    grep -E -q '^\s*password\s+(\S+\s+)+pam_unix\.so\s+(\S+\s+)*sha512\s*(\S+\s*)*(\s+#.*)?$' /etc/pam.d/common-password
) || report "5.3.4"

# 5.4.1.1
(
    [ $(grep -E '^\s*PASS_MAX_DAYS\s+' /etc/login.defs | awk '{print $2}') -le 365 ]
    [ $(grep -E '^[^:]+:[^\!*]' /etc/shadow | cut -d: -f5) -le 365 ]
) || report "5.4.1.1"

# 5.4.1.2
(
    [ $(grep -E '^\s*PASS_MIN_DAYS\s+' /etc/login.defs | awk '{print $2}') -ge 1 ]
    [ $(grep -E '^[^:]+:[^!*]' /etc/shadow | cut -d: -f4) -ge 1 ]
) || report "5.4.1.2"

# 5.4.1.3
(
    [ $(grep -E '^\s*PASS_WARN_AGE\s+' /etc/login.defs | awk '{print $2}') -ge 7 ]
    [ $(grep -E '^[^:]+:[^!*]' /etc/shadow | cut -d: -f6) -ge 7 ]
) || report "5.4.1.3"

# 5.4.1.4
(
    [ $(useradd -D | grep 'INACTIVE' | cut -d= -f2) -le 30 ]
    [ $(grep -E '^[^:]+:[^!*]' /etc/shadow | cut -d: -f7) -le 30 ]
) || report "5.4.1.4"

# 5.4.1.5
(
    [ ! "$(for usr in $(cut -d: -f1 /etc/shadow); do [[ $(chage --list $usr | grep '^Last password change' | cut -d: -f2) > $(date) ]] && echo "$usr :$(chage -- list $usr | grep '^Last password change' | cut -d: -f2)"; done)" ]
) || report "5.4.1.5"

# 5.4.2
(
    [ ! "$(awk -F: '($1!="root" && $1!="sync" && $1!="shutdown" && $1!="halt" && $1!~/^\+/ && $3<'"$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)"' && $7!="'"$(which nologin)"'" && $7!="/bin/false") {print}' /etc/passwd)" ]
    [ ! "$(awk -F: '($1!="root" && $1!~/^\+/ && $3<'"$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)"') {print $1}' /etc/passwd | xargs -I '{}' passwd -S '{}' | awk '($2!="L" && $2!="LK") {print $1}')" ]
) || report "5.4.2"

# 5.4.3
(
    [ "$(grep '^root:' /etc/passwd | cut -f4 -d:)" = "0" ]
) || report "5.4.3"

# 5.4.4
(
    grep -E -i -q '^\s*UMASK\s+(0[0-7][2-7]7|[0-7][2-7]7)\b' /etc/login.defs
    grep -E -q '^\s*session\s+(optional|requisite|required)\s+pam_umask\.so\b' /etc/pam.d/common-session || \
        grep -R -E -i -q '^\s*UMASK\s+\s*(0[0-7][2-7]7|[0-7][2-7]7|u=(r?|w?|x?)(r?|w?|x?)(r?|w?|x?),g=(r?x?|x?r?),o=)\b' /etc/profile* /etc/bash.bashrc*
    [ ! "$(grep -RPi '(^|^[^#]*)\s*umask\s+([0-7][0-7][01][0-7]\b|[0-7][0-7][0-7][0-6]\b|[0-7][01][0-7]\b|[0-7][0-7][0-6]\b|(u=[rwx]{0,3},)?(g=[rwx]{0,3},)?o=[rwx]+\b|(u=[rwx]{1,3},)?g=[^rx]{1,3}( ,o=[rwx]{0,3})?\b)' /etc/login.defs /etc/profile* /etc/bash.bashrc*)" ]
) || report "5.4.4"

# 5.4.5
(
    [ "$(for f in /etc/bash.bashrc /etc/profile /etc/profile.d/*.sh ; do grep -Eq '(^|^[^#]*;)\s*(readonly|export(\s+[^$#;]+\s*)*)?\s*TMOUT=(900|[1-8][0-9][0-9]|[1-9][0-9]|[1-9])\b' $f && grep -Eq '(^|^[^#]*;)\s*readonly\s+TMOUT\b' $f && grep -Eq '(^|^[^#]*;)\s*export\s+([^$#;]+\s+)*TMOUT\b' $f && (echo '0' && break); done; echo '1')" = "0" ]
    [ ! "$(grep -P '^\s*([^$#;]+\s+)*TMOUT=(9[0-9][1-9]|0+|[1-9]\d{3,})\b\s*(\S+\s*)*(\s+#.*)?$' /etc/profile /etc/profile.d/*.sh /etc/bash.bashrc)"]
) || report "5.4.5"

# 5.6
(
    group_name=$(grep pam_wheel.so /etc/pam.d/su | sed 's/^.*group=//')
    [ ! "$(grep "$group_name" /etc/group | cut -d: -f4)" ]
) || report "5.6"

# 6.1.2
(
    stat --format='%a %u/%U %g/%G' /etc/passwd | grep -q '644 0/root 0/root'
) || report "6.1.2"

# 6.1.3
(
    stat --format='%a %u/%U %G' /etc/gshadow- | grep -E -q '6[04]0 0/root (root|shadow)'
) || report "6.1.3"

# 6.1.4
(
    stat --format='%a %u/%U %G' /etc/shadow | grep -E -q '6[04]0 0/root (root|shadow)'
) || report "6.1.4"

# 6.1.5
(
    stat --format='%a %u/%U %g/%G' /etc/group | grep -q '644 0/root 0/root'
) || report "6.1.5"

# 6.1.6
(
    stat --format='%a %u/%U %g/%G' /etc/passwd- | grep -q '6[04][04] 0/root 0/root'
) || report "6.1.6"

# 6.1.7
(
    stat --format='%a %u/%U %G' /etc/shadow- | grep -q -E '6[04]0 0/root (root|shadow)'
) || report "6.1.7"

# 6.1.8
(
    stat --format='%a %u/%U %g/%G' /etc/group- | grep -q '6[04][04] 0/root 0/root'
) || report "6.1.8"

# 6.1.9
(
    stat --format='%a %u/%U %G' /etc/gshadow | grep -q -E '6[04]0 0/root (root|shadow)'
) || report "6.1.9"

# 6.1.10
(
    [ ! "$(df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -type f -perm -0002)" ]
) || report "6.1.10"

# 6.1.11
(
    [ ! "$(df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -nouser)" ]
) || report "6.1.11"

# 6.1.12
(
    [ ! "$(df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -nogroup)" ]
) || report "6.1.12"

# 6.2.1
(
    [ ! "$(awk -F: '($2 == "" ) { print $1 " does not have a password "}' /etc/shadow)" ]
) || report "6.2.1"

# 6.2.2
(
    [ "$(awk -F: '($3 == 0) { print $1 }' /etc/passwd)" = "root" ]
) || report "6.2.2"

# 6.2.3
(
    echo $PATH | grep -q -v '::'
    echo $PATH | grep -q -v ':$'
    for x in $(echo $PATH | tr ':' ' '); do
        [ -d "$x" ]
        ls -ldH "$x" | awk '{print $9}' | grep -v -q '^.$'
        ls -ldH "$x" | awk '{print $3}' | grep -q 'root'
        stat --format='%a' "$x" | grep -q '[0-7][0145][0145]'
    done
) || report "6.2.3"

# 6.2.4
(
    grep -E -v '^(halt|sync|shutdown)' /etc/passwd | awk -F: '($7 != "'"$(which nologin)"'" && $7 != "/bin/false") { print $6 }' | while read -r dir; do
        [ -d "$dir" ]
    done
) || report "6.2.4"

# 6.2.5
(
    grep -E -v '^(halt|sync|shutdown)' /etc/passwd | awk -F: '($7 != "'"$(which nologin)"'" && $7 != "/bin/false") { print $6 }' | while read dir; do
        dirperm=$(ls -ld $dir | cut -f1 -d' ')
        [ "$(echo $dirperm | cut -c6)" = "-" ]
        [ "$(echo $dirperm | cut -c8)" = "-" ]
        [ "$(echo $dirperm | cut -c9)" = "-" ]
        [ "$(echo $dirperm | cut -c10)" = "-" ]
    done
) || report "6.2.5"

# 6.2.6
(
    grep -E -v '^(halt|sync|shutdown)' /etc/passwd | awk -F: '($7 != "'"$(which nologin)"'" && $7 != "/bin/false") { print $1 " " $6 }' | while read user dir; do
        owner=$(stat -L -c "%U" "$dir")
        [ "$owner" = "$user" ]
    done
) || report "6.2.6"

# 6.2.7
(
    grep -E -v '^(halt|sync|shutdown)' /etc/passwd | awk -F: '($7 != "'"$(which nologin)"'" && $7 != "/bin/false") { print $6 }' | while read dir; do
        for file in $dir/.[A-Za-z0-9]*; do
            if [ ! -h "$file" -a -f "$file" ]; then
                fileperm=$(ls -ld $file | cut -f1 -d' ')
                [ "$(echo $fileperm | cut -c6)" = "-" ]
                [ "$(echo $fileperm | cut -c9)" = "-" ]
            fi
        done
    done
) || report "6.2.7"

# 6.2.8
(
    grep -E -v '^(root|halt|sync|shutdown)' /etc/passwd | awk -F: '($7 != "'"$(which nologin)"'" && $7 != "/bin/false") { print $6 }' | while read dir; do
        [ -h "$dir/.forward" -o ! -f "$dir/.forward" ]
    done
) || report "6.2.8"

# 6.2.9
(
    grep -E -v '^(root|halt|sync|shutdown)' /etc/passwd | awk -F: '($7 != "'"$(which nologin)"'" && $7 != "/bin/false") { print $6 }' | while read dir; do
        [ ! -f "$dir/.netrc" ]
    done
) || report "6.2.9"

# 6.2.10
(
    grep -E -v '^(root|halt|sync|shutdown)' /etc/passwd | awk -F: '($7 != "'"$(which nologin)"'" && $7 != "/bin/false") { print $6 }' | while read dir; do
        if [ ! -h "$dir/.netrc" -a -f "$dir/.netrc" ]; then
            stat --format='%a' $dir/.netrc | grep -q '[1-7]00'
        fi
    done
) || report "6.2.10"

# 6.2.11
(
    grep -E -v '^(root|halt|sync|shutdown)' /etc/passwd | awk -F: '($7 != "'"$(which nologin)"'" && $7 != "/bin/false") { print $6 }' | while read dir; do
        [ ! -f "$dir/.rhosts" ]
    done
) || report "6.2.11"

# 6.2.12
(
    for i in $(cut -s -d: -f4 /etc/passwd | sort -u ); do
        grep -q -P "^.*?:[^:]*:$i:" /etc/group
    done
) || report "6.2.12"

# 6.2.13
(
    [ ! "$(cut -f3 -d: /etc/passwd | sort -n | uniq -d)" ]
) || report "6.2.13"

# 6.2.14
(
    [ ! "$(cut -f3 -d: /etc/group | sort -n | uniq -d)" ]
) || report "6.2.14"

# 6.2.15
(
    [ ! "$(cut -f1 -d: /etc/passwd | sort | uniq -d)" ]
) || report "6.2.15"

# 6.2.16
(
    [ ! "$(cut -f1 -d: /etc/group | sort | uniq -d)" ]
) || report "6.2.16"

# 6.2.17
(
    [ ! "$(grep '^shadow:[^:]*:[^:]*:[^:]+' /etc/group)" ]
    [ ! "$(awk -F: '($4 == "$(grep ^shadow: | cut -d: -f3)") { print }' /etc/passwd)" ]
) || report "6.2.17"

# Check if there were any failures
[ $failures -eq 0 ]
