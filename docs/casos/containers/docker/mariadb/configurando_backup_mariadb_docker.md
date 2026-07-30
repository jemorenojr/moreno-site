# Configurando backup de MariaDB em Docker com volume persistente e cron no host

| Informação | Valor |
|------------|-------|
| Tipo | Procedimento |
| Categoria | Containers / Docker / Banco de Dados |
| Subcategoria | Backup e persistência |
| Nível | Intermediário |
| Ambiente | Docker Compose / MariaDB |
| Objetivo | Permitir que o container do MariaDB execute rotinas de backup sem modificar os dados persistentes do banco. |

---

## Objetivo

O container oficial do MariaDB foi projetado para executar o serviço do banco de dados com o mínimo de componentes adicionais.

Durante a implantação do SysPass surgiu a necessidade de executar, dentro do container do MariaDB, uma rotina própria de backup do banco de dados.

Para atender a essa necessidade foram realizadas customizações na imagem e na configuração do Docker Compose, mantendo separados:

- os dados persistentes do MariaDB;
- os scripts operacionais;
- os arquivos de backup;
- as dependências adicionais utilizadas pelo script;
- o mecanismo de agendamento.

A solução permite reconstruir a imagem e recriar o container sem remover os dados armazenados no volume persistente do banco.

---

## Arquitetura adotada

Foi adotada a seguinte organização:

```text
Host
│
├── /var/Backup/syspass
│        │
│        └──────────────► /var/Backup        (container)
│
├── syspass-db/
│      ├── init/
│      │      └─────────► /docker-entrypoint-initdb.d
│      │
│      └── Scripts/
│             └─────────► /Scripts            (container)
│
└── Volume Docker
         │
         └──────────────► /var/lib/mysql
```

Cada ponto de montagem possui uma finalidade específica:

| Origem no host | Destino no container | Finalidade |
|----------------|----------------------|------------|
| Volume `syspass-db-data` | `/var/lib/mysql` | Persistência dos dados do MariaDB |
| `/var/Backup/syspass` | `/var/Backup` | Armazenamento persistente dos backups |
| `./syspass-db/Scripts` | `/Scripts` | Scripts e recursos operacionais |
| `./syspass-db/init` | `/docker-entrypoint-initdb.d` | Scripts executados na inicialização de um banco novo |

---

## Persistência dos dados do banco

Os arquivos do MariaDB permanecem armazenados no volume Docker:

```yaml
volumes:
  - syspass-db-data:/var/lib/mysql
```

Esse volume não faz parte da camada gravável do container nem da imagem utilizada para criá-lo.

Consequentemente, as seguintes operações não removem os dados do banco, desde que o mesmo volume continue montado em `/var/lib/mysql`:

```bash
docker compose build syspass-db
docker compose up -d --no-deps --force-recreate syspass-db
docker compose stop syspass-db
docker compose restart syspass-db
```

!!! warning "Preservação do banco de dados"

    Não utilize o comando abaixo durante esse procedimento:

    ```bash
    docker compose down -v
    ```

    A opção `-v` solicita a remoção dos volumes declarados pelo projeto e pode eliminar os dados persistentes do MariaDB.

Também devem ser evitados comandos como:

```bash
docker volume rm NOME_DO_VOLUME
docker system prune --volumes
```

---

## Montagem do diretório de backup

Foi criado o seguinte bind mount:

```yaml
- /var/Backup/syspass:/var/Backup
```

Com essa configuração, qualquer arquivo gravado pelo container em:

```text
/var/Backup
```

é armazenado no host em:

```text
/var/Backup/syspass
```

### Motivos

Caso os backups fossem gravados apenas na camada gravável do container, eles poderiam ser perdidos quando o container fosse removido e recriado.

A gravação diretamente no host oferece:

- persistência independente do ciclo de vida do container;
- facilidade para copiar os arquivos para outro servidor;
- integração com rotinas externas de backup;
- facilidade de auditoria;
- acesso aos arquivos sem necessidade de entrar no container;
- controle de retenção e capacidade pelo sistema operacional do host.

---

## Montagem do diretório `/Scripts`

Foi criado o seguinte bind mount:

```yaml
- ./syspass-db/Scripts:/Scripts:ro
```

O diretório contém scripts e outros recursos operacionais utilizados pela rotina de backup.

Exemplo:

```text
/Scripts
└── scripts
    └── backup_BD.sh
```

O parâmetro `:ro` monta o diretório como somente leitura dentro do container.

Isso permite que o script seja executado, mas impede que processos internos do container modifiquem os arquivos originais no host.

### Motivos

Manter os scripts fora da imagem oferece as seguintes vantagens:

- alteração dos scripts sem reconstrução da imagem;
- versionamento junto ao projeto;
- separação entre código operacional e imagem do banco;
- reutilização da mesma estrutura em outros containers;
- atualização imediata do script montado;
- redução do risco de alterações não rastreadas dentro do container.

As alterações devem ser realizadas no host:

```bash
vi /srv/syspass-seg/syspass-db/Scripts/backup_BD.sh
```

O arquivo será apresentado dentro do container como:

```text
/Scripts/backup_BD.sh
```

---

## Utilização de uma imagem customizada

Originalmente, o serviço utilizava diretamente a imagem oficial:

```yaml
image: mariadb:10.2
```

Como o script de backup necessita de programas que não estão presentes na imagem padrão, foi criada uma imagem derivada.

A configuração passou a utilizar:

```yaml
build:
  context: .
  dockerfile: syspass-db/Dockerfile
```

Essa abordagem preserva o comportamento original da imagem MariaDB e acrescenta somente as dependências necessárias.

---

## Pacotes adicionados

Foram adicionados os seguintes pacotes:

### `uuid-runtime`

O pacote disponibiliza o comando:

```bash
uuidgen
```

O script utiliza esse comando para criar um identificador único para cada execução do backup.

Esse identificador pode ser utilizado para:

- correlação entre logs;
- identificação da execução enviada para uma API;
- rastreamento de falhas;
- associação entre etapas e artefatos gerados.

### `jq`

O `jq` é utilizado pelo script para construir e validar a estrutura JSON contendo informações como:

- identificador da execução;
- horário de início e término;
- status final;
- etapas executadas;
- mensagens de erro;
- arquivos produzidos;
- tamanho dos artefatos;
- checksums;
- código de saída.

O uso do `jq` reduz o risco de gerar JSON inválido por problemas de escape ou formatação.

---

## Dockerfile

Foi criado o arquivo:

```text
syspass-db/Dockerfile
```

Conteúdo:

```dockerfile
FROM mariadb:10.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        uuid-runtime \
        jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

O uso de uma imagem derivada permite acrescentar novas dependências futuramente.

Por exemplo:

```dockerfile
FROM mariadb:10.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        uuid-runtime \
        jq \
        rsync \
        curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

Após qualquer alteração no Dockerfile, a imagem deve ser reconstruída.

---

## Configuração do `docker-compose.yml`

O serviço `syspass-db` foi configurado da seguinte forma:

```yaml
services:
  syspass-db:
    container_name: syspass-db

    build:
      context: .
      dockerfile: syspass-db/Dockerfile

    restart: unless-stopped

    environment:
      MYSQL_ROOT_PASSWORD_FILE: /run/secrets/mysql_root_password
      MYSQL_DATABASE: syspass-seg
      MYSQL_USER_FILE: /run/secrets/mysql_syspass_user
      MYSQL_PASSWORD_FILE: /run/secrets/mysql_syspass_password

    secrets:
      - mysql_root_password
      - mysql_syspass_user
      - mysql_syspass_password

    volumes:
      - syspass-db-data:/var/lib/mysql
      - /var/Backup/syspass:/var/Backup
      - ./syspass-db/Scripts:/Scripts:ro
      - ./syspass-db/init:/docker-entrypoint-initdb.d:ro

    networks:
      - syspass-net-back
```

Os volumes e secrets permanecem declarados no nível principal do arquivo:

```yaml
volumes:
  syspass-db-data:

secrets:
  mysql_root_password:
    file: ./syspass-db/secrets/mysql_root_password.txt

  mysql_syspass_user:
    file: ./syspass-db/secrets/mysql_syspass_user.txt

  mysql_syspass_password:
    file: ./syspass-db/secrets/mysql_syspass_password.txt
```

---

## Preparação dos diretórios

No host, foram preparados os diretórios utilizados pelos bind mounts:

```bash
cd /srv/syspass-seg

mkdir -p /var/Backup/syspass
mkdir -p syspass-db/Scripts
```

As permissões foram ajustadas:

```bash
chmod 0755 /var/Backup/syspass
chmod 0755 syspass-db/Scripts
chmod 0755 syspass-db/Scripts
chmod 0755 syspass-db/Scripts/backup_BD.sh
```

O script deve possuir um interpretador válido na primeira linha:

```bash
head -n 1 syspass-db/Scripts/backup_BD.sh
```

Exemplo:

```bash
#!/bin/bash
```

---

## Validação da configuração

A sintaxe do Compose pode ser validada com:

```bash
cd /srv/syspass-seg

timeout 15s docker compose config --quiet
```

O uso de `timeout` evita que uma eventual falha do comando permaneça indefinidamente em execução.

Interpretação do código de retorno:

| Código | Significado |
|--------|-------------|
| `0` | Configuração válida |
| `124` | O comando excedeu o tempo definido |
| Outro | Erro retornado pelo Docker Compose |

Para visualizar a configuração processada:

```bash
timeout 15s docker compose config
```

---

## Construção da imagem

A imagem customizada é construída com:

```bash
docker compose build syspass-db
```

Para forçar a reconstrução completa:

```bash
docker compose build --no-cache syspass-db
```

A construção da imagem não altera o container em execução e não modifica o volume do banco.

---

## Recriação do container

Após construir a imagem, somente o container do MariaDB é recriado:

```bash
docker compose up -d --no-deps --force-recreate syspass-db
```

Esse comando:

1. interrompe o container antigo;
2. remove o container antigo;
3. cria um novo container usando a imagem customizada;
4. monta novamente o volume `syspass-db-data` em `/var/lib/mysql`;
5. monta `/var/Backup/syspass` em `/var/Backup`;
6. monta `./syspass-db/Scripts` em `/Scripts`;
7. mantém os dados persistentes existentes.

---

## Validação após a recriação

### Verificar os pontos de montagem

```bash
docker inspect syspass-db \
  --format '{{range .Mounts}}{{printf "%s -> %s\n" .Source .Destination}}{{end}}'
```

Devem ser apresentados os destinos:

```text
/var/lib/mysql
/var/Backup
/Scripts
/docker-entrypoint-initdb.d
```

### Verificar o `uuidgen`

```bash
docker exec syspass-db command -v uuidgen
docker exec syspass-db uuidgen
```

### Verificar o `jq`

```bash
docker exec syspass-db command -v jq
docker exec syspass-db jq --version
```

### Verificar o script

```bash
docker exec syspass-db test -x /Scripts/backup_BD.sh
```

### Validar a sintaxe do script

```bash
docker exec syspass-db bash -n /Scripts/backup_BD.sh
```

### Verificar o diretório de backup

```bash
docker exec syspass-db test -d /var/Backup
```

### Testar escrita no bind mount

```bash
docker exec syspass-db sh -ec '
    touch /var/Backup/.teste-montagem
    ls -l /var/Backup/.teste-montagem
    rm -f /var/Backup/.teste-montagem
'
```

---

## Agendamento do backup

Optou-se por não executar um daemon `cron` dentro do container.

O backup é disparado pelo cron do host, utilizando `docker exec` para executar o script dentro do container.

Foi criado o arquivo:

```text
/etc/cron.d/backup_BD_syspass
```

Conteúdo:

```cron
0 2 * * * root /usr/bin/docker inspect -f '{{.State.Running}}' syspass-db 2>/dev/null | /bin/grep -qx true && /usr/bin/docker exec syspass-db /Scripts/backup_BD.sh >> /var/log/syspass-db-backup.log 2>&1
```

A entrada deve permanecer em uma única linha no arquivo de cron.

Foram aplicadas as permissões:

```bash
chown root:root /etc/cron.d/backup_BD_syspass
chmod 0644 /etc/cron.d/backup_BD_syspass
```

A configuração pode ser consultada com:

```bash
cat /etc/cron.d/backup_BD_syspass
```

!!! note "Diferença entre `/etc/cron.d` e `crontab -l`"

    O comando `crontab -l` não apresenta os arquivos armazenados em `/etc/cron.d`.

    Para consultar esse agendamento, utilize:

    ```bash
    ls -l /etc/cron.d/
    cat /etc/cron.d/backup_BD_syspass
    ```

---

## Funcionamento do comando agendado

O comando utilizado no cron possui duas etapas.

Primeiro, verifica se o container está em execução:

```bash
/usr/bin/docker inspect -f '{{.State.Running}}' syspass-db 2>/dev/null |
/bin/grep -qx true
```

O script somente será executado se o resultado for exatamente:

```text
true
```

Em seguida, executa o backup dentro do container:

```bash
/usr/bin/docker exec syspass-db /Scripts/backup_BD.sh
```

A saída padrão e a saída de erro são gravadas em:

```text
/var/log/syspass-db-backup.log
```

---

## Motivos para utilizar o cron do host

### Processo principal único

O container permanece dedicado ao processo principal do MariaDB.

Não é necessário executar simultaneamente:

- `mysqld`;
- `cron`.

### Menor complexidade

Não é necessário:

- instalar cron na imagem;
- configurar um supervisor de processos;
- adaptar o entrypoint;
- gerenciar sinais de dois processos;
- manter arquivos de cron dentro do container.

### Centralização operacional

Os agendamentos permanecem visíveis e administráveis no host.

### Facilidade de diagnóstico

O mesmo comando utilizado pelo cron pode ser executado manualmente.

### Independência do ciclo de vida do container

O agendamento permanece existente mesmo que o container seja recriado.

---

## Teste manual do backup

Antes de depender do cron, o script deve ser executado manualmente:

```bash
docker exec syspass-db /Scripts/backup_BD.sh
```

O código de retorno pode ser verificado com:

```bash
echo $?
```

O log do cron pode ser consultado com:

```bash
tail -n 100 /var/log/syspass-db-backup.log
```

Os arquivos produzidos podem ser localizados no host:

```bash
find /var/Backup/syspass \
    -maxdepth 3 \
    -type f \
    -printf '%TY-%Tm-%Td %TH:%TM:%TS %10s %p\n' |
    sort
```

---

## Correção para bancos com hífen no nome

O banco utilizado pela aplicação possui o nome:

```text
syspass-seg
```

O script de backup criava dinamicamente uma variável com o prefixo `tb_excluir_`:

```bash
tbvar="tb_excluir_${bd}"
lista_exclusao="${!tbvar:-}"
```

Para o banco `syspass-seg`, isso produzia:

```text
tb_excluir_syspass-seg
```

O hífen não é válido em nomes de variáveis Bash, causando:

```text
bad substitution
```

A correção adotada foi normalizar o nome utilizado para construir a variável:

```bash
bd_var="${bd//[^a-zA-Z0-9_]/_}"

tbvar="tb_excluir_${bd_var}"
lista_exclusao="${!tbvar:-}"

tb_excl=""
for tb in ${lista_exclusao}; do
    tb_excl+=" --ignore-table=${bd}.${tb}"
done
```

Com isso:

```text
Nome real do banco:      syspass-seg
Nome usado na variável:  syspass_seg
```

Caso seja necessário excluir tabelas desse banco, a variável deve ser declarada como:

```bash
tb_excluir_syspass_seg="tabela1 tabela2"
```

O `mysqldump` continuará recebendo o nome real do banco:

```text
--ignore-table=syspass-seg.tabela1
```

---

## Benefícios da solução

A arquitetura adotada oferece:

- separação entre imagem, dados, scripts e backups;
- persistência dos dados do MariaDB em volume dedicado;
- persistência dos backups no filesystem do host;
- facilidade para versionamento dos scripts;
- atualização dos scripts sem reconstrução da imagem;
- possibilidade de adicionar novas ferramentas à imagem;
- reconstrução segura do container sem remoção dos dados;
- agendamento independente do ciclo de vida do container;
- simplificação do processo principal do MariaDB;
- facilidade de auditoria e diagnóstico;
- reutilização do padrão em outros serviços.

---

## Considerações finais

A solução mantém o container do MariaDB próximo da imagem oficial, acrescentando somente as dependências necessárias para executar a rotina operacional de backup.

Os dados do banco permanecem armazenados no volume Docker, enquanto os scripts e os arquivos de backup permanecem no host por meio de bind mounts.

Essa separação permite:

- reconstruir a imagem;
- recriar o container;
- atualizar scripts;
- adicionar dependências;
- manter o agendamento no host;

sem alterar ou substituir os dados persistentes do MariaDB.
