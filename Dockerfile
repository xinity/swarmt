FROM alpine:latest

LABEL maintainer Rachid Zarouali (xinity77@gmail.com)

RUN apk add --no-cache bash

COPY swarmt.sh /usr/local/bin/

ENTRYPOINT ["swarmt/swarmt.sh"]
