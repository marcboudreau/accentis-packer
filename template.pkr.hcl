variable "project" {
    type = string
}

variable "base_image_family" {
    type    = string
    default = "ubuntu-minimal-2004-lts" 
}

variable "root_password" {
    type = string
}

variable "commit_hash" {
    type = string
}

source "googlecompute" "bastion" {
    project_id          = var.project
    source_image_family = var.base_image_family
    zone = "us-central1-a"

    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true

    image_name = "bastion-candidate-${var.commit_hash}"
    
    # Disabled until https://github.com/hashicorp/packer/issues/9997 is fixed.
    #image_encryption_key {
    #    kms_key_name = "projects/${var.project}/locations/global/keyRings/${var.project}-keyring/cryptoKeys/disk-encryption"
    #}


    image_storage_locations = [
        "us",
    ]

    on_host_maintenance = "TERMINATE"
    preemptible         = true

    ssh_username = "packer"
}

build {
    sources = [
        "source.googlecompute.bastion",
    ]

    # Pause for 10 seconds to give a chance to cloud-init to finish.
    provisioner "shell" {
        inline = [
            "sleep 10",
        ]
    }

    # CIS 1.1.1 Disable unused filesystems
    provisioner "shell" {
        inline = [
            "echo 'install cramfs /bin/true' > /etc/modprobe.d/disable-cramfs.conf",
            "echo 'install freevxfs /bin/true' > /etc/modprobe.d/disable-freevxfs.conf",
            "echo 'install jffs2 /bin/true' > /etc/modprobe.d/disable-jffs2.conf",
            "echo 'install hfs /bin/true' > /etc/modprobe.d/disable-hfs.conf",
            "echo 'install hfsplus /bin/true' > /etc/modprobe.d/disable-hfsplus.conf",
            "echo 'install udf /bin/true' > /etc/modprobe.d/disable-udf.conf",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 1.1.2 Ensure /tmp is configured
    provisioner "shell" {
        inline = [
            "sed -i '$atmpfs\t/tmp\ttmpfs\tdefaults,rw,nosuid,nodev,noexec,relatime\t0\t0' /etc/fstab",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 1.1.7 - 1.1.9 Ensure nodev, nosuid, noexec options set on /dev/shm partition
    provisioner "shell" {
        inline = [
            "sed -i '$atmpfs\t/dev/shm\ttmpfs\tdefaults,rw,nosuid,nodev,noexec\t0\t0' /etc/fstab",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 1.1.24 Disable USB Storage
    provisioner "shell" {
        inline = [
            "echo 'install usb-storage /bin/true' > /etc/modprobe.d/disable-usb-storage.conf",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 1.3.2 Ensure sudo commands use pty
    provisioner "shell" {
        inline = [
            "echo 'Defaults use_pty' > /etc/sudoers.d/80-accentis.conf",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 1.3.3 Ensure sudo log file exists
    provisioner "shell" {
        inline = [
            "echo 'Defaults logfile=\"/var/log/sudo.log\"' >> /etc/sudoers.d/80-accentis.conf",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 1.4.1 Ensure AIDE is installed
    provisioner "shell" {
        inline = [
            "apt-get update",
            "apt-get -y -q install aide",
            "aideinit",
        ]
        #inline_shebang = "/bin/bash -ex"
        environment_vars = [
            "DEBIAN_FRONTEND=noninteractive",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }



    # CIS 1.5.2 Ensure permissions on bootloader config are configured
    provisioner "shell" {
        inline = [
            "chmod 0400 /boot/grub/grub.cfg",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 1.5.3 Ensure authentication required for single user mode
    provisioner "shell" {
        inline = [
            "echo '${var.root_password}",
            "${var.root_password}' | passwd root",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 1.6.4 Ensure core dumps are restricted
    provisioner "shell" {
        inline = [
            "sed -i '$a*\thard\tcore\t0' /etc/security/limits.conf",
            "echo 'fs.suid_dumpable = 0' >> /etc/sysctl.d/90-accentis-cis.conf",
            "apt-get remove -y apport",
        ]
        environment_vars = [
            "DEBIAN_FRONTEND=noninteractive",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 1.7.1.2 Ensure AppArmor is enabled in the bootloader configuration
    provisioner "shell" {
        inline = [
            "sed -i '/^\\s*linux\\s/ s/$/ apparmor=1 security=apparmor/' /boot/grub/grub.cfg",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 1.8.1.1 Ensure message of the day is configured properly
    provisioner "shell" {
        inline = [
            "rm -f /etc/update-motd.d/*",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 1.8.1.2 Ensure local login warning banner is configured properly
    provisioner "shell" {
        inline = [
            "echo 'Authorized uses only. All activity may be monitored and reported.' > /etc/issue",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 1.8.1.3 Ensure remote login warning banner is configured properly
    provisioner "shell" {
        inline = [
            "echo 'Authorized uses only. All activity may be monitored and reported.' > /etc/issue.net",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 2.2.15 Ensure mail transfer agent is configured for local-only mode
    provisioner "shell" {
        inline = [
            "sed -i 's/inet_interfaces = .*$/inet_interfaces = loopback-only/' /etc/postfix/main.cf",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 3.2.2 Ensure IP forwarding is disabled
    provisioner "shell" {
        inline = [
            "sed -i '/^#net\\.ipv4\\.ip_forward.*$/d' /etc/sysctl.conf",
            "sed -i 's/^#net\\.ipv6\\.conf\\.all\\.forwarding.*$/net.ipv6.conf.all.forwarding=0/' /etc/sysctl.conf",
        ]

        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 3.3.1 Ensure source routed packets are not accepted
    provisioner "shell" {
        inline = [
            "sed -i '/^#net\\.ipv6\\.conf\\.all\\.accept_source_route/ s/^#//' /etc/sysctl.conf",
            "sed -i '$anet.ipv6.conf.default.accept_source_route=0' /etc/sysctl.conf",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 3.3.2 Ensure ICMP redirects are not accepted
    provisioner "shell" {
        inline = [
            "sed -i '$anet.ipv6.conf.default.accept_redirects=0' /etc/sysctl.conf",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 3.3.3 Ensure secure ICMP redirects are not accepted
    provisioner "shell" {
        inline = [
            "sed -i 's/^net\\.ipv4\\.conf\\.all\\.secure_redirects.*$/net.ipv4.conf.all.secure_redirects=0/' /etc/sysctl.conf",
            "sed -i '$anet.ipv4.conf.default.secure_redirects=0' /etc/sysctl.conf",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 3.3.9 Ensure IPv6 router advertisements are not accepted
    provisioner "shell" {
        inline = [
            "sed -i '$anet.ipv6.conf.all.accept_ra=0' /etc/sysctl.conf",
            "sed -i '$anet.ipv6.conf.default.accept_ra=0' /etc/sysctl.conf",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 3.5.2 Configure nftables
    provisioner "file" {
        source      = "./bastion-nftables.rules"
        destination = "/tmp/nftables.rules"
    }
    provisioner "shell" {
        inline = [
            "apt-get update",
            "apt-get -y -q install nftables",
            "chown root:root /tmp/nftables.rules",
            "chmod 0600 /tmp/nftables.rules",
            "mv /tmp/nftables.rules /etc/nftables.rules",
            "sed -i '$ainclude \"/etc/nftables.rules\"' /etc/nftables.conf",
            "nft -f /etc/nftables.rules",
            "systemctl enable nftables",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
        environment_vars = [
            "DEBIAN_FRONTEND=noninteractive",
        ]
    }

    # Installing Google Cloud Logging Agent
    provisioner "shell" {
        inline = [
            "cd /tmp",
            "curl -sSO https://dl.google.com/cloudagents/add-logging-agent-repo.sh",
            "bash ./add-logging-agent-repo.sh",
            "apt-get update",
            "apt-get -y -q install google-fluentd",
            "apt-get install -y -q google-fluentd-catch-all-config-structured",
            "sed -i '/^# Prometheus monitoring/,+8d' /etc/google-fluentd/google-fluentd.conf",
        ]
        environment_vars = [
            "DEBIAN_FRONTEND=noninteractive",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 4.2.2.1 Ensure journald is configured to send logs to rsyslog
    provisioner "shell" {
        inline = [
            "sed -i -r 's/^#?ForwardToSyslog.*$/ForwardToSyslog=yes/' /etc/systemd/journald.conf",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 4.2.2.2 Ensure journald is configured to compress large log files
    provisioner "shell" {
        inline = [
            "sed -i -r 's/^#?Compress.*/Compress=yes/' /etc/systemd/journald.conf",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 4.2.2.3 Ensure journald is configured to write logfiles to persistent disk
    provisioner "shell" {
        inline = [
            "sed -i 's/^#\\?Storage=.*$/Storage=persistent/' /etc/systemd/journald.conf",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 4.2.3 Ensure permissions on all logfiles are configured
    provisioner "shell" {
        inline = [
            "sed -i 's/^\\$Umask .*/$Umask 0026/' /etc/rsyslog.conf",
            "find /var/log -type f -exec chmod g-wx,o-rwx \"{}\" + -o -type d -exec chmod g-w,o-rwx \"{}\" +",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 5.1 Configure cron
    provisioner "shell" {
        inline = [
            "chmod 0600 /etc/crontab",
            "chmod 0700 /etc/cron.hourly",
            "chmod 0700 /etc/cron.daily",
            "chmod 0700 /etc/cron.weekly",
            "chmod 0700 /etc/cron.monthly",
            "chmod 0700 /etc/cron.d",
            "touch /etc/cron.allow /etc/at.allow",
            "chmod 0600 /etc/cron.allow /etc/at.allow",
            "chown root:root /etc/cron.allow /etc/at.allow",
            "rm -f /etc/cron.deny /etc/at.deny",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 5.2 SSH Server Configuration
    provisioner "shell" {
        inline = [
            "chmod 0600 /etc/ssh/sshd_config",
            "sed -i '$aProtocol 2' /etc/ssh/sshd_config",
            "sed -i 's/^#\\?\\s*LogLevel\\s.*$/LogLevel INFO/' /etc/ssh/sshd_config",
            "sed -i '/^#\\?\\s*[Xx]11[Ff]orwarding\\s.*$/d' /etc/ssh/sshd_config",
            "sed -i '$aX11Forwarding no' /etc/ssh/sshd_config",
            "sed -i 's/^#\\?\\s*[Mm]ax[Aa]uth[Tt]ries\\s.*$/MaxAuthTries 4/' /etc/ssh/sshd_config",
            "sed -i 's/^#\\?\\s*[Ii]gnore[Rr]hosts\\s.*$/IgnoreRhosts yes/' /etc/ssh/sshd_config",
            "sed -i 's/^#\\?\\s*[Hh]ostbased[Aa]uthentication\\s.*$/HostbasedAuthentication no/' /etc/ssh/sshd_config",
            "sed -i 's/^#\\?\\s*[Pp]ermit[Rr]oot[Ll]ogin\\s.*$/PermitRootLogin no/' /etc/ssh/sshd_config",
            "sed -i 's/^#\\?\\s*[Pp]ermit[Ee]mpty[Pp]asswords\\s.*$/PermitEmptyPasswords no/' /etc/ssh/sshd_config",
            "sed -i 's/^#\\?\\s*[Pp]ermit[Uu]ser[Ee]nvironment\\s.*$/PermitUserEnvironment no/' /etc/ssh/sshd_config",
            "sed -i '$aMACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512' /etc/ssh/sshd_config",
            "sed -i 's/^#\\?\\s*[Cc]lient[Aa]live[Ii]nterval\\s.*$/ClientAliveInterval 300/' /etc/ssh/sshd_config",
            "sed -i 's/^#\\?\\s*[Cc]lient[Aa]live[Cc]ount[Mm]ax\\s.*$/ClientAliveCountMax 3/' /etc/ssh/sshd_config",
            "sed -i 's/^#\\?\\s*[Ll]ogin[Gg]race[Tt]ime\\s.*$/LoginGraceTime 60/' /etc/ssh/sshd_config",
            "sed -i 's~^#\\?\\s*[Bb]anner\\s.*$~Banner /etc/issue.net~' /etc/ssh/sshd_config",
            "sed -i 's/^#\\?\\s*[Mm]ax[Ss]tartups\\s.*$/MaxStartups 10:30:60/' /etc/ssh/sshd_config",
            "sed -i 's/^#\\?\\s*[Mm]ax[Ss]essions\\s.*$/MaxSessions 4/' /etc/ssh/sshd_config",
            "sed -i '$aAllowUsers ubuntu tunnel' /etc/ssh/sshd_config",
            "sed -i '$aMatch user tunnel\\nPermitTTY no\\nForceCommand /sbin/nologin' /etc/ssh/sshd_config",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 5.3 Configure PAM
    provisioner "shell" {
        inline = [
            "apt-get -y -q install libpam-pwquality",
            "sed -i 's/^\\s*#*\\s*minlen.*$/minlen = 14/' /etc/security/pwquality.conf",
            "sed -i 's/^\\s*#*\\s*minclass.*/minclass = 4/' /etc/security/pwquality.conf",
            "sed -i '$aauth required pam_tally.so onerr=fail deny=5 unlock_time=900' /etc/pam.d/common-auth",
            "sed -i '$apassword required pam_pwhistory.so remember=5' /etc/pam.d/common-password"
        ]
        environment_vars = [
            "DEBIAN_FRONTEND=noninteractive",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 5.4.1 Set Shadow Password Suite Parameters
    provisioner "shell" {
        inline = [
            "sed -i 's/^PASS_MAX_DAYS\\s.*$/PASS_MAX_DAYS 365/' /etc/login.defs",
            "chage --maxdays 365 root",
            "sed -i 's/^PASS_MIN_DAYS\\s.*$/PASS_MIN_DAYS 7/' /etc/login.defs",
            "chage --mindays 7 root",
            "useradd -D -f 30",
            "chage --inactive 30 root",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 5.4.4 Ensure default user umask is 027 or more restrictive
    provisioner "shell" {
        inline = [
            "echo 'umask 027' >> /etc/bash.bashrc",
            "sed -i 's/^#\\?\\s*UMASK\\s\\s*[[:digit:]][[:digit:]]*$/UMASK\t027/' /etc/login.defs",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 5.4.5 Ensure default user shell timeout is 900 seconds or less
    provisioner "shell" {
        inline = [
            "echo 'TMOUT=900' >> /etc/bash.bashrc",
            "echo 'TMOUT=900' >> /etc/profile",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 5.6 Ensure access to the su command is restricted
    provisioner "shell" {
        inline = [
            "sed -i 's/^# auth/auth/' /etc/pam.d/su",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 6.1 System File permissions
    provisioner "shell" {
        inline = [
            "chmod 0600 /etc/passwd-",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # CIS 6.2.5 Ensure users' home directories permissions are 750 or more restrictive
    provisioner "shell" {
        inline = [
            "chmod 0750 /home/*",
        ]
        execute_command = "chmod +x {{ .Path }}; sudo -S env {{ .Vars }} {{ .Path }}"
    }

    # Generate a manifest of artifacts produced.
    post-processor "manifest" {
        output = "manifest.json"
    }
}
