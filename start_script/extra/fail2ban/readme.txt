
Fail2Ban for HCL Domino (HTTP, SMTP, LDAP, POP3, IMAP)
Date  :  09.08.2019
Author: Daniel Nashed (Nash!Com)

Installation instructions are an example for CentOS 7.x and higher.
The installation part for the software itself might be different depending on your platform.
CentOS includes the software already in epel.
CentOS 6.x still uses init.d so some commands are different.


Install epel
------------

yum install -y epel-release 


Install fail2ban package
------------------------

yum install -y fail2ban 


Ensure SELinux is disabled
--------------------------

Check should return: disabled

getenforce

If not disable after reboot by editing config:

vi /etc/selinux/config 

Change the line 

SELINUX=disabled 

The next reboot disables SELINUX 

You can temporary disable SELinux if you don't want to reboot now (you should reboot at least later to ensure your server will still boot!). 

setenforce 0 


Copy and review configuration files
-----------------------------------

cp jail.local /etc/fail2ban/jail.local 
cp domino.conf /etc/fail2ban/filter.d/domino.conf 


Review the configuration files and take special care about the dateformat used. 
The files have detailed information how to configure.


Enable fail2ban service
-----------------------

systemctl enable fail2ban


Start Service
-------------

systemctl start fail2ban


Useful commands
---------------

Check status:

fail2ban-client status domino


Check log file:

cat /var/log/fail2ban.log 


Unban IP:

Example:

fail2ban-client set domino unbanip 192.168.100.107 


Check Rules for customization and date format change:

fail2ban-regex  /local/notesdata/notes.log /etc/fail2ban/filter.d/domino.conf 

You can use the following filters: 

--print-all-matched 
--print-all-missed 

