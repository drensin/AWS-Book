#! /bin/bash

trap "echo \"##### Script error! ####\"; read" ERR
set -x

export PASSWORD="passw0rd!"

yum -y update

rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-7.noarch.rpm

yum -y groupinstall "Development Tools"
yum -y groupinstall "DNS Name Server"
yum -y groupinstall "Web Server"
yum -y groupinstall "Mail Server"
yum -y groupinstall "MySQL Database"

yum install -y e2fsprogs-devel keyutils-libs-devel krb5-devel libogg libselinux-devel libsepol-devel libxml2-devel libtiff-devel
yum install -y php gmp php-pear php-pear-DB php-gd php-mysql php-pdo kernel-devel ncurses-devel audiofile-devel libogg-devel
yum install -y openssl-devel mysql-devel zlib-devel perl-DateManip sendmail-cf sox
yum -y install libsrtp* flite fail2ban php-posix incron mISDN* php-x*

chkconfig incrond on
service incrond start

echo ?SELINUX=disabled? > /etc/selinux/config
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -F
iptables -X
/etc/init.d/iptables save

cd /usr/src
wget -nc -t 0 --retry-connrefused http://downloads.sourceforge.net/project/lame/lame/3.98.4/lame-3.98.4.tar.gz?ts=1292626574&use_mirror=cdnetworks-us-1

echo "### Wait for download to complete and press a key ###"
read

tar zxvf lame-3.98.4.tar.gz
cd lame-3.98*
./configure
make
make install

cd /usr/src
wget -nc -t 0 --retry-connrefused http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-1.8-current.tar.gz

echo "### Wait for download to complete and press a key ###"
read


tar zxvf asterisk-1.8*.tar.gz
cd asterisk-1.8*
contrib/scripts/get_mp3_source.sh
./configure

echo
echo "## Make sure your terminal window is at least 80x27 ###"
echo "## press a key when ready ###"
read

make menuconfig
#need 80x27

# add-ons - format_mp3, res_config_mysql
# music on-hold - MOH-OPSOUND-GSM
# extra sound - EXTRA-SOUND-EN-GSM
# type 's' when done

make
make install

cd /usr/src
# wget <latest freepbx>
wget -nc -t 0 --retry-connrefused http://mirror.freepbx.org/freepbx-2.10.0.tar.gz

echo "### Wait for download to complete and press a key ###"
read


tar zxvf free*
cd free*

service mysqld start
chkconfig mysqld on

mysqladmin create asterisk
mysqladmin create asteriskcdrdb
mysql asterisk < SQL/newinstall.sql
mysql asteriskcdrdb < SQL/cdr_mysql_table.sql

echo "GRANT ALL PRIVILEGES ON asteriskcdrdb.* to asteriskuser@localhost IDENTIFIED BY '$PASSWORD'; GRANT ALL PRIVILEGES ON asterisk.* to asteriskuser@localhost IDENTIFIED BY '$PASSWORD'; flush privileges; \q" > testsql.sql

mysql < testsql.sql

mysqladmin -u root password $PASSWORD

useradd -c "Asterisk PBX" -d /var/lib/asterisk asterisk
chown -R asterisk:asterisk /var/run/asterisk
chown -R asterisk:asterisk /var/log/asterisk
chown -R asterisk:asterisk /var/lib/php/session/
chown -R asterisk:asterisk /var/lib/asterisk

sed -i -e "s/AllowOverride None/AllowOverride All/g" \
       -e "s/User apache/User asterisk/g" \
       -e "s/Group apache/Group asterisk/g" \
       -e "s/\#ServerName www.example.com\:80/ServerName $HOSTNAME\:80/g" \
   /etc/httpd/conf/httpd.conf
 
service httpd start
service sendmail start
chkconfig httpd on
chkconfig sendmail on

./start_asterisk start

echo "date.timezone = America/New_York" >> /etc/php.ini

./install_amp --username=asteriskuser --password=passw0rd\!

echo "/usr/local/sbin/amportal start" >> /etc/rc.local

wget -nc -t 0 --retry-connrefused http://downloads.zend.com/guard/5.5.0/ZendGuardLoader-php-5.3-linux-glibc23-x86_64.tar.gz

echo "### Wait for download to complete and press a key ###"
read


tar -zxvf ZendGuardLoader*
mkdir /usr/local/lib/php/
cp ZendGuardLoader*/php-5.3.x/ZendGuardLoader.so /usr/local/lib/php/ZendGuardLoader.so

echo "zend_optimizer.optimization_level=15" >> /etc/php.ini
echo "zend_extension=/usr/local/lib/php/ZendGuardLoader.so" >> /etc/php.ini

service httpd restart
php -v

echo "## check php ##"
read

/var/lib/asterisk/bin/module_admin enable framework
/var/lib/asterisk/bin/module_admin enable fw_ari
/var/lib/asterisk/bin/module_admin installall
/var/lib/asterisk/bin/module_admin upgradeall
/var/lib/asterisk/bin/module_admin reload
/var/lib/asterisk/bin/module_admin --repos standard,unsupported,extended,commercial download sysadmin
/var/lib/asterisk/bin/module_admin --repos standard,unsupported,extended,commercial install sysadmin
/var/lib/asterisk/bin/module_admin enable sysadmin
/var/lib/asterisk/bin/module_admin reload

export CMDSTUB="/var/lib/asterisk/bin/module_admin --repos standard,unsupported,commercial,extended"
export CMDSTUB_SAFE="\/var\/lib\/asterisk\/bin\/module_admin --repos standard,unsupported,commercial,extended"

$CMDSTUB listonline | sed -E -e "1,4 d" -e "s/([^ ]+).+/echo\necho \"#### \1 ####\"\n$CMDSTUB_SAFE install \1\n\n/" > getmods.sh

chmod +x getmods.sh

./getmods.sh
./getmods.sh

rm -f ./getmods.sh

/var/lib/asterisk/bin/module_admin reload

/usr/local/sbin/amportal restart

service fail2ban start
service httpd restart

#update modules

#sip settings auto configure.

mkdir /etc/asterisk/keys
cd /usr/src/asterisk*/contrib/scripts

./ast_tls_cert -C pbx.mycompany.com -O "My Super Company" -d /etc/asterisk/keys
chmod +r /etc/asterisk/keys/*

echo "tlsenable=yes" >> /etc/asterisk/sip_general_custom.conf
echo "tlsbindaddr=0.0.0.0" >> /etc/asterisk/sip_general_custom.conf
echo "tlscertfile=/etc/asterisk/keys/asterisk.pem" >> /etc/asterisk/sip_general_custom.conf
echo "tlscafile=/etc/asterisk/keys/ca.crt" >> /etc/asterisk/sip_general_custom.conf
echo "tlscipher=ALL" >> /etc/asterisk/sip_general_custom.conf
echo "tlsclientmethod=tlsv1" >> /etc/asterisk/sip_general_custom.conf

/usr/local/sbin/amportal restart

echo "### DONE! ####"
