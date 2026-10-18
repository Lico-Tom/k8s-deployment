# openapi-generator-python（Helm 部署项目）

用 Helm 把 **openapi-generator 生成的 Python（FastAPI）服务** 部署到 Kubernetes 集群。

被部署的对象就是 `D:\code\k8s-deployment` 那个项目：`python-fastapi` 生成器产出的 FastAPI 应用，
容器端口 `8080`、健康检查路径 `/healthz`、源码是 src 布局（`PYTHONPATH=/app/src`）。
本目录只负责**部署形态**，不包含任何业务代码。

---

## 1. 目录结构

```
openapi-generator-python/          ← chart 根目录（= Helm 的 chart 包）
├── Chart.yaml                     # ★ 必需：chart 元信息（名称、版本、依赖、kubeVersion）
├── values.yaml                    # ★ 必需：默认配置，被 -f / --set 覆盖
├── Chart.lock                     # ○ 可选：dependency update 生成的依赖锁（可不提交）
├── .helmignore                    # ○ 推荐：打包时排除的文件清单
│
├── templates/                     # ★ 必需：K8s 资源模板目录（Go template 语法）
│   ├── _helpers.tpl               #   命名/标签助手（下划线开头，不渲染成资源）
│   ├── NOTES.txt                  #   install/upgrade 后打印的使用提示
│   ├── deployment.yaml            #   主工作负载
│   ├── service.yaml               #   ClusterIP 服务
│   ├── serviceaccount.yaml        #   SA（可关闭）
│   ├── ingress.yaml               #   外部入口，补 /api/v1 前缀
│   ├── hpa.yaml                   #   HPA（autoscaling/v2，带 behavior 调优）
│   ├── pdb.yaml                   #   PodDisruptionBudget
│   ├── configmap.yaml             #   环境变量（非敏感）
│   ├── secret.yaml                #   敏感配置（生产改为引用外部 Secret）
│   ├── pvc.yaml                   #   持久化卷声明（默认关闭）
│   ├── servicemonitor.yaml        #   Prometheus Operator 采集规则（默认关闭）
│   ├── networkpolicy.yaml         #   网络策略（默认关闭）
│   ├── job-migrate.yaml           #   初始化/迁移 Job（post-install,post-upgrade 钩子）
│   └── tests/
│       └── test-connection.yaml   #   helm test 冒烟测试（Pod 直连 /healthz）
│
├── charts/                        # ★ 子 chart 目录（内容可空，目录必须存在）
│   └── .gitkeep                   #   占位；注意打包时顶层文件会被丢弃
├── crds/                          # ○ CRD 目录（Helm 规范目录，有特殊加载规则）
│   └── .gitkeep                   #   占位
│
├── environments/                  # ✚ 本项目自建（Helm 不认识）：按环境拆分的 values
│   ├── values-dev.yaml
│   ├── values-staging.yaml
│   └── values-prod.yaml
├── scripts/                       # ✚ 本项目自建：部署/渲染/卸载脚本（sh + ps1）
│   ├── template.sh / template.ps1
│   ├── deploy.sh / deploy.ps1
│   ├── uninstall.sh / uninstall.ps1
│   ├── test-release.sh
│   ├── package.sh
│   └── lint.sh
├── Makefile                       # ✚ 本项目自建：make lint/template/deploy/...
├── .gitignore
└── README.md
```

图例：★ Helm 要求必需　○ Helm 规范目录/文件，可选　✚ 项目自建，Helm 不感知

---

## 2. Helm 要求的目录逐个说明

| 目录 / 文件 | 必需性 | Helm 怎么处理它 | 本项目现状 |
|---|---|---|---|
| **`templates/`** | ★ **必需** | 唯一会被渲染成 K8s 资源的目录。缺失时 `helm lint/install` 直接报错 | 14 个资源模板 + 1 个测试 |
| `templates/tests/` | ○ 推荐 | 带 `helm.sh/hook: test` 注解的资源，`helm test <release>` 时执行 | 一个 curl 冒烟 Pod |
| `templates/NOTES.txt` | ○ 推荐 | 不是资源，`install/upgrade/status` 后渲染并打印给用户 | 已提供访问方式提示 |
| `templates/_helpers.tpl` | ○ 惯例 | 以下划线 `_` 开头的文件**不会被渲染成资源**，只供 `include` 引用 | 命名、标签、镜像、各类派生名 |
| **`charts/`** | ★ **必需存在** | 子 chart 解压目录。`helm dependency update` 把依赖下载到这里；`helm package` 把这里的 `.tgz` 一起打进父包 | 空目录 + `.gitkeep` 占位 |
| **`crds/`** | ○ 规范目录 | 与 `templates/` 完全不同的加载规则（见下方说明） | 空目录 + `.gitkeep` 占位 |
| **`Chart.yaml`** | ★ **必需** | chart 身份文件，缺了整个 chart 无法加载 | `apiVersion: v2`、`type: application`、声明 `kubeVersion: >=1.24.0-0` |
| **`values.yaml`** | ★ **必需** | 默认配置；可被 `-f`、`--set` 覆盖，子 chart 的 values 用同名键覆盖 | 全量默认值，含中文注释 |
| `Chart.lock` | ○ 可选 | `helm dependency update` 生成，锁定子 chart 版本 | 未生成（无子 chart 依赖） |
| `.helmignore` | ○ 推荐 | 打包时排除文件。语法**不等于** `.gitignore` | 已排除 scripts/、environments/、密钥等 |
| `environments/` `scripts/` `Makefile` | ✚ 非规范 | Helm 完全不感知，纯工程约定 | 本项目自建，已加入 `.helmignore` 不进包 |

### templates/ 的三条硬规则

1. **只渲染扩展名为 `.yaml` `.yml` `.tpl` `.txt` 的文件**，其他一律忽略。
2. **以 `_` 或 `.` 开头的文件不产出资源**（`_helpers.tpl`、`.foo.yaml` 都被跳过），
   这是放助手模板的标准位置。
3. 目录名不是固定的，随便建子目录（如 `templates/tests/`），Helm 会递归扫描。

### charts/ 的两条硬规则

1. **目录必须存在**，哪怕为空——删掉后 `helm dependency update` 会失败。
2. 只有 `charts/` 下的**子目录**（各自带 `Chart.yaml`）会被识别为子 chart；
   **直接放在 `charts/` 顶层的零散文件在打包时被丢弃**——这也是为什么占位文件只在仓库里有用，
   打包后的 `.tgz` 里看不到 `charts/.gitkeep`（实测确认）。

### crds/ 的四条硬规则

1. 安装时机**最早**：在 `templates/` 渲染之前就写进集群。
2. **不做模板渲染**：文件里的 `{{ }}` 不会被解析（需要模板能力请放 `templates/` 并加
   `helm.sh/resource-policy: keep`）。
3. **不参与 release 生命周期**：`helm uninstall` 不会删除 CRD，也不会随 `--atomic` 回滚。
4. 卸载后**依然存在**，是 Helm 有意为之（防止误删导致自定义资源数据丢失）。

---

## 3. 快速开始

```bash
# 0) 前置：helm 3.x / 4.x + kubectl 已能访问目标集群
helm version
kubectl cluster-info

# 1) 静态检查（四套 values 全部跑一遍）
make lint

# 2) 本地渲染，不连集群即可看到最终清单
make template ENV=prod                 # 或 ./scripts/template.sh prod
helm template api . -f environments/values-prod.yaml

# 3) 部署（lint → upgrade --install --atomic，失败自动回滚）
make deploy ENV=prod NAMESPACE=prod
# 等价于
./scripts/deploy.sh prod prod api

# 4) 冒烟测试 + 查看状态
make test ENV=prod
make status ENV=prod
```

生产环境密钥不要写进 values，用外部 Secret：

```bash
kubectl create secret generic openapi-generator-python-secret \
  -n prod --from-literal=API_TOKEN='xxx'
# values-prod.yaml 里已经是 secret.create=false + existingName
```

---

## 4. 三套环境的差异

| 配置项 | dev | staging | prod |
|---|---|---|---|
| 副本数 | 1 | 2 | 3（HPA 3~12） |
| 镜像 tag | `dev` | `rc` | `0.1.0`（钉死版本） |
| 拉取策略 | Always | Always | IfNotPresent |
| 日志级别 | DEBUG | INFO | WARNING |
| CPU / 内存 | 50m~300m / 96~256Mi | 100m~500m / 128~512Mi | 250m~1 / 256Mi~1Gi |
| Ingress | api.dev…（无 TLS） | api.staging…（无 TLS） | api.example.com + cert-manager |
| HPA | 关 | 开（2~4） | 开（3~12，CPU 65% / 内存 80%） |
| PDB | 关 | minAvailable=1 | minAvailable=2 |
| Secret | chart 内建（dev-token） | chart 内建 | **外部 Secret**（create=false） |
| NetworkPolicy | 关 | 关 | 开 |
| ServiceMonitor | 关 | 开（30s） | 开（15s） |
| 拓扑打散 | 无 | 无 | 跨可用区 + 跨节点 |
| priorityClassName | 默认 | 默认 | `system-cluster-critical` |

---

## 5. 常用命令

| 目的 | Git Bash | PowerShell / CMD |
|---|---|---|
| 渲染检查 | `./scripts/template.sh prod` | `.\scripts\template.ps1 -Env prod` |
| 部署/升级 | `./scripts/deploy.sh prod prod api` | `.\scripts\deploy.ps1 -Env prod -Namespace prod` |
| 干跑（只看不装） | `helm install api . --dry-run -f environments/values-prod.yaml` | 同左 |
| 冒烟测试 | `./scripts/test-release.sh prod` | `helm test api -n prod --logs` |
| 发布历史 | `helm history api -n prod` | 同左 |
| 回滚 | `helm rollback api -n prod` | 同左 |
| 卸载 | `./scripts/uninstall.sh prod` | `.\scripts\uninstall.ps1 -Env prod` |
| 拉依赖 + 打包 | `./scripts/package.sh` | `helm dependency update . && helm package . -d dist` |

---

## 6. 已经踩过并处理掉的坑（改动前务必读）

### 坑 1（最坑）：`.helmignore` 里写 `!` 取反，会让整个 chart 加载失败

报错信息是 **`Chart.yaml file is missing`**，跟真实原因毫无关系，排查成本极高。

```gitignore
*.md
!templates/NOTES.txt     # ← 就这一行会导致 chart 加载失败
```

实测（helm 3.19.0 与 4.3.1 表现一致）：只要 `.helmignore` 里存在**任意一行**以 `!` 开头的规则，
`helm lint / template / install / package` 全部失败。`!README.md`、`!templates/NOTES.txt`
单独一行都足以触发。**Helm 的 ignore 实现不支持 `.gitignore` 的取反语法**，也别指望靠
"排除全部再取反个别"来精确控制。

本项目已删除全部 `!` 规则，并把这条警告写进了 `.helmignore` 文件头。

### 坑 2：HPA 与 `replicaCount` 打架

HPA 接管后会持续改写 `spec.replicas`，若模板仍然渲染 `replicas`，
下次 `helm upgrade` 就会把副本数"打回" values 里的静态值，出现扩容后又被缩回去的怪现象。
→ 本项目的 `deployment.yaml` 只在 `autoscaling.enabled=false` 时输出 `replicas`。

### 坑 3：`readOnlyRootFilesystem: true` 下 Python 起不来

只读根文件系统时 Python 需要可写 `/tmp`（字节码缓存、临时文件）。
→ Deployment 默认挂载了一个 `sizeLimit: 64Mi` 的 `emptyDir` 到 `/tmp`。

### 坑 4：改了 ConfigMap/Secret 但 Pod 没重启

K8s 不会因 ConfigMap 变化自动滚动重启。
→ Pod 模板上加了 `checksum/config`、`checksum/secret` 注解，内容一变就触发滚动更新。
副作用是每次改配置都会重启，属于刻意取舍。

### 坑 5：`image.tag` 留空会回落到 `Chart.AppVersion`

方便是方便，但会导致"改 chart 版本顺带换了镜像"这种误升级。
→ `values-prod.yaml` 显式钉了 `0.1.0`，生产**不要留空**。

### 坑 6：Ingress 的路径前缀

openapi 里 `servers.url = http://localhost:8080/api/v1`，但生成器**不会**把 `/api/v1`
写进路由（模板不消费 server url 的 path）。前缀统一在 Ingress 层补：
path 用 `/api/v1(/|$)(.*)`，配合 `nginx.ingress.kubernetes.io/rewrite-target: /$2`，
把 `/api/v1/xxx` 还原成 `/xxx` 转发给后端。

### 坑 7：`crds/` 的内容卸载后仍在

`helm uninstall` 不删 CRD；`helm rollback` 也不回滚 CRD。
需要删除必须手动 `kubectl delete crd <name>`——**这一步会连带删掉所有自定义资源，务必确认**。

### 坑 8：钩子 Job 会阻塞发布

`job-migrate.yaml` 带 `post-install,post-upgrade` 钩子，配 `--atomic --wait` 时，
Job 失败 = 整个 release 回滚。
→ 生产已设 `backoffLimit: 5`、`activeDeadlineSeconds: 900`；不需要初始化步骤时把
`migrationJob.enabled` 置为 `false`。

### 坑 9：打包时 `charts/` 顶层文件被丢弃

占位用的 `charts/.gitkeep` 不会出现在 `.tgz` 里（Helm 只认 `charts/` 下的子目录子 chart）。
占位符对仓库有意义，对包体没有意义，属正常现象。

---

## 7. 校验状态

| 项目 | 结果 |
|---|---|
| `helm lint`（helm **3.19.0**）| 默认 + dev/staging/prod 四套 values 全绿 |
| `helm lint`（helm **4.3.1**）| 同样四套全绿，chart 可跨大版本使用 |
| `helm template`（dev / prod）| 渲染成功，prod 产出 10 类资源 |
| `helm package` | 打包成功，包内仅含 chart 规范内容（脚本/环境配置已排除） |

prod 渲染出的资源：`NetworkPolicy`、`PodDisruptionBudget`、`ServiceAccount`、`ConfigMap`、
`Service`、`Deployment`、`HorizontalPodAutoscaler`、`Ingress`、`ServiceMonitor`、
测试 Pod、迁移 Job。

> 注：本机 helm 装在 `C:\Users\HUAWEI\.workbuddy\binaries\helm\`（3.19.0 与 4.3.1 各一份），
> 不在 PATH 里；脚本支持用 `HELM_BIN=/path/to/helm` 指定。

---

## 8. 与上游项目的衔接

```
D:\code\k8s-deployment      # 业务代码：openapi.yaml → python-fastapi → FastAPI 源码 + Dockerfile
        │  构建镜像 openapi-generator-python:<tag>
        ▼
D:\code\openapi-generator-python   # 本目录：只描述这个镜像怎么在 K8s 上跑
```

镜像里的关键约定（改镜像时这里要同步）：

| 项 | 值 | 来源 |
|---|---|---|
| 容器端口 | `8080` | openapi 的 `servers.url` |
| 健康检查 | `/healthz` | spec 中的 health 接口 |
| 模块路径 | `/app/src` | openapi-generator 的 src 布局，需设 `PYTHONPATH` |
| 入口命令 | `uvicorn openapi_server.app:app` | `app.py` 里注册了统一错误响应 handler |
