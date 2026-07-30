# Diagnóstico de erro "no pg_hba.conf entry" causado por método de autenticação inválido no PostgreSQL

| Informação | Valor |
|------------|-------|
| Tipo | Estudo de Caso |
| Categoria | PostgreSQL / Autenticação |
| Nível | Intermediário |
| Ambiente | PostgreSQL 16 / Debian |
| Data | 2025-07-21 |

---

## Objetivo

Documentar o processo de investigação de um erro de autenticação no PostgreSQL onde conexões remotas eram recusadas com a mensagem:

```text
FATAL: no pg_hba.conf entry for host "...", user "...", database "...".
```

Embora inicialmente o problema indicasse falta de configuração de rede e usuario no `pg_hba.conf`, a investigação demonstrou que a causa raiz era um erro de sintaxe em duas linhas não relacionadas do próprio arquivo.

Este estudo apresenta as hipóteses levantadas, os testes realizados, as evidências coletadas e a solução definitiva.

---

# Ambiente

| Item | Valor |
|------|-------|
| Sistema Operacional | Debian |
| PostgreSQL | 16 |
| Autenticação | MD5 |
| Cliente | psql |
| Tipo de acesso | TCP/IP |

---

# Sintoma

Toda tentativa de conexão remota retornava:

```text
FATAL: no pg_hba.conf entry for host "...",
user "...",
database "...",
SSL encryption

FATAL: no pg_hba.conf entry for host "...",
user "...",
database "...",
no encryption
```

O erro ocorria para diversos usuários de banco, indicando que não estava relacionado apenas a um único usuário.

---

# Primeira hipótese

A hipótese inicial foi de que a rede cliente não estivesse autorizada no `pg_hba.conf`.

Foi adicionada uma regra semelhante a:

```conf
host    all    usuario_aplicacao    198.51.100.0/24    md5
```

Após a alteração foi executado:

```sql
SELECT pg_reload_conf();
```

O retorno foi:

```text
t
```

Mesmo assim as conexões continuavam falhando.

---

# Verificação da regra carregada

Para confirmar que o PostgreSQL interpretava corretamente a regra adicionada foi utilizada a visão:

```sql
SELECT
    line_number,
    type,
    database,
    user_name,
    address,
    netmask,
    auth_method,
    error
FROM pg_hba_file_rules
WHERE user_name @> ARRAY['usuario_aplicacao'];
```

Resultado:

```text
line_number | type | database | address | netmask
------------+------+----------+---------+--------------
100         | host | {all}    | 198.51.100.0 | 255.255.255.0
```

Isso comprovava que a regra estava correta.

Mesmo assim a autenticação continuava falhando.

---

# Segunda hipótese

Como a regra parecia correta, iniciou-se a validação do ambiente.

Foram verificadas:

- endereço IP do cliente;
- rede configurada;
- usuário;
- banco;
- senha;
- método de autenticação;
- recarga das configurações;
- cluster PostgreSQL utilizado;
- processo ativo;
- diretório de dados;
- arquivo de configuração.

---

# Confirmação do ambiente

Foram executados:

```sql
SHOW config_file;
SHOW hba_file;
SHOW listen_addresses;
SHOW port;
```

Também foi validado o processo PostgreSQL:

```bash
systemctl show postgresql@16-main -p MainPID
```

e posteriormente:

```bash
tr '\0' ' ' < /proc/<PID>/cmdline
```

confirmando que o servidor realmente utilizava:

```text
/etc/postgresql/16/main/postgresql.conf
```

e

```text
/etc/postgresql/16/main/pg_hba.conf
```

---

# Confirmação do reload

Também foi verificado o horário de carregamento da configuração:

```sql
SELECT now(), pg_conf_load_time();
```

Após:

```sql
SELECT pg_reload_conf();
```

foi possível confirmar que o PostgreSQL realmente havia recebido o sinal de reload.

---

# Verificação dos logs

O log do PostgreSQL mostrava:

```text
LOG: connection received
FATAL: no pg_hba.conf entry for host "...",
user "...",
database "...",
```

Portanto:

- a conexão chegava ao servidor;
- o servidor recusava a autenticação antes da validação da senha.

---

# Hipóteses descartadas

Durante a investigação foram descartadas as seguintes possibilidades:

- erro de senha;
- usuário inexistente;
- banco inexistente;
- regra de rede incorreta;
- IP do cliente incorreto;
- cluster PostgreSQL incorreto;
- porta incorreta;
- falha de reload.

---

# Investigação do pg_hba.conf

Como todas as verificações anteriores estavam corretas, decidiu-se validar integralmente o arquivo utilizando:

```sql
SELECT
    line_number,
    type,
    database,
    user_name,
    address,
    auth_method,
    error
FROM pg_hba_file_rules
WHERE error IS NOT NULL
ORDER BY line_number;
```

Resultado:

```text
line_number | error
------------+-----------------------------------------
125         | invalid authentication method "md5sum"
126         | invalid authentication method "md5sum"
```

Foi identificado que duas linhas do arquivo possuíam:

```conf
host all zbx_monitor 127.0.0.1/32 md5sum
host all zbx_monitor ::1/128 md5sum
```

---

# Causa raiz

O método de autenticação

```text
md5sum
```

não existe no PostgreSQL.

O método correto é:

```text
md5
```

As linhas corretas são:

```conf
host all zbx_monitor 127.0.0.1/32 md5
host all zbx_monitor ::1/128 md5
```

---

# Solução

Após corrigir as duas linhas inválidas foi executado novamente:

```sql
SELECT pg_reload_conf();
```

A autenticação passou a funcionar imediatamente.

---

# Observações importantes

Um detalhe importante observado durante a investigação é que:

- `pg_reload_conf()` retornar `true` significa apenas que o sinal SIGHUP foi enviado ao servidor;
- isso **não garante** que o arquivo `pg_hba.conf` tenha sido aceito integralmente.

Da mesma forma, consultar apenas regras específicas em:

```sql
pg_hba_file_rules
```

não é suficiente.

É necessário verificar também se existem erros globais no arquivo.

---

# Procedimento recomendado

Sempre que houver alterações no `pg_hba.conf`, execute:

```sql
SELECT
    line_number,
    error
FROM pg_hba_file_rules
WHERE error IS NOT NULL;
```

O resultado esperado deve ser:

```text
(0 linhas)
```

Somente após essa validação execute:

```sql
SELECT pg_reload_conf();
```

---

# Evidências coletadas

Durante a investigação foram utilizadas as seguintes consultas:

Validação da regra carregada:

```sql
SELECT
    line_number,
    type,
    database,
    user_name,
    address,
    netmask,
    auth_method,
    error
FROM pg_hba_file_rules;
```

Validação de erros:

```sql
SELECT
    line_number,
    error
FROM pg_hba_file_rules
WHERE error IS NOT NULL;
```

Confirmação do arquivo carregado:

```sql
SHOW hba_file;
```

Confirmação da configuração:

```sql
SHOW config_file;
```

Confirmação do reload:

```sql
SELECT pg_conf_load_time();
```
