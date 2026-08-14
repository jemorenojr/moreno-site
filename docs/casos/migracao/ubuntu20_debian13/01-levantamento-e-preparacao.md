# Levantamento e preparação

## 3. Levantamento obrigatório antes de qualquer alteração

Antes de modificar discos ou LVM, foram coletadas informações do ambiente.

### Sistema operacional e arquitetura

``` bash
cat /etc/os-release
uname -a
dpkg --print-architecture
```

### Modo de boot

``` bash
[ -d /sys/firmware/efi ] && echo "UEFI" || echo "BIOS/LEGACY"
```

Neste caso:

``` text
BIOS/LEGACY
```

Essa informação é crítica para a instalação posterior do GRUB.

### Filesystems

``` bash
df -hT
findmnt /
findmnt /boot
```

### LVM

``` bash
pvs -o pv_name,vg_name,pv_size,pv_free
vgs
lvs -a -o lv_name,vg_name,lv_size,lv_attr,devices
```

### Particionamento

``` bash
fdisk -l
```

### Swap

``` bash
swapon --show
cat /proc/swaps
free -h
```

No caso executado:

``` text
Swap: 16 GiB
Uso:  0 B
```

Esse dado foi determinante para prosseguir.

------------------------------------------------------------------------

## 4. Transformando a swap no novo root

Primeiro a swap foi retirada de operação:

``` bash
swapoff /dev/mapper/sys-swap
```

Validação:

``` bash
swapon --show
free -h
```

Somente depois de confirmar que não havia swap ativa, o LV foi removido:

``` bash
lvremove sys/swap
```

Foi criado um novo LV de 16 GiB:

``` bash
lvcreate -n Root -L 16G sys
```

> O nome `Root`, com `R` maiúsculo, foi proposital para distingui-lo claramente do antigo `sys/root` do Ubuntu durante o período de coexistência.

O novo filesystem foi criado em ext4:

``` bash
mkfs.ext4 -L Root /dev/mapper/sys-Root
```

E montado:

``` bash
mkdir -p /mnt/debian13
mount /dev/mapper/sys-Root /mnt/debian13
```

Validação:

``` bash
findmnt /mnt/debian13
df -hT /mnt/debian13
blkid /dev/mapper/sys-Root
```

------------------------------------------------------------------------

## 5. Atualização do `debootstrap`

O Ubuntu 20.04 possuía uma versão antiga do `debootstrap`, sem script para Debian 13/Trixie.

A versão original era:

``` text
debootstrap 1.0.118ubuntu1.11
```

Foi obtido um pacote mais recente diretamente do repositório Debian e instalado:

``` bash
wget https://deb.debian.org/debian/pool/main/d/debootstrap/debootstrap_1.0.144_all.deb

dpkg-deb -I debootstrap_1.0.144_all.deb

dpkg -i debootstrap_1.0.144_all.deb
```

Validação:

``` bash
debootstrap --version
ls -l /usr/share/debootstrap/scripts/trixie
```

Resultado:

``` text
debootstrap 1.0.144
trixie -> sid
```

------------------------------------------------------------------------
