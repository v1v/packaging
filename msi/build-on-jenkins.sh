#!/bin/bash -ex
# this script runs on the release machine to submit the actual msi build to a Windows machine

bin=$(dirname $0)
encodedv=$($bin/encode-version.rb $VERSION)

D=/tmp/$$   # temporary directory
mkdir -p $D

# replace variables in the wxs file
eval "cat > $D/jenkins.wxs <<EOF
$(<$bin/jenkins.wxs)
EOF
" 2> /dev/null

cp "${PKCS12_FILE}" $D/key.pkcs12
cp "${PKCS12_PASSWORD_FILE}" $D/key.password

tar cvzf $D/bundle.tgz \
  -C $bin FindJava.java build.sh jenkins.exe.config \
  -C $D jenkins.wxs key.pkcs12 key.password

# we may not be able to control the location of the identity file and ssh does not support agent auth
# so allow it to be optionally specified
CLI_SSH_ARGS=
if [ "x$JENKINS_SSH_KEY" != x ]; then
  CLI_SSH_ARGS="-i $JENKINS_SSH_KEY"
fi
if [ "x$JENKINS_SSH_USER" != x ]; then
  CLI_SSH_ARGS="$CLI_SSH_ARGS -ssh -user $JENKINS_SSH_USER"
fi

# TODO switch to non-Remoting-based variant once JENKINS-49205 is released
case "$(uname)" in
  CYGWIN*)
    tar cfz - `cygpath --dos $D/bundle.tgz` | java -jar $TARGET/jenkins-cli.jar $CLI_SSH_ARGS dist-fork -z= -Z= -f ${ARTIFACTNAME}.war="${WAR}" -l "windows && packaging" -F "${MSI}.tmp=${ARTIFACTNAME}-windows.zip" \
          bash -ex "tar xfz - && build.sh ${ARTIFACTNAME}.war $encodedv ${ARTIFACTNAME} \"${PRODUCTNAME}\" ${PORT} ${CAMELARTIFACTNAME} && tar cfz - ${ARTIFACTNAME}-windows.zip" | tar xfz - ;;
  *)
    tar cfz - $D/bundle.tgz | java -jar $TARGET/jenkins-cli.jar $CLI_SSH_ARGS dist-fork -z= -Z= -f ${ARTIFACTNAME}.war="${WAR}" -l "windows && packaging" -F "${MSI}.tmp=${ARTIFACTNAME}-windows.zip" \
          bash -ex "tar xfz - && build.sh ${ARTIFACTNAME}.war $encodedv ${ARTIFACTNAME} \"${PRODUCTNAME}\" ${PORT} ${CAMELARTIFACTNAME} && tar cfz - ${ARTIFACTNAME}-windows.zip" | tar xfz - ;;
esac

mv ${MSI}.tmp ${MSI}
touch ${MSI}
rm -rf $D
