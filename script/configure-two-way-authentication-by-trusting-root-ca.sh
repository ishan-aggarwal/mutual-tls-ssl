#!/usr/bin/env bash

cleanUpExistingCertificatesAndKeystores() {
    echo 'Cleaning up existing certificates and keystores'

    rm -fv client/src/test/resources/client.cer
    rm -fv client/src/test/resources/client.csr
    rm -fv client/src/test/resources/client.p12
    rm -fv client/src/test/resources/client-private.key
    rm -fv client/src/test/resources/client-signed.cer
    rm -fv client/src/test/resources/client-signed.p12
    rm -fv client/src/test/resources/identity.jks
    rm -fv client/src/test/resources/truststore.jks
    rm -fv root-ca/root-ca.key
    rm -fv root-ca/root-ca.p12
    rm -fv root-ca/root-ca.pem
    rm -fv root-ca/root-ca.srl
    rm -fv server/src/main/resources/identity.jks
    rm -fv server/src/main/resources/server.cer
    rm -fv server/src/main/resources/server.csr
    rm -fv server/src/main/resources/server.p12
    rm -fv server/src/main/resources/server-private.key
    rm -fv server/src/main/resources/server-signed.cer
    rm -fv server/src/main/resources/server-signed.p12
    rm -fv server/src/main/resources/truststore.jks

    rm -fv root-ca/*

    echo 'Finished cleanup'
}

createCertificates() {
    echo 'Starting to create certificates...'

    keytool -genkeypair -keyalg RSA -keysize 2048 -alias server -dname "CN=Hakan,OU=Amsterdam,O=Thunderberry,C=NL" -ext "SAN:c=DNS:localhost,IP:127.0.0.1" -validity 3650 -keystore server/src/main/resources/identity.jks -storepass secret -keypass secret -deststoretype pkcs12
    keytool -genkeypair -keyalg RSA -keysize 2048 -alias client -dname "CN=$1,OU=Altindag,O=Altindag,C=NL" -validity 3650 -keystore client/src/test/resources/identity.jks -storepass secret -keypass secret -deststoretype pkcs12
    keytool -exportcert -keystore client/src/test/resources/identity.jks -storepass secret -alias client -rfc -file client/src/test/resources/client.cer
    keytool -exportcert -keystore server/src/main/resources/identity.jks -storepass secret -alias server -rfc -file server/src/main/resources/server.cer
    keytool -certreq -keystore server/src/main/resources/identity.jks -alias server -keypass secret -storepass secret -keyalg rsa -file server/src/main/resources/server.csr
    keytool -certreq -keystore client/src/test/resources/identity.jks -alias client -keypass secret -storepass secret -keyalg rsa -file client/src/test/resources/client.csr
    keytool -genkeypair -keyalg RSA -keysize 2048 -alias root-ca -dname "CN=Root-CA,OU=Certificate Authority,O=Thunderberry,C=NL" -validity 3650 -ext bc:c -keystore root-ca/identity.jks -storepass secret -keypass secret -deststoretype pkcs12
    keytool -importkeystore -srckeystore root-ca/identity.jks -destkeystore root-ca/root-ca.p12 -srcstoretype jks -deststoretype pkcs12 -srcstorepass secret -deststorepass secret
    openssl pkcs12 -in root-ca/root-ca.p12 -out root-ca/root-ca.pem -nokeys -passin pass:secret -passout pass:secret
    openssl pkcs12 -in root-ca/root-ca.p12 -out root-ca/root-ca.key -nocerts -passin pass:secret -passout pass:secret
    openssl x509 -req -in client/src/test/resources/client.csr -CA root-ca/root-ca.pem -CAkey root-ca/root-ca.key -CAcreateserial -out client/src/test/resources/client-signed.cer -days 1825 -passin pass:secret
    openssl x509 -req -in server/src/main/resources/server.csr -CA root-ca/root-ca.pem -CAkey root-ca/root-ca.key -CAcreateserial -out server/src/main/resources/server-signed.cer -sha256 -extfile server/src/main/resources/extensions/v3.ext -days 1825  -passin pass:secret
    keytool -importkeystore -srckeystore client/src/test/resources/identity.jks -destkeystore client/src/test/resources/client.p12 -srcstoretype jks -deststoretype pkcs12 -srcstorepass secret -deststorepass secret
    openssl pkcs12 -in client/src/test/resources/client.p12 -nodes -out client/src/test/resources/client-private.key -nocerts -passin pass:secret
    openssl pkcs12 -export -in client/src/test/resources/client-signed.cer -inkey client/src/test/resources/client-private.key -out client/src/test/resources/client-signed.p12 -name client -passout pass:secret
    keytool -delete -alias client -keystore client/src/test/resources/identity.jks -storepass secret
    keytool -importkeystore -srckeystore client/src/test/resources/client-signed.p12 -srcstoretype PKCS12 -destkeystore client/src/test/resources/identity.jks -srcstorepass secret -deststorepass secret
    keytool -importkeystore -srckeystore server/src/main/resources/identity.jks -destkeystore server/src/main/resources/server.p12 -srcstoretype jks -deststoretype pkcs12 -srcstorepass secret -deststorepass secret
    openssl pkcs12 -in server/src/main/resources/server.p12 -nodes -out server/src/main/resources/server-private.key -nocerts -passin pass:secret
    openssl pkcs12 -export -in server/src/main/resources/server-signed.cer -inkey server/src/main/resources/server-private.key -out server/src/main/resources/server-signed.p12 -name server -passout pass:secret
    keytool -delete -alias server -keystore server/src/main/resources/identity.jks -storepass secret
    keytool -importkeystore -srckeystore server/src/main/resources/server-signed.p12 -srcstoretype PKCS12 -destkeystore server/src/main/resources/identity.jks -srcstorepass secret -deststorepass secret
    keytool -keystore client/src/test/resources/truststore.jks -importcert -file root-ca/root-ca.pem -alias root-ca -storepass secret -noprompt
    keytool -keystore server/src/main/resources/truststore.jks -importcert -file root-ca/root-ca.pem -alias root-ca -storepass secret -noprompt
}

configureApplicationProperties() {
    echo
    echo 'Configuring application properties of the server'
    rm server/src/main/resources/application.yml
    echo -e 'spring:\n  banner:\n    location: classpath:banner.txt\n\nserver:\n  port: 8443\n  ssl:\n    enabled: true\n    key-store: classpath:identity.jks\n    key-password: secret\n    key-store-password: secret\n    trust-store: classpath:truststore.jks\n    trust-store-password: secret\n    client-auth: need'  >> server/src/main/resources/application.yml

    echo 'Configuring application properties of the client'
    rm client/src/test/resources/application.yml
    echo -e 'spring:\n  main:\n    banner-mode: "off"\n    web-application-type: none\n\nlogging:\n  level:\n    nl.altindag.sslcontext: INFO\n\nclient:\n  ssl:\n    one-way-authentication-enabled: false\n    two-way-authentication-enabled: true\n    key-store: identity.jks\n    key-store-password: secret\n    trust-store: truststore.jks\n    trust-store-password: secret'  >> client/src/test/resources/application.yml
}

#Validate if provided argument is present
if [[ -z "$1" ]]; then
    echo "No common name is provided to create the Client Certificate"
else
    cleanUpExistingCertificatesAndKeystores
    createCertificates "$1"
    configureApplicationProperties
fi

