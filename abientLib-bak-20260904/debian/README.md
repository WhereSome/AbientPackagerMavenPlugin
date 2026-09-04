# Ubuntu 构建脚本

在 CentOS 三套脚本基础上适配 Ubuntu 20.04 / 22.04 / 24.04（也可用于 Debian 11+）。

目录与 CentOS 版一一对应：

| 目录 / 包 | 用途 |
|-----------|------|
| `jdk/` 或 `jdk.tar.gz` | 安装 Zulu JDK 8 / 11 / 17 |
| `yq_install/` 或 `yq.tar.gz` | 安装 yq（改 YAML 用） |
| `script-jar-main/` 或 `script-jar-main.tar.gz` | JAR 部署、启停、更新、回滚 |

部署根目录仍是 `/gqtian/jarapps`，JDK 仍装到 `/usr/java/default`，与 CentOS 版保持一致。

## 推荐使用顺序

1. 把 `zulu*-ca-jdk*-linux_*.tar.gz` 放到 `jdk/software/`，执行 `bash main.sh`
2. 进入 `yq_install/`，执行 `sh main.sh`
3. 进入 `script-jar-main/`，把 jar/zip 放到当前目录，执行 `bash install.sh`

三个分发包统一为 `.tar.gz`，在服务器上解法相同：

```bash
tar -xvf jdk.tar.gz
tar -xvf yq.tar.gz
tar -xvf script-jar-main.tar.gz
```

## 相对 CentOS 改了什么

这些点在 Ubuntu 上会直接失败，所以做了对应替换：

1. **架构检测**：Ubuntu 内核名是 `5.15.0-xx-generic`，不能从 `uname -r` 末尾取 `x86_64`。改为 `uname -m`。
2. **系统判断**：批量升级不再认 `el7` / `an8` / `ky10` 这类内核后缀，改为读 `/etc/os-release`。
3. **包管理**：`yum` 改为 `apt-get`；缺 `rsync` / `unzip` / `ss` 时自动安装。
4. **Java 命令**：`alternatives` 改为 `update-alternatives`。
5. **systemd**：unit 写入 `/lib/systemd/system`（Debian/Ubuntu 惯例）。
6. **服务注销**：没有 `chkconfig`，SysV 回退用 `update-rc.d`。
7. **status.sh**：`systemctl status` 必须带 `--no-pager`，否则 Ubuntu 会卡在 less。
8. **配置文件换行**：Ubuntu 默认 `vi` 是 `vim.tiny`，不用 `++ff=unix`，改成 `sed` 去掉 CRLF。
9. **JDK 查找**：除 `/usr/java` 外，还会尝试 `/usr/lib/jvm`。

未改业务逻辑：安装目录、root 运行、交互菜单、yml 改配置、更新/回滚流程都与 CentOS 版相同。

## 压缩包

在本目录执行打包后，可与 CentOS 目录一样只拷三个包到服务器：

- `jdk.tar.gz`
- `yq.tar.gz`
- `script-jar-main.tar.gz`
