#! /bin/sh

#################################################
#                                               #
# Patch and build asterisk for AllStar Asterisk #
#                                               #
#################################################

cd /usr/src/astsrc-1.4.23-pre/asterisk/

./configure

# Build and install Asterisk
make
make install
make samples
make config

# add the sound files for app_rpt
cd /usr/src/astsrc-1.4.23-pre
mkdir -p /var/lib/asterisk/sounds/rpt
cp -a /usr/src/astsrc-1.4.23-pre/sounds/* /var/lib/asterisk/sounds

# Build URI diag
cd uridiag
make
chmod +x uridiag
cp uridiag /usr/local/bin/uridiag

# Clean out and replace samples
cd /etc/asterisk/
rm *
cp /srv/configs/* .

# Install Nodelist updater
cp /usr/src/astsrc-1.4.23-pre/allstar/rc.updatenodelist /usr/local/bin/rc.updatenodelist

# echo " If all looks good, edit iax.conf extensions.conf and rpt.conf"
# echo " Pay attention to the top of rpt.conf"

