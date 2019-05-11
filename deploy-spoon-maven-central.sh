#!/bin/bash
# Deploy Spoon to Maven Central
# Run by Travis cron jobs
#
# Deploy a beta versions according to the Maven convention: major.minor.patch-beta-number
#

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
sleep 1m
### END GPG INIT

git clone https://github.com/INRIA/spoon/
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

cd spoon

# we do a normal release at the last bump commit
# this works the first time and will fail after
git checkout . # clean
LAST_BUMP_COMMIT=`git --no-pager log --format=format:%H  -L 31,31:pom.xml | head -1`
echo LAST_BUMP_COMMIT $LAST_BUMP_COMMIT
git checkout $LAST_BUMP_COMMIT^1 # checking out the commit just before the bump
xmlstarlet edit -L --update '/_:project/_:description' --value `git rev-parse HEAD` pom.xml
CURRENT_VERSION=`xmlstarlet sel -t -v '/_:project/_:version' pom.xml`
CURRENT_VERSION_NO_SNAPSHOT=`echo $CURRENT_VERSION | sed -e 's/-SNAPSHOT//'`
echo CURRENT_VERSION_NO_SNAPSHOT $CURRENT_VERSION_NO_SNAPSHOT
xmlstarlet edit -L --update '/_:project/_:version' --value $CURRENT_VERSION_NO_SNAPSHOT pom.xml
mvn -q deploy -DskipTests -Prelease -Dgpg.keyname=$KEY


# now we release a beta version
git checkout . # clean
git checkout master

# adding a link to the commit
xmlstarlet edit -L --update '/_:project/_:description' --value `git rev-parse HEAD` pom.xml

CURRENT_VERSION=`xmlstarlet sel -t -v '/_:project/_:version' pom.xml`
CURRENT_VERSION_NO_SNAPSHOT=`echo $CURRENT_VERSION | sed -e 's/-SNAPSHOT//'`
echo CURRENT_VERSION_NO_SNAPSHOT $CURRENT_VERSION_NO_SNAPSHOT

curl "http://search.maven.org/solrsearch/select?q=a:spoon-core+g:fr.inria.gforge.spoon&rows=40&wt=json&core=gav" | jq -r ".response.docs | map(select(.v | match(\"sddf-beta\"))) | .[0] | .v"

LAST_BETA=`curl "http://search.maven.org/solrsearch/select?q=a:spoon-core+g:fr.inria.gforge.spoon&rows=40&wt=json&core=gav" | jq -r ".response.docs | map(select(.v | match(\"$CURRENT_VERSION_NO_SNAPSHOT-beta\"))) | .[0] | .v"`
echo $LAST_BETA

LAST_BETA_NUMBER=`curl "http://search.maven.org/solrsearch/select?q=a:spoon-core+g:fr.inria.gforge.spoon&rows=40&wt=json&core=gav" | jq -r ".response.docs | map(.v) |  map(match(\"beta-(.*)\")) | map(.captures[0].string) | .[0]"`

# better version, provides a default "1" is the last version if not a beta
LAST_BETA_NUMBER=`curl "http://search.maven.org/solrsearch/select?q=a:spoon-core+g:fr.inria.gforge.spoon&rows=40&wt=json&core=gav" | jq -r ".response.docs | map(.v) | map((match(\"-beta-(.*)\") | .captures[0].string) // \"0\") | .[0]"`

echo LAST_BETA_NUMBER $LAST_BETA_NUMBER

NEW_BETA_NUMBER=$((LAST_BETA_NUMBER+1))
echo NEW_BETA_NUMBER $NEW_BETA_NUMBER

# we push a beta
PUSHED_VERSION=$CURRENT_VERSION_NO_SNAPSHOT-beta-$NEW_BETA_NUMBER
echo deploying $PUSHED_VERSION
xmlstarlet edit -L --update '/_:project/_:version' --value $PUSHED_VERSION pom.xml
mvn -q deploy -DskipTests -Prelease -Dgpg.keyname=$KEY




