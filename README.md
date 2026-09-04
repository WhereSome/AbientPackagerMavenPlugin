# AbientPackagerMavenPlugin

用于 Spring Boot 后端项目自动化打包生成 Linux 离线部署包（包含 **RHEL 系** 与 **Debian 系** 两种系统架构分支）的 Maven 插件。

---

## 目录
- [一、核心特性与解决的痛点](#一核心特性与解决的痛点)
- [二、脚本目录结构与修改方式](#二脚本目录结构与修改方式)
- [三、插件打包与发布流程](#三插件打包与发布流程)
- [四、业务项目中使用插件的两种方法](#四业务项目中使用插件的两种方法)
  - [方法一：在业务项目 `pom.xml` 中配置（推荐，团队 0 配置）](#方法一在业务项目-pomxml-中配置推荐团队-0-配置)
  - [方法二：在本地 `settings.xml` 中全局配置（项目 POM 免写仓库）](#方法二在本地-settingsxml-中全局配置项目-pom-免写仓库)
- [五、部署包产物解压与运行说明](#五部署包产物解压与运行说明)
- [六、常见问题排查（国内镜像源配置）](#六常见问题排查国内镜像源配置)

---

## 一、核心特性与解决的痛点

1. **摆脱物理文件拷贝**：彻底取代以往在每个新项目根目录下拷贝 `abientLib` 文件夹的旧模式，脚本资源随插件统一版本化管理。
2. **零胶水配置**：在业务项目中替换原先复杂的 `maven-antrun-plugin`（解压）与 `maven-assembly-plugin`（组装）40+ 行 XML 配置，只需声明一个插件即可。
3. **跨平台权限修复**：在 Windows 开发机环境下打包 Zip 时，插件内置的 Archiver 会**自动为所有 `.sh` 脚本赋予 Linux `0755`（可执行）权限**，彻底消除部署到 Linux 后提示 `Permission denied` 的痛点。

---

## 二、脚本目录结构与修改方式

### 1. 脚本存储位置
所有内置运维脚本均位于本插件源码的：
[src/main/resources/scripts/](file:///E:/ProjectSpace/PersonProject/AbientPackagerMavenPlugin/src/main/resources/scripts)

```text
src/main/resources/scripts/
├── rhel/                           # RHEL 系操作系统专属脚本
│   ├── install.sh                  # 服务初始安装/引导交互脚本
│   ├── batch_jar_script_upgrade.sh # 批量更新运维脚本工具
│   └── scripts/                    # 运维子模块
│       ├── bin/                    # 环境初始化、JDK 选择、YAML 动态修改等
│       └── exec/                   # 启停注册、服务注销、回滚、systemd 守护脚本等
└── debian/                         # Debian / Ubuntu 系操作系统专属脚本
    ├── install.sh
    ├── batch_jar_script_upgrade.sh
    └── scripts/
        ├── bin/
        └── exec/
```

### 2. 脚本修改与维护步骤
当你需要调整启动参数、优化 Systemd 配置或适配新系统时：

1. **直接编辑明文文件**：在上述 `rhel/` 或 `debian/` 目录下用编辑器打开修改对应脚本（如 `install.sh`、`scripts/exec/conf/jar.service` 等）；
2. **换行符规范**：确保保存的脚本文件采用 **LF (Unix 换行符)**，避免在 Windows 下生成 CRLF 导致 Linux Shell 执行报 `\r: command not found`；
3. **权限无须担忧**：直接保存即可，无需在本地执行 `chmod`，插件打包时会自动扫描所有 `.sh` 文件并注入 Linux `0755` 权限。

---

## 三、插件打包与发布流程

### 流程 1：本地立即生效模式（开发与自测）
如果你只在当前开发机上测试修改后的脚本，无需推送到 GitHub：

在插件根目录下执行：
```powershell
mvn clean install
```
> **效果**：本地 Maven 仓库缓存（`~/.m2` 或本地指定仓库）中的插件立即更新。当前机器上的业务工程执行 `mvn clean package`，打包产物立即包含最新修改的脚本。

---

### 流程 2：打版本发布到 GitHub & JitPack（团队协同与线上同步）
当脚本测试完毕，准备同步给团队成员或部署环境使用：

1. **提交代码并打新版本标签**（例如发布 `v1.0.2`）：
   ```powershell
   git add .
   git commit -m "fix: 优化 systemd 启动脚本"
   git tag v1.0.2
   git push origin main --tags
   ```
2. **触发 JitPack 编译**（首次触发）：
   - 访问 [https://jitpack.io](https://jitpack.io)；
   - 输入 `WhereSome/AbientPackagerMavenPlugin` 点击 **Look up**；
   - 找到新打的 `v1.0.2` 标签，点击右侧 **Get it** 即可激活全球 CDN 构建。

---

## 四、业务项目中使用插件的两种方法

业务工程打包时，有两个地方可以声明 JitPack 插件仓库：

### 方法一：在业务项目 `pom.xml` 中配置（推荐，团队 0 配置）

> **适用场景**：团队协作、开源项目、CI/CD 自动化构建。
> **优势**：**自闭环**。项目代码提交后，任何同事或新机器拉下代码直接可用，同事电脑完全不需要修改本地 Maven 配置。

在业务工程的 `pom.xml` 中添加以下两处配置：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" ...>
    ...
    <!-- 1. 配置插件下载仓库（与 dependencies、build 标签同级并列） -->
    <pluginRepositories>
        <pluginRepository>
            <id>jitpack.io</id>
            <url>https://jitpack.io</url>
        </pluginRepository>
    </pluginRepositories>

    <build>
        <plugins>
            <!-- Spring Boot 打包插件保持不变 -->
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>

            <!-- 2. 引入自动化离线部署包插件 -->
            <plugin>
                <groupId>com.github.WhereSome</groupId>
                <artifactId>AbientPackagerMavenPlugin</artifactId>
                <version>v1.0.1</version>
                <executions>
                    <execution>
                        <goals>
                            <goal>package-dist</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
```

---

### 方法二：在本地 `settings.xml` 中全局配置（项目 POM 免写仓库）

> **适用场景**：个人开发环境，不想在每个后端项目的 `pom.xml` 中重复写 `<pluginRepositories>` 块。
> **优势**：所有业务工程的 `pom.xml` 极度精简，只写 `<plugin>` 即可。

1. **修改本地 Maven 全局配置文件**（`conf/settings.xml` 或 `~/.m2/settings.xml`）：
   在 `<profiles>` 节点中添加并激活 JitPack 插件源：

   ```xml
   <profiles>
       <profile>
           <id>jitpack-plugins</id>
           <pluginRepositories>
               <pluginRepository>
                   <id>jitpack.io</id>
                   <url>https://jitpack.io</url>
               </pluginRepository>
           </pluginRepositories>
       </profile>
   </profiles>

   <activeProfiles>
       <activeProfile>jitpack-plugins</activeProfile>
   </activeProfiles>
   ```

2. **业务项目 `pom.xml` 极简引入**：
   业务项目 `pom.xml` 中不再需要写 `<pluginRepositories>`，直接引入插件：

   ```xml
   <build>
       <plugins>
           <plugin>
               <groupId>com.github.WhereSome</groupId>
               <artifactId>AbientPackagerMavenPlugin</artifactId>
               <version>v1.0.1</version>
               <executions>
                   <execution>
                       <goals>
                           <goal>package-dist</goal>
                       </goals>
                   </execution>
               </executions>
           </plugin>
       </plugins>
   </build>
   ```

---

## 五、部署包产物解压与运行说明

在业务工程根目录运行：
```bash
mvn clean package
```
将在 `target/` 目录下同时产出两个不同 Linux 发行版的独立压缩包：
- `${project.build.finalName}-rhel-bin.zip`（适配 CentOS、RedHat、Rocky Linux、Anolis OS、EulerOS 等）
- `${project.build.finalName}-debian-bin.zip`（适配 Ubuntu、Debian、Deepin、UOS 等）

### 服务器部署与启动
将对应的 Zip 上传至目标服务器解压并执行即可：
```bash
# 1. 解压到部署目录
unzip HrLiteBackend-1.0.0-rhel-bin.zip -d /opt/deploy/HrLiteBackend/
cd /opt/deploy/HrLiteBackend/

# 2. 运行交互式安装脚本（根据提示输入服务名、端口号等）
bash install.sh
```

---

## 六、常见问题排查（国内镜像源配置）

如果执行打包时提示无法连接或下载插件失败，通常是因为本地 Maven `settings.xml` 配置了阿里云等国内镜像，并设置了 `<mirrorOf>*</mirrorOf>` 强行拦截了所有外部请求。

**解决方法**：在 `settings.xml` 中将阿里云镜像的 `<mirrorOf>` 改为排除 `jitpack.io`：
```xml
<mirror>
    <id>aliyunmaven</id>
    <!-- 关键：external:*,!jitpack.io 表示除 jitpack 外的外部仓库都走阿里云 -->
    <mirrorOf>external:*,!jitpack.io</mirrorOf>
    <name>阿里云公共仓库</name>
    <url>https://maven.aliyun.com/repository/public</url>
</mirror>
```
