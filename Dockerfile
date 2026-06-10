FROM sfun/cliproxyapi-pro:latest

RUN apk add --no-cache ca-certificates proxychains-ng

ENV TZ=Asia/Shanghai
ENV USAGE_DATA_DIR=/tmp/CLIProxyAPI/usage
ENV USAGE_DB_PATH=/tmp/CLIProxyAPI/usage/usage.sqlite
ENV MANAGEMENT_STATIC_PATH=/tmp
ENV PGSTORE_LOCAL_PATH=/tmp

USER 10014
