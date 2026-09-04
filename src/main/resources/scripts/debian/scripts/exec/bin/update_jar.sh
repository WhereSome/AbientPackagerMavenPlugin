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
jar_file=""
jar_file_md5=""

jar_file_dir="./"
jar_file="$(find $jar_file_dir -maxdepth 1 -name "*.jar" -a -type f 2>/dev/null)"

if [ -z "$jar_file" -o ! -f "$jar_file" ]; then
    echo -e "\033[31mError: \033[0mthe jar_file for update does not exist in $(pwd)"
    exit 1
fi

jar_file_md5=$(sudo md5sum "$jar_file" 2>/dev/null|cut -d" " -f1)
if [ -n "$old_jar_file_md5" -a -n "$jar_file_md5" -a "$old_jar_file_md5" == "$jar_file_md5" ]; then
    echo -e "\033[33mWarn: \033[0m$old_jar_file is same with $jar_file ! needn't update"
    sudo rm -f "$jar_file_dir/$jar_file"
    exit 1
fi

jar_file="$(basename "$jar_file")"
jar_prefix="$(echo "$jar_file"|sed -rn 's/\-[0-9]+\..*$//p')"
old_jar_prefix="$(echo "$old_jar_file"|sed -rn 's/\-[0-9]+\..*$//p')"

if [ -n "$jar_prefix" -a -n "$old_jar_prefix" -a "$jar_prefix" != "$old_jar_prefix" ]; then
    echo -e "\033[31mError: \033[0m$jar_file and $old_jar_file are different services"
    sudo rm -f "$jar_file_dir/$jar_file"
    exit 1
fi

echo -e "\033[32mInfo: \033[0mstart to update......"
date_suffix=$(date '+%Y%m%d%H%M%S')
echo "Please wait. $APP_NAME stopping..."
if [ -f ../shutdown.sh ]; then
    ../shutdown.sh 2> /dev/null
else
    sudo service $APP_NAME stop 2> /dev/null
fi
echo "$APP_NAME stopped"
sleep 2
sudo mkdir -p ../bak
sudo chmod 777 ../{bak,exec} &> /dev/null
old_jar_bak="$(basename "$old_jar_file")_$date_suffix"
sudo mv "$APP_HOME/$old_jar_file" ../bak/"$old_jar_bak"
sudo ln -sf ../bak/"$old_jar_bak" ../bak/rollback &> /dev/null
sudo mv "$jar_file" "$APP_HOME/$jar_file"
sudo chown "${app_booter}":"${app_booter}" "$APP_HOME/$jar_file"
sudo chown "${app_booter}":"${app_booter}" "$APP_HOME"
# sudo find "$APP_HOME" -maxdepth 1 -type f -not -name "*.sh" -exec chown "${app_booter}":"${app_booter}" {} +
sudo chmod -R 775 ../{config,logs} &> /dev/null
sudo chmod 755 ../exec/{bin,conf} &>/dev/null
sudo chmod 500 "$APP_HOME/$jar_file" &> /dev/null
sudo chown -R "${app_booter}":"${app_booter}" ../{config,logs} &> /dev/null

sudo sed -i '/^jar_file=/c\jar_file=\"'"$jar_file"'\"' "$APP_HOME"/exec/conf/env.sh

echo "Please wait. $APP_NAME starting..."
if [ -f ../startup.sh ]; then
    ../startup.sh
else
    sudo service $APP_NAME start
fi
if [ $? -eq 0 ]; then
    echo "$APP_NAME started"
    echo -e "\033[32mSuccess: \033[0mjar update successfully"
else
    echo -e "\033[31mError: \033[0mupdate completed, but start jar service failed"
fi

main_script="$APP_HOME/exec/main.sh"
[ -f "$main_script" ] && sudo sed -i '/^jar_file=/c\jar_file=\"'"$jar_file"'\"' "$main_script"

bakJarNum=0
rmJarNum=0
bakJarNum=$(sudo ls ../bak/*\.jar_* 2>/dev/null|wc -l)
echo "$bakJarMaxNum"|grep -sq "^[1-9][0-9]*$" || bakJarMaxNum=10
if [ "$bakJarNum" -gt "$bakJarMaxNum" ]; then
    rmJarNum=$((bakJarNum - bakJarMaxNum))
    for rmJarFile in $(sudo ls -t ../bak/*\.jar_* 2>/dev/null|tail -n $rmJarNum); do
        [ -f "$rmJarFile" ] && sudo rm -f "$rmJarFile"
    done
fi

sleep 1
if [ -f ../status.sh ]; then
    ../status.sh
    exit $?
else
    sudo service "$APP_NAME" status
    exit $?
fi
