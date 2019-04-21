#!/bin/sh

echo
echo Compacting install data directory ...
echo

cd /local/notesdata
echo "create_r10_databases=1" >> notes.ini
echo "create_r85_log=1" >> notes.ini

# backup notes.ini
cp notes.ini notes.ini.orig

# temorary disable log.nsf for compact
echo "log=,1,0,7,40000" >> notes.ini

# enable compression, discard view index and upgrade to current ODS

echo "--------------------" >> /local/dom_install_data_prep.log
df -h  >> /local/dom_install_data_prep.log
echo "--------------------" >> /local/dom_install_data_prep.log

/opt/ibm/domino/bin/compact -# 4 -* -C -D -n -v -upgrade >> /local/domino_install_data_prep.log

echo "--------------------" >> /local/dom_install_data_prep.log
df -h  >> /local/dom_install_data_prep.log
echo "--------------------" >> /local/dom_install_data_prep.log

# restore original notes.ini
rm notes.ini
mv notes.ini.orig notes.ini


echo Compact done.
echo

