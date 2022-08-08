#! /usr/bin/bash

# nextcloud server stackscript
# nextcloud server configuration to install all programs, config and databases
# Variables setting options :
#    username [ "what you assigned when installing the server operating system" ]
#    hostname [ "what you assigned when installing the server operating system" ]
#    password [ "this will be the password for your admin account on nextcloud system management" ]
#    email_account [ "optional" ]
#    domain_name_private_ip_add [ "example.com, www.example.com, 123.123.123.123, ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff" ]
#    nextcloud_type [ "private" , "public" ]

### Please fill out below variables 
username="XXXXXXX"
hostname="XXXXXXXXXX"
password="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
email_account="username@examplemail.com"
domain_name_private_ip_add="0.0.0.0 ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"
nc_type="private"
###

# update system
sudo apt update && sudo apt upgrade -y
sudo apt-get install -y net-tools lm-sensors ranger fail2ban sendmail-bin sendmail

# enable firewall
sudo ufw allow ssh && sudo ufw enable

# snap install if not present within system
if [ ! -f '/usr/bin/snap' ] ; then
    sudo apt install -y snapd && sudo systemctl restart snapd && sudo snap install core
    NUM="$(sudo cat -n /etc/environment | grep PATH | awk '{print $1;}')" 
    sudo sed "${NUM}s,$,:/snap/bin," /etc/environment >> ~/environment && sudo mv ~/environment /etc/environment
    sudo snap refresh && systemctl restart snapd && systemctl enable --now snapd.apparmor.service
fi

if [ nc_type = "private" ] ; then
    sudo snap install nextcloud
    snap connections nextcloud
    sudo nextcloud.manual-install ${USERNAME} ${PASSWORD}
    sudo nextcloud.occ config:system:set trusted_domains 1 --value=${DOMAIN_NAME}
    sudo ufw allow 80,443/tcp
    sudo nextcloud.enable-https lets-encrypt -y -${EMAIL_ACCOUNT} -${DOMAIN_NAME}
elif [ nc_type = "public" ] ; then
    sudo snap install nextcloud
    snap connections nextcloud
    sudo nextcloud.manual-install ${USERNAME} ${PASSWORD}
    sudo nextcloud.occ config:system:set trusted_domains 1 --value=${DOMAIN_NAME}
    sudo ufw allow 80,443/tcp
    sudo nextcloud.enable-https lets-encrypt -y -${EMAIL_ACCOUNT} -${DOMAIN_NAME}
else
    echo "please enter a valid nextcloud type"
    exit
fi

# crontab
if [ ! -f /var/spool/cron/crontabs/root ] ; then
    echo "# crontab" > /var/spool/cron/crontabs/root
    echo -e "# Edit this file to introduce tasks to be run by cron.\n# " >> /var/spool/cron/crontabs/root
    echo "# Each task to run has to be defined through a single line" >> /var/spool/cron/crontabs/root
    echo "# indicating with different fields when the task will be run" >> /var/spool/cron/crontabs/root
    echo -e "# and what command to run for the task\n# " >> /var/spool/cron/crontabs/root
    echo "# To define the time you can provide concrete values for" >> /var/spool/cron/crontabs/root
    echo "# minute (m), hour (h), day of month (dom), month (mon)," >> /var/spool/cron/crontabs/root
    echo -e "# and day of week (dow) or use '*' in these fields (for 'any').\n# " >> /var/spool/cron/crontabs/root
    echo "# Notice that tasks will be started based on the cron's system" >> /var/spool/cron/crontabs/root
    echo -e "# daemon's notion of time and timezones.\n# " >> /var/spool/cron/crontabs/root
    echo "# Output of the crontab jobs (including errors) is sent through" >> /var/spool/cron/crontabs/root
    echo -e "# email to the user the crontab file belongs to (unless redirected).\n# " >> /var/spool/cron/crontabs/root
    echo "# For example, you can run a backup of all your user accounts" >> /var/spool/cron/crontabs/root
    echo "# at 5 a.m every week with:" >> /var/spool/cron/crontabs/root
    echo -e "# 0 5 * * 1 tar -zcf /var/backups/home.tgz /home/\n# " >> /var/spool/cron/crontabs/root
    echo -e "# For more information see the manual pages of crontab(5) and cron(8)\n# " >> /var/spool/cron/crontabs/root
    echo "# m h  dom mon dow   command" >> /var/spool/cron/crontabs/root
    echo "00 06 * * * system_update_upgrade_reboot.sh" >> /var/spool/cron/crontabs/root
    echo "#00 04 * * * py3_automated_rsync_server_archive_script.py" >> /var/spool/cron/crontabs/root
    echo -e "@reboot ifconfig wlan0 down\n" >> /var/spool/cron/crontabs/root
fi

# fail2ban
if [ -f '/usr/bin/fail2ban' ] ; then
    # create firewall configuration
    sudo touch /etc/fail2ban/jail.local
    sudo echo -e "[DEFAULT]\n" > /etc/fail2ban/jail.local
    sudo echo "# 'bantime' is the number of seconds that a host is banned." >> /etc/fail2ban/jail.local
    sudo echo -e "bantime  = 600\n" >> /etc/fail2ban/jail.local
    sudo echo "# A host is banned if it has generated 'maxretry' during the last 'findtime' # seconds." >> /etc/fail2ban/jail.local
    sudo echo "findtime = 600" >> /etc/fail2ban/jail.local
    sudo echo -e "maxretry = 3\n" >> /etc/fail2ban/jail.local
    sudo echo "# 'ignoreip' can be an IP address, a CIDR mask or a DNS host. Fail2ban will not ban a host which matches an address in this list. Several addresses can be defined using space separator." >> /etc/fail2ban/jail.local
    sudo echo -e "ignoreip = 127.0.0.1/8 179.177.173.117\n" >> /etc/fail2ban/jail.local
    sudo echo "ignoreip = 127.0.0.1/8" >> /etc/fail2ban/jail.local
    sudo echo "bantime = 600" >> /etc/fail2ban/jail.local
    sudo echo "findtime = 600" >> /etc/fail2ban/jail.local
    sudo echo "maxretry = 3" >> /etc/fail2ban/jail.local
    sudo echo "backend = auto" >> /etc/fail2ban/jail.local
    sudo echo "usedns = warn" >> /etc/fail2ban/jail.local
    sudo echo "destemail = zech013@protonmail.com" >> /etc/fail2ban/jail.local
    sudo echo "sendername = Fail2Ban" >> /etc/fail2ban/jail.local
    sudo echo "banaction = iptables-multiport" >> /etc/fail2ban/jail.local
    sudo echo "mta = sendmail" >> /etc/fail2ban/jail.local
    sudo echo "protocol = tcp" >> /etc/fail2ban/jail.local
    sudo echo "chain = INPUT" >> /etc/fail2ban/jail.local
    sudo echo "action_ = %(banaction)..." >> /etc/fail2ban/jail.local
    sudo echo "action_mw = %(banaction)..." >> /etc/fail2ban/jail.local
    sudo echo "protocol="%(protocol)s"..." >> /etc/fail2ban/jail.local
    sudo echo "action_mwl = %(banaction)s..." >> /etc/fail2ban/jail.local
fi

# ssh
if [ ! -f ~/.ssh/authorized_keys  ] ; then
    # sshkey import
    ssh-import-id-gh zxv7
    sudo chmod -R 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys

    # ssh config import
    sudo echo "# This is the sshd server system-wide configuration file.  See" >> /etc/ssh/sshd_config
    sudo echo -e "# sshd_config(5) for more information.\n" >> /etc/ssh/sshd_config
    sudo echo -e "# This sshd was compiled with PATH=/usr/bin:/bin:/usr/sbin:/sbin\n" >> /etc/ssh/sshd_config
    sudo echo "# The strategy used for options in the default sshd_config shipped with" >> /etc/ssh/sshd_config
    sudo echo "# OpenSSH is to specify options with their default value where" >> /etc/ssh/sshd_config
    sudo echo "# possible, but leave them commented.  Uncommented options override the" >> /etc/ssh/sshd_config
    sudo echo -e "# default value.\n" >> /etc/ssh/sshd_config
    sudo echo -e "Include /etc/ssh/sshd_config.d/*.conf\n" >> /etc/ssh/sshd_config
    sudo echo "#Port 22" >> /etc/ssh/sshd_config
    sudo echo "AddressFamily inet" >> /etc/ssh/sshd_config
    sudo echo "#ListenAddress 0.0.0.0" >> /etc/ssh/sshd_config
    sudo echo -e "#ListenAddress ::\n" >> /etc/ssh/sshd_config
    sudo echo "#HostKey /etc/ssh/ssh_host_rsa_key" >> /etc/ssh/sshd_config
    sudo echo "#HostKey /etc/ssh/ssh_host_ecdsa_key" >> /etc/ssh/sshd_config
    sudo echo -e "#HostKey /etc/ssh/ssh_host_ed25519_key\n" >> /etc/ssh/sshd_config
    sudo echo "# Ciphers and keying" >> /etc/ssh/sshd_config
    sudo echo -e "#RekeyLimit default none\n" >> /etc/ssh/sshd_config
    sudo echo "# Logging" >> /etc/ssh/sshd_config
    sudo echo "#SyslogFacility AUTH" >> /etc/ssh/sshd_config
    sudo echo -e "#LogLevel INFO\n" >> /etc/ssh/sshd_config
    sudo echo -e "# Authentication:\n" >> /etc/ssh/sshd_config
    sudo echo "#LoginGraceTime 2m" >> /etc/ssh/sshd_config
    sudo echo "PermitRootLogin no" >> /etc/ssh/sshd_config
    sudo echo "#StrictModes yes" >> /etc/ssh/sshd_config
    sudo echo "#MaxAuthTries 6" >> /etc/ssh/sshd_config
    sudo echo -e "#MaxSessions 10\n" >> /etc/ssh/sshd_config
    sudo echo -e "PubkeyAuthentication yes\n" >> /etc/ssh/sshd_config
    sudo echo "# Expect .ssh/authorized_keys2 to be disregarded by default in future." >> /etc/ssh/sshd_config
    sudo echo -e "#AuthorizedKeysFile     .ssh/authorized_keys .ssh/authorized_keys2\n" >> /etc/ssh/sshd_config
    sudo echo -e "#AuthorizedPrincipalsFile none\n" >> /etc/ssh/sshd_config
    sudo echo "#AuthorizedKeysCommand none" >> /etc/ssh/sshd_config
    sudo echo -e "#AuthorizedKeysCommandUser nobody\n" >> /etc/ssh/sshd_config
    sudo echo "# For this to work you will also need host keys in /etc/ssh/ssh_known_hosts" >> /etc/ssh/sshd_config
    sudo echo "#HostbasedAuthentication no" >> /etc/ssh/sshd_config
    sudo echo "# Change to yes if you don't trust ~/.ssh/known_hosts for" >> /etc/ssh/sshd_config
    sudo echo "# HostbasedAuthentication" >> /etc/ssh/sshd_config
    sudo echo "#IgnoreUserKnownHosts no" >> /etc/ssh/sshd_config
    sudo echo "# Don't read the user's ~/.rhosts and ~/.shosts files" >> /etc/ssh/sshd_config
    sudo echo -e "#IgnoreRhosts yes\n" >> /etc/ssh/sshd_config
    sudo echo "# To disable tunneled clear text passwords, change to no here!" >> /etc/ssh/sshd_config
    sudo echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
    sudo echo -e "PermitEmptyPasswords no\n" >> /etc/ssh/sshd_config
    sudo echo "# Change to yes to enable challenge-response passwords (beware issues with" >> /etc/ssh/sshd_config
    sudo echo "# some PAM modules and threads)" >> /etc/ssh/sshd_config
    sudo echo -e "ChallengeResponseAuthentication no\n" >> /etc/ssh/sshd_config
    sudo echo "# Kerberos options" >> /etc/ssh/sshd_config
    sudo echo "#KerberosAuthentication no" >> /etc/ssh/sshd_config
    sudo echo "#KerberosOrLocalPasswd yes" >> /etc/ssh/sshd_config
    sudo echo "#KerberosTicketCleanup yes" >> /etc/ssh/sshd_config
    sudo echo -e "#KerberosGetAFSToken no\n" >> /etc/ssh/sshd_config
    sudo echo "# GSSAPI options" >> /etc/ssh/sshd_config
    sudo echo "#GSSAPIAuthentication no" >> /etc/ssh/sshd_config
    sudo echo "#GSSAPICleanupCredentials yes" >> /etc/ssh/sshd_config
    sudo echo "#GSSAPIStrictAcceptorCheck yes" >> /etc/ssh/sshd_config
    sudo echo -e "#GSSAPIKeyExchange no\n" >> /etc/ssh/sshd_config
    sudo echo "# Set this to 'yes' to enable PAM authentication, account processing," >> /etc/ssh/sshd_config
    sudo echo "# and session processing. If this is enabled, PAM authentication will" >> /etc/ssh/sshd_config
    sudo echo "# be allowed through the ChallengeResponseAuthentication and" >> /etc/ssh/sshd_config
    sudo echo "# PasswordAuthentication.  Depending on your PAM configuration," >> /etc/ssh/sshd_config
    sudo echo "# PAM authentication via ChallengeResponseAuthentication may bypass" >> /etc/ssh/sshd_config
    sudo echo "# the setting of "PermitRootLogin without-password"." >> /etc/ssh/sshd_config
    sudo echo "# If you just want the PAM account and session checks to run without" >> /etc/ssh/sshd_config
    sudo echo "# PAM authentication, then enable this but set PasswordAuthentication" >> /etc/ssh/sshd_config
    sudo echo "# and ChallengeResponseAuthentication to 'no'." >> /etc/ssh/sshd_config
    sudo echo -e "UsePAM yes\n" >> /etc/ssh/sshd_config
    sudo echo "#AllowAgentForwarding yes" >> /etc/ssh/sshd_config
    sudo echo "#AllowTcpForwarding yes" >> /etc/ssh/sshd_config
    sudo echo "#GatewayPorts no" >> /etc/ssh/sshd_config
    sudo echo "X11Forwarding yes" >> /etc/ssh/sshd_config
    sudo echo "#X11DisplayOffset 10" >> /etc/ssh/sshd_config
    sudo echo "#X11UseLocalhost yes" >> /etc/ssh/sshd_config
    sudo echo "#PermitTTY yes" >> /etc/ssh/sshd_config
    sudo echo "PrintMotd no" >> /etc/ssh/sshd_config
    sudo echo "#PrintLastLog yes" >> /etc/ssh/sshd_config
    sudo echo "#TCPKeepAlive yes" >> /etc/ssh/sshd_config
    sudo echo "#PermitUserEnvironment no" >> /etc/ssh/sshd_config
    sudo echo "#Compression delayed" >> /etc/ssh/sshd_config
    sudo echo "#ClientAliveInterval 0" >> /etc/ssh/sshd_config
    sudo echo "#ClientAliveCountMax 3" >> /etc/ssh/sshd_config
    sudo echo "#UseDNS no" >> /etc/ssh/sshd_config
    sudo echo "#PidFile /var/run/sshd.pid" >> /etc/ssh/sshd_config
    sudo echo "#MaxStartups 10:30:100" >> /etc/ssh/sshd_config
    sudo echo "#PermitTunnel no" >> /etc/ssh/sshd_config
    sudo echo "#ChrootDirectory none" >> /etc/ssh/sshd_config
    sudo echo "#VersionAddendum none" >> /etc/ssh/sshd_config
    sudo echo "# no default banner path" >> /etc/ssh/sshd_config
    sudo echo -e "#Banner none\n" >> /etc/ssh/sshd_config
    sudo echo "# Allow client to pass locale environment variables" >> /etc/ssh/sshd_config
    sudo echo -e "AcceptEnv LANG LC_*\n" >> /etc/ssh/sshd_config
    sudo echo "# override default of no subsystems" >> /etc/ssh/sshd_config
    sudo echo -e "Subsystem sftp  /usr/lib/openssh/sftp-server\n" >> /etc/ssh/sshd_config
    sudo echo "# Example of overriding settings on a per-user basis" >> /etc/ssh/sshd_config
    sudo echo "#Match User anoncvs" >> /etc/ssh/sshd_config
    sudo echo "#       X11Forwarding no" >> /etc/ssh/sshd_config
    sudo echo "#       AllowTcpForwarding no" >> /etc/ssh/sshd_config
    sudo echo "#       PermitTTY no" >> /etc/ssh/sshd_config
    sudo echo "#       ForceCommand cvs server\n" >> /etc/ssh/sshd_config

    sudo systemctl restart sshd
    sudo service sshd restart
fi

# bashrc config
if [ -f ~/.bashrc ] ; then
    echo "# ~/.bashrc: executed by bash(1) for non-login shells." >> ~/.bashrc
    echo "# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)" >> ~/.bashrc
    echo -e "# for examples\n" >> ~/.bashrc
    echo "# If not running interactively, don't do anything" >> ~/.bashrc
    echo "case $- in" >> ~/.bashrc
    echo "    *i*) ;;" >> ~/.bashrc
    echo "      *) return;;" >> ~/.bashrc
    echo -e "esac\n" >> ~/.bashrc
    echo "# don't put duplicate lines or lines starting with space in the history." >> ~/.bashrc
    echo "# See bash(1) for more options" >> ~/.bashrc
    echo -e "HISTCONTROL=ignoreboth\n" >> ~/.bashrc
    echo "# append to the history file, don't overwrite it" >> ~/.bashrc
    echo -e "shopt -s histappend\n" >> ~/.bashrc
    echo "# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)" >> ~/.bashrc
    echo "HISTSIZE=1000" >> ~/.bashrc
    echo -e "HISTFILESIZE=2000\n" >> ~/.bashrc
    echo "# check the window size after each command and, if necessary," >> ~/.bashrc
    echo "# update the values of LINES and COLUMNS." >> ~/.bashrc
    echo -e "shopt -s checkwinsize\n" >> ~/.bashrc
    echo "# If set, the pattern '**' used in a pathname expansion context will" >> ~/.bashrc
    echo "# match all files and zero or more directories and subdirectories." >> ~/.bashrc
    echo -e "#shopt -s globstar\n" >> ~/.bashrc
    echo "# make less more friendly for non-text input files, see lesspipe(1)" >> ~/.bashrc
    echo -e "[ -x /usr/bin/lesspipe ] && eval '$(SHELL=/bin/sh lesspipe)'\n" >> ~/.bashrc
    echo "# set variable identifying the chroot you work in (used in the prompt below)" >> ~/.bashrc
    echo "if [ -z '${debian_chroot:-}' ] && [ -r /etc/debian_chroot ]; then" >> ~/.bashrc
    echo "    debian_chroot=$(cat /etc/debian_chroot)" >> ~/.bashrc
    echo -e "fi\n" >> ~/.bashrc
    echo "# set a fancy prompt (non-color, unless we know we 'want' color)" >> ~/.bashrc
    echo "case '$TERM' in" >> ~/.bashrc
    echo "    xterm-color|*-256color) color_prompt=yes;;" >> ~/.bashrc
    echo -e "esac\n" >> ~/.bashrc
    echo "# uncomment for a colored prompt, if the terminal has the capability; turned" >> ~/.bashrc
    echo "# off by default to not distract the user: the focus in a terminal window" >> ~/.bashrc
    echo "# should be on the output of commands, not on the prompt" >> ~/.bashrc
    echo -e "#force_color_prompt=yes\n" >> ~/.bashrc
    echo "if [ -n '$force_color_prompt' ]; then" >> ~/.bashrc
    echo "    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then" >> ~/.bashrc
    echo "        # We have color support; assume it's compliant with Ecma-48" >> ~/.bashrc
    echo "        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such" >> ~/.bashrc
    echo "        # a case would tend to support setf rather than setaf.)" >> ~/.bashrc
    echo "        color_prompt=yes" >> ~/.bashrc
    echo "    else" >> ~/.bashrc
    echo "        color_prompt=" >> ~/.bashrc
    echo "    fi" >> ~/.bashrc
    echo -e "fi\n" >> ~/.bashrc
    echo "if [ '$color_prompt' = yes ]; then" >> ~/.bashrc
    echo "    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '" >> ~/.bashrc
    echo "else" >> ~/.bashrc
    echo "    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '" >> ~/.bashrc
    echo "fi" >> ~/.bashrc
    echo -e "unset color_prompt force_color_prompt\n" >> ~/.bashrc
    echo "# If this is an xterm set the title to user@host:dir" >> ~/.bashrc
    echo "case '$TERM' in" >> ~/.bashrc
    echo "xterm*|rxvt*)" >> ~/.bashrc
    echo "    PS1='\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1'" >> ~/.bashrc
    echo "    ;;" >> ~/.bashrc
    echo "*)" >> ~/.bashrc
    echo "    ;;" >> ~/.bashrc
    echo -e "esac\n" >> ~/.bashrc
    echo "# enable color support of ls and also add handy aliases" >> ~/.bashrc
    echo "if [ -x /usr/bin/dircolors ]; then" >> ~/.bashrc
    echo "    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"" >> ~/.bashrc
    echo "    alias ls='ls --color=auto'" >> ~/.bashrc
    echo "    #alias dir='dir --color=auto'" >> ~/.bashrc
    echo -e "    #alias vdir='vdir --color=auto'\n" >> ~/.bashrc
    echo "    alias grep='grep --color=auto'" >> ~/.bashrc
    echo "    alias fgrep='fgrep --color=auto'" >> ~/.bashrc
    echo "    alias egrep='egrep --color=auto'" >> ~/.bashrc
    echo -e "fi\n" >> ~/.bashrc
    echo "# colored GCC warnings and errors" >> ~/.bashrc
    echo -e "#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'\n" >> ~/.bashrc
    echo "# some more ls aliases" >> ~/.bashrc
    echo "alias ll='ls -all'" >> ~/.bashrc
    echo "alias la='ls -A'" >> ~/.bashrc
    echo "alias l='ls -CF'" >> ~/.bashrc
    echo "alias sysarc='sudo mount -t ext4 /dev/sda1 /mnt/system_archive'" >> ~/.bashrc
    echo "alias temp.='vcgencmd measure_temp'" >> ~/.bashrc
    echo "alias upd='sudo apt update'" >> ~/.bashrc
    echo -e "alias upg='sudo apt upgrade -y'\n" >> ~/.bashrc
    echo "# Add an 'alert' alias for long running commands.  Use like so:" >> ~/.bashrc
    echo "#   sleep 10; alert" >> ~/.bashrc
    echo -e "alias alert=\'notify-send --urgency=low -i \"$([ $? = 0 ] && echo terminal || echo error)\" \"$(history|tail -n1|sed -e \'\\'\'s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'\')\"\'\n" >> ~/.bashrc
    echo "# Alias definitions." >> ~/.bashrc
    echo "# You may want to put all your additions into a separate file like" >> ~/.bashrc
    echo "# ~/.bash_aliases, instead of adding them here directly." >> ~/.bashrc
    echo -e "# See /usr/share/doc/bash-doc/examples in the bash-doc package.\n" >> ~/.bashrc
    echo "if [ -f ~/.bash_aliases ]; then" >> ~/.bashrc
    echo "    . ~/.bash_aliases" >> ~/.bashrc
    echo -e "fi\n" >> ~/.bashrc
    echo "# enable programmable completion features (you don't need to enable" >> ~/.bashrc
    echo "# this, if it's already enabled in /etc/bash.bashrc and /etc/profile" >> ~/.bashrc
    echo "# sources /etc/bash.bashrc)." >> ~/.bashrc
    echo "if ! shopt -oq posix; then" >> ~/.bashrc
    echo "  if [ -f /usr/share/bash-completion/bash_completion ]; then" >> ~/.bashrc
    echo "    . /usr/share/bash-completion/bash_completion" >> ~/.bashrc
    echo "  elif [ -f /etc/bash_completion ]; then" >> ~/.bashrc
    echo "    . /etc/bash_completion" >> ~/.bashrc
    echo "  fi" >> ~/.bashrc
    echo -e "fi\n" >> ~/.bashrc
fi
