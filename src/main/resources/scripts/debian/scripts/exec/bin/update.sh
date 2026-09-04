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

update_file_num=$(find $jar_file_dir -maxdepth 1 -name "*.jar" -a -type f 2>/dev/null|wc -l)
if [ "$update_file_num" -gt 1 ]; then
    echo -e "\033[31mError: \033[0mtoo many xxx.jar in $(pwd)"
    exit 1
elif [ "$update_file_num" -eq 0 ]; then
    update_file_num=$(find $jar_file_dir -maxdepth 1 -name "*.zip" -a -type f 2>/dev/null|wc -l)
    if [ "$update_file_num" -eq 0 ]; then
        echo -e "\033[31mError: \033[0mcan't find xxx.jar or xxx.zip in $(pwd)"
        exit 1
    elif [ "$update_file_num" -gt 1 ]; then
        echo -e "\033[31mError: \033[0mtoo many xxx.zip in $(pwd)"
        exit 1
    fi
    # jar_zip_file="$(find $jar_file_dir -maxdepth 1 -name "*.zip" -a -type f 2>/dev/null)"
    source "$APP_HOME"/exec/bin/update_zip.sh
else
    # jar_file="$(find $jar_file_dir -maxdepth 1 -name "*.jar" -a -type f 2>/dev/null)"
    source "$APP_HOME"/exec/bin/update_jar.sh
fi
