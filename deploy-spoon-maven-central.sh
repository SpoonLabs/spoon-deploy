#!/bin/bash
# Deploy Spoon to Maven Central
# Run by Travis cron jobs
#
# Deploy versions according to the Maven convention: major.minor.patch-qualifier-number
# - qualifier is "beta" 
# - number is the week number in the year eg 7.3.1-beta-1 (for the first week of january)
#
# The main difference with official releases is that we don't maintain a changelog in this process

set -e

#### GPG INIT
# we generate a throwable GPG Key for Travis
# http://affy.blogspot.com/2014/04/how-to-generate-pgp-key-on-headless.html
umask 0277
# %Key-Length: 1024
# %Subkey-Type: ELG-E
# %Subkey-Length: 1024
cat << EOF > /tmp/$USER-gpg-genkey.conf
%echo Generating a package signing key
Key-Type: RSA
Key-Length: 2048
Name-Real:  `hostname --fqdn`
Name-Email: $USER@`hostname --fqdn`
Expire-Date: 0
%commit
%echo Done
EOF
umask 0002
(find / -xdev -type f -exec sha256sum {} \;>/dev/null \; 2>&1) &
export ENTROPY=$!
gpg --batch --gen-key /tmp/$USER-gpg-genkey.conf 
ps -ef | grep find | awk '{ print $2 }' | grep ${ENTROPY} && kill ${ENTROPY}
rm -f /tmp/$USER-gpg-genkey.conf
KEY=`gpg --list-keys --with-colons | grep pub | cut -f5 -d: | tail -1`
# Maven Central asks whether the key exists in one authoritative servers
gpg --keyserver keyserver.ubuntu.com --send-key $KEY
### END GPG INIT

git clone https://github.com/INRIA/spoon/
cd spoon

# replace the SNAPSHOT qualifier by beta
# we use the week number of the year as human-friendly number
sed -i -e 's/-SNAPSHOT/-beta-'`date +%W`'/' pom.xml

# adding a link to the commit
xmlstarlet edit -L --update '/_:project/_:description' --value `git rev-parse HEAD` pom.xml

DEPLOYED_VERSION=`xmlstarlet sel tr -t -v '/_:project/_:version' pom.xml`

echo deploying $DEPLOYED_VERSION

# MAVEN INIT
mkdir -p ~/.m2
cat << EOF > ~/.m2/settings.xml
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                      http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <servers>
    <server>
        <id>ossrh</id>
        <username>$SONATYPE_USER</username>
        <password>$SONATYPE_PASSWORD</password>
    </server>
</servers>
</settings>
EOF
# END MAVEN INIT

mvn -q deploy -DskipTests -Prelease -Dgpg.keyname=$KEY

