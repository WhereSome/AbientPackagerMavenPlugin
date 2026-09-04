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

old_jvm_Xms=""
old_jvm_Xmx=""
old_jvm_Xms="$(sudo sed -n '/^JAVA_OPTS="/p' $service_env|grep -E -o "\-Xms[0-9]+[mMgG][bB]?")"
old_jvm_Xmx="$(sudo sed -n '/^JAVA_OPTS="/p' $service_env|grep -E -o "\-Xmx[0-9]+[mMgG][bB]?")"

if [ -z "${old_jvm_Xms}" ]; then
    echo -e "\033[31mError: \033[0mcan't get -Xms from $service_env"
    exit 1
elif [ -z "${old_jvm_Xmx}" ]; then
    echo -e "\033[31mError: \033[0mcan't get -Xmx from $service_env"
    exit 1
fi

echo -e "old jvm Xms=\033[32m${old_jvm_Xms}\033[0m"
echo -e "old jvm Xmx=\033[32m${old_jvm_Xmx}\033[0m"

new_jvm_Xms=""
new_jvm_Xmx=""
read_java_opts() {
    sudo sync
    echo 1|sudo tee /proc/sys/vm/drop_caches &> /dev/null
    while true; do
        new_jvm_Xms=""
        new_jvm_Xmx=""
        read -p "Please Input JAVA_OPTS(heap_size 16-31744MB) <(e|E=exit)|(default=512)|example 1024|2048|4096>: " ch
        if [ -z "$ch" ]; then
            ch=512
        elif [ "$ch" = "e" -o "$ch" = "E" ]; then
            echo -e "\033[33mWarn: \033[0mThe installation is interrupted"
            exit 1
        elif [[ ! "$ch" =~ ^[1-9][0-9]+$ ]]; then
            echo -e "\033[31mError: \033[0mInput only can include 0-9"
            continue
        elif [ $ch -lt 16 -o $ch -gt 31744 ]; then
            echo -e "\033[31mError: \033[0mheap_size range 16-31744"
            continue
        fi

        memFree=$(awk '/MemFree:/{print $2 / 1024}' /proc/meminfo|awk -F"." '{print $1}')
        need_mem=$ch
        if [[ $(( need_mem + 128 )) -gt $memFree ]]; then
            echo -e "\033[31mError: \033[0mFree_Memory=${memFree}m Isn't Enough ${ch}+128m ! Please Input Smaller Than $((memFree - 128))"
            continue
        else
            new_jvm_Xms="-Xms${ch}m"
            new_jvm_Xmx="-Xmx${ch}m"
            echo -e "new jvm Xms=\033[32m${new_jvm_Xms}\033[0m"
            echo -e "new jvm Xmx=\033[32m${new_jvm_Xmx}\033[0m"
            if sure_not; then
                return 0
            fi
        fi
    done
}

read_java_opts

if [ "${old_jvm_Xms}" == "${new_jvm_Xms}" -a "${old_jvm_Xmx}" == "${new_jvm_Xmx}" ]; then
    echo -e "\033[31mError: \033[0mold_jvm is same with new_jvm. needn't modify"
    exit 1
fi

echo -e "\033[32mInfo:\033[0mstart to modify..."
sudo sed -i '/^JAVA_OPTS="/s/'"$old_jvm_Xms"'/'"$new_jvm_Xms"'/' $service_env
sudo sed -i '/^JAVA_OPTS="/s/'"$old_jvm_Xmx"'/'"$new_jvm_Xmx"'/' $service_env

echo "Please wait. $APP_NAME stopping..."
if [ -f ../shutdown.sh ]; then
    ../shutdown.sh 2> /dev/null
else
    sudo service $APP_NAME stop 2> /dev/null
fi
echo "$APP_NAME stopped"
sleep 2

echo "Please wait. $APP_NAME starting..."
if [ -f ../startup.sh ]; then
    ../startup.sh
else
    sudo service $APP_NAME start
fi
if [ $? -eq 0 ]; then
    echo "$APP_NAME started"
    echo -e "\033[32mSuccess: \033[0mjar update successfully"
else
    echo -e "\033[31mError: \033[0mupdate completed, but start jar service failed"
fi

sleep 2
if [ -f ../status.sh ]; then
    ../status.sh
else
    sudo service $APP_NAME status
fi
exit $?

