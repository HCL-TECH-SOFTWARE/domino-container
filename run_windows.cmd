docker run -it -e "ServerName=Server1" -e "OrganizationName=MyOrg" -e "AdminFirstName=Heidi" -e "AdminLastName=Harding" -e "AdminPassword=passw0rd" -h vogtsburg.demo.com -p 80:80 -p 1352:1352 -v dominodata_demo1:/local/notesdata --name server1 ibmcom/domino:10.0.1