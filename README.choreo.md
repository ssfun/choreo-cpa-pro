# CLIProxyAPI - Choreo 部署说明

基于 [router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 官方镜像的 **Choreo Web Application** 适配层。  

- 组件类型：**Web Application**（Dockerfile）
- 单公网端口 **`8317`**
- `USER 10014`
- 可写路径仅 **`/tmp`**（`MANAGEMENT_STATIC_PATH` / `PGSTORE_LOCAL_PATH` 等）
- 业务凭证：**外部 Postgres**（`PGSTORE_DSN`）
- 内嵌 **komari-agent**（`KOMARI_SERVER` + `KOMARI_SECRET` 均非空时启动）
- 管理页：`/management.html`（`MANAGEMENT_PASSWORD`）

上游当前锁定版本见 [README.md](./README.md)（`# Version`）。

---

## 架构

```text
客户端 / 管理浏览器
  └─ https://cpa.example.com  （或 *.choreoapps.dev）
        └─ Choreo Web Application :8317
              ├─ /CLIProxyAPI/CLIProxyAPI
              ├─ /tmp/*                 （本地缓存 / 管理静态资源；非持久）
              ├─ 外部 Postgres          （凭证与配置真源，PGSTORE_DSN）
              └─ /app/komari-agent      （可选；上报到你的 Komari 面板）
```

---

## 仓库结构

```text
choreo-cpa/
├── Dockerfile
├── entrypoint.sh
├── .trivyignore
├── .github/workflows/
│   └── update-version.yml
├── README.md
└── README.choreo.md
```

---

## 1. 创建 Choreo Web Application

| 项 | 值 |
|---|---|
| Component type | **Web Application** |
| Build preset | **Dockerfile** |
| Dockerfile Path | `/Dockerfile` |
| Component Directory | `/` |
| Port | **`8317`** |

连接本仓库后 Build → Deploy。

文档：

- [Deploy a containerized application](https://wso2.com/engineering-platform/developer-platform/docs/develop-components/deploy-a-containerized-application/)
- [Build and deploy a web application](https://wso2.com/engineering-platform/developer-platform/docs/develop-components/develop-web-applications/build-and-deploy-a-single-page-web-application/)

---

## 2. 环境变量

### 2.1 必配（生产）

| 变量 | 示例 / 说明 | 类型 |
|---|---|---|
| `MANAGEMENT_PASSWORD` | 管理 WebUI 密码 | **Secret** |
| `PGSTORE_DSN` | `postgres://USER:PASSWORD@HOST:5432/DBNAME?sslmode=require` | **Secret** |

镜像已默认：

| 变量 | 默认 | 说明 |
|---|---|---|
| `MANAGEMENT_STATIC_PATH` | `/tmp` | 管理页静态资源（只读根 FS 必备） |
| `PGSTORE_LOCAL_PATH` | `/tmp` | Postgres 本地缓存目录 |
| `HOME` | `/tmp` | 默认 auth-dir `~/.cli-proxy-api` → `/tmp/.cli-proxy-api` |
| `TZ` | `Asia/Shanghai` | |

生成密码示例：

```bash
openssl rand -base64 24   # MANAGEMENT_PASSWORD
```

### 2.2 外部 Postgres

```bash
PGSTORE_DSN=postgres://cpa_user:pass@host:5432/cpa?sslmode=require
# 可选
# PGSTORE_SCHEMA=public
# PGSTORE_LOCAL_PATH=/tmp
```

| 来源 | 说明 |
|---|---|
| Neon / Supabase / Railway / 自建 | 注入完整 DSN；公网或经可达网络连到 Choreo 出站 |
| 其它兼容 Postgres | 同样只注入 `PGSTORE_DSN` |

**库侧建议：**

- 单独库 + 最小权限用户
- 强制 SSL（`sslmode=require`）
- 用托管侧自动备份 / 快照
- 确认 Choreo 数据平面出站能连到该主机端口

> **不要**只把凭证放在 `/tmp`：云数据平面无持久盘，重启会丢。

### 2.3 其它远程存储（可选，二选一替代 PG）

官方还支持 Object Store / Git；本地缓存路径镜像默认指 `/tmp`。

| 方案 | 变量 |
|---|---|
| Object Store（R2/S3） | `OBJECTSTORE_ENDPOINT` / `OBJECTSTORE_BUCKET` / `OBJECTSTORE_ACCESS_KEY` / `OBJECTSTORE_SECRET_KEY`（`OBJECTSTORE_LOCAL_PATH` 默认 `/tmp`） |
| Git | `GITSTORE_GIT_URL` / `GITSTORE_GIT_USERNAME` / `GITSTORE_GIT_TOKEN`（`GITSTORE_LOCAL_PATH` 默认 `/tmp`） |

生产优先 **Postgres**。

### 2.4 Komari Agent

镜像内已包含 `/app/komari-agent`（构建时从 `ghcr.io/komari-monitor/komari-agent:latest` 复制）。

| 变量 | 说明 | 类型 |
|---|---|---|
| `KOMARI_SERVER` | Agent 入口 `-e`，如 `https://komari.example.com`（**不要**写 `wss://`） | Config |
| `KOMARI_SECRET` | Agent token `-t` | **Secret** |

二者都非空时启动：

```bash
/app/komari-agent -e "$KOMARI_SERVER" -t "$KOMARI_SECRET" --disable-auto-update
```

未配置时日志打印 `[Komari] Not configured...`，不影响 CPA。

---

## 3. 部署步骤

1. 准备 **外部 Postgres**，拿到带 SSL 的 `PGSTORE_DSN`。
2. 确认 Choreo 出站可访问该库（防火墙 / 白名单 / 公网）。
3. （推荐）在 Komari 面板拿到 agent 的 `-e` 基址与 token。
4. 推送本仓库到 GitHub，在 Choreo 创建 **Web Application**（见第 1 节）。
5. 在 Deploy / DevOps 页配置 Configs & Secrets（第 2 / 4 节）。
6. **Build Latest** → 处理 Trivy（升级或 `.trivyignore`）→ Deploy。
7. 打开 `https://<component-url>/management.html`，用 `MANAGEMENT_PASSWORD` 登录。
8. 在管理界面配置上游凭证 / API Key / 客户端 `api-keys`。
9. （可选）绑定自定义域名；Cloudflare 橙云时回源 SSL 常用 **Full**。

---

## 4. 最小 Secret 清单（复制用）

```bash
# 管理
MANAGEMENT_PASSWORD=...

# 外部 Postgres（凭证真源）
PGSTORE_DSN=postgres://user:pass@host:5432/cpa?sslmode=require

# 以下镜像已默认，一般无需再配
# MANAGEMENT_STATIC_PATH=/tmp
# PGSTORE_LOCAL_PATH=/tmp

# Komari Agent（监控本容器；不配则跳过）
# KOMARI_SERVER=https://komari.example.com
# KOMARI_SECRET=...
```

---

## 5. 验证

```bash
# 管理页
curl -sS -o /dev/null -w "%{http_code}\n" "https://cpa.example.com/management.html"

# 根路径
curl -sS -o /dev/null -w "%{http_code}\n" "https://cpa.example.com/"
```

启动日志中应看到类似：

```text
[Init] Preparing /tmp paths...
[Store] PGSTORE_DSN set shape=...
[CPA] Starting CLIProxyAPI on :8317...
```

浏览器：打开 `/management.html` → 登录 → 配置上游后，用客户端 Base URL 指向该 HTTPS 地址做一次模型调用。

---

## 6. 镜像与构建说明

| 项 | 说明 |
|---|---|
| 上游镜像 | `eceasy/cli-proxy-api:v7.2.96`（与 README Version 同步） |
| 二进制 | `/CLIProxyAPI/CLIProxyAPI` |
| 用户 | `10014`（Choreo 强制 10000–20000） |
| 可写 | `/tmp`（管理静态、PG 缓存、默认 auth-dir） |
| Komari Agent | 从 `ghcr.io/komari-monitor/komari-agent:latest` 复制 |

Trivy **CRITICAL** 会导致 Choreo 构建失败：

1. 先依赖 Dockerfile 内 `apt-get upgrade`
2. 定期重建镜像吃安全补丁
3. 短期无法修复时把 CVE 写入 `.trivyignore`（每行一个）

---

## 7. 限制与注意

| 点 | 说明 |
|---|---|
| Web Application 单端口 | 只暴露 8317；官方 compose 里的本机 OAuth 多端口不映射 |
| `/tmp` 非持久 | 凭证真源必须在 Postgres（或 Object/Git store） |
| 请求体约 256KB（云数据平面 Web App） | 超大 base64 附件可能失败 |
| 请求总时长默认约 1 分钟、最长约 5 分钟 | 超长流式可能被网关切断 |
| 管理面公网可达 | 务必设强 `MANAGEMENT_PASSWORD` |
| Scale-to-zero | 冷启动可接受则可开；状态在 Postgres |
| Postgres 网络 | Choreo 需能出站连你的库；部分托管库要加 IP 白名单 |

---

## 8. 故障速查

| 现象 | 处理 |
|---|---|
| 构建 USER 校验失败 | 确认 Dockerfile 末尾 `USER 10014` |
| Trivy CRITICAL | 升级基础包 / 换更新上游 tag / `.trivyignore` |
| 启动后无 store | 检查是否注入 `PGSTORE_DSN`；日志应有 `[Store] PGSTORE_DSN set` |
| 管理页打不开 / 登录失败 | 确认 `MANAGEMENT_PASSWORD`；路径 `/management.html`；`MANAGEMENT_STATIC_PATH=/tmp` |
| 重启后凭证丢失 | 未配远程 store 或 DSN 无效；不要依赖 `/tmp` |
| Postgres 连不上 | DSN、SSL（`sslmode=require`）、白名单、出站端口 |
| Komari 面板无节点 | `KOMARI_SERVER` 与 `KOMARI_SECRET` **都**已设置；`-e` 用 `https://`，不要 `wss://` |
| 日志无 `[Komari] Starting agent...` | 变量为空；看是否打印 `Not configured...` |

---

## 9. 与同目录其它项目对照

| | openlist | deeix | **cpa** |
|---|---|---|---|
| 类型 | Web Application | Web Application | Web Application |
| 端口 | 5244 | 8080 | **8317** |
| 状态 | 外部 MySQL | Postgres + R2 | **Postgres（PGSTORE_DSN）** |
| Komari | 有 | 有 | **有** |
| 管理 UI | 应用自带 | 应用自带 | **`/management.html`** |

---

## 10. 上游与版本同步

- 上游仓库：https://github.com/router-for-me/CLIProxyAPI
- 官方镜像：`eceasy/cli-proxy-api`
- 文档：https://help.router-for.me/
- HF / 数据库云部署：https://help.router-for.me/cn/hands-on/tutorial-8.html

### GitHub Actions

工作流：`.github/workflows/update-version.yml`

| 项 | 说明 |
|---|---|
| 触发 | 每天 UTC 00:00；也可手动 `workflow_dispatch` |
| 检查 | `router-for-me/CLIProxyAPI` 最新 GitHub Release tag |
| 写入 | `README.md` 的 `# Version` / `# Releases`；`Dockerfile` 的 `ARG CPA_TAG=` |
| 提交 | `docs: update to vX.Y.Z` 并 push |
| 通知 | 可选：仓库 Secrets `TELEGRAM_TOKEN` + `TELEGRAM_TO` |
| 清理 | 保留最近约 7 天 / 至少 6 次 workflow run |

### 手动 bump

改两处：

1. `Dockerfile`：`ARG CPA_TAG=vX.Y.Z`
2. `README.md`：`# Version` 与 `# Releases`
