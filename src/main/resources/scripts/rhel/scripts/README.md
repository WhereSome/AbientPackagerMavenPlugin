# 使用说明

一、场景: 支持主流linux版本分支服务器3.10.0-123内核及以上系统安装或更新jar项目、不支持系统小于3.10.0-123版本的内核  

- 1、推荐系统: anolis8以上、uos-v20-1020x以上、kylin10、centos7以上
- 2、内核查看: uname -r
- 3、/linkcld/jarapps目录如果不存在, 部署时会自动创建
- 4、如果更新jar文件, 请在执行脚本之前停止jar服务, 否则执行脚本会报错端口被占用

二、功能:

- 1、新部署jar项目  : 按照规范部署jar项目, 启动进程的用户为bootapp, 增加启动服务文件, 设置开机自启动;
- 2、已存在的jar项目: 更改启动进程的用户为bootapp, 增加启动服务文件, 设置开机自启动;

三、注意事项:

- 注意1: 操作用户的身份: root或者sudo用户; 如果deploy用户已存在--请确保是sudo用户, 否则无法启动服务; 如果没有deploy用户, 请先执行系统初始化脚本
- 注意2: 服务器已安装jdk(脚本中默认读取/usr/java/default  若default不存在则读取/usr/java/jdk*, 如果没有, 则需要交互式手动输入JAVA_HOME路径)
- 注意3: 项目类型:
  - 1、新部署项目:
       如果交互式输入了jar_service_port: 则会自动拼接: 服务名=$APP_NAME-$jar_service_port
       如果没有交互式输入jar_service_port: 服务名=jar项目目录名=$APP_NAME
  - 2、已使用脚本卸载但项目目录存在的项目; 服务名=jar项目目录名
- 注意4: jar包类型分为:
  - 1、jar包可以直接启动服务, 比如运行./demo.jar即可直接启动服务
  - 2、jar包需要借助java -jar demo.jar ......启动服务
- 注意5: jar项目部署完成后, 不要修改jar项目目录/exec/下内容结构, 否则以后脚本版本更新失败

四、脚本使用方法:

- 注意1: 新部署jar时, jar包可以直接放在脚本目录jar-linux中,交互式输入: jar_file_path(zip|tar|jar)=  直接输入jar包名字即可
- 注意2: 新部署jar时, 交互式输入APP_NAME不要包含服务的端口号(如果交互式输入了jar_service_port, 则会自动拼接: 服务名=$APP_NAME-$jar_service_port)
- 1、bash install.sh
- 2、根据项目类型选择部署方式, 并配置合适的参数

五、jar服务管理: jar服务名参考"三、注意事项"中的"注意3"

- 1、cd到jar项目目录中
- 2、./startup.sh  启动
  - ./shutdown.sh 关闭
  - ./restart.sh  重启
  - ./status.sh   查看是否在运行

六、jar服务启动失败, 调试方法

- 1、应用场景: 主要用于jar服务无法启动时, 以调试模式启动服务并输出日志, 有助于排查错误
- 2、调试步骤:
  - 2.1、./debug_startup.sh    //以调试模式启动服务, 并输出日志到./logs/app_name.out
  - 2.2、查看./logs/app_name.out  //在输出的日志文件中, 查看报错
  - 2.3、./debug_shutdown.sh   //调试之后, 请关闭服务的debug进程, 以免影响服务正常运行

七、服务管理和配置修改

- 1、停止服务、取消开机启动
  - 1.1、cd到jar项目目录中
  - 1.2、./shutdown.sh
  - 1.3、取消开机启动:
    - 1.3.1、systemctl disable 服务名
- 2、修改jvm的堆大小配置
  - 2.1、cd /linkcld/jarapps/jar项目目录/exec, 然后执行sh main.sh, 交互式输入2, 然后交互式配置即可
- 3、取消注册或删除jar项目
  - 3.1、cd /linkcld/jarapps/jar项目目录/exec, 然后执行sh main.sh, 交互式输入3, 即可完成jar项目取消服务注册
  - 3.2、如果想删除jar项目, sudo rm -rf /linkcld/jarapps/jar项目目录/  # 慎重！不要删错目录！
- 4、重新注册
  - 4.1、在取消服务注册之后, 如果想重新注册服务, cd /linkcld/jarapps/jar项目目录/exec, 执行sh main.sh, 交互式输入4, 然后部署即可，重新部署的时候会直接调用之前的配置文件

八、更新jar包

需要更新的文件: zip包或jar文件(必须)
使用说明:
jar每次更新会备份旧jar文件到jar项目根目录的bak目录中, 默认保留10个备份jar文件(修改方法: main.sh文件中的变量值: bakJarMaxNum=10)

- 注意1: 已经部署的jar项目目录中的lib和config等目录名不能改动
- 注意2: exec目录中只能上传一个jar文件

- 1 把jar文件(必须) 上传到jar项目根目录的exec目录中
- 2 cd jar项目根目录/exec
- 3 ./update.sh 或者 ./main.sh, 交互式输入1

九、jar包版本回退

场景: 回退到上次更新时备份到bak目录的旧版本, 前提条件是:

- 1、更新过版本
- 2、只能回退一次。回退之后, 只能等下一次更新jar包后才有机会再次回退
- 3、回退之前, 脚本会删除当前使用的jar包, 不会备份当前jar包到bak目录

版本回退的操作方法:

- 1、cd jar项目根目录/exec
- 2、./rollback.sh 或者 ./main.sh, 交互式输入5 
