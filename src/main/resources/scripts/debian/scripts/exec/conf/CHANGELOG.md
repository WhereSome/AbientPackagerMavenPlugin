# Changelog

## 版本号请按照规范x.x.x书写

2026-03-31 Version: 1.3.0

  1. Ubuntu/Debian 适配：uname -m 取架构、apt-get 补依赖、/lib/systemd/system、update-rc.d、systemctl --no-pager、vim.tiny 不去用 ++ff

2025-07-03 Version: 1.2.9

  1. 增加OPTS参数启用SIMD加速,修改jdk判断逻辑

2025-06-26 Version: 1.2.8

  1. 优化zip包更新逻辑

2025-02-20 Version: 1.2.7

  1. 优化升级脚本的时候models目录覆盖问题，优化服务更新完后输出running或其他状态的时候增加颜色且只显示状态前后6行

2025-02-10 Version: 1.2.6

  1. 修改脚本中升级服务的时候升级脚本cp为强制覆盖脚本内容，避免文件存在覆盖失败的问题

2025-02-08 Version: 1.2.5

  1. 解决配置文件覆盖的bug

2025-02-07 Version: 1.2.4

  1. 调整脚本rsync相关配置目录与文件的同步逻辑，优化脚本自动升级失败项目回滚逻辑(是脚本升级，非jar项目更新)

2025-01-20 Version: 1.2.3

  1. 调整脚本安装与更新的时候同步db、docker、doc等目录

2024-12-25 Version: 1.2.2

  1. 修改service文件中的LimitNOFILE与LimitNPROC限制至26384

2024-10-17 Version: 1.2.1

  1. 当shell取值context-path:为空时，使用yq取到的默认name赋值失败，修改脚本无法获取默认name异常。

2024-09-13 Version: 1.2.0

  1. 新增prod文件.linkcld.orm.system-code与.linkcld.security.authn-mode的交互输入
  
2024-09-12 Version: 1.1.9

  1. 更改脚本更新逻辑，修改out文件输出方式与存储逻辑

2024-08-29 Version: 1.1.8

  1. 更改附属目录(docker、doc等目录)拷贝方式，更改快捷启动实现方式

2024-08-26 Version: 1.1.7

  1. 脚本结构变更
  2. 增加脚本升级脚本(单服务升级与服务批量升级)

2024-06-26 Version: 1.1.6

  1. 删除无用脚本，增加env文件提高变量复用率

2024-03-26 Version: 1.1.5

  1. 增加功能 数据库交互,sso交互,orm交互

2023-06-14 Version: 1.1.4

  1. 修改jar服务启动，修改判断方式

2021-03-01 Version: 1.1.3

  1. 修复部署脚本版本持续更新向下兼容问题

2021-02-26 Version: 1.1.2

  1. 增加版本回退功能

2020-12-30 Version: 1.1.1

  1. 修改-XX:+HeapDumpPath为具体文件，避免OOM产生的hprof文件占用太多空间

2020-12-25 Version: 1.1.0

  1. 增加-XX:+HeapDumpOnOutOfMemoryError参数，发生OOM时存储堆内存信息到jar项目/logs目录/xxx.hporf文件

2020-11-24 Version: 1.0.9

  1. 当bootapp用户非新建时不再修改资源限制配置

2020-11-23 Version: 1.0.8

  1. 修复deploy对exec和bak目录无权限的问题

2020-11-19 Version: 1.0.7

  1. 修复config/application.yml文件windows换行符导致的bug

2020-11-18 Version: 1.0.6

  1. 修复/linkcld目录是软链接时管理脚本报错的bug

2020-11-09 Version: 1.0.5

  1. 为了兼容旧的Jenkins配置，增加了exec目录中的update.sh脚本

2020-11-06 Version: 1.0.4

  1. 修改jar部署脚本，修改端口被占用的逻辑。修改jar更新脚本，增加jar包前缀判断。

2020-11-03 Version: 1.0.3

  1. 修改jar更新脚本，增加更新zip包

2020-11-02 Version: 1.0.2

  1. 修改项目根目录的启动和重启服务脚本，增加修改权限的命令

2020-10-12 Version: 1.0.1

  1. deploy用户可以不存在，此时服务管理文件的属主是bootapp

2019-07-30

  1. 优化jmx的jmxremote.rmi.port端口和jmxremote.port端口一致
  2. jmxremote.rmi.port端口以前是随机的，不方便配置防火墙放行

2019-03-29

  1. The first public version
  2. 如果没有deploy用户，可以在脚本执行过程中添加，用于管理jar服务(启动，停止，重启，查看状态)
  3. /linkcld/jarapps是jar部署的规范目录，如果该目录不存在，部署时会自动创建
  4. 新部署或已存在项目，启动jar程序的用户为bootapp，增加服务文件，设置服务开机自启动
  5. jar项目根目录/exec/update.sh可以用于后期更新该jar项目

2022-08-12

  1. 将脚本的java_opts和启动方式配置分离到daemon.sh文件
  2. systemctl启动时直接服务调用该daemon文件，方便对服务的配置进行修改，不用对service文件daemon-reload

2022-10-10

  1. 修改脚本兼容主流linux版本分支服务器3.10.0-123内核及以上系统安装或更新jar项目、不支持系统小于3.10.0-123版本的内核
  2. 在service文件中添加LimitNOFILE等参数，systemctl管理的服务使用的是systemctl默认的Limit，故需要单独设置，与/etc/security/limits.conf区分开来
