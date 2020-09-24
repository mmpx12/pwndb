FROM alpine:latest
COPY pwndb.sh /usr/bin/pwndb
RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing pup curl bash coreutils
RUN chmod +x /usr/bin/pwndb && \
    ln -s /bin/bash /usr/bin/bash && \
    mkdir /app
WORKDIR /app
ENTRYPOINT ["/usr/bin/pwndb"]

