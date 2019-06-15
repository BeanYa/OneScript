#!/bin/sh

# 一些常量
method="aes-256-cfb"
mup="6001"
log="./add.log"

install_sth(){
    source /etc/os-release
    case $ID in
        debian|ubuntu|devuan)
            apt-get install -y $1
            ;;
        centos|fedora|rhel)
            yum install -y $1
            ;;
        *)
            exit 1
            ;;
    esac
}

get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    echo ${IP}
}

add_port(){
    echo -e -n "add: {\"server_port\": $1, \"password\":\"$2\"}" > /dev/udp/127.0.0.1/$mup
    tcp=$(firewall-cmd --zone=public --add-port=$1/tcp --permanent)
    echo "TCP端口 $1 开放操作: $tcp"

    udp=$(firewall-cmd --zone=public --add-port=$1/udp --permanent)
    echo "udp端口 $1 开放操作: $udp"

    rel=$(firewall-cmd --reload)
    echo "防火墙重启操作: $rel"

    echo "IP:$(get_ip) 端口:$1 密码:$2"
    # echo "Domain:$domain Port:$1 PWD:$2"

    # base64链接
    link=$( base64 <<< "$method:$2@$(get_ip):$1" )
    # link=$(base64 <<< "$method:$2@$domain:$1")

    echo "ss://$link"
    echo "-------------------------------------------------------------------------"
}

start_check(){
    process=`ps aux | grep ssserver | grep -v grep`;
    if [ "$process" == "" ]; then
        echo "Shaodwsock is not running"
        ssserver -p 443 -k bean -m aes-256-cfb --manager-address 127.0.0.1:6001 -d start
        firewall-cmd --zone=public --add-port=443/tcp --permanent
        firewall-cmd --zone=public --add-port=443/udp --permanent
        firewall-cmd --reload
        if [ -f "$log" ]; then
            for line in `cat $log`
                do
                line=$(echo $line | tr -d "\"")
                por=${line%:*}
                pwd=${line#*:}
                add_port $por $pwd
                echo "port:$por,pwd:$pwd"
            done
        fi
    else
        echo "Shaodwsock is running"
    fi
}


if ! [ -x "$(command -v pip)" ]; then
  echo 'Python-pip is not installed.'
  install_sth epel-release >&1
  install_sth python-pip >&1
fi

if ! [ -x "$(command -v ssserver)" ]; then
  echo 'Shadowsocks is not installed.'
  pip install shadowsocks
fi

start_check

if [ -n "$1" ]; then
    echo "-------------------------------------------------------------------------"
    echo "Add new Port $1@$(get_ip) PWD:$2"
    add_port $1 $2
    echo -e "\"$1\":\"$2\"" >> add.log
else
    echo "No port to Add"
fi
