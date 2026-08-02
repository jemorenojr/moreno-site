# Operação e diagnóstico

## Fluxo operacional de provisionamento

O fluxo consolidado a partir das fontes é:

1. coletar nome de usuário, nome completo, e-mail e chave pública;
2. validar se o usuário já existe;
3. validar minimamente a chave pública;
4. criar o usuário local;
5. instalar `authorized_keys`;
6. associar o usuário ao grupo do jail;
7. criar a árvore de chroot;
8. copiar binários, bibliotecas e arquivos mínimos;
9. criar dispositivos mínimos;
10. gerar o segredo TOTP;
11. gerar QR Code;
12. entregar o MFA ao usuário;
13. testar login com sessão administrativa paralela aberta;
14. registrar a liberação.

## Rotinas de manutenção

- Remover usuário e respectivo jail.
- Trocar chave SSH.
- Recriar segredo MFA.
- Revogar acesso em caso de desligamento ou incidente.
- Incluir novo binário no jail.
- Atualizar bibliotecas após atualização do sistema.
- Reconstruir o jail quando houver mudança significativa na base do sistema.
- Validar `sshd_config` após qualquer alteração.
- Manter procedimento de recuperação administrativa.

## Registro operacional mínimo

Cada provisionamento ou revogação deve registrar:

- solicitante;
- usuário afetado;
- chave pública cadastrada ou revogada, preferencialmente por fingerprint;
- data da geração ou recriação do MFA;
- responsável pela execução;
- resultado do teste de login;
- pendências e exceções aceitas.

Não registrar segredo TOTP, QR Code ou códigos de emergência.

## Rollback

As fontes históricas não apresentam rollback transacional completo. Em caso de falha parcial, verificar e limpar manualmente:

- conta local;
- grupo suplementar;
- home original;
- diretório dentro do jail;
- arquivo `.google_authenticator`;
- chave em `authorized_keys`;
- arquivos temporários de QR Code;
- alterações feitas em conta administrativa de contingência.

## Diagnóstico

### Chave SSH rejeitada

Verificar:

- presença da chave pública correta em `authorized_keys`;
- permissões do diretório home, `.ssh` e `authorized_keys`;
- formato da chave;
- usuário informado na conexão;
- logs do OpenSSH.

### MFA não solicitado

Verificar:

- `UsePAM yes`;
- método interativo habilitado na versão do OpenSSH;
- presença do módulo `pam_google_authenticator.so`;
- ordem da pilha PAM;
- efeito do parâmetro `nullok`;
- existência do arquivo `.google_authenticator`.

### MFA sempre rejeitado

Verificar:

- horário do servidor;
- horário do dispositivo do usuário;
- segredo TOTP cadastrado;
- recriação recente do arquivo `.google_authenticator`;
- permissões do arquivo de MFA.

### Login autentica, mas o chroot falha

Verificar:

- propriedade do diretório usado por `ChrootDirectory`;
- permissões dos diretórios acima do jail;
- existência da árvore do usuário;
- expansão correta de `%u`;
- logs do OpenSSH.

### Comando não encontrado dentro do jail

Verificar:

- presença do binário;
- variável `PATH`;
- symlinks `bin`, `sbin`, `lib` e `lib64`;
- shell configurado para o usuário.

### Biblioteca ou loader ausente

Verificar:

- saída de `ldd` do binário fora do jail;
- presença do loader dinâmico;
- bibliotecas em caminhos multiarquitetura;
- cópia com `--parents`;
- bibliotecas carregadas indiretamente em tempo de execução.

### DNS sem funcionar dentro do jail

Verificar:

- `/etc/resolv.conf`;
- `/etc/nsswitch.conf`;
- bibliotecas NSS;
- permissões dos arquivos copiados.

### Terminal quebrado

Verificar:

- `TERM`;
- terminfo em `/lib/terminfo` ou `/usr/share/terminfo`;
- arquivos de perfil carregados no shell.

### Envio do QR Code falhando

Verificar:

- conectividade com o relay;
- porta SMTP;
- formato dos endereços;
- resposta SMTP real;
- geração do arquivo PNG;
- remoção prematura de temporários.

### Usuário criado parcialmente

Verificar:

- usuário local;
- home original;
- home copiado para o jail;
- grupo;
- arquivo `.google_authenticator`;
- arquivo temporário de QR Code;
- diretório do jail;
- necessidade de rollback manual.

## Relação com implantação

- Requisitos prévios estão em [Pré-requisitos](index.md).
- Falhas ligadas ao OpenSSH devem ser cruzadas com [Configuração OpenSSH](configuracao_openssh_explicacao.md).
- Falhas de segundo fator devem ser cruzadas com [Configuração PAM/MFA](configuracao-pam-mfa.md).
- Falhas de ambiente restrito devem ser cruzadas com [Construção do chroot](construcao-chroot.md).
