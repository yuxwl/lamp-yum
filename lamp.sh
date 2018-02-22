#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#==========================================================================#
#   System Required:  CentOS 6+                                            #
#   Description:  Yum Install LAMP(Linux + Apache + MySQL/MariaDB + PHP )  #
#   Author: Teddysun <i@teddysun.com>                                      #
#   Intro:  https://teddysun.com/lamp-yum                                  #
#           https://github.com/teddysun/lamp-yum                           #
#==========================================================================#

clear

# Current folder
cur_dir=`pwd`

# Make sure only root can run our script
rootness(){
if [[ $EUID -ne 0 ]]; then
   echo "Error:This script must be run as root!" 1>&2
   exit 1
fi
}

# Disable selinux
disable_selinux(){
if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi
}

# Get public IP
get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

get_char(){
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

# Pre-installation settings
pre_installation_settings(){
    echo
    echo "#############################################################"
    echo "# LAMP Auto yum Install Script for CentOS                   #"
    echo "# Intro: https://teddysun.com/lamp-yum                      #"
    echo "# Author: Teddysun <i@teddysun.com>                         #"
    echo "#############################################################"
    echo
    # Install Atomic repository
    rpm -qa | grep "atomic-release" &>/dev/null
    if [ $? -ne 0 ]; then
        wget -qO- https://www.atomicorp.com/installers/atomic | bash
    fi
    echo "Getting Public IP address..."
    echo -e "Your main public IP is\t\033[32m$(get_ip)\033[0m"
    echo
    # Choose databese
    while true
    do
    echo "Please choose a version of the Database:"
    echo -e "\t\033[32m1\033[0m. Install MySQL-5.5(recommend)"
    echo -e "\t\033[32m2\033[0m. Install MariaDB-10.2"
    read -p "Please input a number:(Default 1) " DB_version
    [ -z "$DB_version" ] && DB_version=1
    case $DB_version in
        1|2)
        echo
        echo "---------------------------"
        echo "You choose = $DB_version"
        echo "---------------------------"
        echo
        break
        ;;
        *)
        echo "Input error! Please only input number 1,2"
    esac
    done
    # Set MySQL root password
    echo "Please input the root password of MySQL or MariaDB:"
    read -p "(Default password: root):" dbrootpwd
    if [ -z $dbrootpwd ]; then
        dbrootpwd="root"
    fi
    echo
    echo "---------------------------"
    echo "Password = $dbrootpwd"
    echo "---------------------------"
    echo
    # Choose PHP version
    while true
    do
    echo "Please choose a version of the PHP:"
    echo -e "\t\033[32m1\033[0m. Install PHP-5.4"
    echo -e "\t\033[32m2\033[0m. Install PHP-5.5"
    echo -e "\t\033[32m3\033[0m. Install PHP-5.6"
    echo -e "\t\033[32m4\033[0m. Install PHP-7.0"
    read -p "Please input a number:(Default 1) " PHP_version
    [ -z "$PHP_version" ] && PHP_version=1
    case $PHP_version in
        1|2|3|4)
        echo
        echo "---------------------------"
        echo "You choose = $PHP_version"
        echo "---------------------------"
        echo
        break
        ;;
        *)
        echo "Input error! Please only input number 1,2,3,4"
    esac
    done

    echo
    echo "Press any key to start...or Press Ctrl+C to cancel"
    char=`get_char`
    # Remove Packages
    yum -y remove httpd*
    yum -y remove mysql*
    yum -y remove mariadb*
    yum -y remove php*
    # Set timezone
    rm -f /etc/localtime
    ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    yum -y install ntp
    ntpdate -d cn.pool.ntp.org
    ntpdate -v time.nist.gov
    /sbin/hwclock -w
}

# Install Apache
install_apache(){
    # Install Apache
    echo "Start Installing Apache..."
    yum -y install httpd
    cp -f $cur_dir/conf/httpd.conf /etc/httpd/conf/httpd.conf
    rm -fv /etc/httpd/conf.d/welcome.conf /data/www/error/noindex.html
    chkconfig httpd on
    mkdir -p /data/www/default
    chown -R apache:apache /data/www/default
    touch /etc/httpd/conf.d/none.conf
    cp -f $cur_dir/conf/index.html /data/www/default/
    cp -f $cur_dir/conf/index_cn.html /data/www/default/
    cp -f $cur_dir/conf/lamp.gif /data/www/default/
    cp -f $cur_dir/conf/p.php /data/www/default/
    cp -f $cur_dir/conf/p_cn.php /data/www/default/
    cp -f $cur_dir/conf/jquery.js /data/www/default/
    cp -f $cur_dir/conf/phpinfo.php /data/www/default/
    echo "Apache Install completed!"
}

# Install database
install_database(){
    if [ $DB_version -eq 1 ]; then
        install_mysql
    elif [ $DB_version -eq 2 ]; then
        install_mariadb
    fi
}

# Install MariaDB
install_mariadb(){
    # Install MariaDB
    echo "# MariaDB 10.2 CentOS repository list - created 2017-07-03 06:59 UTC
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = https://mirrors.ustc.edu.cn/mariadb/yum/10.2/centos6-amd64
gpgkey=https://mirrors.ustc.edu.cn/mariadb/yum/RPM-GPG-KEY-MariaDB
gpgcheck=1" > /etc/yum.repos.d/MariaDB.repo

    echo "Start Installing MariaDB..."
    yum -y install MariaDB-server MariaDB-client
    cp -f $cur_dir/conf/my.cnf /etc/my.cnf
    chkconfig mysqld on
    # Start mysqld service
    service mysqld start
    /usr/bin/mysqladmin password $dbrootpwd
    /usr/bin/mysql -uroot -p$dbrootpwd <<EOF
drop database if exists test;
delete from mysql.user where user='';
update mysql.user set password=password('$dbrootpwd') where user='root';
delete from mysql.user where not (user='root') ;
flush privileges;
exit
EOF
    echo "MariaDB Install completed!"
}

# Install MySQL
install_mysql(){
    # Install MySQL
    echo "Start Installing MySQL..."
    yum -y install mysql mysql-server
    cp -f $cur_dir/conf/my.cnf /etc/my.cnf
    chkconfig mysqld on
    # Start mysqld service
    service mysqld start
    /usr/bin/mysqladmin password $dbrootpwd
    /usr/bin/mysql -uroot -p$dbrootpwd <<EOF
drop database if exists test;
delete from mysql.user where user='';
update mysql.user set password=password('$dbrootpwd') where user='root';
delete from mysql.user where not (user='root') ;
flush privileges;
exit
EOF
    echo "MySQL Install completed!"
}

# Install PHP
install_php(){
    echo "Start Installing PHP..."
    yum -y install libjpeg-devel libpng-devel
    if [ $PHP_version -eq 1 ]; then
        yum -y install php php-cli php-common php-devel php-pdo php-mysqlnd php-mcrypt php-mbstring php-xml php-xmlrpc
        yum -y install php-gd php-bcmath php-imap php-odbc php-ldap php-mhash php-intl
        yum -y install php-xcache php-ioncube-loader php-zend-guard-loader php-snmp php-soap php-tidy
    fi
    if [ $PHP_version -eq 2 ]; then
        yum -y install atomic-php55-php atomic-php55-php-cli atomic-php55-php-common atomic-php55-php-devel atomic-php55-php-pdo atomic-php55-php-mysqlnd atomic-php55-php-mcrypt atomic-php55-php-mbstring atomic-php55-php-xml atomic-php55-php-xmlrpc
        yum -y install atomic-php55-php-gd atomic-php55-php-bcmath atomic-php55-php-imap atomic-php55-php-odbc atomic-php55-php-ldap atomic-php55-php-mhash atomic-php55-php-intl
        yum -y install atomic-php55-php-snmp atomic-php55-php-soap atomic-php55-php-tidy atomic-php55-php-opcache
        # Fix php for httpd configuration
        cat > /etc/httpd/conf.d/php55.conf<<EOF
<IfModule prefork.c>
  LoadModule php5_module modules/libphp55.so
</IfModule>
<IfModule !prefork.c>
  LoadModule php5_module modules/libphp55-zts.so
</IfModule>
AddType text/html .php
DirectoryIndex index.php
<IfModule  mod_php5.c>
    <FilesMatch \.php$>
        SetHandler application/x-httpd-php
    </FilesMatch>
    php_value session.save_handler "files"
    php_value session.save_path    "/var/lib/php/session"
    php_value soap.wsdl_cache_dir  "/var/lib/php/wsdlcache"
</IfModule>
EOF
    fi
    if [ $PHP_version -eq 3 ]; then
        yum -y install atomic-php56-php atomic-php56-php-cli atomic-php56-php-common atomic-php56-php-devel atomic-php56-php-pdo atomic-php56-php-mysqlnd atomic-php56-php-mcrypt atomic-php56-php-mbstring atomic-php56-php-xml atomic-php56-php-xmlrpc
        yum -y install atomic-php56-php-gd atomic-php56-php-bcmath atomic-php56-php-imap atomic-php56-php-odbc atomic-php56-php-ldap atomic-php56-php-mhash atomic-php56-php-intl
        yum -y install atomic-php56-php-snmp atomic-php56-php-soap atomic-php56-php-tidy atomic-php56-php-opcache
        # Fix php for httpd configuration
        cat > /etc/httpd/conf.d/php56.conf<<EOF
<IfModule prefork.c>
  LoadModule php5_module modules/libphp56.so
</IfModule>
<IfModule !prefork.c>
  LoadModule php5_module modules/libphp56-zts.so
</IfModule>
AddHandler php5-script .php
AddType text/html .php
DirectoryIndex index.php
<IfModule  mod_php5.c>
    <FilesMatch \.php$>
        SetHandler application/x-httpd-php
    </FilesMatch>
    php_value session.save_handler "files"
    php_value session.save_path    "/var/lib/php/session"
    php_value soap.wsdl_cache_dir  "/var/lib/php/wsdlcache"
</IfModule>
EOF
    fi
    if [ $PHP_version -eq 4 ]; then
        yum -y install atomic-php70-php atomic-php70-php-cli atomic-php70-php-common atomic-php70-php-devel atomic-php70-php-pdo atomic-php70-php-mysqlnd atomic-php70-php-mcrypt atomic-php70-php-mbstring atomic-php70-php-xml atomic-php70-php-xmlrpc
        yum -y install atomic-php70-php-gd atomic-php70-php-bcmath atomic-php70-php-imap atomic-php70-php-odbc atomic-php70-php-ldap atomic-php70-php-json atomic-php70-php-intl
        yum -y install atomic-php70-php-gmp atomic-php70-php-snmp atomic-php70-php-soap atomic-php70-php-tidy atomic-php70-php-opcache atomic-php70-php-enchant
        # Fix php for httpd configuration
        cat > /etc/httpd/conf.d/php70.conf<<EOF
<IfModule !mod_php5.c>
  <IfModule prefork.c>
    LoadModule php7_module modules/libatomic_php70.so
  </IfModule>
</IfModule>
AddType text/html .php
DirectoryIndex index.php
<IfModule  mod_php7.c>
    <FilesMatch \.php$>
        SetHandler application/x-httpd-php
    </FilesMatch>
    php_value session.save_handler "files"
    php_value session.save_path    "/opt/atomic/atomic_php70/root/var/lib/php/session"
    php_value soap.wsdl_cache_dir  "/opt/atomic/atomic_php70/root/var/lib/php/wsdlcache"
</IfModule>
EOF
    fi
    cp -f $cur_dir/conf/php.ini /etc/php.ini
    echo "PHP install completed!"
}

# Install phpmyadmin.
install_phpmyadmin(){
    if [ ! -d /data/www/default/phpmyadmin ];then
        echo "Start Installing phpMyAdmin..."
        LATEST_PMA=$(wget --no-check-certificate -qO- https://www.phpmyadmin.net/files/ | awk -F\> '/\/files\//{print $3}' | cut -d'<' -f1 | sort -V | tail -1)
        if [[ -z $LATEST_PMA ]]; then
            LATEST_PMA=$(wget -qO- http://dl.lamp.sh/pmalist.txt | tail -1 | awk -F- '{print $2}')
        fi
        echo -e "Installing phpmyadmin version: \033[41;37m $LATEST_PMA \033[0m"
        cd $cur_dir
        if [ -s phpMyAdmin-${LATEST_PMA}-all-languages.tar.gz ]; then
            echo "phpMyAdmin-${LATEST_PMA}-all-languages.tar.gz [found]"
        else
            wget -c http://files.phpmyadmin.net/phpMyAdmin/${LATEST_PMA}/phpMyAdmin-${LATEST_PMA}-all-languages.tar.gz
            tar zxf phpMyAdmin-${LATEST_PMA}-all-languages.tar.gz
        fi
        mv phpMyAdmin-${LATEST_PMA}-all-languages /data/www/default/phpmyadmin
        cp -f $cur_dir/conf/config.inc.php /data/www/default/phpmyadmin/config.inc.php
        #Create phpmyadmin database
        /usr/bin/mysql -uroot -p$dbrootpwd < /data/www/default/phpmyadmin/sql/create_tables.sql
        mkdir -p /data/www/default/phpmyadmin/upload/
        mkdir -p /data/www/default/phpmyadmin/save/
        cp -f /data/www/default/phpmyadmin/sql/create_tables.sql /data/www/default/phpmyadmin/upload/
        chown -R apache:apache /data/www/default/phpmyadmin
        rm -f phpMyAdmin-${LATEST_PMA}-all-languages.tar.gz
        echo "PHPMyAdmin Install completed!"
    else
        echo "PHPMyAdmin had been installed!"
    fi
    #Start httpd service
    service httpd start
}

# Uninstall lamp
uninstall_lamp(){
    echo "Warning! All of your data will be deleted..."
    echo "Are you sure uninstall LAMP? (y/n)"
    read -p "(Default: n):" uninstall
    if [ -z $uninstall ]; then
        uninstall="n"
    fi
    if [[ "$uninstall" = "y" || "$uninstall" = "Y" ]]; then
        clear
        echo "==========================="
        echo "Yes, I agreed to uninstall!"
        echo "==========================="
        echo
    else
        echo
        echo "============================"
        echo "You cancelled the uninstall!"
        echo "============================"
        exit
    fi

    echo "Press any key to start uninstall...or Press Ctrl+c to cancel"
    char=`get_char`
    echo
    if [[ "$uninstall" = "y" || "$uninstall" = "Y" ]]; then
        cd ~
        CHECK_MARIADB=$(mysql -V | grep -i 'MariaDB')
        service httpd stop
        service mysqld stop
        yum -y remove httpd*
        if [ -z $CHECK_MARIADB ]; then
            yum -y remove mysql*
        else
            yum -y remove mariadb*
        fi
        if [ -s /usr/bin/atomic-php55-php ]; then
            yum -y remove atomic-php55-php*
        elif [ -s /usr/bin/atomic-php56-php ]; then
            yum -y remove atomic-php56-php*
        elif [ -s /usr/bin/atomic_php70 ]; then
            yum -y remove atomic-php70-php*
        else
            yum -y remove php*
        fi
        rm -rf /data/www/default/phpmyadmin
        rm -rf /etc/httpd
        rm -f /usr/bin/lamp
        rm -f /etc/my.cnf.rpmsave
        rm -f /etc/php.ini.rpmsave
        echo "Successfully uninstall LAMP!!"
    else
        echo
        echo "Uninstall cancelled, nothing to do..."
        echo
    fi
}

# Add apache virtualhost
vhost_add(){
    #Define domain name
    read -p "(Please input domains such as:www.example.com):" domains
    if [ "$domains" = "" ]; then
        echo "You need input a domain."
        exit 1
    fi
    domain=`echo $domains | awk '{print $1}'`
    if [ -f "/etc/httpd/conf.d/$domain.conf" ]; then
        echo "$domain is exist!"
        exit 1
    fi
    #Create database or not
    while true
    do
    read -p "(Do you want to create database?[y/N]):" create
    case $create in
    y|Y|YES|yes|Yes)
    read -p "(Please input the user root password of MySQL or MariaDB):" mysqlroot_passwd
    /usr/bin/mysql -uroot -p$mysqlroot_passwd <<EOF
exit
EOF
    if [ $? -eq 0 ]; then
        echo "MySQL or MariaDB root password is correct.";
    else
        echo "MySQL or MariaDB root password incorrect! Please check it and try again!"
        exit 1
    fi
    read -p "(Please input the database name):" dbname
    read -p "(Please set the password for mysql user $dbname):" mysqlpwd
    create=y
    break
    ;;
    n|N|no|NO|No)
    echo "Not create database, you entered $create"
    create=n
    break
    ;;
    *) echo Please input only y or n
    esac
    done

    #Create database
    if [ "$create" == "y" ];then
        /usr/bin/mysql -uroot -p$mysqlroot_passwd  <<EOF
CREATE DATABASE IF NOT EXISTS \`$dbname\`;
GRANT ALL PRIVILEGES ON \`$dbname\` . * TO '$dbname'@'localhost' IDENTIFIED BY '$mysqlpwd';
GRANT ALL PRIVILEGES ON \`$dbname\` . * TO '$dbname'@'127.0.0.1' IDENTIFIED BY '$mysqlpwd';
FLUSH PRIVILEGES;
EOF
    fi
    #Define website dir
    webdir="/data/www/$domain"
    DocumentRoot="$webdir/web"
    logsdir="$webdir/logs"
    mkdir -p $DocumentRoot $logsdir
    chown -R apache:apache $webdir
    #Create vhost configuration file
    cat >/etc/httpd/conf.d/$domain.conf<<EOF
<virtualhost *:80>
ServerName  $domain
ServerAlias  $domains 
DocumentRoot  $DocumentRoot
CustomLog $logsdir/access.log combined
DirectoryIndex index.php index.html
<Directory $DocumentRoot>
Options +Includes -Indexes
AllowOverride All
Order Deny,Allow
Allow from All
php_admin_value open_basedir $DocumentRoot:/tmp
</Directory>
</virtualhost>
EOF
    service httpd restart > /dev/null 2>&1
    echo "Successfully create $domain vhost"
    echo "######################### information about your website ############################"
    echo "The DocumentRoot:$DocumentRoot"
    echo "The Logsdir:$logsdir"
    [ "$create" == "y" ] && echo "database name and user:$dbname and password:$mysqlpwd"
}

# Remove apache virtualhost
vhost_del(){
    read -p "(Please input a domain you want to delete):" vhost_domain
    if [ "$vhost_domain" = "" ]; then
        echo "You need input a domain."
        exit 1
    fi
    echo "---------------------------"
    echo "vhost account = $vhost_domain"
    echo "---------------------------"
    echo

    echo "Press any key to start delete vhost...or Press Ctrl+c to cancel"
    echo
    char=`get_char`

    if [ -f "/etc/httpd/conf.d/$vhost_domain.conf" ]; then
        rm -f /etc/httpd/conf.d/$vhost_domain.conf
        rm -rf /data/www/$vhost_domain
    else
        echo "Error:No such domain file, Please check your input domain and try again."
        exit 1
    fi

    service httpd restart
    echo "Successfully delete $vhost_domain vhost"
}

# List apache virtualhost
vhost_list(){
    ls /etc/httpd/conf.d/ | grep -v "php.conf" | grep -v "none.conf" | grep -v "welcome.conf" | grep -iv "README" | awk -F".conf" '{print $1}'
}

# Install LAMP Script
install_lamp(){
    rootness
    disable_selinux
    pre_installation_settings
    install_apache
    install_database
    install_php
    #install_phpmyadmin
    cp -f $cur_dir/lamp.sh /usr/bin/lamp
    chmod +x /usr/bin/lamp
    clear
    echo
    echo 'Congratulations, Yum install LAMP completed!'
    echo "Your Default Website: http://$(get_ip)"
    echo 'Default WebSite Root Dir: /data/www/default'
    echo "MySQL root password:$dbrootpwd"
    echo
    echo "Welcome to visit:https://teddysun.com/lamp-yum"
    echo "Enjoy it! "
    echo
}

# Initialization step
action=$1
[ -z $1 ] && action=install
case "$action" in
install)
    install_lamp
    ;;
uninstall)
    uninstall_lamp
    ;;
add)
   vhost_add
    ;;
del)
   vhost_del
    ;;
list)
   vhost_list
    ;;
*)
    echo "Usage: `basename $0` [install|uninstall|add|del|list]"
    ;;
esac
