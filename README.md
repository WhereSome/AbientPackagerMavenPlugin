# AbientPackagerMavenPlugin

用于 Spring Boot 后端项目自动化打包生成 Linux 离线部署包（包含 RHEL 与 Debian 两种架构分支）的 Maven 插件。

## 特性

- **自动装配部署脚本**：自动注入经生产验证的 RHEL/Debian 启停、运维管理与环境初始化脚本体系。
- **跨平台权限修复**：在 Windows 构建环境下自动为所有 `.sh` Shell 脚本赋予 Linux `0755`（可执行）权限，避免部署到 Linux 后提示 `Permission denied`。
- **零胶水配置**：彻底替代 `maven-antrun-plugin` + `maven-assembly-plugin` 繁琐配置，各后端工程仅需声明一行插件即可。

## 使用方法

### 1. 添加 JitPack 插件仓库
在业务项目的 `pom.xml` 中添加：

```xml
<pluginRepositories>
    <pluginRepository>
        <id>jitpack.io</id>
        <url>https://jitpack.io</url>
    </pluginRepository>
</pluginRepositories>
```

### 2. 引入插件
在业务项目的 `<build><plugins>` 中引入：

```xml
<plugin>
    <groupId>com.github.WhereSome</groupId>
    <artifactId>AbientPackagerMavenPlugin</artifactId>
    <version>v1.0.0</version>
    <executions>
        <execution>
            <goals>
                <goal>package-dist</goal>
            </goals>
        </execution>
    </executions>
</plugin>
```

### 3. 打包生成
```bash
mvn clean package
```
将在 `target/` 目录下产出：
- `${project.build.finalName}-rhel-bin.zip`
- `${project.build.finalName}-debian-bin.zip`
