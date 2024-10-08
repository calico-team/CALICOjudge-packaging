#!/bin/sh -eu

# Create PHP FPM socket dir, change permissions for some domjudge directories and fix scripts
mkdir -p /run/php
chown -R www-data: /opt/domjudge/domserver/tmp

chmod 755 /scripts/start.sh
for script in /scripts/bin/*
do
	if [ -f "$script" ]
	then
		chmod 755 "$script"
		ln -s "$script" /usr/bin/
	fi
done

# Configure php

php_folder=$(echo "/etc/php/8."?"/")
php_version=$(basename "$php_folder")

if [ ! -d "$php_folder" ]
then
	echo "[!!] Could not find php path"
	exit 1
fi

# Set correct settings
sed -ri -e "s/^user.*/user www-data;/" /etc/nginx/nginx.conf
sed -ri -e "s/^upload_max_filesize.*/upload_max_filesize = 100M/" \
	-e "s/^post_max_size.*/post_max_size = 100M/" \
	-e "s/^memory_limit.*/memory_limit = 2G/" \
	-e "s/^max_file_uploads.*/max_file_uploads = 200/" \
	-e "s#^;date\.timezone.*#date.timezone = ${CONTAINER_TIMEZONE}#" \
	 "$php_folder/fpm/php.ini"

ln -s "/usr/sbin/php-fpm$php_version" "/usr/sbin/php-fpm"

# Set up vhost
cp /opt/domjudge/domserver/etc/nginx-conf /etc/nginx/sites-enabled/default
if [ -f /opt/domjudge/domserver/etc/domjudge-fpm.conf ]
then
	# Replace nginx php socket location
	sed -i 's!server unix:.*!server unix:/var/run/php-fpm-domjudge.sock;!' /etc/nginx/sites-enabled/default
	# Remove default FPM pool config and link in DOMjudge version
	if [ -f "$php_version/fpm/pool.d/www.conf" ]
	then
		rm "$php_version/fpm/pool.d/www.conf"
	fi
	if [ ! -f "$php_version/fpm/pool.d/domjudge.conf" ]
	then
		ln -s /opt/domjudge/domserver/etc/domjudge-fpm.conf "$php_folder/fpm/pool.d/domjudge.conf"
	fi
	# Change pm.max_children
	sed --follow-symlinks -i "s/^pm\.max_children = .*$/pm.max_children = ${FPM_MAX_CHILDREN}/" "$php_folder/fpm/pool.d/domjudge.conf"
else
	# Replace nginx php socket location
	sed -i "s!server unix:.*!server unix:/var/run/php/php$php_version-fpm.sock;!" /etc/nginx/sites-enabled/default
fi

cp /opt/domjudge/domserver/etc/nginx-conf-inner /etc/nginx/snippets/domjudge-inner
NGINX_CONFIG_FILE=/etc/nginx/snippets/domjudge-inner
sed -i 's/\/opt\/domjudge\/domserver\/etc\/nginx-conf-inner/\/etc\/nginx\/snippets\/domjudge-inner/' /etc/nginx/sites-enabled/default

# Remove the location configuration
# Wait until the container starts before adding the relevant configuration
sed -i "/^# Uncomment to run it out of the root of your system/,/^# \}/d" "$NGINX_CONFIG_FILE"
sed -i "/^# Or you can install it with a prefix/,/^}/d" "$NGINX_CONFIG_FILE"
sed -i "s/^set \$prefix .*;$/set \$prefix \"\";/" "$NGINX_CONFIG_FILE"

# Remove access_log and error_log entries
sed -i '/access_log/d' "$NGINX_CONFIG_FILE"
sed -i '/error_log/d' "$NGINX_CONFIG_FILE"

# Enable OPCache
echo "opcache.preload=/opt/domjudge/domserver/webapp/config/preload.php" >> "$php_folder/fpm/php.ini"
echo "opcache.preload_user=www-data" >> "$php_folder/fpm/php.ini"
echo "opcache.memory_consumption=512" >> "$php_folder/fpm/php.ini"
echo "opcache.max_accelerated_files=20000" >> "$php_folder/fpm/php.ini"
echo "opcache.validate_timestamps=0" >> "$php_folder/fpm/php.ini"
echo "realpath_cache_size=4096K" >> "$php_folder/fpm/php.ini"
echo "realpath_cache_ttl=600" >> "$php_folder/fpm/php.ini"

# Fix permissions on cache and log directories
chown www-data: -R /opt/domjudge/domserver/webapp/var
