#!/bin/bash
#
###########################################################################
#
# Nome       : 
# Descricao  : Cria o usuario seu ambiente no chroot, e cria uma chave MFA 
# Author     : Jose Edson Moreno Jr.
# Email      : infra@example.net
# Versao     : 0.11
# Data       : 24/03/2025
# copyright  : (C) 2025 by Edson Moreno
# Parametros : prog  
# Retorno    : 
#
# CHANGELOG  :       
#              20250424 - Efetuado alteracoes de aprimoramento de seguranca
############################################################################

# Arquivos disponiveis no jail
arquivos="/bin/awk /bin/bash /bin/grep /bin/groups /bin/id /bin/ls /bin/ping /bin/sh /bin/ssh /usr/bin/ssh-add /bin/whoami /etc/bash.bashrc  /etc/group /etc/nsswitch.conf /etc/passwd /etc/profile /etc/profile.d/tmout.sh /etc/profile.d/aliases.sh /etc/profile.d/history.sh /etc/resolv.conf /usr/bin/dircolors  /etc/bash_completion /etc/profile.d/bash_completion.sh /usr/share/bash-completion/bash_completion"
# Configuracao do email
EMAIL_FROM="infra@example.net"
EMAIL_FROM_DESC="Backup"
EMAIL_SUBJ="[${EMAIL_FROM_DESC}] - MFA ${EMAIL_FROM_DESC} - Seguranca Jail"
EMAIL_SERVER="relay.example.net"
EMAIL_PORT="25"
# Localizacao netcat
NC="/usr/bin/nc"

#JAIL_DIR="/home/Secure/Jail"
JAIL_DIR=$(grep ChrootDirectory /etc/ssh/sshd_config | grep -v '#' | awk '{gsub("/%u", "" ,$0)}{print  $2}')
if [-z "${JAIL_DIR}" ]; then
    echo "Não encontrado configuração de ChrootDirectory no sshd_config"
    exit 1
fi
if [ ! -d "${JAIL_DIR}" ]; then
    mkdir -p "${JAIL_DIR}"
fi

read -p "Usuario : " usuario
getent passwd "${usuario}" && { echo "Usuario já existe!"; exit 1; }
if [[ ! "${usuario}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
   echo "Nome usuario inválido"
   exit 1
fi

read -p "Nome completo usuario : " nome
if [ -z "${nome}" ]; then
   echo "Nome não pode ser vazio"
   exit 1
fi
read -p "Email do usuario : " email
if [ -z "${email}" ]; then
   echo "Email não pode ser vazio"
   exit 1
fi
read -p "Chave publica SSH : " chave
echo "${chave}" | grep -q "ssh-rsa\|ssh-ed25519\|ecdsa" > /dev/null 2>&1
if [ $? -ne 0 ]; then
   echo "Chave SSH invalida!"
   exit 1
fi
read -p "Usuario acessará o roo via admin? <N|s> : " admin
if [[ $admin == 's'  ||  $admin == 'S' ]]; then 
    id admin >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "${chave}" >> /home/admin/.ssh/authorized_keys
    else
        echo "Atencao : Usuario admin inexistente, verificar !"
    fi
fi
egrep "^jail:" /etc/group > /dev/null 
if [ $? -ne 0 ]; then
    groupadd -r jail
fi

useradd -G jail -s /bin/bash -m -c "${nome}" "${usuario}"
mkdir -p /home/"${usuario}"/.ssh
echo "${chave}" > /home/"${usuario}"/.ssh/authorized_keys
echo 'export TERM=xterm-88color' >> /home/"${usuario}"/.bashrc
chmod 600 /home/"${usuario}"/.ssh/authorized_keys
chown -R "${usuario}":"${usuario}" /home/"${usuario}"/
chmod 700 /home/"${usuario}"/
touch /home/"${usuario}"/.hushlogin

echo "Criando area de usuario no Jail"
JAIL_USER="${JAIL_DIR}/${usuario}"
if [ ! -d "${JAIL_USER}" ]; then
    mkdir -p "${JAIL_USER}"/{home,sys,usr/bin,usr/sbin,var,tmp,etc,dev}
fi
cd "${JAIL_USER}"
ln -s usr/bin bin
ln -s usr/sbin sbin
ln -s usr/lib lib
ln -s usr/lib64 lib64
chmod 1777 tmp

# Copiando bibliotecas de programas em bin
for arq in ${arquivos}; do
    if [ -f ${arq} ]; then
        cp --preserve=all --parents "${arq}" "${JAIL_USER}"
        DEP_LIBS=$(ldd ${arq} 2>/dev/null | egrep "\/lib" | awk '{ if ($1 ~ /^\//) print $1; else print $3 }') ;      
        for lib in $DEP_LIBS; do         
            if [ -f "/usr$lib" ]; then             
                cp --parents "/usr${lib}" "${JAIL_USER}";         
            fi;     
        done; 
    else
        echo "ERRO: Arquivo \"${arq}\" inexistente !"
    fi
done

# Reforço de permissões
find "${JAIL_USER}"/etc "${JAIL_USER}"/usr "${JAIL_USER}"/var -type d -exec chmod 755 {} \; 
find "${JAIL_USER}"/etc "${JAIL_USER}"/usr "${JAIL_USER}"/var -type f -exec chmod go-w {} \;

echo "127.0.0.1 localhost " > "${JAIL_USER}"/etc/hosts
# Caso especial NSSLIB, Locale e Terminal
libnss=$(dpkg -L libc6 | egrep "libnss_files.*\.so$")
cp --preserve=all --parents ${libnss} "${JAIL_USER}"
[ ! -f "${JAIL_USER}"/lib/x86_64-linux-gnu/libnss_files.so ] && ln -s ${libnss} "${JAIL_USER}"/lib/x86_64-linux-gnu/libnss_files.so
[ ! -f "${JAIL_USER}"/lib/x86_64-linux-gnu/libnss_files.so.2 ] && ln -s ${libnss} "${JAIL_USER}"/lib/x86_64-linux-gnu/libnss_files.so.2
cp -r --preserve=all --parents /usr/share/locale/en  "${JAIL_USER}"
cp -r --preserve=all --parents /lib/terminfo "${JAIL_USER}"
cp -r --preserve=all --parents /usr/share/terminfo "${JAIL_USER}"
# Fim caso especial

# Copiando dados do usuário
cp -rf --preserve=all --parents /home/"${usuario}" "${JAIL_USER}"
echo "umask 077" >> "${JAIL_USER}"/home/"${usuario}"/.bashrc
echo "PATH=/bin:/usr/bin" >> "${JAIL_USER}"/home/"${usuario}"/.bashrc
echo "unset LD_PRELOAD LD_LIBRARY_PATH" >> "${JAIL_USER}"/home/"${usuario}"/.bashrc
egrep "^${usuario}:" /etc/passwd > "${JAIL_USER}"/etc/passwd
egrep "^jail:" /etc/group | awk -v user="${usuario}" -F':' '{print "user:" $2 ":" $3 ":" user}' > "${JAIL_USER}"/etc/group
egrep "^${usuario}:" /etc/group | egrep -v "^jail:" >> "${JAIL_USER}"/etc/group

# Dispositivos essenciais com permissão mínima
mkdir "${JAIL_USER}"/dev
mknod -m 666 "${JAIL_USER}"/dev/null c 1 3
mknod -m 622 "${JAIL_USER}"/dev/tty c 5 0
mknod -m 666 "${JAIL_USER}"/dev/zero c 1 5
mknod -m 444 "${JAIL_USER}"/dev/random c 1 8
mknod -m 444 "${JAIL_USER}"/dev/urandom c 1 9

echo "Usuario Criado !"

echo "Criando MFA do usuario"
google=$(su -l "${usuario}" -c "google-authenticator -t -d -f -r 3 -R 30 -W -C" )
otpauth=$(echo "$google" | grep otpauth | awk -F'otpauth' '{print "otpauth" $2}')
file_otpauth="$(mktemp -q .google_mfa.XXXXXXXXX).png"
echo -e "$(echo "${otpauth}" | sed 's/+/ /g; s/%/\\x/g' )" | qrencode -s 12 -o ${file_otpauth}
mfa=$(echo "$google" | egrep -v "URL|otpauth")

# Envio por e-mail
LANG_OLD=${LANG}
unset LANG
HORA=`date +"Date: %a, %d %b %Y %T %z"`
export LANG=${LANG_OLD}
ESUBJECT='=?utf-8?B?'$(echo "${EMAIL_SUBJ}" | base64 -w 0)'?='
idmulti=$(md5sum /home/"${usuario}"/.google_authenticator | awk '{print "--=_Next_Part_"$1}')
( sleep 2
    echo -en "EHLO $(hostname -s)\r\n"
    sleep 2
    echo -en "MAIL FROM:${EMAIL_FROM}\r\n"
    sleep 2
#    IFS=';'
#    for email_ in ${email}; do
#    	echo -en "RCPT TO:${email_}\r\n" 
#    done
#    unset IFS
    echo -en "RCPT TO:${email}\r\n"
    sleep 2
    echo -en "DATA\r\n"
    sleep 3
    echo -en "From: ${EMAIL_FROM_DESC} <${EMAIL_FROM}>\r\n"
    echo -en "To: ${email}\r\n"
    echo -en "${HORA}\r\n"
    echo -en "Subject: ${ESUBJECT}\r\n"
    echo -en "Content-Type: multipart/mixed;\r\n"
    echo -en "        boundary=\"${idmulti}\"\r\n"
    echo -en "\r\n--${idmulti}\r\n"
    echo -en "Content-Disposition: inline;\r\n"
    echo -en "MIME-Version: 1.0\r\n"
    echo -en "Content-Transfer-Encoding: base64\r\n"
    echo -en "Content-Type: text/plain; charset=\"utf-8\"\r\n\r\n"
    for linha in $(echo -e "Ativar o MFA no Google Authenticator para maquina $(hostname).\n\n${otpauth}\n\n${mfa}" | base64); do
            echo -en "${linha}\r\n"
    done
     # Adicionar a imagem em base64
    echo -en "\r\n--${idmulti}\r\n"
    echo -en "Content-Type: image/png; name=\"qrcode.png\"\r\n"
    echo -en "Content-Transfer-Encoding: base64\r\n"
    echo -en "Content-Disposition: attachment; filename=\"qrcode_mfa_${usuario}.png\"\r\n\r\n"

    base64 ${file_otpauth} | while IFS= read -r linha; do
        echo -en "${linha}\r\n"
    done
    echo -en "\r\n--${idmulti}--\r\n.\r\n"
    echo -en "NOOP\r\n"
    sleep 1
    echo -en "NOOP\r\n"
    sleep 1
    echo -en "NOOP\r\n"
    sleep 1
    echo -en "QUIT\r" ) | ${NC} -w 30 -v ${EMAIL_SERVER} ${EMAIL_PORT}
rm -f "${file_otpauth}"
echo "Enviado MFA para o usuario e ambiente criado."
