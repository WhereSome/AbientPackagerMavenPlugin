#!/bin/bash
export GREEN='\033[0;32m'   # 定义绿色颜色代码
export RED='\033[0;31m'     # 定义红色颜色代码
export YELLOW='\033[1;33m'  # 定义黄色颜色代码
export NC='\033[0m'         # 恢复默认颜色

bakJarMaxNum=10
# 以 root 身份运行 jar 服务
app_booter="root"
#daemon.sh绝对路径
service_file=""
#jar.service绝对路径
unmodified_jar_service_file=""
#jar名字
jar_file=""
#service服务全路径
service_registration_file=""
#输出路径/linkcld/jarapp/app_name
jarappsdir=""

# 定义要与CHANGELOG.md比较的版本号
script_version=""

JAVA_HOME="/usr/java/default"
PATH=$JAVA_HOME/bin:$PATH
CLASSPATH=./:${CLASSPATH}
JAVA_OPTS="-Xms256m -Xmx256m"
JAVA_FIXED_OPTS="-Djava.security.egd=file:///dev/urandom -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=./logs/heapdump.hprof"
JAVA_OPTS="-server $JAVA_OPTS $JAVA_FIXED_OPTS"
#服务名字
APP_NAME="hireH5Server-6835"

getStartupShutdown() {
    if [ ! -f ../startup.sh ] || [ ! -f ../shutdown.sh ]; then
        echo -e "\033[31mError: \033[0mstartup.sh or shutdown.sh isn't exist. please registration service first"
        exit 1
    fi
}

checkStartupShutdownScriptPresence() {
    if [ -f ../startup.sh ] || [ -f ../shutdown.sh ]; then
        echo -e "\033[31mError: \033[0mstartup.sh or shutdown.sh is exist. Please uninstall the service first"
        exit 1
    fi
}

exec_var() {
    if [ -z "$jar_file" -o ! -f "$APP_HOME/$jar_file" ]; then
        echo -e "\033[31mError: \033[0mold jar file does not exist in $APP_HOME"
        exit 1
    fi

    if ! id "$app_booter" &>/dev/null; then
        echo -e "\033[31mError: \033[0muser $app_booter isn't exist"
        exit 1
    fi
    cd "$APP_HOME"/exec || exit
}

getServiceFile() {
if [ -z "$service_env" -o ! -f "$service_env" ]; then
    if [ -f ${APP_HOME}/exec/conf/env.sh ]; then
        service_env="${APP_HOME}/exec/conf/env.sh"
    else
        echo -e "\033[31mError: \033[0mcan't find ${APP_NAME} env file"
        exit 1
    fi
fi

if ! grep -sq "$jar_file" $service_env; then
    echo -e "\033[31mError: \033[0mcan't search $service_env from $jar_file"
    exit 1
fi
}

sure_not() {
    while true; do
        read -p "Are you sure of the above operations ? (y|Y = sure)|(n|N = input again)|(e|E = exit): " read_sn
        echo
        case "$read_sn" in
            [yY])
                echo -e "${GREEN}Info: please wait. start exec next step...${NC}"
                return 0 ;;
            [nN])
                echo -e "${YELLOW}Warn: Please Input Again......${NC}"
                return 1 ;;
            [eE])
                echo -e "${GREEN}Info: Nothing done${NC}"
                exit 1 ;;
            *)
                echo -e "${RED}Error:${NC} Usage <y|Y n|N e|E>"
                continue
        esac
    done
}