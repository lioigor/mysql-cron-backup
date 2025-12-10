FROM mysql:8.4

RUN microdnf install -y \
    tzdata \
    bash \
    gzip \
    openssl \
    cronie \
    tar && \
    microdnf clean all

ARG DOCKERIZE_VERSION=v0.7.0
RUN curl -sSL https://github.com/jwilder/dockerize/releases/download/${DOCKERIZE_VERSION}/dockerize-linux-amd64-${DOCKERIZE_VERSION}.tar.gz \
    | tar -xz -C /usr/local/bin

ENV CRON_TIME="0 3 * * sun" \
    MYSQL_HOST="mysql" \
    MYSQL_PORT="3306" \
    TIMEOUT="10s" \
    MYSQLDUMP_OPTS="--quick"

COPY ["run.sh", "backup.sh", "restore.sh", "delete.sh", "/"]

RUN mkdir /backup && \
    chmod 777 /backup && \
    chmod 755 /run.sh /backup.sh /restore.sh /delete.sh && \
    touch /mysql_backup.log && \
    chmod 666 /mysql_backup.log

VOLUME ["/backup"]

HEALTHCHECK --interval=2s --retries=1800 \
    CMD stat /HEALTHY.status || exit 1

CMD dockerize -wait tcp://${MYSQL_HOST}:${MYSQL_PORT} -timeout ${TIMEOUT} /run.sh