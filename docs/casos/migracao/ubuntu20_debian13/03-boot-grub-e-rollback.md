# Boot, GRUB e rollback

## 12. LVM e initramfs

O novo Debian precisava encontrar o root localizado dentro do LVM durante o estágio inicial do boot.

Foram instalados:

``` bash
apt install -y lvm2 initramfs-tools
```

Validação:

``` bash
pvs
vgs
lvs
```

Nenhuma alteração foi realizada no VG destinado aos dados da aplicação.

------------------------------------------------------------------------

## 13. Instalação do kernel Debian

O kernel Debian foi instalado com:

``` bash
apt install -y linux-image-amd64
```

Na execução documentada:

``` text
Linux 6.12.94+deb13-amd64
```

O initramfs foi inspecionado:

``` bash
lsinitramfs /boot/initrd.img-* | \
    grep -E 'lvm|dm-mod|dm_mod|ext4'
```

Foram confirmados:

``` text
dm-mod
ext4
lvm
```

Isso demonstrava que o initramfs possuía os componentes necessários para localizar e montar o novo root LVM/ext4.

------------------------------------------------------------------------

## 14. Limpeza do `/boot` antigo

A partição `/boot` tinha aproximadamente 1 GiB e continha kernels antigos acumulados.

Antes da limpeza foi preservada uma cópia da configuração GRUB:

``` bash
cp -a /boot/grub /root/grub-ubuntu-backup
```

Foram removidos somente kernels antigos já identificados como desnecessários.

Foi mantido o kernel Ubuntu efetivamente em execução:

``` text
vmlinuz-5.4.0-169-generic
initrd.img-5.4.0-169-generic
System.map-5.4.0-169-generic
config-5.4.0-169-generic
```

Após a limpeza, o `/boot` caiu para aproximadamente:

``` text
80 MiB utilizados
828 MiB disponíveis
```

Essa limpeza permitiu manter simultaneamente o kernel Ubuntu de recuperação e o novo kernel Debian.

------------------------------------------------------------------------

## 15. Compartilhamento temporário do `/boot`

A partição `/dev/sdb2`, que já estava montada como `/boot` no Ubuntu, foi disponibilizada dentro do chroot:

``` bash
mount --bind /boot /mnt/debian13/boot
```

Dentro do Debian:

``` bash
findmnt /boot
```

O kernel Debian foi reinstalado para garantir que seus arquivos fossem gravados no `/boot` físico:

``` bash
apt install --reinstall -y linux-image-6.12.94+deb13-amd64
```

O `/boot` passou então a conter simultaneamente:

``` text
Ubuntu 20.04
    vmlinuz-5.4.0-169-generic
    initrd.img-5.4.0-169-generic

Debian 13
    vmlinuz-6.12.94+deb13-amd64
    initrd.img-6.12.94+deb13-amd64
```

------------------------------------------------------------------------

## 16. GRUB e estratégia de rollback

Como o servidor utilizava BIOS/Legacy, foi instalado:

``` bash
apt install -y grub-pc
```

O GRUB foi configurado para apresentar o menu durante os primeiros boots:

``` text
GRUB_DEFAULT=0
GRUB_TIMEOUT=10
GRUB_TIMEOUT_STYLE=menu
```

### Entrada explícita para rollback

Não se confiou exclusivamente no `os-prober`.

Foi criada uma entrada manual para o Ubuntu:

``` bash
cat > /etc/grub.d/41_ubuntu_fallback <<'EOF'
#!/bin/sh
cat <<'GRUBEOF'
menuentry 'Ubuntu 20.04 - FALLBACK' {
    insmod part_gpt
    insmod ext2
    insmod lvm

    search --no-floppy --fs-uuid --set=boot <UUID-DO-BOOT>

    linux /vmlinuz-5.4.0-169-generic root=/dev/mapper/sys-root ro
    initrd /initrd.img-5.4.0-169-generic
}
GRUBEOF
EOF

chmod 755 /etc/grub.d/41_ubuntu_fallback
```

A configuração foi então gerada:

``` bash
update-grub
```

Foram verificadas explicitamente as entradas:

``` bash
grep -nE "^menuentry |^submenu " /boot/grub/grub.cfg

grep -A12 -B2 \
    "Ubuntu 20.04 - FALLBACK" \
    /boot/grub/grub.cfg

grep -A18 -m1 \
    "menuentry 'Debian GNU/Linux'" \
    /boot/grub/grub.cfg
```

O Debian aparecia como entrada padrão utilizando:

``` text
/vmlinuz-6.12.94+deb13-amd64
root=/dev/mapper/sys-Root
```

O Ubuntu permanecia disponível como fallback:

``` text
/vmlinuz-5.4.0-169-generic
root=/dev/mapper/sys-root
```

### Gravação do GRUB

Somente depois dessas validações o bootloader foi efetivamente gravado:

``` bash
grub-install --target=i386-pc /dev/sdb

grub-install --recheck \
    --target=i386-pc /dev/sdb
```

Resultado:

``` text
Installation finished. No error reported.
```

------------------------------------------------------------------------

## 17. Checklist antes do primeiro reboot

Nenhum reboot foi executado imediatamente após a instalação do GRUB.

Foram validados individualmente:

### Root e `/boot`

``` bash
findmnt /
findmnt /boot
findmnt --verify --verbose
```

### Kernel

``` bash
ls -lh \
    /boot/vmlinuz-6.12.94+deb13-amd64 \
    /boot/initrd.img-6.12.94+deb13-amd64
```

### LVM

``` bash
lvs
```

### Driver da interface

``` bash
find /lib/modules/6.12.94+deb13-amd64 \
    -name 'tg3.ko*'
```

### Rede

``` bash
cat /etc/network/interfaces
cat /etc/systemd/network/10-management.link
ifquery enp5s0f0
```

### SSH

``` bash
sshd -t
systemctl is-enabled ssh
```

### GRUB

``` bash
grub-probe --target=device /
grub-probe --target=device /boot
```

Resultado esperado:

``` text
/      -> /dev/mapper/sys-Root
/boot  -> /dev/sdb2
```

Esse checklist foi particularmente importante porque a máquina era administrada remotamente e não havia operador disponível no local para recuperação imediata.

------------------------------------------------------------------------

## 18. Saída do chroot e primeiro reboot

O chroot foi encerrado:

``` bash
exit
```

Os mounts auxiliares foram desmontados:

``` bash
umount /mnt/debian13/boot
umount /mnt/debian13/dev/pts
umount /mnt/debian13/dev
umount /mnt/debian13/proc
umount /mnt/debian13/sys
umount /mnt/debian13/run
umount /mnt/debian13
```

Validação:

``` bash
findmnt -R /mnt/debian13
```

Por fim:

``` bash
sync
sync
reboot
```

------------------------------------------------------------------------
