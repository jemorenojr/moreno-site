# Migração remota de Ubuntu 20.04 para Debian 13 usando `debootstrap` e LVM

## Visão geral

Este documento descreve uma migração **in-place assistida**, realizada remotamente, de Ubuntu 20.04 LTS para Debian 13 (Trixie), sem utilizar mídia de instalação e sem interromper o sistema durante a preparação.

A estratégia foi aproveitar o LV originalmente dedicado a swap para criar um novo filesystem raiz para o Debian. O Debian foi instalado com `debootstrap` enquanto o Ubuntu permanecia em produção. A partição `/boot` existente foi temporariamente compartilhada entre os dois sistemas e o GRUB foi configurado com uma entrada explícita de fallback para o Ubuntu.

> **Importante:** este procedimento manipula LVM, `/boot`, initramfs e GRUB. Um erro pode tornar o servidor não inicializável ou inacessível remotamente. O procedimento deve ser adaptado ao layout real da máquina e executado somente após levantamento completo do ambiente.

## Documentos da série

- [Levantamento e preparação](01-levantamento-e-preparacao.md)
- [Instalação e configuração do Debian](02-instalacao-e-configuracao.md)
- [Boot, GRUB e rollback](03-boot-grub-e-rollback.md)
- [Resultado e lições aprendidas](04-resultado-e-licoes.md)

------------------------------------------------------------------------

## 1. Cenário inicial

O servidor executava:

``` text
Ubuntu 20.04.4 LTS
Kernel 5.4.0-169-generic
Arquitetura amd64
Boot BIOS/Legacy
LVM
```

Layout lógico relevante:

``` text
VG sys
├── root    15 GiB
├── swap    16 GiB
├── tmp      5 GiB
├── var     30 GiB
├── usr     20 GiB
└── home    14 GiB
```

Havia ainda outro VG, destinado aos dados da aplicação, que **não deveria ser alterado**.

O disco de sistema utilizava GPT:

``` text
/dev/sdb1    1 MiB    BIOS boot
/dev/sdb2    1 GiB    /boot (ext4)
/dev/sdb3  100 GiB    LVM - VG sys
/dev/sdb4   ...       LVM - dados da aplicação
```

A dificuldade era direta: o VG `sys` não possuía espaço livre.

Por outro lado, o servidor tinha aproximadamente 32 GiB de RAM e a swap de 16 GiB estava completamente sem uso. Isso permitiu reaproveitar o LV de swap como área para a nova instalação.

------------------------------------------------------------------------

## 2. Princípio da migração

A estratégia adotada foi:

``` text
Sistema em execução
Ubuntu 20.04
    |
    +-- sys/root   -> Ubuntu /
    +-- sys/usr    -> Ubuntu /usr
    +-- sys/var    -> Ubuntu /var
    +-- sys/home   -> Ubuntu /home
    +-- sys/tmp    -> Ubuntu /tmp
    |
    +-- sys/swap
          |
          +-- swapoff
          +-- lvremove
          +-- novo LV sys/Root
                  |
                  +-- ext4
                  +-- Debian 13 via debootstrap
```

Durante toda a instalação do Debian, o Ubuntu continuou executando normalmente.

A indisponibilidade ocorreu apenas no reboot necessário para transferir o controle ao novo sistema.

------------------------------------------------------------------------
