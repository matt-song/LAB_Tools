#!/usr/bin/perl
################################################################################
# Author     :  Matt Song                                                      #
# Create Date:  2014/02/23                                                     #
# Description:  This is a simple OS initialize script used in Matt's LAB       #
################################################################################
use strict;
use Term::ANSIColor;

my @NameServer = ('202.96.209.5','202.96.209.6');
my $NTPServer = 'stdtime.gov.hk';
my $ServiceInstall = 'man ntp vim-enhanced sysstat acpid wget traceroute';
my @ServicesRunning = ('sshd','rsyslog','network','crond','sysstat','acpid','ntpd');
my $DEBUG = 1;

### show info message
&ShowInfo();

### add DNS servers
&AddDNSServer(@NameServer);

### install services
&InstallService($ServiceInstall);

### Setting Services
&SettingService(@ServicesRunning);

### Setting NTP
&SettingNTP($NTPServer);

### Setting Environment(bashrc)
&EnvSetting();

### Other Setting (Clean Firewall, SElinux)
&OtherSetting();


#### Functions ####

sub OtherSetting
{
    ECHO_INFO("Start to Clean Firewall setting");
    unless ( system('iptables -F') )
    {
        ECHO_INFO("Filewall rules has been cleaned, saving it..");
        unless ( system('iptables-save > /etc/sysconfig/iptables') )
        {
            ECHO_INFO("Filewall rules saved");
        }
        else
        {
            ECHO_ERROR('Failed saving empty iptable to default vaule!');
        }
    }
    else
    {
        ECHO_ERROR('Unable to clean iptable!');
    }
    ECHO_INFO("Start to turn off SELinux");
    unless ( system('setenforce 0'))
    {
        ECHO_INFO("SELinux has been disabled");
    }
    else
    {
        ECHO_ERROR('Failed to turn off SELinux!');
    }
}
sub SettingNTP
{
    my $NTPServer = shift;
    open CRON,'/var/spool/cron/root' 
        or do { ECHO_ERROR('Failed to write crontab file!'); return 1; };
    my $alreadyDone = 0;
    foreach my $line (<CRON>)
    {
        chomp($line);
        if ($line =~ /$NTPServer/)
        {
            ECHO_WARN("NTP Server aleady added, skip!");
            $alreadyDone = 1;
            last;
        }
    }
    close CRON;
    unless ($alreadyDone)
    {
        open CRON,'>>','/var/spool/cron/root';
        print CRON "*/15 * * * * /usr/sbin/ntpdate $NTPServer > /dev/null 2>&1\n";
        ECHO_INFO("NTP server added!");
        close CRON;
    }
}

sub EnvSetting
{
    my $bashrcFile = '/root/.bashrc_matt';
    ECHO_WARN("Extend script [$bashrcFile] already exsisted, will override..") if ( -f $bashrcFile);
    open BASHRCEX,'>',$bashrcFile;
    my $content = q(
## color variables 
green="\[\e[1;32m\]"
red="\[\e[1;31m\]"
yellow="\[\e[1;33m\]"
normal="\[\e[0m\]"
##PS1 output
ethip=`ifconfig | grep "192.168" | awk {'print $2'} | sed 's/addr://g'`
PS1="[$red\u@$green\h $yellow$ethip$normal][\w]\\\\\\$ "
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias vi='vim'
);
    print BASHRCEX $content;
    close BASHRCEX;
    open BASHRC,'/root/.bashrc';
    my $alreadyDone = 0;
    foreach my $line (<BASHRC>)
    {
        chomp($line);
        if ( $line =~ /$bashrcFile/)
        {
            ECHO_WARN("Already added extend bashrc file, skip...") ;
            $alreadyDone = 1;
            last;
        }
    }
    close BASHRC;
    unless ($alreadyDone) 
    {
        open BASHRC,'>>','/root/.bashrc';
        print BASHRC "
if [ -f $bashrcFile ]; then
    . $bashrcFile
fi\n";
        ECHO_INFO("Write extend bashrc file into .bashrc successful!");
        close BASHRC;
    }
}
sub SettingService 
{
    my @RunningServices = @_;
    my $returnCode = 0;
    
    ECHO_INFO("Start to stop unnecessary services..");
    open SERVICES,q(chkconfig --list | grep 3:on | awk {'print $1'} |);
    foreach my $service (<SERVICES>) 
    {
        chomp($service);
        if( system("chkconfig $service off"))
        {
            ECHO_ERROR("Failed to turn off bootstrap service [$service]");
            $returnCode += 1;
        }
        else
        {
            ECHO_INFO("Disabled bootstrap service [$service]");
        }
    }
    foreach my $service (@RunningServices)
    {
        if ( system("chkconfig $service on") )
        {
            ECHO_ERROR("Failed to start service [$service]");
            $returnCode += 1;
        }
        else
        {
            ECHO_INFO("Started service [$service]");
        }
    }    
    ECHO_INFO("All unnecessary services has been stoped!") unless ($returnCode);
}
sub InstallService
{
    my $servers = shift;
    ECHO_INFO("Start to install Basic system services [$servers]...");
    if ( system("yum -y -q install $servers") )
    {
        ECHO_ERROR("Failed to install basic system package");
    }
    else
    {
        ECHO_INFO("All service successfully installed!");
    }
}
sub ShowInfo
{
    system('clear');
    my $msg = '
+--------------------------------------------------------------------------------+
|                 === Welcom to CentOS System Intialization ===                  |
|                                                                                |
|                     Author: Matt Song   Data: 2014/02/23                       |
+--------------------------------------------------------------------------------+
Here is Setting Brief:
';

    printColor('yellow',"$msg");
    printColor('yellow',"Name Server will be set to:     @NameServer");
    printColor('yellow',"NTP Server will be set to:      $NTPServer\n");
    printColor('yellow',"Filewall setting will be cleaned");
    printColor('yellow',"Selinux will be disable\n");
    printColor('cyan',"Do you want to continue?[y/n]");
    chomp(my $confirm = <STDIN>);
    if ($confirm =~ /^y$|^yes$/i)
    {
        ECHO_INFO('Start working...');
    }
    else
    {
        &ECHO_ERROR('User canceled!!',1);
    }
}
sub AddDNSServer
{
    my @DNSServer = shift;
    ECHO_INFO('Start to add DNS server...');
    open DNSCONF,'>','/etc/resolv.conf' or die "Fail to open DNS conf file\n";
    foreach my $server (@DNSServer)
    {
        print DNSCONF "nameserver $server\n";
    }
    ECHO_INFO('DNS Server has been added!');
    close DNSCONF;
}
sub printColor
{
    my ($Color,$MSG) = @_;
    print color "$Color"; print "$MSG"."\n"; print color 'reset'; 
}
sub ECHO_DEBUG
{
    my $message = shift;
    printColor('blue',"[DEBUG] $message") if $DEBUG; 
}
sub ECHO_WARN
{
    my $message = shift;
    printColor('yellow',"[WARNING] $message");
}
sub ECHO_INFO
{
    my $message = shift;
    printColor('green',"[INFO] $message");
}
sub ECHO_ERROR
{
    my ($Message,$ErrorOut) = @_;
    printColor('red',"[ERROR] $Message");
    if ($ErrorOut == 1){ exit(1);}else{return 1;}
}
