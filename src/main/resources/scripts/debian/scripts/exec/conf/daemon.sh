#!/bin/bash

curDir=$(dirname "$0")
APP_HOME=$(cd "$curDir"/..; pwd)

source $APP_HOME/exec/conf/env.sh

LOG_DIR="$APP_HOME/logs"
LOG_FILE="$LOG_DIR/$APP_NAME".out
PID_DIR="$APP_HOME/pid"
PID_FILE="$PID_DIR/$APP_NAME".pid

JDK17_JAVA_OPTS="--add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.io=ALL-UNNAMED --add-opens java.base/java.math=ALL-UNNAMED --add-opens java.base/java.net=ALL-UNNAMED --add-opens java.base/java.nio=ALL-UNNAMED --add-opens java.base/java.security=ALL-UNNAMED --add-opens java.base/java.text=ALL-UNNAMED --add-opens java.base/java.time=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED --add-opens java.base/jdk.internal.access=ALL-UNNAMED --add-opens java.base/jdk.internal.misc=ALL-UNNAMED --add-opens=java.rmi/sun.rmi.transport=ALL-UNNAMED "
JDK21_JAVA_OPTS="--add-modules jdk.incubator.vector "

# JAVA_VERSION=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1)
get_java_version() {
    local version
    version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F '.' '{if ($1 == "1") print $2; else print $1}')
    echo "${version:-0}"  # 如果无法获取版本，默认返回 0
}
JAVA_VERSION=$(get_java_version)

if [[ JAVA_VERSION -ge 17 ]]; then
    JAVA_OPTS="$JAVA_OPTS $JDK17_JAVA_OPTS"
fi

if [[ JAVA_VERSION -ge 21 ]]; then
    JAVA_OPTS="$JAVA_OPTS $JDK21_JAVA_OPTS"
fi

get_pid() {
    if [ -f "$PID_FILE" ]; then
        cat "$PID_FILE"
    else
        echo ""
    fi
}

check_status() {
    local pid=$(get_pid)
    if [ -n "$pid" ] && ps -p $pid > /dev/null; then
        echo "$APP_NAME is running with PID $pid."
        return 0
    else
        echo "$APP_NAME is not running."
        return 1
    fi
}

kill_app() {
    local pid=$(get_pid)
    if check_status; then
        echo "Attempting to stop $APP_NAME (PID $pid)..."
        kill "$pid"
        
        # 等待一段时间检查进程是否终止
        for i in {1..45}; do
            if ! ps -p $pid > /dev/null; then
                echo "$APP_NAME stopped successfully."
                break
            fi
            sleep 1
        done
        
        # 如果循环结束后进程仍未终止，则强制杀死
        if ps -p $pid > /dev/null; then
            echo "Force stopping $APP_NAME with kill -9"
            kill -9 "$pid"
        fi
        
        rm -f "$PID_FILE"
    else
        echo "$APP_NAME is not running."
    fi
}
start_app() {
    if check_status; then
        echo "$APP_NAME is already running."
        return
    fi

    if [ -e "$LOG_FILE" ] && [ $(stat -c%s $LOG_FILE ) -gt 10485760 ]; then
        echo "" > "$LOG_FILE"
    fi

    if [ -n "$DEBUG" ]; then
        nohup java ${JAVA_OPTS} -jar "${APP_HOME}/${jar_file}" >>"$LOG_FILE" 2>&1 & echo $! > "$PID_FILE"
    else
        nohup java ${JAVA_OPTS} -jar "${APP_HOME}/${jar_file}" >/dev/null 2>>"$LOG_FILE" & echo $! > "$PID_FILE"
    fi

    
    echo "$APP_NAME started successfully. Check $LOG_FILE for logs."
}

restart_app() {
    kill_app
    sleep 2 # 等待一段时间确保应用完全停止
    start_app
}

usage() {
    echo "Usage: $0 {start|stop|restart|status}"
}

case "$1" in
    start)
        start_app
        ;;
    stop)
        kill_app
        ;;
    restart)
        restart_app
        ;;
    status)
        check_status
        ;;
    *)
        usage
        ;;
esac
