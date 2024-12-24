#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# Copyright: (c) 2018, Gonzalo Alvarez

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
url_regex='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'

set -e

[ -d '.env' ] || mkdir .env
cd .env
[ -f 'synology.py' ] || curl -LO https://raw.githubusercontent.com/GonzaloAlvarez/synologycli/refs/heads/main/synology.py
[ -x 'synology.py' ] || chmod +x synology.py
if [ ! -x 'macosvm' ]; then
    curl -LO https://github.com/s-u/macosvm/releases/download/0.2-1/macosvm-0.2-1-arm64-darwin21.tar.gz
    tar -xzf macosvm-0.2-1-arm64-darwin21.tar.gz
    rm -f macosvm-0.2-1-arm64-darwin21.tar.gz
fi
if [[ $1 =~ $url_regex ]]; then
    [ -f "$(basename $1)" ] || curl -LO "$1"
    ./macosvm --disk $2-base-disk.img,size=50g --aux $2-base-aux.img --restore $(basename $1) $2-base-vm.json
    rm -f "$(basename $1)"
    cat <<EOF
Now you gotta go through the setup process. Make sure you create a single user 'admin' pw:'admin'
Once you are in the screen, do the following:
    - Enable Auto-Login. Users & Groups -> Login Options -> Automatic login -> admin.
    - Allow SSH. Sharing -> Remote Login
    - Change the VM name in General -> About
    - Disable Lock Screen. Preferences -> Lock Screen -> disable "Require Password" after 5.
    - Disable Screen Saver.
    - Run sudo visudo in Terminal, find %admin ALL=(ALL) ALL add admin ALL=(ALL) NOPASSWD: ALL to allow sudo without a password.
    - Install xcode in the terminal
EOF
    ./macosvm -g $2-base-vm.json
    tar -cf $2-base-vm.tar $2-base-disk.img $2-base-aux.img $2-base-vm.json
    ./synology.py up $2-base-vm.tar
    rm -f $2-base-vm.tar
fi
if [ ! -f "$1-base-vm.json" ]; then
    ./synology.py dw $1-base-vm.tar
    tar -xvf $1-base-vm.tar
    rm -f $1-base-vm.tar
fi
./macosvm --ephemeral $1-base-vm.json 2>/dev/null >/dev/null &
sleep 3
cd "$SCRIPT_DIR"
ssh -l admin $(arp -an | grep "11:22:33" | sed -n 's/.*\(([^()]*)\).*/\1/p' | tr -d '[()]')
