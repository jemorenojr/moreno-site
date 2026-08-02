# Arquitetura

## Responsabilidade da solução

A Jump Server centraliza o acesso administrativo a servidores Linux. Ela recebe conexões SSH autorizadas, aplica autenticação multifator e entrega ao usuário um ambiente de shell limitado por Chroot Jail.

O papel principal da arquitetura é reduzir a quantidade de pontos expostos e tornar o fluxo de entrada previsível. Ela não substitui políticas de identidade, segmentação de rede, gestão de privilégios ou auditoria centralizada.

## Fronteiras

A solução cobre:

- autenticação inicial por chave pública;
- solicitação de segundo fator TOTP;
- associação de usuários a um grupo de acesso;
- confinamento de sistema de arquivos com `ChrootDirectory`;
- disponibilização controlada de binários dentro do jail;
- acesso posterior aos servidores internos a partir da Jump Server.

A solução não cobre:

- isolamento forte equivalente a container ou máquina virtual;
- gestão centralizada de identidades;
- rotação automática de chaves;
- auditoria completa de comandos;
- proteção contra comprometimento da própria Jump Server.

## Fluxo de autenticação

```text
1. Usuário inicia SSH para jump.example.net
2. OpenSSH valida a chave pública
3. OpenSSH aciona PAM
4. PAM solicita código TOTP
5. Módulo pam_google_authenticator valida o código
6. OpenSSH aplica Match Group e ChrootDirectory
7. Usuário recebe shell dentro do jail
8. Usuário acessa destinos internos permitidos
```

## Separação de responsabilidades

| Camada | Pergunta respondida | Mecanismo |
|--------|---------------------|-----------|
| Autenticação | O usuário consegue provar quem é? | Chave pública e TOTP. |
| Autorização | O usuário pertence ao grupo tratado pela regra? | Conta local, grupo e regras `Match`. |
| Confinamento | Qual árvore de arquivos o usuário enxerga? | `ChrootDirectory`. |
| Acesso posterior | Para onde o usuário pode seguir depois do login? | Ferramentas disponíveis no jail e regras de rede. |
| Auditoria | O que precisa ser registrado? | Logs de SSH, PAM, alterações operacionais e mecanismos externos. |

Essa separação evita tratar o chroot como se fosse autenticação ou autorização. O chroot é aplicado depois que o usuário já foi autenticado.

## Componentes e responsabilidades

| Componente | Responsabilidade |
|------------|------------------|
| OpenSSH | Receber conexões, validar chave pública e aplicar regras `Match`. |
| PAM | Inserir o segundo fator no processo de autenticação. |
| `pam_google_authenticator.so` | Validar o código TOTP associado ao usuário. |
| Grupo `jail` | Selecionar usuários sujeitos ao `ChrootDirectory`. |
| Chroot | Reduzir a visão do sistema de arquivos após login. |
| Scripts históricos | Provisionar usuários, ambiente, MFA e remoção. |
| Relay SMTP | Enviar QR Code e dados iniciais de MFA no modelo histórico. |

## Modelo de confiança

A arquitetura pressupõe que:

- a Jump Server é administrada como ativo crítico;
- cada usuário possui chave SSH individual;
- o segredo TOTP é entregue de forma controlada;
- os servidores internos confiam na Jump Server como ponto de entrada;
- o grupo usado no bloco `Match` representa usuários que devem ser confinados.

Também pressupõe que os servidores internos aceitam a Jump Server como origem administrativa controlada. Essa relação deve ser documentada na política de rede e nas regras de firewall, mas esses detalhes não aparecem completos nas fontes históricas.

## Pontos únicos de falha

- Indisponibilidade da Jump Server bloqueia o acesso administrativo centralizado.
- Erro na pilha PAM pode impedir autenticações legítimas.
- Erro no `sshd_config` pode impedir novas sessões.
- Falha na conta administrativa de contingência pode dificultar recuperação.
- Bibliotecas ausentes no jail podem impedir comandos básicos.

## Dependências externas

- Repositório de pacotes da distribuição para instalação e atualização.
- Sincronismo de horário para validação TOTP.
- Relay SMTP, se o fluxo de entrega de QR Code por e-mail for mantido.
- Resolução DNS, quando comandos dentro do jail dependem de nomes.
- Política externa de backup e recuperação da Jump Server.

## Decisões registradas

- Concentrar acesso externo em uma máquina intermediária para reduzir pontos de entrada.
- Combinar chave pública e TOTP para evitar dependência exclusiva de senha.
- Usar chroot para limitar o ambiente pós-login.
- Manter um usuário administrativo de contingência fora do fluxo comum, sujeito a validação operacional.

## Relação com outros documentos

- Detalhamento do SSH está em [Detalhamento da configuração do OpenSSH](configuracao_openssh_explicacao.md).
- A configuração de segundo fator está em [Configuração PAM/MFA](configuracao-pam-mfa.md).
- A composição do ambiente restrito está em [Construção do chroot](construcao-chroot.md).
- Os riscos estão consolidados em [Segurança e limitações](seguranca-limitacoes.md).
