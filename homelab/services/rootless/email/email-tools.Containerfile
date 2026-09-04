FROM docker.io/library/alpine:3.22

RUN apk add --no-cache ca-certificates cyrus-sasl-login isync postfix \
	&& addgroup -g 1000 mbsync \
	&& adduser -D -H -u 1000 -G mbsync mbsync \
	&& cp -a /var/spool/postfix /var/spool/postfix.default

COPY postfix-entrypoint.sh /usr/local/bin/postfix-entrypoint
RUN chmod 0755 /usr/local/bin/postfix-entrypoint
