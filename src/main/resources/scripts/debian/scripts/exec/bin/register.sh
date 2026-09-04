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
checkStartupShutdownScriptPresence

echo "sudo systemctl start ${APP_NAME}"|sudo tee "$jarappsdir/"startup.sh > /dev/null
echo "sudo systemctl status ${APP_NAME} --no-pager"|sudo tee "$jarappsdir/"status.sh > /dev/null
echo "sudo systemctl stop ${APP_NAME}"|sudo tee "$jarappsdir/"shutdown.sh > /dev/null
echo "sudo systemctl restart ${APP_NAME}"|sudo tee "$jarappsdir/"restart.sh > /dev/null
# 调试启停使用与正式服务相同的运行用户
echo -e '#!/bin/bash\nexport DEBUG=true\nsudo -u '"${app_booter}"' ./bin/daemon.sh start' | sudo tee "$jarappsdir/"debug_startup.sh > /dev/null
echo -e '#!/bin/bash\nexport DEBUG=true\nsudo -u '"${app_booter}"' ./bin/daemon.sh stop' | sudo tee "$jarappsdir/"debug_shutdown.sh > /dev/null

sudo rm -f "$jarappsdir/"*.bat

[ -n "$sudo_group" ] && sudo chown "${sudo_user}":"${sudo_group}" "$jarappsdir/"{startup.sh,status.sh,shutdown.sh,restart.sh,debug_startup.sh,debug_shutdown.sh} &>/dev/null \
|| sudo chown "${sudo_user}" "$jarappsdir/"{startup.sh,status.sh,shutdown.sh,restart.sh,debug_startup.sh,debug_shutdown.sh} &>/dev/null
sudo chmod 755 "$jarappsdir/"{startup.sh,status.sh,shutdown.sh,restart.sh,debug_startup.sh,debug_shutdown.sh} &>/dev/null

sudo chmod -R 755 "$jarappsdir/bin/"
sudo chown -R ${app_booter}:${app_booter} "$jarappsdir/bin/"

if [ -n "$after_service" ]; then
    sudo sed -i '/^After=/c\After=network.target '"${after_service}"'' "$unmodified_jar_service_file"
fi
sudo sed -i '/^\# Systemd unit file for/c\# Systemd unit file for '"${APP_NAME}"'' "$unmodified_jar_service_file"
sudo sed -i '/^Description=/c\Description=jarapps '"${jar_file}"'' "$unmodified_jar_service_file"
sudo sed -i '/^WorkingDirectory=/c\WorkingDirectory='"$jarappsdir"'' "$unmodified_jar_service_file"
sudo sed -i '/^ExecStart=/c\ExecStart='"$service_file"' start' "$unmodified_jar_service_file"
sudo sed -i '/^ExecStop=/c\ExecStop='"$service_file"' stop' "$unmodified_jar_service_file"
sudo sed -i '/^ExecReload=/c\ExecReload='"$service_file"' restart ' "$unmodified_jar_service_file"

sudo sed -i '/^User=/c\User='"$app_booter"'' "$unmodified_jar_service_file"
sudo sed -i '/^Group=/c\Group='"$app_booter"'' "$unmodified_jar_service_file"

if [ -d /lib/systemd/system ]; then
    systemd_unit_dir=/lib/systemd/system
else
    systemd_unit_dir=/usr/lib/systemd/system
fi
service_file="${systemd_unit_dir}/${APP_NAME}.service"
sudo \cp "$unmodified_jar_service_file" "$service_file"
sudo chmod 644 "$service_file"
sudo systemctl daemon-reload
sudo systemctl enable "${APP_NAME}".service &> /dev/null

echo -e "\033[32mSuccess: Re register ${APP_NAME} OK\033[0m"
