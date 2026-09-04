#!/bin/bash

## update: projcet exist, just input project_directory_name
readDir() {
    while true; do
        APP_NAME=""
        project_path=""
        jar_file=""
        read -p "Please input jar project directory name: e|E=(exit)|${basedir}/\$project_directory_name=" ch
        if [ -z "$ch" ]; then
            echo -e "\033[31mError: \033[0mInput can't be null"
            continue
        elif [ "$ch" = "e" -o "$ch" = "E" ]; then
            echo -e "\033[33mWarn: \033[0mThe installation is interrupted"
            exit 1
        fi

        ch=$(echo "$ch" |sed 's#^/*##g' |sed 's#/*$##g')
        APP_NAME="$ch"
        ch="$basedir/$ch"
        if [ ! -d "$ch" ]; then
            echo -e "\033[31mError: \033[0mproject_directory $ch isn't exist"
            continue
        elif [ -f $ch/startup.sh ] && grep -E -sq "systemctl|\/etc\/init\.d\/" $ch/startup.sh; then
            echo -e "\033[31mError: \033[0mPlease check $ch/startup.sh ! Maybe already have servie_file"
            exit 1
        elif [ -f /lib/systemd/system/"${APP_NAME}".service ]; then
            echo -e "\033[31mError: \033[0mservice file /lib/systemd/system/${APP_NAME}.service is existed"
            continue
        elif [ -f /usr/lib/systemd/system/"${APP_NAME}".service ]; then
            echo -e "\033[31mError: \033[0mservice file /usr/lib/systemd/system/${APP_NAME}.service is existed"
            continue
        elif [ -f /etc/init.d/"$APP_NAME" ]; then
            echo -e "\033[31mError: \033[0mservice file /etc/init.d/$APP_NAME is existed"
            continue
        fi

        if [ -n "$(sudo ls "$ch"/*.jar 2> /dev/null)" ]; then
            jar_file="$(sudo ls "$ch"/*.jar 2> /dev/null |xargs -I {} basename {})"
            project_path="$ch"
            break
        elif [ -n "$(sudo ls "$ch"/bin/*.jar 2> /dev/null)" ]; then
            jar_file="$(sudo ls "$ch"/bin/*.jar 2> /dev/null |xargs -I {} basename {})"
            jar_file="bin/$jar_file"
            project_path="$ch"
            break
        else
            echo -e "\033[31mError: \033[0mproject_directory don't have jar file"
            continue
        fi
    done
}

## check service_port in use? not config
read_service_port() {
    if [ -z "$jar_config_file" ]; then
        jar_default_port=""
    elif ! sudo ls "$jar_config_file" &>/dev/null; then
        jar_default_port=""
    else
        jar_config_file_port="$(sudo grep -sv "^[[:blank:]]*#" $jar_config_file |grep -s -A4 "^server:"|grep -s "^[[:blank:]]*port:"|grep -so "[0-9]*"|sed -n '1p')"
        [ -n "$jar_config_file_port" ] && jar_default_port=$jar_config_file_port || jar_default_port=""
    fi
    jar_default_port_tag=false
    while true; do
        jar_port=0
        $jar_default_port_tag && jar_default_port=""
        read -p "Please input jar service port: (n|N=skip | 1024-65535 <default=${jar_default_port:-null}>)=" jar_port
        if [ -z "$jar_port" -a -n "$jar_default_port" ]; then
            jar_port="$jar_default_port"
            jar_default_port_tag=true
        fi
        if [ -z "$jar_port" ]; then
            echo -e "\033[31mError: \033[0mInput can't be null"
            continue
        elif [ "$jar_port" == "N" -o "$jar_port" == "n" ]; then
            jar_port=0
            echo
            return 1
        elif [ ${#jar_port} -lt 4 -o ${#jar_port} -gt 5 ]; then
            echo -e "\033[31mError: \033[0mport range 1024-65535"
            continue
        elif [[ "$jar_port" =~ ^[1-9][0-9]+$ ]] && [ $jar_port -ge 1024 -a $jar_port -le 65535 ]; then
            :
        else
            echo -e "\033[31mError: \033[0mport range 1024-65535"
            continue
        fi
        #check port is using ?
        if sudo ss -antlp|grep -wsq "$jar_port"; then
            tmp_srv_port_using=true
        fi
        echo -e "\033[32mInfo: \033[0mjar service port=$jar_port"
        echo

        return 0
    done
}

## Set APP_NAME
read_APP_NAME() {
    if [ -z "$jar_config_file" ]; then
        jar_default_srv_name=""
        jar_default_srv_name_show=""
        jar_config_file_srv_name_yq=""
    elif ! sudo ls $jar_config_file &>/dev/null; then
        jar_default_srv_name=""
        jar_default_srv_name_show=""
        jar_config_file_srv_name_yq=""
    else
        jar_config_file_srv_name="$(sudo grep -sv "^[[:blank:]]*#" $jar_config_file |grep -s -A4 "^server:"|awk '$0 ~ "^[[:blank:]]*context-path:"{print $2}'|sed -n '1p')"
        jar_config_file_srv_name_yq="$(sudo yq eval '.spring.application.name'  $jar_config_file)"
        if [ -n "$jar_config_file_srv_name" ] ; then
            jar_default_srv_name="${jar_config_file_srv_name##*/}"
            [ "${jar_port}" -ne 0 ] && jar_default_srv_name_show="$jar_default_srv_name" || jar_default_srv_name_show="$jar_default_srv_name"
        else
             # 如果从配置文件中解析的服务名称为空，则尝试使用yq解析另外一个字段
            if [ -n "$jar_config_file_srv_name_yq" ];then
                [ "${jar_port}" -ne 0 ] && jar_default_srv_name_show="$jar_config_file_srv_name_yq" || jar_default_srv_name_show="$jar_config_file_srv_name_yq"
            else
                # 如果两种方法都无法获取服务名称，则保持变量为空
                jar_default_srv_name=""
                jar_default_srv_name_show=""
            fi
        fi
    fi
    jar_default_srv_name_tag=false
    APP_NAME=""
    while true; do
        $jar_default_srv_name_tag && jar_default_srv_name="" && jar_default_srv_name_show=""
        read -p "Please input jar service name: e|E=(exit) | APP_NAME(a-zA-Z0-9._-) (default=${jar_default_srv_name_show:-null})=" ch
        if [ -z "$ch" -a -n "$jar_default_srv_name_show" ]; then
            ch="$jar_default_srv_name_show"
            jar_default_srv_name_tag=true
        fi
        if [ -z "$ch" ]; then
            echo -e "\033[31mError: \033[0mInput can't be null"
            continue
        elif [ "$ch" = "e" -o "$ch" = "E" ]; then
            echo -e "\033[33mWarn: \033[0mThe installation is interrupted"
            exit 1
        elif [[ ! "$ch" =~ ^[a-zA-Z] ]]; then
            echo -e "\033[31mError: \033[0mInput must start with a-zA-Z"
            continue
        elif [[ ! "$ch" =~ [a-zA-Z0-9]$ ]]; then
            echo -e "\033[31mError: \033[0mInput must end with a-zA-Z0-9"
            continue
        elif [ ${#ch} -lt 2 -o ${#ch} -gt 24 ]; then
            echo -e "\033[31mError: \033[0mInput length range 2-24"
            continue
        elif [[ ! "$ch" =~ ^[0-9a-zA-Z_\.\-]+$ ]]; then
            echo -e "\033[31mError: \033[0mInput only can include a-zA-Z0-9._-"
            continue
        fi
        yml_spring_application_name="$ch"
        [ "${jar_port}" -ne 0 ] && ch="${ch}-${jar_port}"
        echo -e "\033[32mInfo: \033[0mjar service name=\"\033[32m${ch}\033[0m\""

        jar_dir_exist=false
        jar_service_exist=false
        if [ -d "$basedir/$ch" -a -n "$(sudo ls -A "$basedir/$ch" 2>/dev/null)" ]; then
            jar_dir_exist=true
        fi
        if [ -f /lib/systemd/system/"${ch}".service ]; then
            jar_service_exist="/lib/systemd/system/${ch}.service"
        elif [ -f /usr/lib/systemd/system/"${ch}".service ]; then
            jar_service_exist="/usr/lib/systemd/system/${ch}.service"
        elif [ -f /etc/init.d/"$ch" ]; then
            jar_service_exist="/etc/init.d/$ch"
        fi

        if $jar_dir_exist && [ -f "${jar_service_exist}" ]; then
            tmp_exec_version="$(sed -n '2p' "$basedir/$ch/"exec/main.sh 2>/dev/null|grep -so "Version:.*$"|awk '{print $2}')"
            if [[ "$tmp_exec_version" =~ ^[1-9]\.[0-9]\.[0-9]$ ]] && [ -d "$basedir/$ch/exec/bin" -a -d "$basedir/$ch/exec/conf" ] && sudo ls "$basedir/$ch/startup.sh" &>/dev/null; then
                updateJarFile
                exit $?
            else
                echo -e "\033[31mError: \033[0m$basedir/$ch is existed, but the $basedir/$ch/exec/bin/update.sh is invalid to update jar file"
                return 3
            fi
        elif ${jar_dir_exist}; then
            echo -e "\033[31mError: \033[0mdirectory $basedir/$ch is existed, but can't find service file"
            if [ -f "$basedir"/"$ch"/exec/main.sh -a -f "$basedir"/"$ch"/exec/bin/register.sh ]; then
                echo -e "\033[32mTips: \033[0myou can exec $basedir/$ch/exec/main.sh to install jar service"
            fi
            exit 1
        elif [ -f "${jar_service_exist}" ]; then
            echo -e "\033[31mError: \033[0mservice file ${jar_service_exist} is existed, but $basedir/$ch isn't exist"
            return 3
        elif ${tmp_srv_port_using}; then
            echo -e "\033[31mError: \033[0mport $jar_port is using"
            return 3
        fi

        APP_NAME="$ch"
        while true; do
            read -p "Please check variables is right ? (y|Y=sure) | (n|N=input APP_NAME again): " ch
            case $ch in
                [yY])
                    echo
                    return 0
                    ;;
                [nN])
                    return 3
                    ;;
                *)
                    echo
                    echo -e "\033[31mError: \033[0mUsage y|Y|n|N"
                    continue
                    ;;
            esac
        done
    done
}

# compute memory
java_opts=""
read_java_opts() {
    sudo sync
    echo 1|sudo tee /proc/sys/vm/drop_caches &> /dev/null
    while true; do
        java_opts=""
        read -p "Please Input JAVA_OPTS(heap_size 16-31744MB): (e|E=exit)|(default=512) (Example: 1024): " ch
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
        if [[ $((need_mem + 128))  -gt $memFree ]]; then
            echo -e "\033[31mError: \033[0mFree_Memory=${memFree}m Isn't Enough ${ch}+128m ! Please Input Smaller Than $((need_mem + 128))"
            continue
        else
            java_opts="-Xms${ch}m -Xmx${ch}m"
            return 0
        fi
    done
}
