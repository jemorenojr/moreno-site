# Jump Server Linux com Autenticação Multifator e Ambiente Restrito

## Objetivo

Configurar um Jump Server Linux no qual o usuário acessa o ambiente por meio de SSH, autentica-se com chave individual e passa por validação adicional com MFA TOTP. Após o acesso, a sessão fica restrita a um ambiente mínimo baseado em Chroot Jail.

## Fluxo do procedimento

```text
1. Preparar pacotes
2. Configurar OpenSSH
3. Configurar PAM com Google Authenticator
4. Criar grupo jail
5. Criar ou associar usuário ao grupo jail
6. Construir o ambiente chroot
7. Copiar binários e bibliotecas
8. Testar o chroot
9. Gerar MFA do usuário
10. Liberar acesso SSH
```

Para a visão arquitetural completa, consulte [Arquitetura](arquitetura.md).

## Premissas usadas nos exemplos

| Item | Valor sanitizado |
|------|------------------|
| Usuário de exemplo | `usuario-exemplo` |
| Grupo de confinamento | `jail` |
| Diretório base do jail | `/srv/secure-jail` |
| Diretório do usuário no jail | `/srv/secure-jail/usuario-exemplo` |
| Jump Server | `jump.example.net` |
| Relay SMTP, se usado | `relay.example.net` |

No material original existem caminhos, domínios, usuários e IPs específicos do ambiente de produção. Eles foram substituídos por exemplos neutros nesta versão derivada.

## Pré-requisitos

O servidor precisa ter:

- sistema Linux instalado;
- rede configurada;
- OpenSSH Server;
- PAM habilitado para SSH;
- pacote `libpam-google-authenticator`;
- pacote `qrencode`, quando houver geração de QR Code;
- uma conta administrativa de contingência já testada.

Exemplo de instalação em distribuições compatíveis com `apt`:

```bash
apt-get update
apt-get install openssh-server libpam-google-authenticator qrencode
```

## Configuração

### Configuração do OpenSSH

No arquivo de configuração do OpenSSH, validar as diretivas relacionadas à autenticação por chave pública, PAM e autenticação interativa.

Exemplo sanitizado:

```text
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
PubkeyAuthentication yes
UsePAM yes
AuthenticationMethods publickey,keyboard-interactive
```

Também é necessário `ChallengeResponseAuthentication yes`. Em algumas versões do OpenSSH, a diretiva equivalente pode ser `KbdInteractiveAuthentication`. Confirme a diretiva correta na versão instalada.

Em seguida, configurar a regra para usuários do grupo `jail`:

#### Bloco para usuários confinados

Exemplo sanitizado:

```text
Match Group jail
    ChrootDirectory /srv/secure-jail/%u
```

O grupo seleciona os usuários que receberão a raiz de sistema de arquivos restrita após autenticação.

#### Bloco para conta administrativa

Exemplo sanitizado:

```text
Match User admin-local
    AllowUsers admin-local@localhost admin-local@127.0.0.1 admin-local@::1
```

O objetivo é ter uma conta de gerenciamento com escopo restrito. O contrato dessa conta deve ser validado fora do chroot, uma vez que ela será usada para acesso ao sistema e para sua administração. É uma conta crítica; a disponibilidade da chave SSH e da senha deve ser controlada e protegida.

#### Configuração Debian 12

```
PermitRootLogin no
IgnoreRhosts yes
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication yes
GSSAPIAuthentication yes
GSSAPICleanupCredentials yes
UsePAM yes
AuthenticationMethods publickey,password publickey,keyboard-interactive
X11Forwarding yes
PrintMotd no
ClientAliveInterval 1800
ClientAliveCountMax 3
Banner /etc/ssh/ssh_banner
AcceptEnv LANG LC_*
Subsystem	sftp	/usr/lib/openssh/sftp-server
Match User admin
        AllowUsers admin@localhost admin@127.0.0.1 admin@::1
Match Group jail
        ChrootDirectory /home/Secure/Jail/%u
```

#### Configuração Ubuntu Server 20

```
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
SyslogFacility AUTHPRIV
PubkeyAuthentication yes
AuthorizedKeysFile	.ssh/authorized_keys
PermitEmptyPasswords no
PasswordAuthentication no
ChallengeResponseAuthentication yes
GSSAPIAuthentication yes
GSSAPICleanupCredentials no
UsePAM yes
ClientAliveInterval 120
ClientAliveCountMax 2
AuthenticationMethods publickey,password publickey,keyboard-interactive
X11Forwarding yes
UseDNS no
ChrootDirectory none
AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES
AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT
AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE
AcceptEnv XMODIFIERS
Subsystem	sftp	/usr/libexec/openssh/sftp-server
	
Match User admin
	AllowUsers admin@localhost admin@127.0.0.1
Match Group jail
	ChrootDirectory /home/Secure/Jail/%u
```

#### Validação

Antes de recarregar o serviço SSH:

```bash
sshd -t
```

Mantenha uma sessão administrativa aberta antes de testar novo login.

Aprofundamento: [Configuração OpenSSH](configuracao_openssh_explicacao.md).

### PAM para MFA

A complementação da configuração do SSH ocorre no arquivo PAM usado pelo serviço, normalmente `/etc/pam.d/sshd`. O procedimento consiste em adicionar o módulo do Google Authenticator ao final do arquivo.

Arquivo `/etc/pam.d/sshd`:

```text
auth required pam_google_authenticator.so nullok
```

O parâmetro `nullok` permite login sem MFA para usuários que ainda não possuem `.google_authenticator`. Isso pode ser útil durante a implantação, mas precisa ser tratado como exceção controlada e, se possível, removido ao final.

No Debian é necessário que estas linhas estejam comentadas, já no Ubuntu estas linhas não comprometeram o funcionamento:

```text
#@include common-auth
#@include common-password
```

Essa mudança altera o fluxo de autenticação e deve ser validada por distribuição antes de uso.

Aprofundamento: [Configuração PAM/MFA](configuracao-pam-mfa.md).

### Configuração do chroot

#### Criação do grupo e associação do usuário

Garantir que exista o grupo usado pelo bloco `Match`:

```bash
groupadd -r jail
```

Se o usuário já existir, associar ao grupo:

```bash
usermod -a -G jail usuario-exemplo
```

Se o usuário ainda não existir, ele deve ser criado com home, shell e chave pública antes da liberação do acesso.

Aprofundamento operacional: [Operação e diagnóstico](operacao-diagnostico.md).

#### Construção manual do Chroot Jail

> **Nota operacional:** O ambiente disponibilizado neste procedimento é mínimo e foi pensado para reduzir ao máximo a superfície de um possível ataque. Nele são disponibilizados apenas o shell, comandos mínimos para estabelecimento da sessão, `screen` e `ssh` para acesso à próxima máquina. Outros programas foram excluídos propositalmente.

Criar o diretório do usuário dentro do jail:

```bash
mkdir -p /srv/secure-jail/usuario-exemplo
cd /srv/secure-jail/usuario-exemplo
mkdir -p etc home sys usr/bin usr/sbin var tmp dev
ln -s usr/bin bin
ln -s usr/sbin sbin
ln -s usr/lib lib
ln -s usr/lib64 lib64
chmod 1777 tmp
```

Criar dispositivos básicos dentro do jail:

```bash
mknod -m 666 /srv/secure-jail/usuario-exemplo/dev/null c 1 3
mknod -m 622 /srv/secure-jail/usuario-exemplo/dev/tty c 5 0
mknod -m 666 /srv/secure-jail/usuario-exemplo/dev/zero c 1 5
mknod -m 444 /srv/secure-jail/usuario-exemplo/dev/random c 1 8
mknod -m 444 /srv/secure-jail/usuario-exemplo/dev/urandom c 1 9
```

Copiar dados mínimos do usuário e do grupo para dentro do jail:

```bash
getent passwd usuario-exemplo > /srv/secure-jail/usuario-exemplo/etc/passwd
getent group jail > /srv/secure-jail/usuario-exemplo/etc/group
getent group usuario-exemplo >> /srv/secure-jail/usuario-exemplo/etc/group || true
```

Aprofundamento: [Construção do chroot](construcao-chroot.md).

#### Cópia de binários e bibliotecas

Copiar os programas mínimos. O procedimento mostra o exemplo com `bash` e `ls`; a mesma lógica se aplica aos demais comandos que forem necessários.

```bash
cp /bin/bash /bin/ls /srv/secure-jail/usuario-exemplo/bin/
```

Identificar as bibliotecas usadas por cada binário:

```bash
ldd /bin/bash
ldd /bin/ls
```

Copiar as bibliotecas preservando caminhos:

```bash
cp --parents /lib/x86_64-linux-gnu/libtinfo.so.6 /srv/secure-jail/usuario-exemplo/usr
cp --parents /lib/x86_64-linux-gnu/libdl.so.2 /srv/secure-jail/usuario-exemplo/usr
cp --parents /lib/x86_64-linux-gnu/libc.so.6 /srv/secure-jail/usuario-exemplo/usr
cp --parents /lib64/ld-linux-x86-64.so.2 /srv/secure-jail/usuario-exemplo/usr
```

Copiar também componentes auxiliares quando necessário:

```bash
libnss=$(dpkg -L libc6 | egrep "libnss_files.*\.so$")
cp --preserve=all --parents ${libnss} /srv/secure-jail/usuario-exemplo
cp -r --preserve=all --parents /usr/share/locale/en /srv/secure-jail/usuario-exemplo
cp -r --preserve=all --parents /lib/terminfo /srv/secure-jail/usuario-exemplo
cp -r --preserve=all --parents /usr/share/terminfo /srv/secure-jail/usuario-exemplo
```

Essa é a parte mais sensível do procedimento: copiar somente o binário não basta. Se faltar biblioteca, loader, NSS ou terminfo, o comando pode existir dentro do jail e ainda assim não funcionar.

Aprofundamento: [Construção do chroot](construcao-chroot.md).

#### Teste do chroot

Testar o ambiente antes de liberar o login SSH:

```bash
chroot /srv/secure-jail/usuario-exemplo
```

Dentro do jail, testar:

```bash
ls /
whoami
id
```

Se o shell não abrir ou algum comando falhar, consultar [Operação e diagnóstico](operacao-diagnostico.md).

### Criação manual do MFA

Quando o jail foi criado manualmente, gerar o MFA para o usuário:

```bash
su -l usuario-exemplo -c "google-authenticator -t -d -f -r 3 -R 30 -W -C"
```

O QR Code, a URL `otpauth` e os códigos de emergência são dados sensíveis. Não registre esses dados em documentação pública.

Aprofundamento: [Configuração PAM/MFA](configuracao-pam-mfa.md) e [Segurança e limitações](seguranca-limitacoes.md).

## Procedimento automático

A fim de facilitar a manutenção dos usuários em jail, foi criado um script para automatizar a criação e remoção de usuário, do jail e do MFA.

| **Script** | **Descrição** |
|------------|---------------|
|  [useradd_jail.sh](scripts/useradd_jail.sh)   | Automatiza o processo de criação do usuário, home do usuário em chroot e MFA. [Detalhamento do script](scripts/index.md)       |
|  [userdel_jail.sh](scripts/userdel_jail.sh)  | Automatiza o processo de remoção do usuário e da home do usuário em chroot ( em resumo é userdel com remoção da home ).        |

O script exige previamente:

- nome do usuário;
- nome completo;
- e-mail para envio do QR Code;
- chave pública SSH.

Ele executa, em sequência:

1. validação básica dos dados;
2. criação do usuário;
3. instalação da chave pública;
4. inclusão no grupo `jail`;
5. criação do chroot;
6. cópia de binários e bibliotecas;
7. geração do MFA;
8. envio do QR Code por e-mail.

A documentação específica do `useradd_jail.sh` está disponível em [Detalhamento do script](scripts/index.md).

## Validação final

Antes de considerar o acesso liberado:

- validar `sshd -t`;
- manter sessão administrativa paralela;
- testar login com chave pública;
- confirmar solicitação de MFA;
- confirmar entrada no chroot;
- executar comandos básicos dentro do jail;
- registrar usuário, data, chave por fingerprint e responsável;
- não registrar segredo MFA nem QR Code.
