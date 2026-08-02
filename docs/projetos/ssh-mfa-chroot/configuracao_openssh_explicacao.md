# Detalhamento da configuração do OpenSSH (`sshd_config`)

Esta documentação fornece uma análise detalhada e estruturada da política de segurança e dos parâmetros aplicados no arquivo de configuração do servidor SSH (`/etc/ssh/sshd_config`).

A configuração analisada adota uma **postura de segurança robusta (*hardening*)**, implementando **autenticação de múltiplos fatores (MFA)**, restrição estrita do usuário administrador e isolamento de usuários em ambiente fechado (*Chroot Jail*).

---

## Resumo da política de segurança

* **MFA obrigatório:** exige chave pública **+** senha/código interativo para autenticação.
* **Acesso root:** bloqueado diretamente via SSH.
* **Usuário admin:** restrito exclusivamente a conexões com origem no próprio servidor (`localhost`).
* **Grupo jail:** usuários isolados dentro de um diretório chroot dedicado.

---

## Autenticação e controle de acesso

### Bloqueio do usuário root

```ssh
PermitRootLogin no
```

* **Descrição:** impede que o usuário `root` faça login direto via SSH.
* **Impacto de segurança:** reduz a superfície de ataque para tentativas de força bruta contra a conta superusuária. Administradores devem se autenticar com uma conta comum e elevar privilégios via `sudo`.

### Desativação de mecanismos legados e senhas vazias

```ssh
IgnoreRhosts yes
PermitEmptyPasswords no
```

* `IgnoreRhosts yes`: ignora arquivos `.rhosts` e `.shosts`, prevenindo autenticações baseadas na confiança fraca legada do protocolo `rlogin`.
* `PermitEmptyPasswords no`: impede o acesso de qualquer conta de usuário que não possua uma senha definida.

### Integração com PAM e GSSAPI (Kerberos)

```ssh
GSSAPIAuthentication yes
GSSAPICleanupCredentials yes
UsePAM yes
```

* `GSSAPIAuthentication yes`: habilita suporte à autenticação centralizada, como Kerberos ou Active Directory.
* `GSSAPICleanupCredentials yes`: garante que os privilégios e *tickets* do Kerberos sejam removidos ao encerrar a sessão.
* `UsePAM yes`: ativa a integração com o *Pluggable Authentication Modules* (PAM) do Linux para gerenciamento centralizado de regras de autenticação, políticas de senha e módulos de segurança adicionais.

---

## Requisito de múltiplos fatores (MFA/2FA)

Esta seção define a regra mais crítica de acesso ao servidor:

```ssh
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication yes
AuthenticationMethods publickey,password publickey,keyboard-interactive
```

### Detalhamento dos mecanismos

* `PasswordAuthentication no`: desativa a autenticação tradicional que exige *apenas* a senha do usuário.
* `PubkeyAuthentication yes`: habilita a autenticação via pares de chaves SSH (`id_rsa`, `id_ed25519`, etc.).
* `ChallengeResponseAuthentication yes`: habilita a autenticação interativa baseada em desafios, necessária para módulos OTP/PAM como Google Authenticator.

### Aplicação de MFA (`AuthenticationMethods`)

A linha `AuthenticationMethods publickey,password publickey,keyboard-interactive` estabelece que o cliente deve fornecer **dois fatores sequenciais** para obter acesso:

1. **Fator 1:** uma **chave pública** (*pubkey*) válida.
2. **Fator 2:** uma **senha** ou um desafio interativo (**keyboard-interactive**/OTP).

> **Nota operacional:** Embora `PasswordAuthentication` esteja desativado isoladamente, o uso em `AuthenticationMethods` permite que a senha seja solicitada *exclusivamente* como segundo fator, após a validação bem-sucedida da chave pública.

---

## Sessão, ambiente e mensagens

```ssh
X11Forwarding yes
PrintMotd no
ClientAliveInterval 1800
ClientAliveCountMax 3
Banner /etc/ssh/ssh_banner
AcceptEnv LANG LC_*
```

* `X11Forwarding yes`: permite o redirecionamento da interface gráfica de aplicações do servidor para a máquina do cliente. *(Recomendação: desativar se não for utilizado).*
* `PrintMotd no`: impede que o próprio serviço `sshd` exiba a mensagem do dia (*Message of the Day*), delegando essa exibição ao módulo PAM.
* `ClientAliveInterval 1800` & `ClientAliveCountMax 3`:
  * o servidor envia uma sondagem a cada **1800 segundos (30 minutos)** para verificar a presença do cliente;
  * caso o cliente não responda por **3 vezes consecutivas**, a sessão é encerrada por inatividade, com tempo total sem resposta de **1,5 hora**.
* `Banner /etc/ssh/ssh_banner`: exibe o texto do arquivo `/etc/ssh/ssh_banner` antes da autenticação, utilizado para avisos legais de privacidade e autorização.
* `AcceptEnv LANG LC_*`: permite a transferência das variáveis de ambiente de idioma e codificação do cliente para o servidor.

---

## Subsistema SFTP e bloco condicional (`Match`)

```ssh
Subsystem sftp /usr/lib/openssh/sftp-server
```

Define o executável encarregado de processar as conexões de transferência de arquivos via SFTP.

### Restrição do usuário administrador

```ssh
Match User admin
        AllowUsers admin@localhost admin@127.0.0.1 admin@::1
```

* **Descrição:** aplica uma regra condicional para a conta `admin`.
* **Efeito:** o usuário `admin` fica estritamente restrito a conexões com origem na própria máquina local (`localhost`, `127.0.0.1` ou `::1` em IPv6). Conexões diretas da rede externa para essa conta serão rejeitadas.

### Isolamento em chroot (grupo jail)

```ssh
Match Group jail
        ChrootDirectory /home/Secure/Jail/%u
```

* **Descrição:** aplica uma regra condicional para qualquer usuário pertencente ao grupo `jail`.
* **Efeito:** redireciona a raiz do sistema de arquivos (`/`) do usuário para o diretório `/home/Secure/Jail/<nome_do_usuario>` no momento do login. O usuário fica restrito à sua pasta e impedido de navegar na estrutura do sistema operacional.

---

## Verificação e aplicação das alterações

Antes de reiniciar o serviço em produção, recomenda-se validar a sintaxe das configurações para prevenir interrupções de acesso:

```bash
# Validar a sintaxe do arquivo de configuração
sudo sshd -t

# Recarregar as configurações do serviço sem derrubar conexões ativas
sudo systemctl reload sshd
```

Durante o teste:

- manter sessão administrativa já autenticada;
- testar novo login com usuário controlado;
- validar autenticação por chave;
- validar solicitação de TOTP, que depende da configuração MFA explicada em seção própria;
- validar aplicação do chroot, que depende de ambiente chroot já preparado;
- revisar logs do serviço SSH.
