#!/bin/bash

## exec script
main() {
    source ./scripts/bin/install_env.sh                   # 定义环境变量
    source ./scripts/bin/check.sh                         # 检查jar部署的前提条件
    source ./scripts/bin/select_jdk.sh                    # 选择jdk
    source ./scripts/bin/input_basic_info.sh              # 输入jar包信息(名字、端口、内存)
    source ./scripts/bin/get_jar_file.sh                  # 获取jar包信息
    source ./scripts/bin/yml_modify.sh                    # 提供 yml_name_port（写服务名/端口）
    source ./scripts/bin/install_jar_init.sh              # jar包安装

    main_check
    main_java_home

    APP_NAME=""
    jar_file=""
    jar_port=0
    if [ "$install_code" == "new" ]; then
        jar_packet=""
        jar_dir=""
        jar_file=""
        # read_jar_file
        echo
        jar_config_dir="config"
        # jar_db_dir="db"
        # jar_docker_dir="docker"
        # jar_docs_dir="docs"
        # mapfile -t jar_properties_file < <(find . -maxdepth 1 -name "*.properties" -type f)
	    jar_config_file="$jar_config_dir/application.yml"
        echo -e "\033[32mInfo: \033[0mCheck jar file, please wait a moment..."
        sudo ls "$jar_config_file" &>/dev/null && sudo vi +':wq ++ff=unix' "$jar_config_file" &>/dev/null
        read_jar_file
        while ${tmp_set_srv_tag}; do
            tmp_srv_port_using=false
            read_service_port
            read_APP_NAME
            [ $? -eq 0 ] && tmp_set_srv_tag=false || echo
        done
        # 仅按需写入服务名/端口，不再做上家公司的 SSO/ORM/数据库交互配置
        if [ -f "$jar_config_file" ]; then
            yml_name_port
        fi
    elif [ "$install_code" == "update" ]; then
        project_path=""
        readDir
    else
        echo -e "\033[31mError: \033[0m\$install_code=install_code is wrong"
        exit 1
    fi

    read_java_opts
    echo
    java_opts="$java_opts"

    echo
    echo_var
    sure_not
    install_jar_pre

    service_file=""
    install_jar

    setChmodPermission

    conf_service_manage

    echo -e "\033[32mSuccess: install ${APP_NAME} OK\033[0m"
}

main
exit
