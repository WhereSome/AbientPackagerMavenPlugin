#!/bin/bash
#
## target: new or exist
check_var() {
    if [ -z "$sudo_user" ]; then
        echo -e "${RED}Error: sudo user isn't set. please set sudo_user first.. ${NC}"
        exit 1
    fi
    if ! id "$sudo_user" &>/dev/null; then
        echo -e "${YELLOW}Warn: ${sudo_user} isn't exist.. ${NC}"
        sudo_user="$app_booter"
        sudo_group="$app_booter"
    else
        opt_groupID="$(id -g "${sudo_user}" 2>/dev/null)"
        [ -n "$opt_groupID" ] && sudo_group=$(awk -F":" -v opt_id="$opt_groupID" '{if($3 == opt_id){print $1}}' /etc/group 2>/dev/null|sed -n '1p') || sudo_group=""
    fi
}

check_file() {
    if ! unzip -v &> /dev/null; then
        echo -e "${RED}Error:  ${NC}unzip is not installed"
    fi

    if [ "$(md5sum ./scripts/exec/main.sh |cut -d" " -f1)" != "1d1d7e78f508cdb159d532126e21649a" ]; then
        echo -e "${RED}Error: ${NC} ./scripts/exec/main.sh is changed"
        exit 1
    fi    
}

# check_file(){
#     if [ "$(ls ./scripts/exec/conf 2>/dev/null | wc -l)" -lt 3 ]; then
#         echo -e "${RED}Error: ${NC}./scripts/conf file isn't enough"
#         exit 1
#     fi

#     if [ $(ls ./scripts/bin 2>/dev/null|wc -l) -lt 2 ]; then
#         echo -e "${RED}Error: ${NC}./scripts/bin file isn't enough"
#         exit 1
#     fi

#     if [ "$(md5sum ./scripts/exec/main.sh |cut -d" " -f1)" != "1d1d7e78f508cdb159d532126e21649a" ]; then
#         echo -e "${RED}Error: ${NC} ./scripts/exec/main.sh is changed"
#         exit 1
#     fi
# }

check_yq() {
  if command -v yq &> /dev/null; then
    sudo yq --version > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo -e "${RED}Error: yq is not installed. Please go to ftp to download the yq script yourself (version)${NC}"
      exit 1
    fi
  else
    echo -e "${RED}Error: yq is not installed. Please go to ftp to download the yq script yourself (command)${NC}"
    exit 1
  fi
}

main_check() {
    check_var
    check_file
    check_yq
}

