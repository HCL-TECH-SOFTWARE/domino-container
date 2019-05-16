
nrpc.xml defines the NRPC port 1352

First of all you have to copy the file into the right directory and reload the configuration.
In the next step you enable the newly defined service.
The commands below can help you to query the firewall settings.


cp nrpc.xml /etc/firewalld/services/ 

firewall-cmd --reload

firewall-cmd --zone=public --permanent --add-service=nrpc

firewall-cmd --get-services
firewall-cmd --zone=public --permanent --list-services
firewall-cmd --list-all
firewall-cmd --get-default-zone
firewall-cmd --get-active-zones
