FROM alpine:3.15

RUN apk add --no-cache mysql-client python3 py3-pip \
    && pip install awscli

ADD run.sh /run.sh

VOLUME ["/data"]
CMD ["sh", "/run.sh"]
