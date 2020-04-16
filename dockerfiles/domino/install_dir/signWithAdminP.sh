#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2020 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

signWithAdminP=/local/notesdata/signWithAdminP.txt

# For every file name listed in the text file above, 
# create Domino AdminP database signing request

if [ -f "$signWithAdminP" ]; then
echo "Creating AdminP request 'sign with server id' as requested" 
for i in `cat $signWithAdminP`
  do
    echo "Signing request for " $i
    cd /local/notesdata 
    $LOTUS/bin/java -jar ./DatabaseSigner.jar $i
  done
  rm -f $signWithAdminP
fi
