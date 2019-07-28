#!/bin/bash
# generate a GPG Key for Spoon
# usefule when the key expires,
# with error "gpg: signing failed: unusable secret key"
# see https://travis-ci.org/SpoonLabs/spoon-deploy/builds/564568512
# doc: http://affy.blogspot.com/2014/04/how-to-generate-pgp-key-on-headless.html

USER=spoon-bot
GPG_CONF=/tmp/$USER-gpg-genkey.conf
umask 0277
# %Key-Length: 1024
# %Subkey-Type: ELG-E
# %Subkey-Length: 1024
cat << EOF > $GPG_CONF
%echo Generating a package signing key
Key-Type: RSA
Key-Length: 2048
Name-Real:  Spoon Bot
Name-Email: spoon-devel@lists.gforge.inria.fr
Expire-Date: 0
%commit
%echo Done
EOF
umask 0002
(find / -xdev -type f -exec sha256sum {} \;>/dev/null \; 2>&1) &
export ENTROPY=$!
gpg --batch --gen-key $GPG_CONF 
ps -ef | grep find | awk '{ print $2 }' | grep ${ENTROPY} && kill ${ENTROPY}
rm -f $GPG_CONF
KEY=`gpg --list-keys --with-colons | grep pub | cut -f5 -d: | tail -1`
# Maven Central asks whether the key exists in one authoritative servers
gpg --keyserver keyserver.ubuntu.com --send-key $KEY

echo generated $KEY according to $GPG_CONF

gpg --export-secret-keys $KEY > spoonbot.gpgkey

echo generated spoonbot.gpgkey

travis encrypt-file spoonbot.gpgkey

echo you have to push the new key
sleep 1m

