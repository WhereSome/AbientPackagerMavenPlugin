#!/bin/bash

export GREEN='\033[0;32m'   # 定义绿色颜色代码
export RED='\033[0;31m'     # 定义红色颜色代码
export YELLOW='\033[1;33m'  # 定义黄色颜色代码
export NC='\033[0m'         # 恢复默认颜色

# 以 root 身份运行 jar 服务（不再创建/使用 bootapp）
export app_booter=root
export basedir=/gqtian/jarapps
export defaut_java_home=/usr/java/default
export after_service=""
export script_file=./scripts/bin/install_jar_init.sh
export install_code=""
export sudo_user=root

## 通用y/n配置确认函数
sure_not() {
    while true; do
        read -p "Please check variables is right ? (y|Y=sure)|(e|E=exit): " ch
        echo
        case $ch in
            [yY])
                break
                ;;
            [eE])
                echo -e "${YELLOW}Warn: The installation is interrupted${NC}"
                exit 1
                ;;
            *)
                echo -e "${RED}Error: Usage y|Y|e|E ${NC}"
                continue
                ;;
        esac
    done
}
