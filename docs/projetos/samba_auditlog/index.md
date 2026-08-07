# Samba Auditlog --- Auditoria estruturada para servidores Samba

O Samba possui mecanismos nativos capazes de registrar detalhadamente operações sobre arquivos e diretórios. Com `vfs_full_audit`, é possível registrar usuário, origem, compartilhamento e operação. O problema aparece depois: em um servidor com grande volume de eventos, responder **quem acessou, quando acessou, de onde veio, quais caminhos percorreu e quais operações realizou** exige reconstruir uma história a partir de muitas linhas de log.

O **Samba Auditlog** foi criado para facilitar essa investigação. Ele não substitui a auditoria do Samba. Recebe os eventos produzidos pelo `vfs_full_audit`, preserva o registro bruto e cria uma representação interpretada e estruturada no MariaDB. A aplicação Web trabalha sobre essa massa de dados para oferecer diferentes formas de consulta e acompanhamento.

## Visão geral

``` text
Samba / vfs_full_audit
        │
        ▼
     rsyslog
        │ UDP 127.0.0.1:780
        ▼
      Parser
        │
        ├──────────────► registro bruto preservado
        ▼
dados interpretados
        │
        ▼
     MariaDB
        │
        ├── pesquisa por usuário
        ├── pesquisa por arquivo
        ├── itens removidos
        ├── dashboard
        ├── compartilhamentos
        └── alertas
```

O sistema trabalha, portanto, com duas representações: o **registro bruto**, mantido como referência do evento recebido, e a **representação estruturada**, criada para tornar a auditoria pesquisável.

## Documentação por camadas

### 1. Origem do projeto

Por que os logs do Samba, apesar de completos, tornam uma investigação
extensa difícil quando o volume de eventos cresce.

[Origem e problema da auditoria](01-origem-e-problema.md)

### 2. Coleta e transporte

Como `vfs_full_audit` produz os eventos e como o rsyslog seleciona
`smbd_audit` e os encaminha ao parser.

[Coleta com vfs_full_audit e rsyslog](02-coleta-e-transporte.md)

### 3. Parser e normalização

Onde o evento deixa de ser apenas uma linha de log e passa a ser separado em informações utilizáveis pela aplicação, mantendo também o registro bruto.

[Parser e normalização](03-parser-e-normalizacao.md)

### 4. Persistência e histórico

Por que os dados interpretados são armazenados no MariaDB e como isso transforma uma sequência cronológica de eventos em uma massa consultável por diferentes perspectivas.

[Persistência e histórico](04-persistencia-e-historico.md)

### 5. Consulta e investigação

Como a aplicação utiliza a mesma base para pesquisas por usuário, arquivo, itens removidos, compartilhamentos e outras perspectivas.

[Consulta e investigação](05-consulta-e-investigacao.md)

### 6. Histórico e estado atual

A diferença entre os eventos históricos armazenados e as informações atuais obtidas diretamente do Samba através de `smbstatus`.

[Histórico e estado atual](06-historico-e-estado-atual.md)

### 7. Autenticação e autorização

Como LDAP, grupos administrativos e `admin users` do Samba determinam quais compartilhamentos e dados podem ser consultados.

[Autenticação e autorização](07-autenticacao-e-autorizacao.md)

### 8. Alertas

Como informações processadas pelo sistema podem também gerar acompanhamento operacional através do Telegram.

[Alertas](08-alertas.md)

### 9. Operação dos serviços

Como systemd, Supervisor, Gunicorn, Nginx e cron mantêm as responsabilidades operacionais separadas.

[Operação dos serviços](09-operacao-dos-servicos.md)

## Tecnologias utilizadas

O projeto reúne componentes bastante tradicionais de uma infraestrutura Linux:

- Samba;
- `vfs_full_audit`;
- rsyslog;
- Python 3;
- Flask;
- Gunicorn;
- MariaDB;
- LDAP;
- Nginx;
- Supervisor;
- systemd;
- cron;
- Telegram Bot API.

## Arquitetura consolidada

``` text
Clientes SMB
    │
    ▼
Samba / vfs_full_audit
    │
    ▼
rsyslog
    │ UDP/780
    ▼
Parser Python
    │
    ├──────────────► registro bruto
    ▼
MariaDB / Samba_Audit_Log
    │
    ├───────────────┬─────────────────┐
    ▼               ▼                 ▼
Consultas        Dashboard          Alertas
    │                                  │
    ▼                                  ▼
Aplicação Flask                     Telegram
    │
    ├── LDAP
    ├── smbstatus
    ▼
Gunicorn
    │
    ▼
Nginx
    │
    ▼
Navegador
```

## Projeto

O projeto completo está publicado no GitHub:

**Samba Auditlog**  
https://github.com/jemorenojr/Samba_Auditlog

No repositório estão disponíveis:

- código-fonte;
- parser de auditoria;
- aplicação Web;
- scripts auxiliares;
- schema do banco;
- procedures;
- exemplos de configuração do Samba;
- configuração do rsyslog;
- configuração do systemd;
- configuração do Supervisor;
- configuração do Nginx;
- documentação de instalação.

Para reproduzir a solução, consulte principalmente:

```text
README.md
INSTALL.md
```
O projeto foi desenvolvido e testado em Debian 12 e Debian 13.

## Licença

O **Samba Auditlog** é disponibilizado sob a **Apache License 2.0**.

O texto integral da licença está disponível no arquivo `LICENSE` do repositório.

Bibliotecas e componentes de terceiros distribuídos junto ao projeto mantêm suas respectivas licenças.