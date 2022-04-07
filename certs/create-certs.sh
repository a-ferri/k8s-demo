#!/bin/bash

KEY_FILE="self.key"
CERT_FILE="cert.pem"
CERT_NAME="ingress-tls"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${KEY_FILE} -out ${CERT_FILE} -subj "/CN=*.${ING_ADDR}/O=${ING_ADDR}"

kubectl create secret tls ${CERT_NAME} --key ${KEY_FILE} --cert ${CERT_FILE}
