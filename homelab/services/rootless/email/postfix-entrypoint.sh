#!/bin/sh
set -eu

if [ ! -d /var/spool/postfix/maildrop ]; then
	cp -a /var/spool/postfix.default/. /var/spool/postfix/
fi

postconf -e 'compatibility_level = 3.6'
postconf -e 'myhostname = email.local'
postconf -e 'inet_interfaces = all'
postconf -e 'inet_protocols = ipv4'
postconf -e 'mynetworks = 127.0.0.0/8, 10.0.2.0/24, 169.254.0.0/16'
postconf -e 'smtpd_relay_restrictions = permit_mynetworks, reject'
postconf -e 'smtpd_sender_restrictions = check_sender_access lmdb:/etc/postfix/allowed_senders, reject'
postconf -e 'relayhost = [smtp.gmail.com]:587'
postconf -e 'sender_dependent_relayhost_maps = lmdb:/etc/postfix/sender_relay'
postconf -e 'smtp_sender_dependent_authentication = yes'
postconf -e 'smtp_sasl_auth_enable = yes'
postconf -e 'smtp_sasl_password_maps = lmdb:/etc/postfix/sasl_passwd'
postconf -e 'smtp_sasl_security_options = noanonymous'
postconf -e 'smtp_sasl_tls_security_options = noanonymous'
postconf -e 'smtp_sasl_mechanism_filter = plain, login'
postconf -e 'smtp_tls_security_level = encrypt'
postconf -e 'smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt'
postconf -e 'maillog_file = /dev/stdout'

cat > /etc/postfix/sender_relay <<'EOF'
ebrahimhagh2004@gmail.com [smtp.gmail.com]:587
hireme@ebra.dev [smtp.gmail.com]:587
me@ebra.dev [smtp.gmail.com]:587
sayhi@ebra.dev [smtp.gmail.com]:587
qa7355608@gmail.com [smtp.gmail.com]:587
auth@ebra.dev [smtp.gmail.com]:587
vaultwarden@ebra.dev [smtp.gmail.com]:587
ebrahimhagh2004@icloud.com [smtp.mail.me.com]:587
EOF

cat > /etc/postfix/allowed_senders <<'EOF'
ebrahimhagh2004@gmail.com OK
hireme@ebra.dev OK
me@ebra.dev OK
sayhi@ebra.dev OK
qa7355608@gmail.com OK
auth@ebra.dev OK
vaultwarden@ebra.dev OK
ebrahimhagh2004@icloud.com OK
EOF

umask 077
{
	printf '%s %s:%s\n' 'ebrahimhagh2004@gmail.com' 'ebrahimhagh2004@gmail.com' "$GMAIL_MAIN_APP_PASSWORD"
	printf '%s %s:%s\n' 'hireme@ebra.dev' 'ebrahimhagh2004@gmail.com' "$GMAIL_MAIN_APP_PASSWORD"
	printf '%s %s:%s\n' 'me@ebra.dev' 'ebrahimhagh2004@gmail.com' "$GMAIL_MAIN_APP_PASSWORD"
	printf '%s %s:%s\n' 'sayhi@ebra.dev' 'ebrahimhagh2004@gmail.com' "$GMAIL_MAIN_APP_PASSWORD"
	printf '%s %s:%s\n' 'qa7355608@gmail.com' 'qa7355608@gmail.com' "$GMAIL_QA_APP_PASSWORD"
	printf '%s %s:%s\n' 'auth@ebra.dev' 'qa7355608@gmail.com' "$GMAIL_QA_APP_PASSWORD"
	printf '%s %s:%s\n' 'vaultwarden@ebra.dev' 'qa7355608@gmail.com' "$GMAIL_QA_APP_PASSWORD"
	printf '%s %s:%s\n' 'ebrahimhagh2004@icloud.com' 'ebrahimhagh2004@icloud.com' "$ICLOUD_APP_PASSWORD"
	printf '%s %s:%s\n' '[smtp.gmail.com]:587' 'ebrahimhagh2004@gmail.com' "$GMAIL_MAIN_APP_PASSWORD"
	printf '%s %s:%s\n' '[smtp.mail.me.com]:587' 'ebrahimhagh2004@icloud.com' "$ICLOUD_APP_PASSWORD"
} > /etc/postfix/sasl_passwd

postmap lmdb:/etc/postfix/sender_relay
postmap lmdb:/etc/postfix/allowed_senders
postmap lmdb:/etc/postfix/sasl_passwd
postfix check

exec postfix start-fg
