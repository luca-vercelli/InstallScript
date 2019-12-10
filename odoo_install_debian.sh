#!/bin/bash
################################################################################
# Script for installing Odoo V10 on Debian (could be used for other version too)
# Based on installation script by Yenthe Van Ginneken https://github.com/Yenthe666/InstallScript
# Author: William Olhasque
#-------------------------------------------------------------------------------
# This script will install Odoo on your Debian Jessie server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
#  nano odoo-install.sh
# Place this content in it and then make the file executable:
#  chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install
################################################################################

##fixed parameters
#odoo
OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
OE_ADDONS_PATH="$OE_HOME_EXT/addons,$OE_HOME/custom/addons"
#The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
#Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="False"
#Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
#Choose the Odoo version which you want to install. For example: 10.0, 9.0, 8.0, 7.0 or saas-6. When using 'trunk' the master version will be installed.
#IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 10.0
OE_VERSION="11.0"
# Set this to True if you want to install Odoo 10 Enterprise!
IS_ENTERPRISE="False"
#set the superadmin password
OE_SUPERADMIN="admin"
OE_CONFIG="${OE_USER}-server"

#Python env
OE_PYTHON_ENV="${OE_HOME}/python_env"

#PostgreSQL Version
#OE_POSTGRESQL_VERSION="9.6"



##
###  WKHTMLTOPDF download links
## === Debian Jessie
## https://www.odoo.com/documentation/8.0/setup/install.html#deb ):
## TODO WKHTMLTOX_X64=https://nightly.odoo.com/extra/wkhtmltox-0.12.1.2_linux-jessie-amd64.deb

#
# Install dialog
#
echo -e "\n---- Update Server ----"
apt-get update >> ./install_log
echo -e "\n---- Install dialog ----"
apt-get install dialog -y >> ./install_log
#
# Remove Odoo and PostgreSQL
#
#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Upgrade Server ----"
apt-get upgrade -y >> ./install_log

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
apt-get update >> ./install_log
apt-get install postgresql  -y >> ./install_log

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 --"
apt-get install python3 python3-pip

echo -e "\n---- Install tool packages ----"
 apt-get install wget git bzr python-pip gdebi-core -y

echo -e "\n---- Install python packages ----"
apt-get install python-pypdf2 python-dateutil python-feedparser python-ldap python-libxslt1 python-lxml python-mako python-openid python-psycopg2  python-pychart python-pydot python-pyparsing python-reportlab python-simplejson python-tz python-vatnumber python-vobject python-webdav python-werkzeug python-xlwt python-yaml python-zsi python-docutils python-psutil python-mock python-unittest2 python-jinja2 python-pypdf python-decorator python-requests python-passlib python-pil -y
pip3 install pypdf2 pybabel Babel passlib Werkzeug decorator python-dateutil pyyaml psycopg2 psutil html2text docutils lxml pillow reportlab ninja2 requests gdata XlsxWriter vobject python-openid pyparsing pydot mock mako Jinja2 ebaysdk feedparser xlwt psycogreen suds-jurko pytz pyusb greenlet xlrd 

echo -e "\n---- Install python libraries ----"
# This is for compatibility with Ubuntu 16.04. Will work on 14.04, 15.04 and 16.04
apt-get install python3-suds

echo -e "\n--- Install other required packages"
apt-get install node-clean-css -y
apt-get install node-less -y
apt-get install python-gevent -y

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
	echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 10 ----"
	_url=$WKHTMLTOX_X64
	wget --quiet $_url
	gdebi --n `basename $_url` >> ./install_log
	rm `basename $_url`
else
	echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

echo -e "\n---- Create ODOO system user ----"
adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER >> ./install_log
#The user should also be added to the sudo'ers group.
adduser $OE_USER sudo >> ./install_log

echo -e "\n---- Create Log and data directory ----"
mkdir /var/log/$OE_USER >> ./install_log
mkdir /var/lib/$OE_USER >> ./install_log
chown $OE_USER:$OE_USER /var/log/$OE_USER
chown $OE_USER:$OE_USER /var/lib/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/ >> ./install_log

if [ $IS_ENTERPRISE = "True" ]; then
	# Odoo Enterprise install!
	su $OE_USER -c "mkdir $OE_HOME/enterprise"
	su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

	echo -e "\n---- Adding Enterprise code under $OE_HOME/enterprise/addons ----"
	git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons"

	echo -e "\n---- Installing Enterprise specific libraries ----"
	apt-get install nodejs npm -y >> ./install_log
	npm install -g less
	npm install -g less-plugin-clean-css
	echo -e "\n--- Create symlink for node"
	ln -s /usr/bin/nodejs /usr/bin/node
	OE_ADDONS_PATH="$OE_HOME/enterprise/addons,$OE_ADDONS_PATH"
fi

echo -e "\n---- Create custom module directory ----"
su $OE_USER -c "mkdir $OE_HOME/custom" >> ./install_log
su $OE_USER -c "mkdir $OE_HOME/custom/addons" >> ./install_log


echo -e "\n---- Setting permissions on home folder ----"
chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Create server config file"

cat <<EOF > /etc/${OE_CONFIG}.conf
[options]
addons_path = $OE_ADDONS_PATH
admin_passwd =  $OE_SUPERADMIN
csv_internal_sep = ,
data_dir = /var/lib/$OE_USER/.local/share/Odoo
db_host = False
db_maxconn = 64
db_name = False
db_password = False
db_port = False
db_template = template1
db_user = $OE_USER
dbfilter = .*
debug_mode = False
demo = {}
email_from = False
geoip_database = /usr/share/GeoIP/GeoLiteCity.dat
import_partial =
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 60
limit_time_real = 120
list_db = True
log_db = False
log_db_level = warning
log_handler = :INFO
log_level = info
logfile = /var/log/$OE_USER/$OE_CONFIG
logrotate = True
longpolling_port = 8072
max_cron_threads = 1
osv_memory_age_limit = 1.0
osv_memory_count_limit = False
pg_path = None
pidfile = None
proxy_mode = True
reportgz = False
server_wide_modules = None
smtp_password = False
smtp_port = 25
smtp_server = localhost
smtp_ssl = False
smtp_user = False
syslog = False
test_commit = False
test_enable = False
test_file = False
test_report_directory = False
translate_modules = ['all']
unaccent = False
without_demo = False
workers = 2
xmlrpc = True
xmlrpc_interface =
xmlrpc_port = $OE_PORT
EOF

chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
chmod 640 /etc/${OE_CONFIG}.conf


echo -e "\n---- Install python packages and virtualenv ----"
pip install  virtualenv >> ./install_log
mkdir $OE_PYTHON_ENV >> ./install_log
virtualenv $OE_PYTHON_ENV -p /usr/bin/python2.7 >> ./install_log
source /odoo/python_env/bin/activate && pip install -r $OE_HOME_EXT/requirements.txt >> ./install_log
deactivate


#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------

echo -e "* Create service file"
cat <<EOF > ~/$OE_CONFIG.service
[Unit]
Description=Odoo server
Documentation=https://odoo.com
After=network.target

[Service]
User=odoo
Group=odoo
ExecStart=$OE_PYTHON_ENV/bin/python $OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf


[Install]
WantedBy=multi-user.target

EOF

echo -e "* Security Init File"
mv ~/$OE_CONFIG.service /etc/systemd/system/$OE_CONFIG.service

echo -e "* Start ODOO on Startup"
systemctl enable $OE_CONFIG.service


echo -e "* Starting Odoo Service"
systemctl start $OE_CONFIG.service





echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_USER"
echo "Addons folder: $OE_USER/$OE_CONFIG/addons/"
echo "Start Odoo service:  systemctl start $OE_CONFIG.service"
echo "Stop Odoo service:  systemctl stop $OE_CONFIG.service"
echo "Restart Odoo service:  systemctl restart $OE_CONFIG.service"
echo "-----------------------------------------------------------"
