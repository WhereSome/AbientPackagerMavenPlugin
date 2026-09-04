#!/bin/bash
#
curDir=$(dirname "$0")
if [ -z "$APP_HOME" ]; then
APP_HOME=$(cd "$curDir"/../..; pwd)
export APP_HOME
fi

source "$APP_HOME"/exec/conf/env.sh

exec_var
getServiceFile
getStartupShutdown

read_rm_tag() {
    while true; do
        rm_tag=false
        if sure_not; then
            rm_tag=true
            return 0
        fi
    done
}

read_rm_tag

echo "Please wait. $APP_NAME stopping..."
if [ -f ../shutdown.sh ]; then
    ../shutdown.sh 2> /dev/null
else
    sudo service $APP_NAME stop 2> /dev/null
fi
if [ $? -ne 0 ]; then
    echo -e "\033[33mWarn: \033[0mservice $APP_NAME stop failed, will force kill it"
fi

sleep 2

echo -e "\033[32mInfo:\033[0mstart to unregister..."
if [[ "$service_env" =~ env.sh$ ]]; then
    sudo rm -f "$service_registration_file"
    sudo systemctl disable "${APP_NAME}".service &>/dev/null
    sudo systemctl daemon-reload
    sudo systemctl reset-failed "${APP_NAME}".service &>/dev/null
else
    # Ubuntu 没有 chkconfig，SysV 服务用 update-rc.d 删除
    if command -v update-rc.d >/dev/null 2>&1; then
        sudo update-rc.d -f "${APP_NAME}" remove &>/dev/null
    fi
    sudo rm -f "/etc/init.d/${APP_NAME}"
fi

sudo rm -f ../{startup.sh,status.sh,shutdown.sh,restart.sh}
sudo rm -f ../{debug_startup.sh,debug_shutdown.sh}

echo -e "\033[32mInfo: \033[0mthe script exec finished"
