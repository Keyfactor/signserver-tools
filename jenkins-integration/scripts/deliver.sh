#!/bin/bash -x

echo 'The following complex command extracts the value of the <name/> element'
echo 'within <project/> of your Java/Maven project''s "pom.xml" file.'
set -x
NAME=`mvn help:evaluate -Dexpression=project.name | grep "^[^\[]"`
set +x

echo 'The following complex command behaves similarly to the previous one but'
echo 'extracts the value of the <version/> element within <project/> instead.'

set -x
VERSION=`mvn help:evaluate -Dexpression=project.version | grep "^[^\[]"`
set +x

# Use options "-keystore $keystore -keystorepwd $password -keyalias jenkins" (matching the alias in your p12 credentials) to use client certificate authentication with signclient
# the values is then configured as Credentials in Jenkins admin and delivered to this script from the Jenkinsfile, i.e. not hard coded anywhere
EATER="$(jenkins/scripts/signserver/bin/signclient signdocument -host ec2-13-48-31-155.eu-north-1.compute.amazonaws.com -port 443 -workername JArchiveCMSSigner -infile "target/${NAME}-${VERSION}.jar" -outfile "target/${NAME}-${VERSION}-signed.jar" -truststore jenkins/scripts/ManagementCA.cacert.jks -truststorepwd "changeit" -clientside -digestalgorithm SHA-256 -keystore $keystore -keystorepwd $password -keyalias jenkins)"
RETVAL=$?
if [ $RETVAL -eq 0 ]; then
	echo $EATER
	echo 'JAR signed successfully.'
else
	echo $EATER
	echo 'JAR signing failed.'
	exit 1
fi

EATER2="$(jarsigner -verify -strict -verbose -keystore jenkins/scripts/ManagementCA.cacert.jks -storepass changeit target/${NAME}-${VERSION}-signed.jar)"

RETVAL=$?
if [ $RETVAL -eq 0 ]; then
	echo $EATER2
	echo 'JAR signing verified.'
	echo 'Rename signed JAR.'
	mv -f "target/${NAME}-${VERSION}-signed.jar" "target/${NAME}-${VERSION}.jar"
	
else
	echo $EATER2
	echo 'JAR signing verification failed.'
	exit 1
fi


echo 'The following Maven command installs your Maven-built Java application'
echo 'into the local Maven repository, which will ultimately be stored in'
echo 'Jenkins''s local Maven repository (and the "maven-repository" Docker data'
echo 'volume).'
set -x
mvn jar:jar install:install help:evaluate -Dexpression=project.name
set +x



echo 'The following command runs and outputs the execution of your Java'
echo 'application (which Jenkins built using Maven) to the Jenkins UI.'
set -x
java -jar target/${NAME}-${VERSION}.jar


