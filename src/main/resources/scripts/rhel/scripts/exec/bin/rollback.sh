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
old_jar_file="$jar_file"

old_jar_file_md5=$(sudo md5sum "$APP_HOME/$old_jar_file" 2>/dev/null|cut -d" " -f1)

# find xxx.jar or xxx.zip in ./
jar_file_path="$(readlink ../bak/rollback 2>/dev/null)"
if [ -z "$jar_file_path" -o ! -f "$jar_file_path" ]; then
    echo -e "\033[31mError: \033[0mthe jar_file for rollback does not exist"
    exit 1
fi

jar_file_md5=""
jar_file_md5=$(sudo md5sum "$jar_file_path" 2>/dev/null|cut -d" " -f1)
if [ -n "$old_jar_file_md5" -a -n "$jar_file_md5" -a "$old_jar_file_md5" == "$jar_file_md5" ]; then
    echo -e "\033[33mWarn: \033[0m$old_jar_file is same with rollback version $jar_file_path ! needn't rollback"
    exit 1
fi
jar_file=" "
jar_file="$(basename "$jar_file_path")"
jar_file="$(echo "$jar_file"|awk -F"_20" '{print $1}')"
jar_prefix="$(echo "`basename "$jar_file"`"|sed -rn 's/\-[0-9]+\..*$//p')"
old_jar_prefix="$(echo "$old_jar_file"|sed -rn 's/\-[0-9]+\..*$//p')"

if [ -n "$jar_prefix" -a -n "$old_jar_prefix" -a "$jar_prefix" != "$old_jar_prefix" ]; then
    echo -e "\033[31mError: \033[0m$jar_file_path and $old_jar_file are different services"
    exit 1
fi

echo -e "\033[32mInfo: \033[0mstart to update......"
echo "Please wait. $APP_NAME stopping..."
if [ -f ../shutdown.sh ]; then
    ../shutdown.sh 2> /dev/null
else
    sudo service "$APP_NAME" stop 2> /dev/null
fi
echo "$APP_NAME stopped"
sleep 2
sudo mkdir -p ../bak
sudo chmod 777 ../{bak,exec} &> /dev/null
sudo rm -f "$APP_HOME/$old_jar_file"
sudo unlink ../bak/rollback &> /dev/null
sudo mv "$jar_file_path" "$APP_HOME/$jar_file"
sudo chown "${app_booter}":"${app_booter}" "$APP_HOME/$jar_file"
sudo chown "${app_booter}":"${app_booter}" "$APP_HOME"
sudo chmod -R 775 ../{config,logs} &> /dev/null
sudo chmod 755 ../exec/{bin,conf} &>/dev/null
sudo chmod 500 "$APP_HOME/$jar_file" &> /dev/null
sudo chown -R "${app_booter}":"${app_booter}" ../{config,logs} &> /dev/null
sudo sed -i '/^jar_file=/c\jar_file=\"'"$jar_file"'\"' "$APP_HOME"/exec/conf/env.sh

echo "Please wait. $APP_NAME starting..."
if [ -f ../startup.sh ]; then
    ../startup.sh
else
    sudo service "$APP_NAME" start
fi
if [ $? -eq 0 ]; then
    echo "$APP_NAME started"
    echo -e "\033[32mSuccess: \033[0mjar update successfully"
else
    echo -e "\033[31mError: \033[0mupdate completed, but start jar service failed"
fi

main_script="$APP_HOME/exec/main.sh"
[ -f "$main_script" ] && sudo sed -i '/^jar_file=/c\jar_file=\"'"$jar_file"'\"' $main_script

sleep 1
if [ -f ../status.sh ]; then
    ../status.sh
    exit $?
else
    sudo service "$APP_NAME" status
    exit $?
fi
