# Script useradd_jail.sh

Este documento detalha o funcionamento do script `useradd_jail.sh`, os pré-requisitos necessários para sua execução e as configurações exigidas para o envio do QR Code de MFA por e-mail.

O script automatiza a criação de um usuário de acesso SSH confinado em chroot, configura chave pública, prepara a estrutura mínima do jail, gera o segredo TOTP com `google-authenticator`, cria um QR Code com `qrencode` e envia as informações iniciais de MFA por SMTP usando `nc`.

> O envio do QR Code e da URL `otpauth` por e-mail expõe o segredo inicial do segundo fator. Esse fluxo deve ser tratado como procedimento operacional controlado, não como recomendação genérica de segurança.

## Responsabilidade

O `useradd_jail.sh` executa as seguintes responsabilidades em uma única rotina:

- coleta os dados do usuário;
- valida minimamente nome de usuário, e-mail não vazio e chave pública SSH;
- cria o grupo `jail`, se ele ainda não existir;
- cria o usuário local com shell `/bin/bash`;
- instala a chave pública em `authorized_keys`;
- cria a área do usuário dentro do diretório de chroot;
- copia binários, arquivos de configuração e bibliotecas necessários para o ambiente confinado;
- cria dispositivos básicos em `dev`;
- gera o arquivo `.google_authenticator` para o usuário;
- extrai a URL `otpauth`;
- gera uma imagem PNG do QR Code;
- envia a URL, os códigos gerados e o QR Code por e-mail;
- remove o arquivo temporário do QR Code ao final.

O script não substitui a configuração prévia do OpenSSH, PAM, Google Authenticator ou relay SMTP. Ele pressupõe que o servidor já está preparado para autenticação com chave pública, MFA e chroot.

## Pré-requisitos do sistema

Antes de executar o script, o servidor deve possuir:

- OpenSSH Server instalado e em operação;
- `ChrootDirectory` configurado em `/etc/ssh/sshd_config`;
- autenticação PAM integrada ao Google Authenticator;
- pacote `libpam-google-authenticator`;
- comando `google-authenticator` disponível;
- comando `qrencode` disponível;
- comando `nc` disponível em `/usr/bin/nc`;
- comando `dpkg` disponível, pois o script usa `dpkg -L libc6`;
- comandos administrativos `useradd`, `groupadd`, `getent`, `mknod`, `chmod`, `chown` e `find`;
- acesso de rede ao relay SMTP configurado no script;
- permissão de execução como usuário privilegiado, normalmente `root`.

Também é necessário que o servidor tenha os binários e arquivos listados na variável `arquivos`, porque eles serão copiados para dentro do jail com suas bibliotecas:

```bash
/bin/awk
/bin/bash
/bin/grep
/bin/groups
/bin/id
/bin/ls
/bin/ping
/bin/sh
/bin/ssh
/usr/bin/ssh-add
/bin/whoami
/etc/bash.bashrc
/etc/group
/etc/nsswitch.conf
/etc/passwd
/etc/profile
/etc/profile.d/tmout.sh
/etc/profile.d/aliases.sh
/etc/profile.d/history.sh
/etc/resolv.conf
/usr/bin/dircolors
/etc/bash_completion
/etc/profile.d/bash_completion.sh
/usr/share/bash-completion/bash_completion
```

Se algum desses arquivos não existir no sistema, o script apenas registra a mensagem de erro para aquele item e continua a execução. Isso pode gerar um jail incompleto.

## Configuração SSH esperada

O diretório base do jail é descoberto automaticamente a partir de `/etc/ssh/sshd_config`:

```bash
JAIL_DIR=$(grep ChrootDirectory /etc/ssh/sshd_config | grep -v '#' | awk '{gsub("/%u", "" ,$0)}{print  $2}')
```

Por esse motivo, a configuração do OpenSSH deve conter uma diretiva `ChrootDirectory` compatível com o padrão usado no procedimento:

```text
ChrootDirectory /home/Secure/Jail/%u
```

O script remove o trecho `/%u` e usa o diretório restante como base. No exemplo acima, o valor efetivo de `JAIL_DIR` passa a ser:

```text
/home/Secure/Jail
```

Se a diretiva não existir, estiver comentada ou tiver formato diferente, a descoberta automática pode falhar ou apontar para um diretório incorreto.

## Configurações de e-mail

O envio de e-mail é controlado pelas variáveis definidas no início do script:

```bash
EMAIL_FROM="infra@example.net"
EMAIL_FROM_DESC="Backup"
EMAIL_SUBJ="[${EMAIL_FROM_DESC}] - MFA ${EMAIL_FROM_DESC} - Seguranca Jail"
EMAIL_SERVER="relay.example.net"
EMAIL_PORT="25"
NC="/usr/bin/nc"
```

Esses valores devem ser revisados antes da execução em outro ambiente.

### EMAIL_FROM

Define o remetente usado no comando SMTP `MAIL FROM` e no cabeçalho MIME `From`.

O valor deve ser um endereço aceito pelo relay SMTP. Exemplo:

```bash
EMAIL_FROM="infra@example.net"
```

Se o relay aplicar validação de remetente, SPF interno, lista de remetentes autorizados ou restrição por domínio, esse endereço precisa estar autorizado.

### EMAIL_FROM_DESC

Define o nome descritivo exibido no cabeçalho `From` e também compõe o assunto.

Exemplo:

```bash
EMAIL_FROM_DESC="Equipe de Infraestrutura"
```

Esse texto não autentica o remetente. Ele apenas melhora a identificação visual da mensagem para o destinatário.

### EMAIL_SUBJ

Define o assunto da mensagem. O script codifica o assunto em Base64 no formato MIME:

```bash
ESUBJECT='=?utf-8?B?'$(echo "${EMAIL_SUBJ}" | base64 -w 0)'?='
```

O assunto pode conter texto em português, mas deve evitar dados sensíveis, segredo MFA, nome de host interno crítico ou identificadores de cliente.

### EMAIL_SERVER

Define o relay SMTP usado para entrega da mensagem.

Exemplo:

```bash
EMAIL_SERVER="relay.example.net"
```

O servidor informado precisa aceitar conexões SMTP vindas do host que executa o script. O script não faz autenticação SMTP, não usa STARTTLS e não negocia TLS. Portanto, o relay deve permitir entrega direta em rede confiável ou o fluxo deve ser adaptado antes de uso em ambiente que exija autenticação ou criptografia.

### EMAIL_PORT

Define a porta TCP usada para conexão com o relay SMTP.

O script está preparado para SMTP simples na porta `25`:

```bash
EMAIL_PORT="25"
```

Portas como `465` ou `587` normalmente exigem TLS, STARTTLS ou autenticação, recursos que o script atual não implementa.

### NC

Define o caminho do comando Netcat usado para abrir a sessão SMTP:

```bash
NC="/usr/bin/nc"
```

O script usa:

```bash
${NC} -w 30 -v ${EMAIL_SERVER} ${EMAIL_PORT}
```

O binário deve existir nesse caminho. Em distribuições diferentes, pode ser necessário ajustar para outro caminho ou variante de Netcat.

## Requisitos para entrega de e-mail

Antes de usar o script em operação, validar:

- resolução DNS do relay SMTP;
- conectividade TCP até `EMAIL_SERVER:EMAIL_PORT`;
- permissão do host de origem no relay;
- aceitação do remetente configurado em `EMAIL_FROM`;
- aceitação do destinatário informado na execução;
- ausência de exigência de autenticação SMTP;
- ausência de exigência de TLS ou STARTTLS;
- política de tamanho de mensagem compatível com anexo PNG;
- roteamento de saída e firewall liberados.

Um teste simples de conectividade TCP pode ser feito com:

```bash
nc -vz relay.example.net 25
```

Esse teste confirma apenas a abertura da conexão TCP. Ele não confirma aceitação de remetente, destinatário, conteúdo ou política antispam.

## Dados solicitados na execução

Durante a execução, o script solicita:

- `Usuario`: login local a ser criado;
- `Nome completo usuario`: descrição usada no cadastro do usuário;
- `Email do usuario`: destinatário do QR Code e das informações de MFA;
- `Chave publica SSH`: chave pública instalada em `authorized_keys`;
- `Usuario acessará o roo via admin? <N|s>`: opção para acrescentar a chave pública também ao usuário `admin`, caso exista.

O campo de e-mail é validado apenas contra valor vazio. O script não valida formato, domínio, destinatário permitido ou múltiplos destinatários. O campo deve ser preenchido com um único endereço de e-mail operacionalmente aprovado.

## Fluxo de processamento

O processamento geral é:

1. identifica o diretório base do jail a partir do `sshd_config`;
2. cria o diretório base, se necessário;
3. coleta usuário, nome, e-mail e chave SSH;
4. impede criação se o usuário já existir;
5. valida o nome do usuário com expressão regular simples;
6. valida se a chave contém `ssh-rsa`, `ssh-ed25519` ou `ecdsa`;
7. opcionalmente adiciona a chave ao usuário `admin`;
8. cria o grupo `jail`, se necessário;
9. cria o usuário local;
10. instala a chave pública e ajusta permissões da home;
11. cria a árvore de diretórios do jail do usuário;
12. cria links simbólicos para `bin`, `sbin`, `lib` e `lib64`;
13. copia arquivos e bibliotecas para dentro do jail;
14. ajusta permissões de diretórios e arquivos copiados;
15. cria arquivos mínimos de `hosts`, `passwd` e `group` dentro do jail;
16. cria dispositivos básicos com `mknod`;
17. gera o MFA com `google-authenticator`;
18. converte a URL `otpauth` em QR Code PNG;
19. monta uma mensagem MIME multipart;
20. envia a mensagem por SMTP via `nc`;
21. remove o PNG temporário.

## Saída esperada

Ao final, espera-se que existam:

- usuário local criado no sistema;
- usuário incluído no grupo `jail`;
- chave pública instalada em `/home/<usuario>/.ssh/authorized_keys`;
- área do jail criada em `JAIL_DIR/<usuario>`;
- arquivos mínimos de shell e bibliotecas copiados para o jail;
- arquivo `.google_authenticator` criado na home real do usuário;
- e-mail enviado ao usuário com URL `otpauth`, códigos gerados e QR Code em anexo.

O script não confirma de forma robusta se o servidor SMTP aceitou todas as etapas da transação. A saída do `nc` deve ser observada pelo operador.

## Tratamento de erros e limitações

As principais limitações observáveis são:

- não há rollback automático em caso de falha parcial;
- a validação de e-mail verifica apenas se o campo não está vazio;
- a validação de chave SSH é básica e baseada em substring;
- o SMTP é montado manualmente via `echo` e `nc`;
- as respostas SMTP não são interpretadas etapa por etapa;
- o envio não usa autenticação nem criptografia;
- o QR Code é gerado em arquivo temporário local antes do envio;
- a criação de `dev` pode falhar em reexecução se o diretório já existir;
- o jail pode ficar incompleto se algum binário, arquivo ou biblioteca não existir;
- a cópia de dependências depende do formato de saída de `ldd`;
- a descoberta de `ChrootDirectory` depende do formato do `sshd_config`;
- o script deve ser executado com privilégios elevados.

Esses pontos não impedem o uso em ambiente controlado, mas precisam ser considerados antes de tratar o script como automação genérica ou reutilizável fora do contexto original.

## Validação operacional

Após executar o script, validar:

- existência do usuário com `getent passwd <usuario>`;
- participação no grupo `jail`;
- permissões de `/home/<usuario>` e `/home/<usuario>/.ssh/authorized_keys`;
- existência de `JAIL_DIR/<usuario>`;
- existência de `/home/<usuario>/.google_authenticator`;
- recebimento do e-mail pelo usuário;
- leitura do QR Code no aplicativo autenticador;
- login SSH com chave pública;
- solicitação do código MFA;
- entrada efetiva no chroot;
- execução de comandos básicos dentro do jail, como `whoami`, `id`, `ls` e `ssh`.

Não registrar em documentação, chamados ou histórico operacional o conteúdo da URL `otpauth`, QR Code, segredo MFA ou códigos de emergência.

## Relação com o procedimento principal

Esta página detalha apenas o script `useradd_jail.sh`. O procedimento completo de preparação do servidor continua documentado em [Arquitetura de acesso seguro com Jump Server, MFA e Chroot](../index.md).

Para análise de riscos e limitações gerais da solução, consultar [Segurança e limitações](../seguranca-limitacoes.md).
