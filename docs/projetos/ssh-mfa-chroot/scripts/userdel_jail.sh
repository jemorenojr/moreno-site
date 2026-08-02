#!/bin/bash
JAIL_DIR=$(grep ChrootDirectory /etc/ssh/sshd_config | grep -v '#' | awk '{gsub("/%u", "" ,$0)}{print  $2}')
read -p "Usuario : " usuario
grep "${usuario}" /etc/passwd > /dev/null
if [ $? -eq 0 ]; then
    userdel -r "${usuario}"
    echo "Usuario removido do passwd !"
    if [ -d "/home/${usuario}" ]; then
        rm -rf "/home/${usuario}"
    fi
else
    echo "Usuario inexistente !"
fi
if [ -d "${JAIL_DIR}/${usuario}" ]; then
    if [ ! "${usuario}" == "skel" ]; then 
        rm -rf "${JAIL_DIR}/${usuario}"
        echo "Usuario removido do Jail !"
    else
        echo "Usuario de sistema não pode ser removido"
    fi
else
    echo "Usuario inexistente no Jail !"
fi
