# Construção do chroot

## Objetivo

Construir uma árvore de sistema de arquivos suficiente para que o usuário autenticado receba um shell funcional sem enxergar o sistema de arquivos real da Jump Server.

## Estrutura mínima

Exemplo sanitizado:

```text
/Secure/Jail/
└── usuario-exemplo
    ├── bin -> usr/bin
    ├── dev
    ├── etc
    ├── home
    ├── lib -> usr/lib
    ├── lib64 -> usr/lib64
    ├── tmp
    ├── usr
    └── var
```

## Permissões

O diretório usado em `ChrootDirectory` deve atender às exigências do OpenSSH. Diretórios do caminho do chroot não podem ser graváveis pelo usuário confinado.

O diretório gravável do usuário deve ficar dentro do jail, normalmente abaixo de `home/usuario-exemplo`.

## Binários

O projeto disponibiliza somente estes comandos. Essa escolha é intencional e tem como premissa fornecer um ambiente altamente restritivo, com superfície mínima de ataque:

```text
./usr/bin/bash
./usr/bin/ls
./usr/bin/ssh
./usr/bin/screen
./usr/bin/id
./usr/bin/sh
./usr/bin/grep
```

Cada comando incluído deve ter justificativa operacional e análise de risco.

## Bibliotecas e loader

Programas dinâmicos dependem de bibliotecas e do loader. Por isso, copiar apenas o binário não basta.

Para resolver a questão das dependências de biblioteca, usa-se o `ldd` para descobrir dependências e `cp --parents` para preservar caminhos.

## Arquivos auxiliares

No ambiente criado, o jail exige:

- `/etc/passwd`;
- `/etc/group`;
- `/etc/nsswitch.conf`;
- `/etc/resolv.conf`;
- bibliotecas NSS;
- arquivos de perfil do shell.

Esses arquivos devem conter somente o necessário para o ambiente confinado.

## Dispositivos mínimos

Há também a necessidade de dispositivos como:

```text
null
tty
zero
random
urandom
```

A criação com `mknod` altera o sistema de arquivos e deve ser feita apenas dentro da árvore correta do jail.

## Testes

Testes esperados antes de liberar um usuário:

- login SSH aplica chroot;
- shell inicia;
- `id` e `groups` retornam dados coerentes;
- `ssh` está disponível quando necessário;
- DNS funciona se houver acesso por nome;
- terminal não fica quebrado;
- bibliotecas necessárias estão presentes.

## Limitações de manutenção

Quando o sistema base é atualizado, bibliotecas copiadas para o jail podem ficar obsoletas. A solução precisa de rotina para reconstruir ou atualizar jails existentes.
