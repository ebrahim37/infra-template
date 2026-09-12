FROM docker.io/library/alpine:latest

RUN apk add --no-cache ca-certificates cyrus-sasl-login goimapnotify isync postfix python3 \
	&& addgroup -g 1000 mbsync \
	&& adduser -D -H -u 1000 -G mbsync mbsync \
	&& cp -a /var/spool/postfix /var/spool/postfix.default

COPY mail-notifier.py /usr/local/bin/mail-notifier
COPY postfix-entrypoint.sh /usr/local/bin/postfix-entrypoint
COPY mbsync-entrypoint.sh /usr/local/bin/mbsync-entrypoint
RUN chmod 0755 /usr/local/bin/mail-notifier /usr/local/bin/postfix-entrypoint /usr/local/bin/mbsync-entrypoint
