#! /bin/bash

build_opendkim_keys()
{
  domain=$1

  pushd /etc/opendkim/keys
  mkdir ${domain}
  cd ${domain}
  opendkim-genkey -s mail -d ${domain}
  chown opendkim:opendkim mail.private
  # Add the public key to the domain's DNS records
  # public key 位于 mail.txt
  #
  # Name: mail._domainkey.example.com.
  # Text: "v=DKIM1; k=rsa; p=您的公钥"
  popd
}

if [ "X${MAIL_DOMAIN}" == "X" ]; then
  echo "need MAIL_DOMAIN"
  exit 1
fi

build_opendkim_keys ${MAIL_DOMAIN}
