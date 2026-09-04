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

new_jar_file=""
tmp_dir="$APP_HOME/tmp"
jar_file_dir="./"
sudo mkdir -p "$tmp_dir"
sudo chmod 755 "$tmp_dir"
jar_zip_file="$(find $jar_file_dir -maxdepth 1 -name "*.zip" -a -type f 2>/dev/null)"

# formatted_tmp_path="${tmp_dir#./}"
if [ -z "$jar_zip_file" ]; then
    echo -e "${RED} Error: $jar_zip_file format not right ! Can't unzip${NC}"
    exit 1
fi

# 解压 ZIP 文件
sudo unzip -o -d "$tmp_dir" "$jar_zip_file" &>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED} Error: $jar_zip_file format not right ! Can't unzip${NC}"
    exit 1
fi

# 检查条件
num_dirs=$(find "$tmp_dir" -maxdepth 1 -type d '!' -wholename "$tmp_dir" | wc -l)

# 获取解压后的目录
jar_zip_dir="$(sudo ls -d $tmp_dir/* 2>/dev/null)"
jar_zip_file_path="$(sudo ls "$jar_zip_dir/"*.jar 2>/dev/null)"
new_jar_file="$(basename "$jar_zip_file_path")"

old_jar_path="$(find "$APP_HOME" -maxdepth 1 -name "*.jar" -a -type f 2>/dev/null)"
old_jar_file=$(basename "$old_jar_path")

# 检查新旧文件是否相同
old_jar_file_md5=$(sudo md5sum "$APP_HOME/$old_jar_file" 2>/dev/null | cut -d" " -f1)
new_jar_file_md5=$(sudo md5sum "$jar_zip_dir/$new_jar_file" 2>/dev/null | cut -d" " -f1)

if [ -z "$new_jar_file" ]; then
    echo -e "${RED} Error: Unable to extract JAR file from ZIP file${NC}"
    exit 1
fi
if [ -z "$jar_zip_dir" ]; then
    echo -e "${RED} Error: $jar_zip_file format not right ! Can't unzip${NC}"
    exit 1
fi
# 查找 JAR 文件
jar_files_count="$(sudo ls "$jar_zip_dir"/*.jar 2>/dev/null | wc -l)"
if [ "$jar_files_count" -eq 0 ]; then
    echo -e "${RED} Error: can't find xxx.jar in $jar_zip_file ${NC}"
    exit 1
elif [ "$jar_files_count" -gt 1 ]; then
    echo -e "${RED} Error: too many xxx.jar in $jar_zip_file ${NC}"
    exit 1
fi
if [ "$num_dirs" -ne 1 ]; then
    echo -e "${RED} Error: The packaging is not in accordance with the company's specifications. Please repack it.${NC}" #解压后的一级目录下只能有一个子目录，不能有文件或多个目录
    exit 1
fi
sudo chmod 644 "$jar_zip_file_path"  #新的jar文件名字权限

# 备份旧 JAR 文件
backup_old_and_update_jar() {
    local date_suffix="$(date '+%Y%m%d%H%M%S')"
    local old_jar_bak="$(basename "$old_jar_file")_$date_suffix"
    if [ -n "$old_jar_file_md5" -a -n "$new_jar_file_md5" -a "$old_jar_file_md5" == "$new_jar_file_md5" ]; then
        echo -e "${RED}Error: $old_jar_file is same with $new_jar_file ! needn't update${NC}"
        # 清理临时目录
        if [[ -d "${tmp_dir}" ]]; then
            sudo rm -rf "${tmp_dir}"   #执行rm时候校验非空
        fi
        exit 1
    fi

    sudo mkdir -p "$APP_HOME/bak"
    sudo \cp -a "$APP_HOME/$old_jar_file" "$APP_HOME/bak/$old_jar_bak"  #备份旧的jar文件
    sudo ln -sf "$APP_HOME/bak/$old_jar_bak" "$APP_HOME/bak/rollback"
}

sync_files_based_on_config() {
    yaml_update_config_file="$APP_HOME/docs/update-config.yml"

    # 检查 update-config.yml 是否存在
    if [ ! -f "$yaml_update_config_file" ]; then
        # 如果文件不存在，执行 rsync，同步所有内容，排除不必要的内容
        sudo rsync -a --exclude='scripts/' --exclude='*.jar' --exclude='config/' --exclude='/*.sh' "$jar_zip_dir/" "$jarappsdir" &> /dev/null
    else
        # 读取 ignored_dirs
        ignored_dirs=""
        while read -r line; do
            [ -n "$line" ] && ignored_dirs="$ignored_dirs $line"
        done < <(sudo yq eval '.ignore.dirs[]' "$yaml_update_config_file" 2>/dev/null)

        # 设置默认值，如果 ignored_dirs 为空，则设为 'config'
        [ -z "$ignored_dirs" ] && ignored_dirs="config"

        # 读取 ignored_files
        ignored_files=""
        while read -r line; do
            [ -n "$line" ] && ignored_files="$ignored_files $line"
        done < <(sudo yq eval '.ignore.files[]' "$yaml_update_config_file" 2>/dev/null)

        # 初始排除选项数组
        exclude_dirs=("--exclude=scripts/" "--exclude=*.jar" "--exclude=/*.sh")

        # 如果 ignored_dirs 非空，添加到排除选项数组
        if [ -n "$ignored_dirs" ]; then
            for ignored_dir in $ignored_dirs; do
                exclude_dirs+=("--exclude=$ignored_dir")
            done
        fi

        # 如果 ignored_files 非空，添加到排除选项数组
        if [ -n "$ignored_files" ]; then
            for ignored_file in $ignored_files; do
                exclude_dirs+=("--exclude=$ignored_file")
            done
        fi

        # 执行 rsync，排除需要排除的目录和文件
        sudo rsync -a "${exclude_dirs[@]}" "$jar_zip_dir/" "$jarappsdir" &> /dev/null
    fi
}

# 停止服务
stop_service() {
    if [ -f "../shutdown.sh" ]; then
        sudo ../shutdown.sh 2> /dev/null
    else
        sudo service "$APP_NAME" stop 2> /dev/null
    fi
    echo "$APP_NAME Stopped"
    sleep 2
}
    
# 更新相关配置文件
update_config() {
    local config_file=""$APP_HOME"/exec/conf/env.sh"
    # sudo mv "$jar_file" "$APP_HOME/$jar_file"
    sudo mv "$jar_zip_file_path" "$APP_HOME/$new_jar_file"    #更新新的jar文件
    # sudo rsync -a --exclude='scripts/' --exclude='*.jar' --exclude='config/' --exclude='/*.sh' "$jar_zip_dir/" "$jarappsdir" &> /dev/null    #更新相关文件
    
    sync_files_based_on_config      #通过update-file.yml判断更新哪些文件与目录
    
    sudo chown "${app_booter}":"${app_booter}" "$APP_HOME/$new_jar_file"
    sudo chown "${app_booter}":"${app_booter}" "$APP_HOME"
    # sudo find "$APP_HOME" -maxdepth 1 -type f -not -name "*.sh" -exec chown "${app_booter}":"${app_booter}" {} +
    sudo chmod 755 ../exec/{bin,conf} &>/dev/null
    sudo chmod 644 "$APP_HOME/$new_jar_file" &> /dev/null
    # sudo chown -R "${app_booter}":"${app_booter}" ../{config,logs} &> /dev/null
    sudo chown -R "${app_booter}":"${app_booter}" "$APP_HOME" &> /dev/null

    sudo sed -i '/^jar_file=/c\jar_file=\"'"$new_jar_file"'\"' "$config_file"
}

# 重启服务
restart_service() {
    cd "$JAVA_HOME"   #因为如果升级服务的时候调用升级脚本升级失败，回滚会删除当前工作目录，使用旧的备份回滚，所以需要切一下目录，若使用不切目录，在旧的目录下启动会找不到工作目录
    cd - > /dev/null 2>&1
    if [ -f "$APP_HOME/restart.sh" ]; then
        echo "Service is starting..."
        sudo "$APP_HOME"/restart.sh | tee /dev/tty | grep -q "running"
        sleep 2s
    else
        echo "Service is starting..."
        sudo service "$APP_NAME" restart  | tee /dev/tty | grep -q "running" 2> /dev/null
        sleep 2s
    fi
    if [ $? -eq 0 ]; then
        echo "$APP_NAME Started"
        echo -e "${GREEN}Success: $APP_NAME Started , checking the service status${NC}"
    else
       echo -e "${RED} Error: update completed, but start jar service failed${NC}"
    fi
}

# 清理旧备份
cleanup_backups() {
    local bak_dir="../bak/"
    local max_backups="$bakJarMaxNum"
    local current_backups=$(sudo ls "$bak_dir"*\.jar_* 2>/dev/null | wc -l)

    if [ "$current_backups" -gt "$max_backups" ]; then
        local remove_count=$((current_backups - max_backups))
        for rmJarFile in $(sudo ls -t "$bak_dir"*\.jar_* 2>/dev/null | tail -n "$remove_count"); do
            [ -f "$rmJarFile" ] && sudo rm -f "$rmJarFile"
        done
    fi
}

# 检查服务状态
check_service() {
    if [ -f "../status.sh" ]; then
        sleep 2s
        # if sudo ../status.sh | tee /dev/tty | grep -q "running"; then
        if sudo ../status.sh | awk '{ lines[NR] = $0 } /Active:/ { active_line = NR } END { start = active_line - 6 > 0 ? active_line - 6 : 1; end = active_line + 6; for (i = start; i <= end; i++) { if (i in lines) { if (lines[i] ~ /Active:.*running/) gsub(/running/, "\033[32;1mrunning\033[0m", lines[i]); else if (lines[i] ~ /Active:.*\(/) gsub(/\(.*\)/, "\033[31;1m&\033[0m", lines[i]); print lines[i] } } }'  ; then
        #  ../status.sh的时候返回颜色，running为绿色，其他为红色 且只显示前后6行
            if [ -f "$jar_zip_file" ]; then
                sudo rm -rf "$jar_zip_file" # 删除 ZIP 文件
            fi
        else
            echo -e "${RED}Service status is abnormal, the update may fail. Please check the service status, configuration files, or permissions.${NC}"
            # exit 1
        fi
    else
        sleep 2s
        if sudo service "$APP_NAME" status --no-pager | awk '{ lines[NR] = $0 } /Active:/ { active_line = NR } END { start = active_line - 6 > 0 ? active_line - 6 : 1; end = active_line + 6; for (i = start; i <= end; i++) { if (i in lines) { if (lines[i] ~ /Active:.*running/) gsub(/running/, "\033[32;1mrunning\033[0m", lines[i]); else if (lines[i] ~ /Active:.*\(/) gsub(/\(.*\)/, "\033[31;1m&\033[0m", lines[i]); print lines[i] } } }' ; then
            if [ -f "$jar_zip_file" ]; then
                sudo rm -rf "$jar_zip_file"
            fi
        else
            echo -e "${RED}Service status is abnormal, the update may fail. Please check the service status, configuration files, or permissions.${NC}"
            # exit 1
        fi
    fi
}

do_not_upgrade_script() {
    stop_service        # 停止服务
    backup_old_and_update_jar  # 备份旧 JAR
    update_config       # 更新配置文件与jar文件
    restart_service       # 重启服务
    cleanup_backups     # 清理旧备份
    check_service       # 检查服务状态
    # # 检查服务状态
    # if [ -f "../status.sh" ]; then
    #     sudo ../status.sh
    # else
    #     sudo service "$APP_NAME" status
    # fi
}

upgrade_scripts_and_services() {
    sudo \cp -a "$APP_HOME" "$APP_HOME"_Bak   #更新jar文件之前先备份项目目录 方便失败回滚
    backup_old_and_update_jar  # 备份旧 JAR
    export tmp_updata_zip_dir_list="$jarappsdir"
    export tmp_updata_zip_work_directory="${jar_zip_dir}"
    export tmp_updata_zip_manage_temp_dir="${jar_zip_dir}/scripts/exec"
    # 导入包含 main 函数的脚本
    source $jar_zip_dir/batch_jar_script_upgrade.sh
    if [ $? -eq 0 ]; then
        update_config   # 更新配置文件与jar文件
        restart_service   # 重启服务
        cleanup_backups  # 清理旧备份
        check_service    # 通过服务状态确认是否删除安装的zip包
    else
        # update_config   # 更新配置文件与jar文件
        restart_service   # 重新启服务
        cleanup_backups  # 清理旧备份
        # check_service    # 通过服务状态确认是否删除安装的zip包
    fi    

    # if [ -f "../status.sh" ]; then
    #     sudo ../status.sh
    # else
    #     sudo service "$APP_NAME" status  --no-pager
    # fi
}
# 版本号比较函数
version_compare() {
    # 参数：$1 - 版本号1, $2 - 版本号2
    # 返回值：1: 小于, 0: 等于, 2: 大于
    local v1="$1"
    local v2="$2"
    IFS='.' read -r -a parts1 <<< "$v1"
    IFS='.' read -r -a parts2 <<< "$v2"

    # 补齐版本号的部分，以便进行比较
    for ((i = 0; i < ${#parts1[@]}; i++)); do
        if [ "${parts2[i]}" == "" ]; then
            parts2[i]=0
        fi
    done
    for ((i = 0; i < ${#parts2[@]}; i++)); do
        if [ "${parts1[i]}" == "" ]; then
            parts1[i]=0
        fi
    done

    for ((i = 0; i < ${#parts1[@]}; i++)); do
        if [ "${parts1[i]}" -lt "${parts2[i]}" ]; then
            return 1
        elif [ "${parts1[i]}" -gt "${parts2[i]}" ]; then
            return 2
        fi
    done

    return 0
}
# 定义函数：检查版本号是否满足条件
main_zip() {
    online_script_version=$script_version
    #提取所上传zip包中脚本的版本号
    script_version_in_zip=$(grep -Eo 'Version: [0-9]+\.[0-9]+\.[0-9]+' "$jar_zip_dir/scripts/exec/conf/CHANGELOG.md" | head -1 | awk '{print $2}')
  
    # 检查是否提取到了版本号
    if [ -z "$online_script_version" ] || [ -z "$script_version_in_zip" ]; then
        echo -e "${YELLOW}If the online version number or the script version number in the uploaded zip package is empty, you can directly upgrade and update the script.${NC}"
        upgrade_scripts_and_services
    else
        # 执行版本号比较
        version_compare "$online_script_version" "$script_version_in_zip"
        result=$?
        if [ "$result" -eq 0 ]; then
            echo -e "${GREEN}Extracted version number:${NC}${RED}($online_script_version)${NC} ${GREEN}equal to the specified version number:${NC}${RED}($script_version_in_zip)${NC}"
            echo -e "${YELLOW}Updating Service...${NC}"
            do_not_upgrade_script
        else
            echo -e "${GREEN}Extracted version number:${NC}${RED}($online_script_version)${NC} ${GREEN}less than the specified version number:${NC}${RED}($script_version_in_zip)${NC}"
            echo -e "${YELLOW}Updating services and upgrading scripts...${NC}"
            upgrade_scripts_and_services
        fi
    fi    
    # 清理临时目录
    if [[ -d "${tmp_dir}" ]]; then
        sudo rm -rf "${tmp_dir}"   #执行rm时候必须校验非空
    fi
    jar_count=$(find "$APP_HOME" -maxdepth 1 -type f -name "*.jar" | wc -l)
    # 如果 jar 文件数量等于 2，则删除旧的 jar 文件
    if [ "$jar_count" -eq 2 ]; then
        sudo rm -rf "$APP_HOME/$old_jar_file"
    fi    
}
main_zip
