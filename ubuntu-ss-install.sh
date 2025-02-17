#!/bin/sh

# Check system
if [ ! -f /etc/lsb-release ];then
    if ! grep -Eqi "ubuntu|debian" /etc/issue;then
        echo "\033[1;31mOnly Ubuntu or Debian can run this shell.\033[0m"
        exit 1
    fi
fi

# Make sure only root can run our script
[ `whoami` != "root" ] && echo "\033[1;31mThis script must be run as root.\033[0m" && exit 1

# Version
LIBSODIUM_VER=1.0.17
MBEDTLS_VER=2.16.0
ss_file=0
v2_file=0
get_latest_ver(){
    ss_file=$(wget -qO- https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest | grep name | grep tar | cut -f4 -d\")
    v2_file=$(wget -qO- https://api.github.com/repos/lyj55r/v2ray-plugin/releases/latest | grep linux-amd64 | grep name | cut -f4 -d\")
}

# Set shadowsocks-libev config password
set_password(){
    clear
    echo "\033[1;34mPlease enter password for shadowsocks-libev:\033[0m"
    read -p "(Default password: M3chD09):" shadowsockspwd
    [ -z "${shadowsockspwd}" ] && shadowsockspwd="M3chD09"
    echo "\033[1;35mpassword = ${shadowsockspwd}\033[0m"
}

# Set domain
set_domain(){
    echo "\033[1;34mPlease enter your domain:\033[0m"
    echo "If you don't have one, you can register one for free at:"
    echo "https://my.freenom.com/clientarea.php"
    read domain
    str=`echo $domain | grep '^\([a-zA-Z0-9_\-]\{1,\}\.\)\{1,\}[a-zA-Z]\{2,5\}'`
    while [ ! -n "${str}" ]
    do
        echo "\033[1;31mInvalid domain.\033[0m"
        echo "\033[1;31mPlease try again:\033[0m"
        read domain
        str=`echo $domain | grep '^\([a-zA-Z0-9_\-]\{1,\}\.\)\{1,\}[a-zA-Z]\{2,5\}'`
    done
    echo "\033[1;35mdomain = ${domain}\033[0m"
}

# Pre-installation
pre_install(){
    read -p "Press any key to start the installation." a
    echo "\033[1;34mStart installing. This may take a while.\033[0m"
    apt-get update
    apt-get install -y --no-install-recommends gettext build-essential autoconf libtool libpcre3-dev asciidoc xmlto libev-dev libc-ares-dev automake
}


# Installation of Libsodium
install_libsodium(){
    if [ -f /usr/lib/libsodium.a ];then
        echo "\033[1;32mLibsodium already installed, skip.\033[0m"
    else
        if [ ! -f libsodium-$LIBSODIUM_VER.tar.gz ];then
            wget https://download.libsodium.org/libsodium/releases/libsodium-$LIBSODIUM_VER.tar.gz
        fi
        tar xf libsodium-$LIBSODIUM_VER.tar.gz
        cd libsodium-$LIBSODIUM_VER
        ./configure --prefix=/usr && make
        make install
        cd ..
        ldconfig
        if [ ! -f /usr/lib/libsodium.a ];then
            echo "\033[1;31mFailed to install libsodium.\033[0m"
            exit 1
        fi
    fi
}


# Installation of MbedTLS
install_mbedtls(){
    if [ -f /usr/lib/libmbedtls.a ];then
        echo "\033[1;32mMbedTLS already installed, skip.\033[0m"
    else
        if [ ! -f mbedtls-$MBEDTLS_VER-gpl.tgz ];then
            wget https://tls.mbed.org/download/mbedtls-$MBEDTLS_VER-gpl.tgz
        fi
        tar xf mbedtls-$MBEDTLS_VER-gpl.tgz
        cd mbedtls-$MBEDTLS_VER
        make SHARED=1 CFLAGS=-fPIC
        make DESTDIR=/usr install
        cd ..
        ldconfig
        if [ ! -f /usr/lib/libmbedtls.a ];then
            echo "\033[1;31mFailed to install MbedTLS.\033[0m"
            exit 1
        fi
    fi
}


# Installation of shadowsocks-libev
install_ss(){
    if [ -f /usr/local/bin/ss-server ];then
        echo "\033[1;32mShadowsocks-libev already installed, skip.\033[0m"
    else
        if [ ! -f $ss_file ];then
            ss_url=$(wget -qO- https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest | grep browser_download_url | cut -f4 -d\")
            wget $ss_url
        fi
        tar xf $ss_file
        cd $(echo ${ss_file} | cut -f1-3 -d\.)
        ./configure && make
        make install
        cd ..
        if [ ! -f /usr/local/bin/ss-server ];then
            echo "\033[1;31mFailed to install shadowsocks-libev.\033[0m"
            exit 1
        fi
    fi
}


# Installation of v2ray-plugin
install_v2(){
    if [ -f /usr/local/bin/v2ray-plugin ];then
        echo "\033[1;32mv2ray-plugin already installed, skip.\033[0m"
    else
        if [ ! -f $v2_file ];then
            v2_url=$(wget -qO- https://api.github.com/repos/lyj55r/v2ray-plugin/releases/latest | grep linux-amd64 | grep browser_download_url | cut -f4 -d\")
            wget $v2_url
        fi
        tar xf $v2_file
        mv v2ray-plugin_linux_amd64 /usr/local/bin/v2ray-plugin
        if [ ! -f /usr/local/bin/v2ray-plugin ];then
            echo "\033[1;31mFailed to install v2ray-plugin.\033[0m"
            exit 1
        fi
    fi
}

# Configure
ss_conf(){
    mkdir /etc/shadowsocks-libev
    cat >/etc/shadowsocks-libev/config.json << EOF
{
    "server":"0.0.0.0",
    "server_port":443,
    "password":"$shadowsockspwd",
    "timeout":300,
    "method":"aes-256-gcm",
    "plugin":"v2ray-plugin",
    "plugin_opts":"server;tls;cert=/etc/letsencrypt/live/$domain/fullchain.pem;key=/etc/letsencrypt/live/$domain/privkey.pem;host=$domain;loglevel=none"
}
EOF
    cat >/lib/systemd/system/shadowsocks.service << EOF
[Unit]
Description=Shadowsocks-libev Server Service
After=network.target
[Service]
ExecStart=/usr/local/bin/ss-server -c /etc/shadowsocks-libev/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
}

get_cert(){
    if [ -f /etc/letsencrypt/live/$domain/fullchain.pem ];then
        echo "\033[1;32mcert already got, skip.\033[0m"
    else
        apt-get update
        if grep -Eqi "ubuntu" /etc/issue;then
            apt-get install -y software-properties-common
            add-apt-repository -y universe
            add-apt-repository -y ppa:certbot/certbot
            apt-get update
        fi
        apt-get install -y certbot 
        certbot certonly --cert-name $domain -d $domain --standalone --agree-tos --register-unsafely-without-email
        systemctl enable certbot.timer
        systemctl start certbot.timer
        if [ ! -f /etc/letsencrypt/live/$domain/fullchain.pem ];then
            echo "\033[1;31mFailed to get cert.\033[0m"
            exit 1
        fi
    fi
}

start_ss(){
    systemctl status shadowsocks > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        systemctl stop shadowsocks
    fi
    systemctl enable shadowsocks
    systemctl start shadowsocks
}

remove_files(){
    rm -f libsodium-$LIBSODIUM_VER.tar.gz mbedtls-$MBEDTLS_VER-gpl.tgz $ss_file $v2_file
    rm -rf libsodium-$LIBSODIUM_VER mbedtls-$MBEDTLS_VER $(echo ${ss_file} | cut -f1-3 -d\.)
}

print_ss_info(){
    clear
    echo "\033[1;32mCongratulations, Shadowsocks-libev server install completed\033[0m"
    echo "Your Server IP        :  ${domain} "
    echo "Your Server Port      :  443 "
    echo "Your Password         :  ${shadowsockspwd} "
    echo "Your Encryption Method:  aes-256-gcm "
    echo "Your Plugin           :  v2ray-plugin"
    echo "Your Plugin options   :  tls;host=${domain}"
    echo "Enjoy it!"
}
set_password
set_domain
pre_install
install_libsodium
install_mbedtls
get_latest_ver
install_ss
install_v2
ss_conf
get_cert
start_ss
remove_files
print_ss_info
