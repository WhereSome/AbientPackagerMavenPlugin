#!/bin/bash
#

## install jarapp
install_jar_pre() {
    if ! id "$app_booter" &>/dev/null; then
        sudo groupadd "$app_booter" &>/dev/null
        sudo useradd "$app_booter" -g "$app_booter" -M -s "${nologin_shell:-/usr/sbin/nologin}" &>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "\033[31mError: \033[0madd user $app_booter failed"
            exit 1
        fi
    fi

    if [ "$app_booter" != "$sudo_user" ]; then
        sudo usermod -aG "$app_booter" "$sudo_user"
    fi

    if [ "$install_code" == "new" ]; then
        sudo mkdir -p "$basedir"/"$APP_NAME"
        sudo chmod 755 "$basedir/$APP_NAME"
        install_jar_init_jar_config_dir="null"
        jar_config_dir="${updata_jar_config_dir:-$install_jar_init_jar_config_dir}"
        install_jar_init_jar_models_dir="null"
        jar_models_dir="${updata_jar_models_dir:-$install_jar_init_jar_models_dir}"
        # sudo cp -rf "$jar_config_dir" "$basedir/$APP_NAME/" &> /dev/null
        # sudo cp -rf "$jar_properties_file" "$jar_db_dir" "$jar_docker_dir" "$jar_docs_dir" "$basedir/$APP_NAME/" &> /dev/null
        sudo rsync -a --exclude='scripts/' --exclude="$jar_config_dir" --exclude="$jar_models_dir" --exclude='*.jar' --exclude='/*.sh' --exclude='tmp/' . "$basedir/$APP_NAME/" &> /dev/null
        sudo chmod 755 "$basedir/$APP_NAME/*"  &> /dev/null  

        if [ -f "$jar_dir" ]; then
            sudo \cp -rf "$jar_dir" "$basedir/$APP_NAME/" &> /dev/null
            sudo rm -fr ./tmp &> /dev/null
        elif [ -d "$jar_dir" ]; then
            sudo mv "$jar_dir"/* "$basedir"/"$APP_NAME"/ &> /dev/null
            sudo rm -fr ./tmp &> /dev/null
        fi
    fi

    sudo mkdir -p "$basedir/$APP_NAME/"{bak,exec,config,logs,bin,pid}
    sudo mkdir -p "$basedir/$APP_NAME/"exec/bin
    sudo chown -R ${app_booter}:${app_booter} "$basedir/$APP_NAME"
    [ -n "$sudo_group" ] && sudo chown -R "${sudo_user}":"${sudo_user}" "$basedir/$APP_NAME/"{bak,exec} &>/dev/null \
    || sudo chown -R "${sudo_user}":"${sudo_user}" "$basedir/$APP_NAME/"{bak,exec} &>/dev/null
    sudo chmod 775 "$basedir/$APP_NAME/"{config,logs}
    sudo chmod 777 "$basedir/$APP_NAME/"{bak,exec}
    sudo chmod 755 "$basedir/$APP_NAME/"exec/{bin,conf} &>/dev/null
    sudo chmod 755 "$basedir/$APP_NAME/"
    sudo chmod 500 "$basedir/$APP_NAME/$jar_file" &> /dev/null
    dir="$basedir/$APP_NAME"
    while [ "$dir" != "/" ]; do
        sudo chmod o+rx "$dir" &>/dev/null
        dir="$(dirname "$dir")"
    done
}

install_jar() {
    service_parameter="scripts/exec/conf/daemon.sh"
    service_temp="scripts/exec/conf/jar.service"
    echo "sudo systemctl start ${APP_NAME}"|sudo tee "$basedir/$APP_NAME/"startup.sh > /dev/null
# Ubuntu 的 systemctl status 默认走 less pager，必须把 --no-pager 写进脚本内容
    echo "sudo systemctl status ${APP_NAME} --no-pager"|sudo tee "$basedir/$APP_NAME/"status.sh > /dev/null
    echo "sudo systemctl stop ${APP_NAME}"|sudo tee "$basedir/$APP_NAME/"shutdown.sh > /dev/null
    echo "sudo systemctl restart ${APP_NAME}"|sudo tee "$basedir/$APP_NAME/"restart.sh > /dev/null
    # 调试启停使用与正式服务相同的运行用户
    echo -e '#!/bin/bash\nexport DEBUG=true\nsudo -u '"${app_booter}"' ./bin/daemon.sh start' | sudo tee "$basedir/$APP_NAME/"debug_startup.sh > /dev/null    
    echo -e '#!/bin/bash\nexport DEBUG=true\nsudo -u '"${app_booter}"' ./bin/daemon.sh stop' | sudo tee "$basedir/$APP_NAME/"debug_shutdown.sh > /dev/null    
    
    sudo rm -f "$basedir/$APP_NAME/"*.bat

    [ -n "$sudo_group" ] && sudo chown "${sudo_user}":"${sudo_user}" "$basedir/$APP_NAME/"{startup.sh,status.sh,shutdown.sh,restart.sh,debug_startup.sh,debug_shutdown.sh} &>/dev/null \
    || sudo chown "${sudo_user}":"${sudo_user}" "$basedir/$APP_NAME/"{startup.sh,status.sh,shutdown.sh,restart.sh,debug_startup.sh,debug_shutdown.sh} &>/dev/null
    sudo chmod 755 "$basedir/$APP_NAME/"{startup.sh,status.sh,shutdown.sh,restart.sh,debug_startup.sh,debug_shutdown.sh} &>/dev/null

    sudo sed -i '/^source/c\source "'"$basedir/$APP_NAME/exec/conf/env.sh"'"' "$service_parameter"

    service_parameter_file="$basedir/$APP_NAME/bin/daemon.sh"
    sudo \cp -f "$service_parameter" "$service_parameter_file"
    # shellcheck disable=SC1001
    sudo chmod -R 755 "$basedir/$APP_NAME/bin/"
    sudo chown -R ${app_booter}:${app_booter} "$basedir/$APP_NAME/bin/"

    if [ -n "$after_service" ]; then
        sudo sed -i '/^After=/c\After=network.target '"${after_service}"'' "$service_temp"
    fi
    sudo sed -i '/^\# Systemd unit file for/c\# Systemd unit file for '"${APP_NAME}"'' "$service_temp"
    sudo sed -i '/^Description=/c\Description=jarapps '"${jar_file}"'' "$service_temp"
    sudo sed -i '/^WorkingDirectory=/c\WorkingDirectory='"$basedir/$APP_NAME"'' "$service_temp"
    sudo sed -i '/^ExecStart=/c\ExecStart='"$service_parameter_file"' start' "$service_temp"
    sudo sed -i '/^ExecStop=/c\ExecStop='"$service_parameter_file"' stop' "$service_temp"
    sudo sed -i '/^ExecReload=/c\ExecReload='"$service_parameter_file"' restart ' "$service_temp"

    sudo sed -i '/^User=/c\User='"$app_booter"'' "$service_temp"
    sudo sed -i '/^Group=/c\Group='"$app_booter"'' "$service_temp"

    service_file="${systemd_unit_dir:-/lib/systemd/system}/${APP_NAME}.service"
    sudo \cp -f "$service_temp" "$service_file"
    sudo chmod 644 "$service_file"
    sudo systemctl daemon-reload
    sudo systemctl enable "${APP_NAME}".service &> /dev/null
    service_registration_file=${service_file}
    service_file=${service_parameter_file}    
}

setChmodPermission() {
    sudo sed -i '1i\sudo chown -R '"${app_booter}:${app_booter}"' $basedir' "$basedir/$APP_NAME/"startup.sh > /dev/null
    sudo sed -i '1i\sudo chmod 777 $basedir/{bak,exec} &>/dev/null' "$basedir/$APP_NAME/"startup.sh > /dev/null
    sudo sed -i '1i\sudo find $basedir -name "*.sh" -type f|xargs -I {} sudo chmod 755 {}' "$basedir/$APP_NAME/"startup.sh > /dev/null
    sudo sed -i '1i\sudo find $basedir -type f ! -name "*.gz" -exec sudo chmod 644 {} \\;' "$basedir/$APP_NAME/"startup.sh > /dev/null
    sudo sed -i '1i\sudo find $basedir -type d|xargs -I {} sudo chmod 755 {}' "$basedir/$APP_NAME/"startup.sh > /dev/null
    sudo sed -i '1i\sudo chmod 755 $basedir' "$basedir/$APP_NAME/"startup.sh > /dev/null
    sudo sed -i '1i\[ ${#basedir} -lt 20 ] && exit 1' "$basedir/$APP_NAME/"startup.sh > /dev/null
    sudo sed -i '1i\basedir="'"$basedir/$APP_NAME"'"' "$basedir/$APP_NAME/"startup.sh > /dev/null
    sudo sed -i '1i\#!/bin/bash' "$basedir/$APP_NAME/"startup.sh > /dev/null

    sudo sed -i '1i\#!/bin/bash' "$basedir/$APP_NAME/"shutdown.sh > /dev/null
    sudo sed -i '1i\#!/bin/bash' "$basedir/$APP_NAME/"status.sh > /dev/null

    sudo sed -i '1i\sudo chown -R '"${app_booter}:${app_booter}"' $basedir' "$basedir/$APP_NAME/"restart.sh > /dev/null
    sudo sed -i '1i\sudo chmod 777 $basedir/{bak,exec} &>/dev/null' "$basedir/$APP_NAME/"restart.sh > /dev/null
    sudo sed -i '1i\sudo find $basedir -name "*.sh" -type f|xargs -I {} sudo chmod 755 {}' "$basedir/$APP_NAME/"restart.sh > /dev/null
    sudo sed -i '1i\sudo find $basedir -type f ! -name "*.gz" -exec sudo chmod 644 {} \\;' "$basedir/$APP_NAME/"restart.sh > /dev/null
    sudo sed -i '1i\sudo find $basedir -type d|xargs -I {} sudo chmod 755 {}' "$basedir/$APP_NAME/"restart.sh > /dev/null
    sudo sed -i '1i\sudo chmod 755 $basedir' "$basedir/$APP_NAME/"restart.sh > /dev/null
    sudo sed -i '1i\[ ${#basedir} -lt 20 ] && exit 1' "$basedir/$APP_NAME/"restart.sh > /dev/null
    sudo sed -i '1i\basedir="'"$basedir/$APP_NAME"'"' "$basedir/$APP_NAME/"restart.sh > /dev/null
    sudo sed -i '1i\#!/bin/bash' "$basedir/$APP_NAME/"restart.sh > /dev/null

}

## conf_service_manage
conf_service_manage() {
    echo -e "\033[32mInfo: \033[0mwill config jar service manage script next step"
    jar_init_manage_temp_dir="scripts/exec"
    manage_temp_dir="${tmp_updata_zip_manage_temp_dir:-$jar_init_manage_temp_dir}"
    if [ ! -d $manage_temp_dir ]; then
        echo -e "\033[31mError: \033[0m$manage_temp_dir isn't exist"
        return 1
    fi
    manage_dir="exec"
    sudo rm -rf "$basedir/$APP_NAME/$manage_dir"
    sudo \cp -rf "$manage_temp_dir" "$basedir/$APP_NAME/$manage_dir"
    sudo chmod -R 755 "$basedir/$APP_NAME/$manage_dir"
    sudo chmod 777 "$basedir/$APP_NAME/$manage_dir"
    sudo chmod 755 "$basedir/$APP_NAME/$manage_dir/"{bin,conf} &>/dev/null
    main_script="$basedir/$APP_NAME/$manage_dir/main.sh"
    service_env="scripts/exec/conf/env.sh"
    service_temp="scripts/exec/conf/jar.servide"
    service_env_file="$basedir/$APP_NAME/exec/conf/env.sh"
    changelog_version="scripts/exec/conf/CHANGELOG.md"
    script_version=$(grep -Eo 'Version: [0-9]+\.[0-9]+\.[0-9]+' "$changelog_version" | head -1 | awk '{print $2}')   > /dev/null

    if [ ! -f $service_env ] && [ ! -f "$main_script" ]; then
        echo -e "\033[31mError: \033[0m$service_env or $main_script isn't exist"
        return 1
    fi
    sudo sed -i '/^source/c\source "'"$basedir/$APP_NAME/exec/conf/env.sh"'"' "$main_script"
    # sudo sed -i '/^jar_full_path=/c\jar_full_path=\"'"$basedir/$APP_NAME"'\"' $service_env
    sudo sed -i '/^APP_NAME=/c\APP_NAME=\"'"$APP_NAME"'\"' $service_env
    sudo sed -i '/^service_file=/c\service_file=\"'"$service_file"'\"' $service_env
    sudo sed -i '/^unmodified_jar_service_file=/c\unmodified_jar_service_file=\"'"$basedir/$APP_NAME/exec/conf/jar.service"'\"' $service_env
    sudo sed -i '/^jarappsdir=/c\jarappsdir=\"'"$basedir/$APP_NAME"'\"' $service_env
    sudo sed -i '/^service_registration_file=/c\service_registration_file=\"'"$service_registration_file"'\"' $service_env
    sudo sed -i '/^jar_file=/c\jar_file=\"'"$jar_file"'\"' $service_env
    sudo sed -i '/^export JAVA_HOME=/c\export JAVA_HOME="'"$java_home"'"' "$service_env"
    sudo sed -i '/^APP_NAME=/c\APP_NAME="'"$APP_NAME"'"' "$service_env"
    sudo sed -i '/^JAVA_OPTS="-X/c\JAVA_OPTS="'"${java_opts}"'"' "$service_env"

    sudo sed -i '/^script_version=/c\script_version=\"'"$script_version"'\"' $service_env

    sudo \cp "$service_env" "$service_env_file" 2>/dev/null
    sudo chmod -R 755 "$basedir/$APP_NAME/exec/conf/"
    sudo chown -R ${app_booter}:${app_booter} "$basedir/$APP_NAME/exec/conf/"

    [ -n "$sudo_group" ] && sudo chown -R "${sudo_user}":"${sudo_user}" "$basedir/$APP_NAME/$manage_dir" &>/dev/null \
    || sudo chown -R "${sudo_user}":"${sudo_user}" "$basedir/$APP_NAME/$manage_dir" &>/dev/null
}

echo_var() {
    echo -e "APP_NAME=\"\033[32m${APP_NAME}\033[0m\""
    if [ "$install_code" == "new" ]; then
        echo -e "jar_packet=\"\033[32m${jar_packet}\033[0m\""
    elif [ "$install_code" == "update" ]; then
        echo -e "project_path=\"\033[32m${project_path}\033[0m\""
    fi
    echo -e "JAVA_HOME=\"\033[32m${java_home}\033[0m\""
    echo -e "JAVA_OPTS=\"\033[32m${java_opts}\033[0m\""
}
