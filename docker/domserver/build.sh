#!/bin/sh -eu

cd /domjudge-src/CALICOjudge*
chown -R domjudge: .
# If we used a local source tarball, it might not have been built yet
sudo -u domjudge sh -c '. /venv/bin/activate && make dist'
sudo -u domjudge ./configure -with-baseurl=http://localhost/

# Passwords should not be included in the built image. We create empty files here to prevent passwords from being generated.
sudo -u domjudge touch etc/dbpasswords.secret etc/restapi.secret etc/symfony_app.secret etc/initial_admin_password.secret
if [ ! -f webapp/config/load_db_secrets.php ]
then
	# DOMjudge 7.1
	sudo -u domjudge touch webapp/.env.local webapp/.env.local.php
fi

sudo -u domjudge make domserver
make install-domserver

# Remove installed password files
rm /opt/domjudge/domserver/etc/*.secret
if [ ! -f webapp/config/load_db_secrets.php ]
then
	# DOMjudge 7.1
	rm /opt/domjudge/domserver/webapp/.env.local /opt/domjudge/domserver/webapp/.env.local.php
fi

sudo -u domjudge sh -c '. /venv/bin/activate && make docs'
# Use Python venv to use the latest Sphinx to build DOMjudge docs.
# shellcheck source=/dev/null
. /venv/bin/activate
make install-docs
