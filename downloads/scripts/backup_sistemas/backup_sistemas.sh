#!/bin/bash
#
###########################################################################
#
# Nome       : backup_sistemas.sh
# Descricao  : Executa backup em equipamentos possibilitando escolher o que
#              sera armazenado e excluido do backup. Se baseia no arquivo
#              /root/.backup_sistemas na maquina em que sera feito o backup.
#              Se a linha comecar com a letra I, fara o backup do
#              diretorio/arquivo. Se comecar com a letra E, exclui o
#              diretorio/arquivo.
#              Ex:
#              I /
#              E /sys
#              A exclusao sera baseada nas regras de exclusao do rsync.
# Author     : Jose Edson Moreno Jr.
# Email      : edson.moreno@gmail.com
# Versao     : 0.5
# Data       : 21/02/2021
# copyright  : (C) 2021 by Edson Moreno
# Parametros : prog
# Retorno    :
#
# CHANGELOG  : 22/12/2017 - Alterado estrutura do programa para melhorar log
#                         e documentacao do codigo
#              04/01/2018 - Corrigido envio de relatorio email
#              10/01/2018 - Separado as configuracoes gerais, assim em upgrade nao
#                           se perde as configuracoes antigas
#              16/01/2018 - Colocado tratamento de diretorios de destino
#              16/07/2018 - Alterado para permitir que ate tres programas rode,
#              para que backups demorados nao atrapalhe os outros, foi colocado
#              um lock para cada backup e assim mantido o numero de backups
#              simultaneos
#              18/07/2018 - Corrigido o contador de controle de backups simultaneos
#              07/08/2018 - Alterado modo de retensao, agora se nao for feito backup
#              sera mantido os ultimos backups, mesmo que a data passe a da retensao
#              21/07/2020 - Acrescentado controle para nao criar diretorios que nao sejam
#              subvolumes de btrfs
#              26/01/2021 - Alterado o script para trabalhar com simbolic link no rsync,
#              retirado o controle de btrfs, que apresentava problemas de controle de
#              espaco em disco, ocupando muito espaco no log do btrfs.
#              21/02/2021 - Alterado as variaveis de controle, para conter timestamp
#              08/02/2024 - Alterado para manter a estrutura de diretorio original
#              25/04/2024 - Correcao de bug para backup da raiz "/"
#              30/04/2024 - Alterado para detectar formatacao errada arquivo bkp remoto
############################################################################

prog="$0"

# Carrega configuracoes gerais.
basedir=$(dirname ${prog})
if [ "${basedir}" == "." ]; then
        basedir=${PWD}
fi
. ${basedir}/backup_geral.conf

tmp_log="$1"
STATUS="${Dir_Backup}/Log/.status_$(date +%s)"
[ ! -d "${Dir_Backup}/Log" ] && mkdir -p "${Dir_Backup}/Log"
echo -e "\nBackup iniciado [$(date +%x\ %X)]" | tee -a ${STATUS}
PID=$$
SYSLOG=$(mktemp -u -p "${Dir_Backup}/Log" --suffix=_sys.log )

sincroniza () {
    arq="$1"
    dir_base_backup="$2"
    dir_old_backup="$3"
    server=$4
    porta=$5
    controle=$6
    hora=$7
    lock=$8
    dir_backup="${dir_base_backup}/${hora}"
    dir_backup_log="${dir_base_backup}/Log/${hora}.log"
    echo -e "$(date +%s) [${PID}] - Inicio Processo Backup do server [${server}] - $(cat ${controle})" >> ${SYSLOG} 2>&1
    # Cria Subvolume novo ou faz snapshot do antigo.
    echo -en "$(date +%s) [${PID}] - " >> ${SYSLOG} 2>&1
    bloqueio_erro=1
    loop_bloqueio=0
    touch ${controle}.lock
    # Cria Diretorio de Log.
    if [ ! -d $(dirname "${dir_backup_log}") ]; then
       mkdir -p $(dirname "${dir_backup_log}")
    fi
    rm -f ${arq}_exclude
    touch ${arq}_exclude
    while read linha ; do
        [ "$linha" == "" ] && continue
        if [ $(echo "${linha}" | awk '{print NF}') -ne 2 ]; then
           echo "Erro na linha \"${linha}\", nao contem 2 campos: [I/E] [Diretorio]" >> ${dir_backup_log}
           continue
        fi
        if [ "${linha:0:1}" == "E" ]; then
           echo "${linha:2}" >> ${arq}_exclude
        fi
    done < ${arq}
    while read linha ; do
        [ "$linha" == "" ] && continue
        if [ $(echo "${linha}" | awk '{print NF}') -ne 2 ]; then
           echo "Erro na linha \"${linha}\", nao contem 2 campos: [I/E] [Diretorio]" >> ${dir_backup_log}
           continue
        fi
        if [ "${linha:0:1}" == "E" ]; then
           continue
        fi
        base=$(echo "${linha:2}" | sed -s 's/\/\+/\//g')
        base="${base%*/}"
        ultima_barra=${base##*\/}
        if [[ -z "$ultima_barra" ]]; then
           raiz="/"
           base="/"
        else
           raiz="${base%/*}/"
        fi
        if [[ -z "${raiz}" ]]; then
           raiz="/"
        fi
        if [ ! -d  "${dir_backup}${raiz}" ]; then
           mkdir -p "${dir_backup}${raiz}"
        fi
        if [ "${linha:0:1}" == "I" ]; then
           echo -e "$(date +%s) [${PID}] --- INICIO - server [${server}] Path = ${base}" >> ${dir_backup_log}
           mkdir -p "${dir_backup}" >> ${SYSLOG} 2>&1
           if [ ! -d "${dir_old_backup}" ]; then
               rsync -arugtpl  --numeric-ids --delete --exclude-from=${arq}_exclude -e "ssh -p ${porta} -o PasswordAuthentication=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null " ${server}:"${base}" "${dir_backup}${raiz}" >> ${dir_backup_log} 2>&1
               ret=$?
           else
               rsync -arugtpl  --numeric-ids --delete --exclude-from=${arq}_exclude --link-dest="${dir_old_backup}${raiz}" -e "ssh -p ${porta} -o PasswordAuthentication=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null " ${server}:"${base}" "${dir_backup}${raiz}" >> ${dir_backup_log} 2>&1
               ret=$?
           fi
           if [ ${ret} -ne 0 ]; then
               echo -e "\n$(date +%s) [${PID}] - Erro durante o sync do servidor [${server}], verificar log ${dir_backup_log}\n" >> ${SYSLOG}
           fi
           echo -e "$(date +%s) [${PID}] --- FIM - server [${server}] Path = ${linha:2} \n" >> ${dir_backup_log}
        fi
    done < ${arq}
    echo -e "$(date +%s) [${PID}] - Fim Processo Backup do server [${server}] - $(cat ${controle})" >> ${SYSLOG} 2>&1
    echo $(($(cat ${controle}) - 1 )) > ${controle}
    rm -f ${arq}_exclude ${arq} ${lock} ${controle}.lock
}

if [ $(ls .lock_* 2>/dev/null | wc -l) -ge 3 ]; then
    echo -e "$(date +%s) [${PID}] - ERRO muitos arquivo ${Dir_Backup}/Log/.lock existente, Saindo ! "
    exit 1
else
    # Trava sistema, para chamada resto programa.
    mknod -m 600 ${Dir_Backup}/Log/.lock_${PID} p
fi


# Pega as Estatisticas de execucao.
val_ini=$(df -P -k ${Dir_Backup} | tail -n 1 | awk '{print $3}')
espaco=$(df ${Dir_Backup} | tail -n 1  | awk 'sub ("%","",$5) {print $5}')
msg_espaco="Espaco alocado no sistema ${val_ini} Kb - Ocupado ${espaco}% "
inibkp=$(date +%s)
data_inicio="${inibkp} [${PID}] - Inicio Procedimento Backup"
echo -e "\n${data_inicio}  ---------------------\n" >> ${SYSLOG}
echo -e "$(date +%s) [${PID}] - ${msg_espaco}\n" >> ${SYSLOG}
echo -e "\n$(date +%s) [${PID}] - Bakcup Inicializado (${msg_espaco})" >> ${STATUS}

# Garante backup nao enche o brtf causando seu travamento.
#(
#    # Watchdog do espaco em disco p/ brtfs.
#    while [ 1 ]; do
#        # Verifica espaco livre na particao sem compressao.
#        espaco=$(df ${Dir_Backup} | tail -n 1  | awk 'sub ("%","",$5) {print $5}')
#        if [ $((100 - ${espaco})) -le ${limite_espaco} ]; then
#            # Havendo pouco espaco na particao, verifica espaco na particao btrfs.
#            # espaco=$(/sbin/btrfs fi df ${Dir_Backup} | grep Data\:  | sed -e 's/,/ /g;s/=/ /g;s/[KMG]B//g' | awk '{printf "%d\n", (1-$5/$3)*100}')
#            espaco=$(/sbin/btrfs filesystem usage -b ${Dir_Backup} | egrep size\|\ allocated  | awk -F':' '{printf $2 "  " }' | awk '{printf "%d\n", (1-$2/$1)*100}')
#            if [ ${espaco} -le ${limite_espaco} ]; then
#                kill -9 ${PID} $( ps -ax 2>/dev/null | grep rsync | grep -v grep | awk '{print $1}') > /dev/null 2>&1
#                date +%s%n"- Falta de espaco para o btrfs ( total livre ${espaco}% )" >> ${SYSLOG}
#                echo -e "\nBackup nao efetuado por insuficiencia de espaco no btrfs ( total livre ${espaco}% )\n" > ${Dir_Backup}/Log/${STATUS}
#                rm -f ${Dir_Backup}/Log/.lock_${PID} ${controle}
#            fi
#        fi
#        [ ! -p ${Dir_Backup}/Log/.lock_${PID} ]; exit 0
#        sleep 60
#    done
#)&

# Controle de numero rsync.
controle=$(mktemp -u -p "${Dir_Backup}/Log" --suffix=_control )
echo "0" > ${controle}

# Coleta os diretorios que serao feito o backup.
for server_in in ${Servers} ; do
    server=${server_in%%:*}
    # Verifica se cadastro do server possui a porta de ssh, nao havendo usa a padrao.
    [ "${server}" == "${server_in##*:}" ] && port=22 || port=${server_in##*:}
    # Coleta a lista de backup na maquina remota.
    scp -P ${port} -o PasswordAuthentication=no -o ConnectTimeout=20 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${server}:/root/.backup_sistemas ${Dir_Temp}/${server}.lst >/dev/null 2>&1
    # Pega os diretorios que serao excluidos.
    if [ $? -eq 1 ]; then
        echo -e "$(date +%s) [${PID}] - Ignorando ${server}, sem listagem de backup" >> ${SYSLOG}
        continue
    fi
    # Verifica diretorio de backup.
    [ ! -d "${Dir_Backup}/${server}" ] && mkdir -p "${Dir_Backup}/${server}"
     # Verifica se numero de backups simultaneos esta no limite.
    while [ $(cat ${controle}) -ge ${Backups_Simultaneos} ]; do
        sleep 60
    done
    if [ -p "${Dir_Backup}/${server}/.lock" ]; then
        echo -e "$(date +%s) [${PID}] - AVISO arquivo ${Dir_Backup}/${server}/.lock existente, Ignorando Backup da maquina [${server}] ! "
        continue
    fi
    # Recupera o ultimo diretorio de backup.
    lastbackup="${Dir_Backup}/${server}/$([ "$(ls -t1r ${Dir_Backup}/${server} 2>/dev/null | head -n 1)" == "" ] && echo "__vazio__" || ls -t1r ${Dir_Backup}/${server} 2>/dev/null | head -n 1)"
    # Novo diretorio de backup.
    newbackup="${Dir_Backup}/${server}"
    echo $(($(cat ${controle}) + 1 )) > ${controle}
    # Trava sistema, para backup de outra maquina.
    mknod -m 600 "${Dir_Backup}/${server}/.lock" p
    # Inicia o procedimento de backup por maquina.
    sincroniza "${Dir_Temp}/${server}.lst" "${newbackup}"  "${lastbackup}" "${server}" "${port}" "${controle}" "$(date +%Y%m%d%H%M)" "${Dir_Backup}/${server}/.lock" &
    sleep 30
done

# Aguarda a finalizacao de todos os backups.
while [ $(cat ${controle}) -ne 0 ]; do
    sleep 60
done

# Remove diretorios antigos de backup.
#bkp_btrfs=$(mktemp -u -p "${Dir_Backup}/Log" --suffix=_bkp_btrfs.tmp )
#btrfs subvolume list ${Dir_Backup} > ${bkp_btrfs}
for server_in in ${Servers} ; do
    server=${server_in%%:*}
    if [ ! -d ${Dir_Backup}/${server} ]; then
        continue
    fi
    cd ${Dir_Backup}/${server}
    if [ -p "${Dir_Backup}/${server}/.lock" ]; then
        echo -e "$(date +%s) [${PID}] - Ignorando diretorio [${dir_excl}] do server [${server}] - LOCK" >> ${SYSLOG}
        continue
    fi
    for dir_excl in $(ls -X  | grep -v Log) ; do
        if [ $(date -d "now -${Retensao} days" +%Y%m%d) -gt ${dir_excl:0:8} ]; then
            if [ $(ls  | grep -v Log | wc -l) -lt $((Retensao - 1)) ]; then
                echo -e "$(date +%s) [${PID}] - Ignorando diretorio do server [${server}] - Numero de backup inferior a retencao, provavelmente nao fez backup" >> ${SYSLOG}
                break
            fi
#            grep ${dir_excl} ${bkp_btrfs} > /dev/null 2>&1
#            if [ $? -eq 0 ]; then
#               /sbin/btrfs subvolume delete ${dir_excl}
#                echo -e "$(date +%s) [${PID}] - Subvolume do brtfs removido [${dir_excl}] do server [${server}]" >> ${SYSLOG}
#            else
                rm -rf ${dir_excl}
                echo -e "$(date +%s) [${PID}] - Removido [${dir_excl}] do server [${server}]" >> ${SYSLOG}
#            fi
        fi
    done
done
# rm -f ${bkp_btrfs}

date +%s" [${PID}] - Fim backup" >> ${SYSLOG}

espaco=$(df ${Dir_Backup} | tail -n 1  | awk 'sub ("%","",$5) {print $5}')
val_fim=$(df -P -k ${Dir_Backup} | tail -n 1 | awk '{print $3}')
echo -e "\n$(date +%s) [${PID}] - Bakcup Finalizado ( Espaco: Alocado $((val_fim - val_ini)) Kb, alocado no sistema ${val_fim} Kb - Ocupado ${espaco}% )\n" | tee -a ${SYSLOG}

# Inicio Procedimento de envio de relatorio.
#date +%s" [${PID}] - Inicio relatorio backup" >> ${Dir_Backup}/Log/sys.log
#num_linhas_msg=$(( $(wc -l ${Dir_Backup}/Log/sys.log | awk '{print $1}' ) - $(egrep -n "${inibkp}.*Inicio Procedimento Backup" ${Dir_Backup}/Log/sys.log | awk -F':' '{print $1-2}') ))
#tail -n ${num_linhas_msg} ${Dir_Backup}/Log/sys.log > ${Dir_Backup}/Log/${TMP_EMAIL}
TMP_EMAIL="${Dir_Backup}/Log/.email_$(date +%s).txt"
cat ${SYSLOG} > ${TMP_EMAIL}
date +%s" [${PID}] - Inicio relatorio backup" | tee -a ${SYSLOG}
LANG_OLD=${LANG}
unset LANG
HORA=`date +"Date: %a, %d %b %Y %T %z"`
export LANG=${LANG_OLD}
ESUBJECT='=?utf-8?B?'$(echo "${EMAIL_SUBJ}" | base64 -w 0)'?='
idmulti=$(md5sum ${TMP_EMAIL} | awk '{print "--=_Next_Part_"$1}')
( sleep 2
    echo -en "EHLO $(hostname -s)\r\n"
    sleep 2
    echo -en "MAIL FROM:${EMAIL_FROM}\r\n"
    sleep 2
    IFS=';'
    for email_ in ${Email}; do
        echo -en "RCPT TO:${email_}\r\n"
    done
    unset IFS
    sleep 2
    echo -en "DATA\r\n"
    sleep 3
    echo -en "From: ${EMAIL_FROM_DESC} <${EMAIL_FROM}>\r\n"
    echo -en "To: ${Email}\r\n"
    echo -en "${HORA}\r\n"
    echo -en "Subject: ${ESUBJECT}\r\n"
    echo -en "Content-Type: multipart/mixed;\r\n"
    echo -en "        boundary=\"${idmulti}\"\r\n"
    echo -en "\r\n--${idmulti}\r\n"
    echo -en "Content-Disposition: inline;\r\n"
    echo -en "MIME-Version: 1.0\r\n"
    echo -en "Content-Transfer-Encoding: base64\r\n"
    echo -en "Content-Type: text/plain; charset=\"utf-8\"\r\n\r\n"
    for linha in $(base64 ${TMP_EMAIL}); do
            echo -en "${linha}\r\n"
    done
    echo -en "\r\n--${idmulti}--\r\n.\r\n"
    echo -en "NOOP\r\n"
    sleep 1
    echo -en "NOOP\r\n"
    sleep 1
    echo -en "NOOP\r\n"
    sleep 1
    echo -en "QUIT\r" ) | ${NC} -v ${EMAIL_SERVER} ${EMAIL_PORT}
#    echo -en "QUIT\r" ) | ${NC} -v --idle-timeout=45 ${EMAIL_SERVER} ${EMAIL_PORT}
date +%s" [${PID}] - Fim relatorio backup"%n"----------" | tee -a ${SYSLOG}
cat ${SYSLOG} >> ${Dir_Backup}/Log/sys_sistema.log
rm -f ${TMP_EMAIL} ${STATUS} ${Dir_Backup}/Log/.lock_${PID} ${SYSLOG}
rm -f ${controle}

#/sbin/btrfs subvolume sync ${Dir_Backup}
