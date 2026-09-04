#!/bin/bash

## if $basedir/$APP_NAME is exist, then ask update jar file ?
updateJarFile() {
    while true; do
        echo
        echo -e "\033[31mAttention: $basedir/$ch is exist, are you sure to update the jar file ?\033[0m"
        read -p "(y|Y=update jar file) | (e|E=exit): " update_c
        if [ -z "$update_c" ]; then
            echo -e "\033[31mError: \033[0minput can't be null"
            continue
        elif [ "$update_c" == "y" -o "$update_c" == "Y" ]; then
            tmp_current_version="$(sed -n '2p' scripts/exec/main.sh 2>/dev/null|grep -so "Version:.*$"|awk '{print $2}')"
            tmp_exec_version_num="$(echo "$tmp_exec_version"|tr '.' '0')"
            tmp_current_version_num="$(echo "$tmp_current_version"|tr '.' '0')"
            tmp_version_check=""
            [ -n "$tmp_exec_version_num" -a -n "$tmp_current_version_num" ] && tmp_version_check="$(expr "$tmp_current_version_num" - "$tmp_exec_version_num" 2>/dev/null)"
            if [ -n "$tmp_version_check" -a "$tmp_version_check" -gt 0 ]; then
                sudo \cp -f scripts/exec/bin/* "$basedir/$ch/"exec/bin/ &>/dev/null
                sudo \cp -f scripts/exec/conf/* "$basedir/$ch/"exec/conf/ &>/dev/null
                sudo chmod 777 "$basedir/$ch/"exec &>/dev/null
                sudo chmod 755 "$basedir/$ch/"exec/{bin,conf} &>/dev/null
                if [ "$tmp_exec_version_num" -lt 10103 ]; then
                    sudo sed -i '11,$d' "$basedir/$ch/"exec/main.sh
                    sudo sed -n '11,$p' scripts/exec/main.sh |sudo tee -a "$basedir/$ch/"exec/main.sh >/dev/null
                fi
                sudo \cp -f scripts/exec/main.sh "$basedir/$ch/"exec/ &>/dev/null
                sudo sed -i '2c\# Version: '"$tmp_current_version"'' "$basedir/$ch/"exec/main.sh &>/dev/null
                sudo \cp -f scripts/exec/update.sh "$basedir/$ch/"exec/ &>/dev/null
                sudo \cp -f scripts/exec/rollback.sh "$basedir/$ch/"exec/ &>/dev/null
                sudo \cp -f scripts/CHANGELOG.md "$basedir/$ch/"exec/ &>/dev/null
                sudo \cp -f scripts/README.md "$basedir/$ch/"exec/ &>/dev/null
                sudo chmod 755 "$basedir/$ch/"exec/*.sh &>/dev/null
            fi

            if [ -f "$jar_dir" ]; then
                sudo \cp -rf "$jar_dir" "$basedir/$ch/exec" &> /dev/null
                sudo rm -fr ./tmp &> /dev/null
            elif [ -d "$jar_dir" ]; then
                sudo mv "$jar_dir/$jar_file" "$basedir/$ch/exec" &> /dev/null
                sudo rm -fr ./tmp &> /dev/null
            else
                echo -e "\033[31mError: \033[0mcan't get jar file"
                exit 1
            fi
            dir="$basedir/$ch/exec"
            while [ "$dir" != "/" ]; do
                sudo chmod o+rx "$dir" &>/dev/null
                dir="$(dirname "$dir")"
            done
            cd "$basedir/$ch/exec" || exit
            ./main.sh <<<1
            update_rst_code=$?
            [ -f "$basedir/$ch/exec/$jar_file" ] && sudo rm -f "$basedir/$ch/exec/$jar_file"
            [ $update_rst_code -eq 0 ] && exit 100 || exit $update_rst_code
        elif [ "$update_c" == "e" -o "$update_c" == "E" ]; then
            echo -e "\033[33mWarn: \033[0mThe installation is interrupted"
            exit 1
        else
            echo -e "\033[31mError: \033[0mUsage y|Y|e|E"
            continue
        fi
    done
}

# for check discompress jar file
check_jar_file() {
    if [ $? -ne 0 ]; then
        echo -e "\033[31mError: \033[0m$ch format not right ! Can't decompression"
        exit 1
    fi
    jar_dir="$(ls -d ./tmp/* 2>/dev/null)"
    if [ -z "$jar_dir" ]; then
        echo -e "\033[31mError: \033[0m$ch format not right ! Can't decompression"
        exit 1
    fi
    if [ -n "$(ls "$jar_dir"/*.jar 2> /dev/null)" ]; then
        jar_file="$(ls "$jar_dir"/*.jar 2> /dev/null |xargs -I {} basename {})"
    elif [ -n "$(ls "$jar_dir"/bin/*.jar 2> /dev/null)" ]; then
        jar_file="$(ls "$jar_dir"/bin/*.jar 2> /dev/null |xargs -I {} basename {})"
        jar_file="bin/$jar_file"
    else
        echo -e "\033[31mError: \033[0mtar packet havn't jar file"
        exit 1
    fi
}
read_jar_file() {
    if [ "$(sudo ls ./*.jar 2> /dev/null|wc -l)" -eq 1 ]; then
        jar_default_file="$(sudo ls ./*.jar 2> /dev/null |xargs -I {} basename {})"
        read_jar_file_path
    else
        echo -e "\033[31mInfo: \033[0mCannot get in the current directory ./*. jar or ./*.jar is too many Or does not exist"
        read_jar_file_path
    fi
}

read_jar_file_path() {
    while true; do
        jar_file=""
        jar_packet=""
        if [ -z "$jar_default_file" -o ! -f "$jar_default_file" ]; then
            read -p "Please input jar file path: e|E=(exit)|jar_file_path(zip|tar|jar)=" ch
        else
            ch="$jar_default_file"
        fi

        if [ "$ch" = "e" -o "$ch" = "E" ]; then
            echo -e "\033[33mWarn: \033[0mThe installation is interrupted"
            exit 1
        fi
        if [ -z "$ch" ]; then
            echo -e "\033[31mError: \033[0mInput can't be null"
            jar_default_file=""
            continue
        elif [ ! -f $ch ]; then
            echo -e "\033[31mError: \033[0mjar_file $ch isn't exist"
            jar_default_file=""
            continue
        elif [[ ! "$ch" =~ \.(tar|tgz|tar\.gz|zip|jar)$ ]]; then
            echo -e "\033[31mError: \033[0mjar_file type must be .zip|.tar|.tgz|.jar|.tar.gz"
            jar_default_file=""
            continue
        fi

        jar_packet="$ch"

        sudo mkdir -p ./tmp
        sudo chmod 777 ./tmp
        sudo rm -fr ./tmp/*

        if [[ "$ch" =~ \.(tar|tgz)(\..*)?$ ]]; then
            sudo tar xf $ch -C ./tmp &> /dev/null
            check_jar_file
            return 0
        elif [[ "$ch" =~ \.zip$ ]]; then
            sudo unzip -d ./tmp/ $ch &> /dev/null
            check_jar_file
            return 0
        elif [[ "$ch" =~ \.jar$ ]]; then
            jar_dir="$ch"
            jar_file="$(basename $ch)"
            return 0
        fi
    done
}

##


