#!/bin/bash
#

## Set JAVA_HOME
java_home=

check_java_version() {
    if [ -z "$java_home" ]; then
        java_home=/usr/java/default
    fi
    if [ ! -d "$java_home" ]; then
        echo ""
        return 1
    fi
    java_home=$(echo "$java_home" |sed 's/^[[:blank:]]*//g' |sed 's/[[:blank:]]*$//g' |sed 's#/*$##g')
    java_version=$("$java_home"/bin/java -version 2>&1 )
    java_version=$?
    if [ $java_version -eq 0 ]; then
        echo "$java_home"
        return 0
    else
        echo ""
        return 1
    fi
}

ls_java_home() {
    jdk="$(ls -d /usr/java/jdk* 2> /dev/null |sed -n '1p')"
    if [ -n "$jdk" ]; then
        java_home="$jdk"
        check_java_version
    fi
}

read_java_home() {
    while true; do
        read -p "Please input JAVA_HOME path: e|E=(exit)|JAVA_HOME(jdk)=" ch
        if [ -z "$ch" ]; then
            echo -e "\033[31mError: \033[0mInput can't be null"
            continue
        elif [ "$ch" = "e" -o "$ch" = "E" ]; then
            echo -e "\033[33mWarn: \033[0mThe installation is interrupted"
            exit 1
        elif [[ "$ch" =~ [[:blank:]]+ ]]; then
            echo -e "\033[31mError: \033[0mInput can't include blank"
            continue
        fi
        java_home="$ch"
        java_home=$(check_java_version)
        if [ -z "$java_home" ]; then
            echo -e "\033[31mError: \033[0m$ch isn't valid jdk"
            continue
        else
            return 0
        fi
    done
}

main_java_home() {
    java_home=$(check_java_version)
    if [ -z "$java_home" ]; then
        java_home=$(ls_java_home)
        if [ -z "$java_home" ]; then
            read_java_home
        fi
    fi
}

