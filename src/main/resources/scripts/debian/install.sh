#!/bin/bash
# Version: 1.3.0-ubuntu

GREEN='\033[0;32m'   # 定义绿色颜色代码
RED='\033[0;31m'     # 定义红色颜色代码
YELLOW='\033[1;33m'  # 定义黄色颜色代码
NC='\033[0m'         # 恢复默认颜色

if [ ! -x /usr/bin/sudo ]; then
    echo -e "${RED}: command /usr/bin/sudo isn't existed ${NC}"
    exit 1
fi

if ! sudo -l &> /dev/null; then
    echo -e "${RED}: The current user is not a sudo user or password is incorrect${NC}"
    exit 1
fi

if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    if [ "$ID" != "ubuntu" ] && ! echo " ${ID_LIKE} " | grep -qw debian; then
        echo -e "${YELLOW}Warn: this script is intended for Ubuntu/Debian, current OS: ${ID:-unknown}${NC}"
    fi
fi

if ! sudo chmod 755 ./scripts/bin/main.sh; then
    echo -e "${RED}: Settings './script/bin/main.sh' file permission failed${NC}"
    exit 1
fi

ensure_pkg() {
    local pkg="$1"
    local bin_name="${2:-$1}"
    if command -v "$bin_name" &> /dev/null; then
        return 0
    fi
    echo -e "${YELLOW}Info: ${bin_name} is not installed, installing via apt-get...${NC}"
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq; then
        echo -e "${RED}: apt-get update failed, please install ${pkg} manually${NC}"
        exit 1
    fi
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null; then
        echo -e "${RED}: failed to install ${pkg}${NC}"
        exit 1
    fi
}

# command 是 shell 内置命令，不能用 sudo 直接调用，否则会误报未安装
ensure_pkg rsync rsync
ensure_pkg unzip unzip
ensure_pkg iproute2 ss

# if [ "$(md5sum ./scripts/exec/main.sh |cut -d" " -f1)" != "c726992d3468a2f391b861f20673fe2f" ]; then
#     echo -e "${RED}Error: ${NC} ./scripts/exec/main.sh is changed"
#     exit 1
# fi

sudo cp -a ./scripts/exec/conf ./scripts/
sudo chmod 755 ./scripts/{bin,conf} &>/dev/null

#show choice manual
show_manual() {
cat <<-EOF
+-----------------------------------------------+
|                                               |
|            ======================             |
|             install jar    step1              |
|            ======================             |
|                                               |
|        1 new jar project       <input 1>      |
|        2 existed jar project   <input 2>      |
|        0 exit                  <input 0|e|E > |
|                                               |
+-----------------------------------------------+
EOF
}

while true; do
    # target: new or exist
    install_code=""
    
    show_manual
    read -p "input your choice: 1|2|0|e|E >>: " ch
    echo
    case $ch in
    1)
        install_code="new"
        sudo sed -i "s/^export install_code=.*/export install_code=$install_code/" ./scripts/bin/install_env.sh
        sudo ./scripts/bin/main.sh
        ;;
    2)
        install_code="update"
        sudo sed -i "s/^export install_code=.*/export install_code=$install_code/" ./scripts/bin/install_env.sh
        sudo ./scripts/bin/main.sh
        ;;
    0|e|E)
        echo -e "${GREEN}exit...${NC}" 
        exit 9
        ;;
    "")
        echo -e "${YELLOW}can't null. please input again ${NC}"
        continue
        ;;
    *)
        echo -e "${RED}input error. input 1|2|0|e|E${NC}" 
        continue
        ;;
    esac
    sleep 0.2
    read -p "EnterSpace..."
    echo
done
