#!/bin/bash

#执行非空校验
read_nonempty_input() {
    local var_name=$1
    local prompt=$2
    local input

    while true; do
        read -p "$prompt" input
        input=$(echo "$input" | tr -d ' ')  # 去除输入字符串中的空格
        if [[ -n "$input" ]]; then
            eval "$var_name=\$input"
            break
        else
            echo -e "${RED}Error: Input cannot be blank. Please try again. ${NC}"
        fi
    done
}
#不执行非空校验
read_input() {
    local var_name=$1
    local prompt=$2
    local input

    read -p "$prompt" input
    input=$(echo "$input" | tr -d ' ')  # 去除输入字符串中的空格
    eval "$var_name=\$input"

}

yml_modify() {
    sudo yq eval -i '.spring.profiles.active = "prod"' "$jar_config_file"
    sudo yml_spring_application_name="${yml_spring_application_name}" yq eval -i '.spring.application.name = env(yml_spring_application_name)' "$jar_config_file"
    if [ -n "$jar_config_file_port" ]; then 
        sudo jar_port="${jar_port}" yq eval -i '.server.port = env(jar_port)' "$jar_config_file"
    fi

    invalid_count=0
    db_type=""
    while [ $invalid_count -lt 2 ]; do
        read_nonempty_input "db_type" "Enter the database type (mysql/dm/oracle/h2/exit): "
        case $db_type in
            "mysql")
                read_nonempty_input "host" "Enter db_host(ip): "
                read_input "port" "Enter db_port(default:3306): "
                read_nonempty_input "database" "Enter database: "
                read_nonempty_input "username" "Enter username: "
                read_nonempty_input "password" "Enter password: "
                driver_class_name="com.mysql.cj.jdbc.Driver"
                url="jdbc:mysql://${host}:${port:-3306}/${database}?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&autoReconnect=true&connectTimeout=30000&socketTimeout=60000"
                database_platform="org.hibernate.dialect.MySQL8Dialect"
                echo -e "${GREEN}The modified url is: $url user:$username pwd:$password ${NC}"
                break
                ;;
            "dm")
                read_nonempty_input "host" "Enter db_host(ip): "
                read_input "port" "Enter db_port(default:5236): "
                read_nonempty_input "username" "Enter username: "
                read_nonempty_input "password" "Enter password: "
                driver_class_name="dm.jdbc.driver.DmDriver"
                url="jdbc:dm://${host}:${port:-5236}?autoReconnect=true&connectTimeout=30000&socketTimeout=60000"
                database_platform="org.hibernate.dialect.DmDialect"
                echo -e "${GREEN}The modified url is: $url user:$username pwd:$password ${NC}"
                break
                ;;
            "oracle")
                read_nonempty_input "host" "Enter db_host(ip): "
                read_input "port" "Enter db_port(default:1521): "
                read_nonempty_input "sid" "Enter sid: "
                read_nonempty_input "username" "Enter username: "
                read_nonempty_input "password" "Enter password: "
                driver_class_name="oracle.jdbc.OracleDriver"
                url="jdbc:oracle:thin:@${host}:${port:-1521}:${sid}"
                database_platform="org.hibernate.dialect.Oracle12cDialect"
                echo -e "${GREEN}The modified url is: $url user:$username pwd:$password ${NC}"
                break
                ;;
            "h2")
                driver_class_name="org.h2.Driver"
                url="jdbc:h2:mem:test;MODE=MySQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=true"
                database_platform="org.hibernate.dialect.H2Dialect"
                echo -e "${GREEN}The modified url is: $url${NC}"
                break
                ;;
            "exit")
                echo -e "${YELLOW}Exit db configuration${NC}"
                break
                ;;             
            *)
                ((invalid_count++))
                if [ $invalid_count -eq 2 ]; then
                    echo -e "${RED}Exceeded maximum invalid attempts. Exiting...${NC}"
                    exit 1
                else
                    echo -e "${RED}Invalid input. Please try again.${NC}"
                fi
                ;;
        esac
    done
    valid_db_types=("mysql" "dm" "oracle" "h2")

    found=false
    for valid_type in "${valid_db_types[@]}"; do
    if [[ "$valid_type" == "$db_type" ]]; then
        found=true
        break
    fi
    done

    if $found; then
    # 如果db_type在valid_db_types中，执行以下操作
    sudo driver_class_name="${driver_class_name}" yq eval -i '.spring.datasource.driver-class-name = env(driver_class_name)' $jar_config_file_prod
    sudo url="${url}" yq eval -i '.spring.datasource.url = env(url)' $jar_config_file_prod
    sudo database_platform="${database_platform}" yq eval -i '.spring.jpa.database-platform = env(database_platform)' $jar_config_file_prod
    sudo username="${username}" yq eval -i '.spring.datasource.username = env(username)' $jar_config_file_prod
    sudo password="${password}" yq eval -i '.spring.datasource.password = env(password)' $jar_config_file_prod
    sudo yq eval -i ".mybatis-plus.mapper-locations = [\"classpath*:mapper/common/*Mapper.xml\", \"classpath*:mapper/${db_type}/*Mapper.xml\"]" $jar_config_file_prod
    echo -e "${GREEN}Configuration file has been updated, datasource set to: ${YELLOW}$db_type${NC} ${NC}"
    fi

    while true; do
        read -p "Configure SSO? (y/n): " sso_config
        if [[ $sso_config == "y" || $sso_config == "n" ]]; then
            break
        else
            echo -e "${RED}SSO Invalid input. Please enter 'y' for yes or 'n' for no.${NC}"
        fi
    done 
    if [ "$sso_config" == "y" ]; then
        read_nonempty_input "server_host_url" "Enter sso.server.host-url(Cannot be empty): "
        read -p "Enter sso.server.web-host-url (default=\${sso.server.host-url}): " input_web_host_url
        web_host_url=${input_web_host_url:-\$\{sso.server.host-url\}}
        read_input "server_login_url" "Enter sso.server.login-url(Can be empty): "
        read_nonempty_input "client_host_url" "Enter sso.client.host-url(Cannot be empty): "
        read_nonempty_input "security_authn_mode" "Enter linkcld.security.authn-mode(Cannot be empty): "
        read_nonempty_input "orm_url" "Enter linkcld orm url(Cannot be empty): "
        read_nonempty_input "orm_system_code" "Enter linkcld orm system-code(Cannot be empty): "
        while true; do
            info_list=(
                "1. sso.server.host-url: $server_host_url"
                "2. sso.server.web-host-url: $web_host_url"
                "3. sso.server.login-url: $server_login_url"
                "4. sso.client.host-url: $client_host_url"
                "5. linkcld.security.authn-mode: $security_authn_mode"
                "6. linkcld.orm.url: $orm_url"
                "7. linkcld.orm.system-code: $orm_system_code"

            )
            
            echo -e "${GREEN}The configuration is as follows (1)${NC}"
            for info in "${info_list[@]}"; do
                echo "$info"
            done

            read_input "confirm" "Confirm the above configuration is correct? (y/n): "

            case $confirm in
                n)
                    read -p "Enter the number to modify (1|2|3|4|5|6|7|e|E): " index
                    case $index in
                        1)
                            read_nonempty_input "server_host_url" "Enter sso.server.host-url(Cannot be empty): "
                            ;;                        
                        2)
                            read_nonempty_input "web_host_url" "Enter sso.server.web-host-url(Cannot be empty): "
                            ;;                            
                        3)
                            read_input "server_login_url" "Enter sso.server.login-url(Can be empty): "
                            ;;
                        4)
                            read_nonempty_input "client_host_url" "Enter sso.client.host-url(Cannot be empty): "
                            ;;
                        5)
                            read_nonempty_input "security_authn_mode" "Enter linkcld.security.authn-mode(Cannot be empty): "
                            ;;                            
                        6)
                            read_nonempty_input "orm_url" "Enter linkcld orm url(Cannot be empty): "
                            ;;
                        7)
                            read_nonempty_input "orm_system_code" "Enter linkcld.orm.system-code(Cannot be empty): "
                            ;;                        
                        e|E)
                            echo -e "${YELLOW}Exiting configuration${NC}"
                            break
                            ;;                        
                    esac
                    ;;
                y)
                    break
                    ;;
            esac
        done
            if [[ -z "$server_login_url" ]]; then
                # 注释掉 .sso.server.login-url 字段
                sudo sed -i 's/^\(\s*login-url:\s*\).*/# \1/' $jar_config_file_prod
                sudo server_host_url="${server_host_url}" web_host_url="${web_host_url}" server_login_url="${server_login_url}" client_host_url="${client_host_url}" security_authn_mode="${security_authn_mode}" orm_system_code="${orm_system_code}" orm_url="${orm_url}"  yq eval -i '.sso.server.host-url = env(server_host_url) |.sso.server.web-host-url = env(web_host_url) | .sso.client.host-url = env(client_host_url) | .linkcld.orm.url = env(orm_url)|.linkcld.orm.url = env(orm_url)|.linkcld.orm["system-code"] = env(orm_system_code)|.linkcld.security["authn-mode"] = env(security_authn_mode)' $jar_config_file_prod
            # sed -i 's/^\(\s*sso:\s*\)\(\n\|\r\)\(\s*server:\s*\)\(\n\|\r\)\(\s*login-url:\)/\1\2\3\4# \5/' config/application-prod.yml
            else
                sudo server_host_url="${server_host_url}" web_host_url="${web_host_url}" server_login_url="${server_login_url}" client_host_url="${client_host_url}" security_authn_mode="${security_authn_mode}" orm_system_code="${orm_system_code}" orm_url="${orm_url}" yq eval -i '.sso.server.host-url = env(server_host_url) |.sso.server.web-host-url = env(web_host_url) |  .sso.server.login-url = env(server_login_url) | .sso.client.host-url = env(client_host_url) | .linkcld.orm.url = env(orm_url)|.linkcld.orm["system-code"] = env(orm_system_code)|.linkcld.security["authn-mode"] = env(security_authn_mode)' $jar_config_file_prod
            fi
            # sudo server_host_url="${server_host_url}" web_host_url="${web_host_url}" server_login_url="${server_login_url}" client_host_url="${client_host_url}" orm_url="${orm_url}" yq eval -i '.sso.server.host-url = env(server_host_url) |.sso.server.web-host-url = env(web_host_url) |  .sso.server.login-url = env(server_login_url) | .sso.client.host-url = env(client_host_url) | .linkcld.orm.url = env(orm_url)' $jar_config_file_prod
            echo -e "${GREEN}SSO+ORM Final configuration information: ${NC}"
            for info in "${info_list[@]}"; do
                echo "$info"
            done
            echo -e "${GREEN}Configuration has been written to the application-prod.yml file(SSO+ORM)${NC}"
        else
            while true; do
                read -p "Configure ORM? (y/n): " orm_config
                if [[ $orm_config == "y" || $orm_config == "n" ]]; then
                    break
                else
                    echo -e "${RED}ORM Invalid input. Please enter 'y' for yes or 'n' for no.${NC}"
                fi
            done
            if [ "$orm_config" == "y" ]; then
                read_nonempty_input "orm_url" "Enter linkcld orm url(Cannot be empty): "        
                read_nonempty_input "orm_system_code" "Enter linkcld.orm.system-code(Cannot be empty): "           
                while true; do
                    info_list=(
                        "1. linkcld.orm.url: $orm_url"
                        "2. linkcld.orm.system-code: $orm_system_code"
                    )
                    for info in "${info_list[@]}"; do
                        echo "$info"
                    done    
                    read -p "Confirm the above configuration is correct? (y/n): " confirm
                    case $confirm in
                        n)
                            read -p "Enter the number to modify (1|2|e|E): " index
                            case $index in
                                1)
                                    read_nonempty_input "orm_url" "Enter linkcld orm url(Cannot be empty): "                               
                                    ;;
                                2)
                                    read_nonempty_input "orm_system_code" "Enter linkcld.orm.system-code(Cannot be empty): "
                                    ;;                                      
                                e|E)
                                    echo -e "${YELLOW}Exiting configuration(1)${NC}"
                                    break
                                    ;;
                            esac
                            ;;
                        y)
                            break
                            ;;
                    esac
                done                
                sudo orm_url="${orm_url}" orm_system_code="${orm_system_code}" yq eval -i '.linkcld.orm.url = env(orm_url)|.linkcld.orm["system-code"] = env(orm_system_code)' $jar_config_file_prod
                echo -e "${GREEN}ORM Final configuration information:${NC}"
                for info in "${info_list[@]}"; do
                    echo "$info"
                done
                echo -e "${GREEN}Configuration has been written to the application-prod.yml file (ORM)${NC}"
            fi            
        fi
}
yml_name_port () {
        sudo yml_spring_application_name="${yml_spring_application_name}" yq eval -i '.spring.application.name = env(yml_spring_application_name)' $jar_config_file
        if [ -n "$jar_config_file_port" ]; then 
           sudo jar_port="${jar_port}" yq eval -i '.server.port = env(jar_port)' $jar_config_file
        fi 
}