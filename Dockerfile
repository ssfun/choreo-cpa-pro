# ==========================================
# CLIProxyAPI - Choreo Web Application 适配
# 基于官方镜像：单端口 8317 + Postgres 凭证存储 + /tmp 可写
# ==========================================
# 版本锁定见 README.md # Version
ARG CPA_TAG=v7.2.96
FROM eceasy/cli-proxy-api:${CPA_TAG}

USER root

# 系统层升级，降低 Trivy CRITICAL 失败率
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        tzdata \
        curl \
    && rm -rf /var/lib/apt/lists/*

# 内嵌 komari-agent（可选）
COPY --from=ghcr.io/komari-monitor/komari-agent:latest /app/komari-agent /app/komari-agent
COPY entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh /app/komari-agent \
    && chown 10014:10014 /app/entrypoint.sh /app/komari-agent \
    && chown -R 10014:10014 /CLIProxyAPI

WORKDIR /CLIProxyAPI

# --- Choreo 默认运行时约定（均可被环境变量覆盖）---
# 只读根目录：管理静态资源与 PG 本地缓存必须落 /tmp
ENV TZ=Asia/Shanghai \
    HOME=/tmp \
    XDG_CONFIG_HOME=/tmp/.config \
    XDG_DATA_HOME=/tmp/.local/share \
    MANAGEMENT_STATIC_PATH=/tmp \
    PGSTORE_LOCAL_PATH=/tmp \
    GITSTORE_LOCAL_PATH=/tmp \
    OBJECTSTORE_LOCAL_PATH=/tmp

# Choreo 要求 numeric USER 10000-20000
USER 10014

EXPOSE 8317

ENTRYPOINT ["/app/entrypoint.sh"]
