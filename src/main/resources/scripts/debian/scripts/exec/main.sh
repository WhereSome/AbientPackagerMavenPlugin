#!/bin/bash
#

# vars
curDir=$(dirname "$0")
APP_HOME=$(cd "$curDir"/..; pwd)
export APP_HOME

source $APP_HOME/exec/conf/env.sh

if [ -z "$bakJarMaxNum" -o -z "$APP_NAME" -o -z "$service_file" -o -z "$jar_file" -o -z "$service_registration_file" ]; then
    echo "Error: ./main.sh's vars bakJarMaxNum, APP_NAME, service_file, jar_file, service_registration_file is null. please set vars first"
    exit 1
fi


if [ ! -x /usr/bin/sudo ]; then
    echo "Error: command /usr/bin/sudo isn't existed"
    exit 1
fi

if ! sudo -l &> /dev/null; then
    echo "Error: you must switch root or sudo user"
    exit 1
fi

# if [ ! -f ./bin/exec.sh ]; then
#     echo "Error: bin/exec.sh isn't existed"
#     exit 1
# elif ! sudo chmod 755 ./bin/exec.sh; then
#     echo "Error: you must switch root or sudo user"
#     exit 1
# fi


showManual() {
cat <<-EOF
+-------------------------------------------+
|                                           |
|         ======================            |
|           jar service manage              |
|         ======================            |
|                                           |
|     1 update jar file      <input 1>      |
|     2 modify JAVA_OPTS     <input 2>      |
|     3 uninstall service    <input 3>      |
|     4 re register          <input 4>      |
|     5 rollback jar file    <input 5>      |
|     0 exit                 <input 0|e|E > |
|                                           |
+-------------------------------------------+
EOF
}

sudo chmod 755 ./bin/
ch="${shortcut_instruction_ch:-}"
while true; do
    # target: new or exist
    exec_tag=""
    showManual
    if [ -z "$ch" ]; then
        read -p "input your choice: 1|2|3|4|5|0|e|E >>: " ch
    fi
    case $ch in
    1)
        exec_tag="./bin/update.sh"
        echo
        if [ ! -f $exec_tag ]; then
            echo "Error: $exec_tag isn't existed"
            continue
        fi
        break
        ;;
    2)
        exec_tag="./bin/modify.sh"
        echo
        if [ ! -f $exec_tag ]; then
            echo "Error: $exec_tag isn't existed"
            continue
        fi
        break
        ;;
    3)
        exec_tag="./bin/unregister.sh"
        echo
        if [ ! -f $exec_tag ]; then
            echo "Error: $exec_tag isn't existed"
            continue
        fi
        break
        ;;
    4)
        exec_tag="./bin/register.sh"
        echo
        if [ ! -f $exec_tag ]; then
            echo "Error: $exec_tag isn't existed"
            continue
        fi
        sudo chmod 755 $exec_tag
        $exec_tag
        exit $?
        ;;
    5)
        exec_tag="./bin/rollback.sh"
        echo
        if [ ! -f $exec_tag ]; then
            echo "Error: $exec_tag isn't existed"
            continue
        fi
        break
        ;;
    0|e|E)
        echo -e "\033[32mInfo: \033[0mnothing done"
        exit 9
        ;;
    "")
        echo -e "\033[31mError: \033[0minput can't null. please input again"
        echo
        continue
        ;;
    *)
        echo -e "\033[31mError: \033[0minput error. usage: 1|2|3|4|5|0|e|E"
        echo
        continue
        ;;
    esac
done
ch=""
script_file="$exec_tag"

if [ -z "$script_file" ]; then
    echo "Error: script_file is null. please set vars first"
    exit 1
fi

if [ ! -f "$script_file" ]; then
    echo "Error: $script_file isn't existed"
    exit 1
fi

sudo chmod 755 $script_file

# unregister service
if echo "$script_file"|grep -sq "./bin/unregister\.sh$"; then
    "$script_file" "$APP_HOME" "$bakJarMaxNum" "$APP_NAME" "$service_file" "$jar_file" "$service_registration_file"
    exit $?
fi

# modify java_opts
if echo "$script_file"|grep -sq "./bin/modify\.sh$"; then
    "$script_file" "$APP_HOME" "$bakJarMaxNum" "$APP_NAME" "$service_file" "$jar_file" "$service_registration_file"
    exit $?
fi

# update jar file
if echo "$script_file"|grep -sq "./bin/update\.sh$"; then
    "$script_file" "$APP_HOME" "$bakJarMaxNum" "$APP_NAME" "$service_file" "$jar_file" "$service_registration_file"
    exit $?
fi

# rollback jar file
if echo "$script_file"|grep -sq "./bin/rollback\.sh$"; then
    "$script_file" "$APP_HOME" "$bakJarMaxNum" "$APP_NAME" "$service_file" "$jar_file" "$service_registration_file"
    exit $?
fi
