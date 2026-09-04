#!/bin/bash
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

directory="/gqtian/jarapps"  # 目标目录
curDir=$(dirname "$0")
batch_jar_script_upgrade_work_directory=$(cd "$curDir"; pwd)
work_directory="${tmp_updata_zip_work_directory:-$batch_jar_script_upgrade_work_directory}"
jar_upgrade_log_dir="$directory/jar_upgrade_log_dir"   #升级日志目录
output_file="$jar_upgrade_log_dir/filtered_directories.txt"  # 输出未满足条件的目录文件匹配项来自check_directory_conditions函数
daemon1_file="$jar_upgrade_log_dir/unmatched_daemon1.txt"    # 存储未匹配到 JAVA_HOME 和 JAVA_OPTS 的目录文件
services_failed_start_file="$jar_upgrade_log_dir/services_failed_start.txt"  # 存储启动失败的service

framework=$(uname -m)
system_version=$(uname -r | awk -F '[.]' '{print $(NF-1)}')
allowed_architectures=("aarch64" "x86_64")
allowed_sinicization_system=("an8" "ky10" "oe1" "fos22" "uelc20" "el7")

threshold=6 # 设置/gqtian/jarapps目录的剩余空间阈值
space_info=$(df -P $directory | tail -1) # 获取目录所在的文件系统剩余空间信息
space_percentage=$(echo $space_info | awk '{print $5}' | sed 's/%//') # 提取剩余空间百分比
remaining_percentage=$((100 - space_percentage)) # 计算剩余空间的补充百分比

# 比较剩余空间补充百分比与阈值
if [ $remaining_percentage -lt $threshold ]; then
    echo -e "${RED} error: Dir $directory the remaining space is less than $threshold%, The space is insufficient. Please delete unnecessary logs first${NC}"
    exit 1
fi
# 确保脚本必须是 root 用户运行
# if [ "$EUID" -ne 0 ]; then
#     echo -e "${RED} Error: This script must be run as root${NC}"
#     exit 1
# fi
if [[ ! " ${allowed_sinicization_system[*]} " =~ ${system_version} ]]; then
    echo -e "${RED} error: Unsupported system version. Allowed versions are: ${allowed_sinicization_system[*]}${NC}"
    exit 1
fi
if [[ ! " ${allowed_architectures[*]} " =~  ${framework}  ]]; then
    echo -e "${RED} error: Unsupported architecture. Allowed architectures are: ${allowed_architectures[*]}${NC}"
    exit 1
fi
if [ ! -x /usr/bin/sudo ]; then
    echo -e "${RED}Error: command /usr/bin/sudo isn't existed${NC}"
    exit 1
fi
if ! sudo -l &> /dev/null; then
    echo -e "${RED}Error: you must switch to root or use sudo${NC}"
    exit 1
fi
# 检查运行用户是否存在（当前为 root）
if ! id "root" &>/dev/null; then
    echo -e "${RED}Error: user 'root' does not exist${NC}"
    exit 1
fi

# command 是 shell 内置命令，不能用 sudo 直接调用，否则会误报未安装
if ! command -v rsync &> /dev/null  ; then
    echo -e "${RED}: rsync is not installed.${NC}"
    exit 1
fi

if [ ! -d "$jar_upgrade_log_dir" ]; then
    sudo mkdir -p "$jar_upgrade_log_dir"
fi
#获取源文件的权限、所有者和所属组信息
target_stats=$(stat -c "%a %u %g" "$directory")
IFS=' ' read -r existing_permissions target_uid target_gid <<< "$target_stats"
sudo chmod -R "$existing_permissions" "$jar_upgrade_log_dir" 2>/dev/null
sudo chown -R "$target_uid:$target_gid" "$jar_upgrade_log_dir" 2>/dev/null

sure_not() {
    while true; do
        read -rp "Are you sure of the above operations ? (y|Y = sure)|(e|E = exit): " read_sn
        echo
        case "$read_sn" in
            [yY])
                echo -e "${GREEN}Info: please wait. start exec next step...${NC}"
                return 0 ;;
            # [nN])
            #     echo -e "${YELLOW}Warn: Please Input Again......${NC}"
            #     return 1 ;;
            [eE])
                echo -e "${GREEN}Info: Nothing done${NC}"
                exit 1 ;;
            *)
                echo -e "${RED}Error:${NC} Usage <y|Y n|N e|E>"
                continue
        esac
    done
}

# 定义函数：检查目录是否满足条件
check_directory_conditions() {
    local dir="$1"  # 传递目录路径作为参数
    local service_name=$(basename "$dir")
    # 检查目录内是否存在 config、exec 文件夹及其他特定文件
    if [ -d "$dir/config" ] && [ -d "$dir/exec" ] && [ -n "$(find "$dir/" -maxdepth 1 -type f -name '*.jar' -print -quit)" ] && [ -f "$dir/shutdown.sh" ] && [ -f "$dir/status.sh" ] && [ -f "$dir/restart.sh" ] ; then
        if sudo systemctl cat  "$service_name" 2>/dev/null; then
                return 0  # 满足条件
            else
                return 1  # 不满足条件
        fi
    else
        return 1  # 目录不满足条件
    fi
}

# 定义函数：输出未满足条件的目录到文件
output_filtered_directories() {
    sudo echo "不满足条件的项目：" > "$output_file"  # 写入文件头部信息 不满足条件的项目
    for filtered_dir in "${filtered_directories[@]}"; do  # 遍历未满足条件的目录数组
       sudo echo "$filtered_dir" >> "$output_file"  # 将每个未满足条件的目录追加到文件
    done
}

waiting_logic () {
    duration=15  # 设置总的等待时间（秒）
    symbols=(".  " ".. " "..." "...." "....." "......")
    for ((i=duration; i>0; i--)); do
        for symbol in "${symbols[@]}"; do
            echo -ne "请 等 待：${GREEN}${symbol}\033[0K\r${NC}"
            sleep 0.5
        done
    done
}

# 修改之前先备份目录
bak_directory() {
    local project_dir="$1"  # 传递项目目录路径作为参数
    local original_dir="$project_dir"  # 定义旧目录路径
    # # 检查 status.sh 脚本输出是否包含 "running"
    # if "$project_dir/status.sh" | grep -q "running"; then
    #     local project_bak_dir="${project_dir}_Bak"  # 定义备份目录路径
    #     sudo \cp -a "$project_dir" "$project_bak_dir"  2>/dev/null # 复制目录并保留权限
    # fi
    local project_bak_dir="${project_dir}_Bak"  # 定义备份目录路径
    if [ ! -d "$project_bak_dir" ]; then
        sudo \cp -a "$project_dir" "$project_bak_dir" 2>/dev/null # 复制目录并保留权限
    fi    
    echo "$project_bak_dir"  # 返回备份目录路径
    echo "$original_dir"  # 返回原始目录路径    
}

call_jar_deployed_script_upgrade() {
    local daemon_dir="$1"
    local jar_file="$2"
    local service_name="$3"
    local daemon1_file="$4"
    memory_opts=$(grep 'JAVA_OPTS.*-Xms'  "$daemon_dir/exec/conf/env.sh"  2>/dev/null | awk -F'"' '{print $2}')

    # 获取 daemon.sh 中的 JAVA_HOME（老版本的jar部署脚本,当前版本jar部署脚本较多）
    java_home=$(grep -o 'JAVA_HOME=[^ ]*' "$daemon_dir/bin/daemon.sh" 2>/dev/null | awk -F'=' '{print $2}' | sed 's/"//g')
    if [ -n "$java_home" ]; then
        local memory_opts=$(grep 'JAVA_OPTS.*-Xms' "$daemon_dir/bin/daemon.sh" 2>/dev/null | awk -F'"' '{print $2}' | awk '{print $2, $3}')
        local java_opts="$memory_opts" 
    else
         # 获取 env.sh 中的 JAVA_HOME（次新版本的jar部署脚本）
        java_home=$(grep -o 'JAVA_HOME=[^ ]*' "$daemon_dir/exec/conf/env.sh"  2>/dev/null | awk -F'=' '{print $2}' | sed 's/"//g' )
        if [ -n "$java_home" ]; then
            local memory_opts=$(grep 'JAVA_OPTS.*-Xms' "$daemon_dir/exec/conf/env.sh"  2>/dev/null | awk -F'"' '{print $2}')
            local java_opts="$memory_opts"
        else
            # 获取 systemctl 中的 JAVA_HOME（最老版本的jar部署脚本）
            java_home=$(sudo systemctl cat "$service_name" 2>/dev/null | grep -o 'JAVA_HOME=[^ ]*' | awk -F'=' '{print $2}' | sed 's/"//g')
            if [ -n "$java_home" ]; then
                local memory_opts=$(sudo systemctl cat "$service_name" 2>/dev/null | grep 'JAVA_OPTS.*-Xms' | sed -n 's/.*\(-Xms[0-9]*m\).*\(-Xmx[0-9]*m\).*/\1 \2/p')
                local java_opts="$memory_opts"
            else
                echo -e "${RED}Error: JAVA_HOME not found in either daemon.sh or systemctl configuration.${NC}"
                exit 1
            fi
        fi
    fi

    output=$(bak_directory "$daemon_dir")
    # 将 output 中的换行符替换为分号，方便正确处理
    clean_output=$(echo "$output" | tr '\n' ';')
    IFS=';' read -r project_bak_dir _ <<< "$clean_output"     #输出备份目录路径 *_bak
    # 读取第二个值到original_dir变量
    IFS=';' read -r _ original_dir <<< "$clean_output"  #输出原始目录名字
    if [[ -n "$java_home" ]] && [[ -n "$memory_opts" ]] && [[ -n "$jar_file" ]] && [[ -n "$service_name" ]]; then
        printf "开始升级：${GREEN}%s${NC}\n" "$original_dir"
        sudo systemctl daemon-reload
        sudo systemctl stop "$service_name"
        echo -e "正在停止：${GREEN}${service_name}${NC}"
        waiting_logic
        # sleep 15  
        cd "$work_directory" || exit
        export bakJarMaxNum=10
        export app_booter=root
        export sudo_user=root
        export install_code=new
        export basedir=/gqtian/jarapps
        export JAVA_HOME="$java_home"
        export java_opts="$java_opts"
        export service_file="$service_registration_file"
        export APP_NAME="$app_name"
        export jar_file="$jar_file"
        export jarappsdir="$project_dir"
        export JAVA_FIXED_OPTS="-Djava.security.egd=file:///dev/urandom -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=./logs/heapdump.hprof"
        export JAVA_OPTS="-server $java_opts $JAVA_FIXED_OPTS"
        export updata_jar_config_dir="config/"
        export updata_jar_models_dir="models/"
        #+ local unmodified_jar_service_file=/linkcld/jarapps/portal-ls-3066/exec/conf/jar.serivce
        #+ local service_registration_file=/usr/lib/systemd/system/portal-ls-3066.service
        export jar_dir=""
        #export jar_config_dir="$jar_config_dir"
        # export jar_db_dir="db"
        # export jar_docker_dir="docker"
        # export jar_docs_dir="docs"
        # mapfile -t jar_properties_file < <(find . -maxdepth 1 -name "*.properties" -type f)
        # export jar_properties_file
        source $work_directory/scripts/bin/install_jar_init.sh              
        install_jar_pre
        install_jar
        setChmodPermission
        conf_service_manage >/dev/null 2>&1   #丢掉conf_service_manage的Info: will config jar service manage script next step输出
        echo -e "修改完成：${GREEN}$service_name${NC}"
        sudo systemctl daemon-reload &> /dev/null
        sudo systemctl start "$service_name" &> /dev/null
        echo -e "正在启动：${GREEN}$service_name${NC}"
        waiting_logic  #sleep 15     
        if sudo systemctl is-active --quiet "$service_name"; then
            echo -e "启动成功：${GREEN}$service_name${NC}"
            echo -e "${YELLOW}----------------------------------------------- ${NC}"
            if [[ -d "${daemon_dir}_Bak" ]]; then
                sudo rm -rf "${daemon_dir}_Bak"   #执行rm时候必须校验非空
            fi
            return 0
        else
            echo -e "启动失败：${RED}$service_name${NC}"
            echo -ne "正在回滚：${YELLOW}${service_name}${NC}"
            if [[ -d "${daemon_dir}_Bak" ]]; then
                sudo rm -rf "$daemon_dir"
                sudo mv "${daemon_dir}_Bak" "$daemon_dir"
            fi
            sudo systemctl daemon-reload &> /dev/null
            sudo systemctl restart "$service_name" &> /dev/null
            waiting_logic    #等待15s        
            if sudo systemctl is-active --quiet "$service_name"; then
                echo -e "回滚成功：${GREEN}$service_name${NC}"
                echo -e "${YELLOW}----------------------------------------------- ${NC}"
                return 0
            else
                echo -e "回滚失败：${RED}$service_name${NC}"
                sudo echo "$daemon_dir" >> "$services_failed_start_file"
                return 1
            fi
        fi        
    else
        sudo echo "$daemon_dir" >> "$daemon1_file"
    fi
}

# 处理存在和不存在 daemon.sh 的情况
handle_directories() {
    local original_directories=("$@")  # 传递的原始目录数组
    local all_directories=("${original_directories[@]}")  # 存储所有目录
    local total_directories="${#all_directories[@]}"
    local processed_count=0
    local success_count=0
    local fail_count=0
    sure_not

    for daemon_dir in "${original_directories[@]}"; do
        local jar_file=$(basename "$(find "$daemon_dir/" -maxdepth 1 -type f -name '*.jar')")  # 获取目录下的 .jar 文件名
        local app_name="$(basename "$daemon_dir")"    
        local service_name=$(grep -o 'status [^ ]*' "$daemon_dir/status.sh" | sed 's/status //') #构建 service 文件名
        if call_jar_deployed_script_upgrade "$daemon_dir" "$jar_file" "$service_name" "$daemon1_file"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        ((processed_count++))
    done

    if [ "$processed_count" -eq "$total_directories" ]; then
        echo "所有匹配的jar项目脚本已处理完成"
        echo -e "升级成功：${GREEN} $success_count ${NC}个"
        echo -e "升级失败：${RED} $fail_count ${NC}个"
    fi
    if [ "$fail_count" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# 定义函数：主程序逻辑
main() {
    cd "$directory" || exit  # 切换到目标目录，如果失败则退出
    # directories=()  # 初始化满足条件的目录数组
    # directories=("${tmp_updata_zip_dir_list:-}")  # 如果环境变量 tmp_updata_zip_dir_list 存在，则将其值赋给 directories；否则为空数组
    # # 确保 directories 是一个真正的空数组
    # directories=("${directories[@]//#/}")  # 移除数组中的空字符串

    # 初始化满足条件的目录数组
    directories=()  
    # 如果环境变量 tmp_updata_zip_dir_list 存在，则将其值赋给 directories；否则为空数组
    if [ -n "${tmp_updata_zip_dir_list}" ]; then
        IFS=' ' read -r -a directories <<< "$tmp_updata_zip_dir_list"
    else
        directories=()
    fi

    filtered_directories=()  # 初始化未满足条件的目录数组
    original_directories=()  # 初始化新目录数组

    if [ ${#directories[@]} -eq 0 ]; then
        # 遍历目录并检查条件
        while IFS= read -r -d '' dir; do  # 读取目录列表
            if [ "$dir" != "." ]; then  # 排除当前目录
                full_path="$(realpath "$dir")"  # 获取目录的绝对路径
                if check_directory_conditions "$full_path"; then  # 检查目录是否满足条件
                    directories+=("$full_path")  # 将满足条件的目录添加到数组中
                else
                    filtered_directories+=("$full_path")  # 将未满足条件的目录添加到数组中
                fi
            fi
    # 查找当前目录下的所有子目录    使用bash执行  sh不支持当前写法    
        done < <(find . -maxdepth 1 -type d -print0)  

        # 输出未满足条件的目录
        output_filtered_directories  # 调用函数输出未满足条件的目录

        # 输出满足条件和不满足条件的目录
        echo "满足匹配条件的目录："  # 输出满足条件的目录信息
        printf "${GREEN}%s${NC}\n" "${directories[@]}"  # 打印目录列表

        echo "不满足匹配条件的目录(将不做任何修改，自行对服务进行判断，已输出${jar_upgrade_log_dir}目录)："  # 输出不满足条件的目录信息
        printf "${RED}%s${NC}\n" "${filtered_directories[@]}"  # 打印目录列表
    fi
    # 处理存在和不存在 daemon.sh 的情况
    handle_directories "${directories[@]}"  # 调用函数处理新目录
}

main