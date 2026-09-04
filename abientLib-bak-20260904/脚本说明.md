# abientLib 部署与环境脚本说明

`abientLib` 提供了工程在 Linux 服务器环境下的离线依赖环境安装、打包构建以及应用运维全生命周期脚本体系。为避免针对具体发行版命名导致混乱，脚本按 **Linux 两大系统来源** 进行归类划分：

- **RHEL 系 (`abientLib/rhel/`)**：适用于 CentOS、RedHat Enterprise Linux、Rocky Linux、AlmaLinux、Anolis OS (龙蜥)、EulerOS (欧拉)、Kylin OS (银河麒麟) 等基于 RPM/YUM 包管理器的操作系统。
- **Debian 系 (`abientLib/debian/`)**：适用于 Ubuntu 20.04 / 22.04 / 24.04、Debian 11 / 12、Deepin、统信 UOS (Debian 底座) 等基于 DPKG/APT 包管理器的操作系统。

---

## 一、目录结构与资产说明

```text
abientLib/
├── 脚本说明.md                       # 本说明文档
├── build-tool/                       # 构建通用工具备份
├── rhel/                             # RHEL 系专属资源
│   ├── assembly-rhel.xml             # Maven Assembly 打包描述符（产出 *-rhel-bin.zip）
│   ├── jdk.tar.gz                    # JDK 自动化安装包
│   ├── yq.tar.gz                     # YAML 命令行解析工具离线安装包
│   └── script-jar-main.zip           # Spring Boot JAR 服务管理与运维脚本包
└── debian/                           # Debian 系专属资源
    ├── README.md                     # Debian 系适配细节说明
    ├── assembly-debian.xml           # Maven Assembly 打包描述符（产出 *-debian-bin.zip）
    ├── jdk.tar.gz                    # JDK 自动化安装包（Debian 适配版）
    ├── yq.tar.gz                     # YAML 命令行解析工具离线安装包（Debian 适配版）
    └── script-jar-main.zip           # Spring Boot JAR 服务管理与运维脚本包（Debian 适配版）
```

---

## 二、两套脚本差异与底层适配对比

为了确保同一套运维规范在不同发行版上表现一致，Debian 系在保持与 RHEL 系操作界面完全统一的前提下，底层做了以下精准适配：

| 适配维度 | RHEL 系 (`rhel/`) | Debian 系 (`debian/`) | 适配原因 |
| :--- | :--- | :--- | :--- |
| **CPU 架构识别** | `uname -r` 末尾提取 | `uname -m` 直接读取 | Ubuntu/Debian 内核格式为 `5.15.0-xx-generic`，尾部不带架构名 |
| **系统版本检测** | 匹配 `el7`/`el8`/`an8`/`ky10` | 读取 `/etc/os-release` 的 `ID`/`VERSION_ID` | Debian 系无 RedHat 风格内核命名 |
| **底层包管理器** | `yum` / `dnf` | `apt-get` | 缺失 `rsync`、`unzip`、`ss` (iproute2) 时自动补装 |
| **JDK 注册命令** | `alternatives` | `update-alternatives` | 软链接与命令管理工具命名不同 |
| **Systemd Unit 路径** | `/usr/lib/systemd/system/` | `/lib/systemd/system/` | 遵循各自发行版的标准文件系统布局 |
| **服务注销回退** | `chkconfig --del` | `update-rc.d -f remove` | SysVinit 兼容命令不同 |
| **状态查看输出** | `systemctl status <service>` | `systemctl status <service> --no-pager` | 避免 Debian/Ubuntu 默认进入 `less` 分页导致脚本卡死 |
| **配置文件换行符** | `vi` 配合 `++ff=unix` | `sed -i 's/\r$//'` | Ubuntu 默认 `vi` 简版 (`vim.tiny`) 不支持 `++ff` 参数 |

---

## 三、部署使用全流程（实操指南）

服务器初始部署或维护时，推荐遵循 **JDK 安装 ➡️ yq 工具安装 ➡️ 应用服务安装** 的顺序执行。

### 1. JDK 离线自动化安装 (`jdk.tar.gz`)

用于在服务器上自动化部署 Zulu JDK（支持 JDK 8 / 11 / 17 / 21），统一建立软链接至 `/usr/java/default` 并配置系统环境变量。

1. **解压安装包**：
   ```bash
   tar -zxvf jdk.tar.gz
   cd jdk/
   ```
2. **放置 JDK 源码包**：
   - 将对应平台的 JDK 安装包（如 `zulu21.38.21-ca-jdk21.0.5-linux_x64.tar.gz`）放置到 `software/` 目录下。
3. **执行安装**：
   ```bash
   bash main.sh
   ```
   脚本将自动检测架构、解压至 `/usr/java/`、配置 `update-alternatives`/`alternatives` 并写入 `/etc/profile`。

---

### 2. yq 工具离线安装 (`yq.tar.gz`)

用于在 Shell 中快速解析和修改 `application.yml` 配置文件。

1. **解压安装包**：
   ```bash
   tar -zxvf yq.tar.gz
   cd yq_install/
   ```
2. **执行安装**：
   ```bash
   bash main.sh
   ```
   脚本会自动根据机器架构（x86_64 / aarch64）将对应的 `yq` 可执行二进制部署至 `/usr/local/bin/yq` 或 `/usr/bin/yq`。

---

### 3. 应用服务部署与日常运维 (`script-jar-main.zip` / 产物安装包)

#### (1) 服务初始安装
在业务模块通过 Maven 打包后（如 `commonModel-1.0.0-rhel-bin.zip` 或 `commonModel-1.0.0-debian-bin.zip`），解压后根目录即包含完整部署体系：

```bash
unzip <artifact>-<version>-<os>-bin.zip -d /opt/deploy/<app_name>/
cd /opt/deploy/<app_name>/
bash install.sh
```
- **交互流程**：
  - 自动检测系统环境（端口占用、JDK 路径、内存规格）。
  - 提示输入服务名称、运行端口、JVM 堆内存（默认自适应）、激活环境（`active profile`）。
  - 自动通过 `yq` 修改 `config/application.yml`。
  - 将应用规范化部署到根目录 `/gqtian/jarapps/<service_name>/`。
  - 自动注册 systemd 服务并设置开机自启。

#### (2) 日常启停与状态管理
服务注册后，直接使用标准 systemd 运维或使用内置脚本：
```bash
# 标准 systemd 控制
systemctl start <service_name>
systemctl stop <service_name>
systemctl restart <service_name>
systemctl status <service_name>

# 或者使用安装目录下的快捷脚本
cd /gqtian/jarapps/<service_name>/
./bin/daemon.sh start | stop | restart | status
```

#### (3) 在线升级与更新
当业务有新版本发布时，进入已部署的服务目录：
```bash
cd /gqtian/jarapps/<service_name>/scripts/exec/
# 1. 增量更新单个 JAR
bash update_jar.sh /path/to/new-app.jar

# 2. 完整包升级更新（保留原自定义配置）
bash update_zip.sh /path/to/new-app-bin.zip
```
- 升级过程会自动备份当前版本至 `backup/` 历史归档目录。

#### (4) 快速故障回滚
如果新发布的版本存在问题需要紧急回退：
```bash
cd /gqtian/jarapps/<service_name>/scripts/exec/
bash rollback.sh
```
- 脚本会列出 `backup/` 下的历史版本快照，选择对应版本序号即可实现秒级无缝回滚并重启。

---

## 四、Maven 构建与二次开发规范

### 1. 产物生成机制
各个子模块执行 `mvn clean package` 时，`maven-antrun-plugin` 与 `maven-assembly-plugin` 协同工作：
1. 自动从 `abientLib/{os}/script-jar-main.zip` 解压出对应系统的部署脚本到 `target/os-{os}/`。
2. 按照 `abientLib/{os}/assembly-{os}.xml` 规则，将可执行 Jar、配置文件、运维脚本打包为独立的分发包：
   - `{artifact}-{version}-rhel-bin.zip`
   - `{artifact}-{version}-debian-bin.zip`

### 2. 部署脚本二次开发修改指南
如果需要对部署脚本逻辑（如 `install.sh`、`daemon.sh`、JVM 默认参数等）进行调整：
1. 解压对应目录下的 `script-jar-main.zip`。
2. 修改相关的 `.sh` / 配置文件并完成本地测试。
3. 重新打包为 `script-jar-main.zip` 并替换：
   ```bash
   # 以 rhel 为例：在修改后的 script-jar-main 目录同级执行
   zip -r script-jar-main.zip script-jar-main/
   ```
4. 执行 Maven 打包时将自动携带最新脚本生效。
