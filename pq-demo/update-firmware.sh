#!/usr/bin/env bash

PQ_VERIFIER_JAR=PQ-Verifier/target/PostQuantum-Verifier-jar-with-dependencies.jar

FIRMWARE_FILE=firmware
FIRMWARE_SIG=firmware.p7s

INSTALLED_FIRMWARE="installed-firmware"
FAILED_FIRMWARE="failed-firmware"

# trust dir containing trusted CA (ca.pem) for "legacy"
# signature and self-signed SPHINCS+ cert from PQ-enabled
# signer
TRUST_DIR=trust
# Trusted CA for non-PQ algo (typically use the DSSRootCA10 demo CA)
CA_FILE=$TRUST_DIR/ca.pem

# create firmware directories (if needed)
mkdir -p $INSTALLED_FIRMWARE
mkdir -p $FAILED_FIRMWARE

echo "Press [CTRL+C] to stop"

function verifyOpenSSL() {
  echo "Verifying with openssl"
  openssl smime -verify -in $FIRMWARE_SIG -inform DER -content $FIRMWARE_FILE -CAfile $CA_FILE
}

function verifyPQ() {
  echo "Verifying with PQ verifier tool"
  java -jar $PQ_VERIFIER_JAR cms $FIRMWARE_SIG $FIRMWARE_FILE $TRUST_DIR
}

function asn1Dump() {
  echo "Signature content"
  dumpasn1 $FIRMWARE_SIG
}

function installFirmware() {
  local FILE=${INSTALLED_FIRMWARE}/${FIRMWARE_FILE}
  if [ -f "$FILE" ]; then
    echo "Existing firmware version: " $(cat $FILE)
    echo "Expecting PQ (SPINCS+) signature for new firmware"

    # verifiy subsequent update with the PQ verifier
    verifyPQ
  else
    echo "Installing initial firmware"
    echo "Expecting legacy (non-PQ) signature"

    # verify initial version with openssl (assume non-PQ)
    verifyOpenSSL
  fi

  if [ $? -eq 0 ]; then
    echo "Successfully verified firmware, installing"

    asn1Dump

    mv $FIRMWARE_FILE $INSTALLED_FIRMWARE
    mv $FIRMWARE_SIG $INSTALLED_FIRMWARE

    echo "Successfully installed new firmware"
  else
    echo "Firmware did not verify"
    local s=$(date +%s)

    echo "Copying failed firmware and signature to \"failed-firmware\" with timestamp" $s

    mv $FIRMWARE_FILE $FAILED_FIRMWARE/${FIRMWARE_FILE}-failed-$s
    mv $FIRMWARE_SIG $FAILED_FIRMWARE/${FIRMWARE_FILE}-failed-$s.p7s
    
  fi

}

function waitForFirmware() {
   while true
   do
     echo "Waiting for new firmware"
     while true
     do
       echo -n "."
       sleep 1
       if [[ -f "$FIRMWARE_FILE" && -f "$FIRMWARE_SIG" ]]; then
         echo
  	  echo "Found new firmware version: " $(cat $FIRMWARE_FILE)
  	 # wait some time to make sure signature has been written
  	 echo "Trying to verify new firmware"
  	 sleep 10
  	 installFirmware
  	 break
       fi
     done
     echo
   done
}

waitForFirmware
