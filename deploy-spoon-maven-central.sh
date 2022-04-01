#!/bin/bash
# Deploy Spoon to Maven Central
# Run by Travis cron jobs
#
# Deploy a beta versions according to the Maven convention: major.minor.patch-beta-number
#

# Install dependencies
sudo apt-get install -y xmlstarlet

git clone https://github.com/INRIA/spoon/

cd spoon

function quick_fix_pom() {
# quickfix
cd spoon-pom

# not required anymore, fixed on master
# xmlstarlet ed -L -d '/_:project/_:parent' pom.xml

# see https://github.com/joel-costigliola/assertj-core/issues/1403#issuecomment-500100254
JAVADOC_PLUGIN="/_:project/_:profiles/_:profile[./_:id='release']/_:build/_:plugins/_:plugin[./_:artifactId='maven-javadoc-plugin']"
xmlstarlet sel -t -v $JAVADOC_PLUGIN  pom.xml
# xmlstarlet ed -L -s $JAVADOC_PLUGIN --type elem -n configuration pom.xml
xmlstarlet ed -L -s $JAVADOC_PLUGIN/_:configuration --type elem -n source -v 1.8 pom.xml
cd ..
}

# Prevent error: "gpg: signing failed: Inappropriate ioctl for device"
export GPG_TTY=$(tty)

## now, official releases are handled by a separate script

# now we release a beta version
git reset --hard # clean
git checkout master
quick_fix_pom


# adding a link to the commit
xmlstarlet edit -L --update '/_:project/_:description' --value `git rev-parse HEAD` pom.xml

CURRENT_VERSION=`xmlstarlet sel -t -v '/_:project/_:version' pom.xml`
CURRENT_VERSION_NO_SNAPSHOT=`echo $CURRENT_VERSION | sed -e 's/-SNAPSHOT//'`
echo CURRENT_VERSION_NO_SNAPSHOT $CURRENT_VERSION_NO_SNAPSHOT

# provides a default "1" is the last version if not a beta
LAST_BETA_NUMBER=`curl -L "http://search.maven.org/solrsearch/select?q=a:spoon-core+g:fr.inria.gforge.spoon&rows=40&wt=json&core=gav" | jq -r ".response.docs | map(.v) | map((match(\"$CURRENT_VERSION_NO_SNAPSHOT-beta-(.*)\") | .captures[0].string) // \"0\") | .[0]"`
echo LAST_BETA_NUMBER $LAST_BETA_NUMBER

NEW_BETA_NUMBER=$((LAST_BETA_NUMBER+1))
echo NEW_BETA_NUMBER $NEW_BETA_NUMBER

# we push a beta
PUSHED_VERSION=$CURRENT_VERSION_NO_SNAPSHOT-beta-$NEW_BETA_NUMBER
echo deploying $PUSHED_VERSION
xmlstarlet edit -L --update '/_:project/_:version' --value $PUSHED_VERSION pom.xml
mvn -q clean deploy -DskipTests -Prelease
