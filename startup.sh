#!/bin/sh
						#redis
redis-server --daemonize yes

						#elasticsearch
chown -R elasticsearch /usr/share/elasticsearch
						
if (( $(ps aux | grep 'elastic' | awk '{print $2}' | wc -l) > 0 ))
then
echo -e "\relastic is already running"
else
su - elasticsearch -c /usr/share/elasticsearch/bin/elasticsearch > /dev/null 2>&1 & 
echo -e "\relastic has started"
fi
                                                  #rabbitmq
if (( $(ps aux | grep 'rabbitmq' | awk '{print $2}' | wc -l) > 0 ))
then
echo -e "\rrabbitmq is already running"
else
/usr/share/rabbitmq-server/sbin/rabbitmq-plugins enable --offline rabbitmq_management
/usr/share/rabbitmq-server/sbin/rabbitmq-server &
echo -e "\rrabbitmq has started"
fi
							#nginx
#if (( $(ps aux | grep 'nginx' | awk '{print $2}' | wc -l) > 0 ))
#then
#echo -e "\rnginx is already running"
#else
#mkdir -p /var/log/nginx /var/tmp/nginx 
#/usr/sbin/nginx -g 'daemon off;' &
#echo -e "\rnginx has started"
#fi

							#php
if (( $(ps aux | grep 'php-fpm7' | awk '{print $2}' | wc -l) > 0 ))
then
echo -e "\rphp is already running"
else
/usr/sbin/php-fpm7 -F &
echo -e "\rphp has started"
fi

                                                     #varnish
if (( $(ps aux | grep 'varnishd' | awk '{print $2}' | wc -l) > 0 ))
then
echo -e "\rvarnish is already running"
else
varnishd -f /etc/varnish/default.vcl &
echo -e "\rvarnish has started"
fi

							#mysql
VOLUME_HOME=/var/lib/mysql
if [ ! -d "/run/mysqld" ]; then
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld
fi
if [[ ! -d $VOLUME_HOME ]]; then
	echo '==> Initializing database <=='
mkdir -p $VOLUME_HOME
chown -R mysql:mysql $VOLUME_HOME
mysql_install_db --user=mysql --basedir=/usr --datadir=$VOLUME_HOME
sleep 3
tfile=`mktemp`
if [ ! -f "$tfile" ]; then
return 1
fi
# save sql
echo "[i] Create temp file: $tfile"
cat << EOF > $tfile
USE mysql;
FLUSH PRIVILEGES;
DELETE FROM mysql.user;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION;
EOF
echo "[i] Creating database: magento"
echo "CREATE DATABASE IF NOT EXISTS magento CHARACTER SET utf8 COLLATE utf8_general_ci;" >> $tfile
echo "GRANT ALL ON magento.* to 'magento'@'%' IDENTIFIED BY 'magento';" >> $tfile
echo 'FLUSH PRIVILEGES;' >> $tfile
echo 'SET GLOBAL log_bin_trust_function_creators = 1;' >> $tfile
echo "[i] run tempfile: $tfile"
/usr/bin/mysqld --user=mysql --datadir=/var/lib/mysql --bootstrap --verbose=0 < $tfile
rm -f $tfile
echo "[i] Sleeping 5 sec"
sleep 5
else
    echo "=> Using an existing data of MySQL <=="
fi
echo "Starting process"
exec /usr/bin/mysqld --user=mysql --datadir=/var/lib/mysql --console --log-bin-trust-function-creators=1 > /dev/null 2>&1 &

if (( $(ps aux | grep 'nginx' | awk '{print $2}' | wc -l) > 0 ))
then
echo -e "\rnginx is already running"
else
mkdir -p /var/log/nginx /var/tmp/nginx /var/lib/nginx /var/lib/nginx/tmp /var/lib/nginx/logs
/usr/sbin/nginx -g 'daemon off;' &
echo -e "\rnginx has started"
fi



							#version list

hostname -i
hostname
composer -V
curl http://localhost:9200
redis-cli --version
php -v
mysql -V
/usr/share/rabbitmq-server/sbin/rabbitmqctl --version
varnishd -V
/usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
