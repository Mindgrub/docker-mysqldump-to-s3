FROM alpine:3.18

RUN apk add --no-cache mysql-client python3 py3-pip coreutils jq \
    && pip install awscli

ADD run.sh /run.sh

VOLUME ["/data"]
CMD ["sh", "/run.sh"]
