# Arquitetura

## Visão estrutural

O Nexus funciona como um orquestrador síncrono executado dentro do shell atual. Ele não mantém daemon próprio, não abre porta de rede e não implementa um servidor intermediário.

```text
                   argumento, pipe ou redirecionamento
                                  |
                                  v
                       +--------------------+
                       | Parser de opções   |
                       | modo e sessão      |
                       +---------+----------+
                                 |
                                 v
                       +--------------------+
                       | Montagem da entrada|
                       | argumentos + stdin |
                       +---------+----------+
                                 |
                                 v
                       +--------------------+
                       | Roteador heurístico|
                       | expressões regulares|
                       +----+----------+----+
                            |          |
                 +----------+          +----------------+
                 |                                      |
                 v                                      v
       +--------------------+                 +--------------------+
       | Ollama local       |                 | Codex CLI          |
       | GET /api/tags      |                 | projeto/repositório|
       | POST /api/chat     |                 +--------------------+
       +---------+----------+
                 |
                 v
       +--------------------+
       | Resposta no shell  |
       +---------+----------+
                 |
                 v
       +--------------------+
       | Histórico JSON     |
       | ~/.nexus/sessions  |
       +--------------------+
```

## Fluxo interno

### 1. Inicialização

A função define os valores padrão usados durante a execução:

```bash
local MAX_HISTORY_MESSAGES=20
local BASE_DIR="${HOME}/.nexus"
local SESSION_NAME="default"
local MODE="auto"
local OLLAMA_BASE_URL="http://localhost:11434"
```

Os modelos são associados a papéis, e não diretamente a comandos do usuário:

```bash
local MODEL_ASSIST="qwen3.5:latest"
local MODEL_GENERIC="llama3:latest"
local MODEL_CODE="qwen3-coder:latest"
```

### 2. Preparação do armazenamento

O diretório de sessões é criado antes do processamento:

```text
~/.nexus/
└── sessions/
    ├── default.json
    ├── storage.json
    └── projeto-x.json
```

Permissões aplicadas:

```text
~/.nexus                   700
~/.nexus/sessions          700
arquivo de sessão          600
```

Essas permissões reduzem a exposição a outros usuários locais, mas não criptografam o conteúdo.

### 3. Validação de dependências

Para as rotas locais, a função exige:

```bash
jq
curl
ollama
```

A presença do binário `ollama` não comprova que a API está funcional. Por isso, o serviço é validado posteriormente por uma requisição a `/api/tags`.

O binário `codex` só é verificado quando a rota selecionada é `codex`.

### 4. Parsing de opções

O parser reconhece:

```text
--new
--session NOME
--mode MODO
--help
-h
```

Os demais argumentos são concatenados e formam a instrução textual. O parse completo ocorre antes da remoção do histórico, portanto a ordem entre `--new` e `--session` não altera qual sessão será reiniciada.

### 5. Validação da sessão

O nome deve começar por letra ou número e pode conter:

```text
A-Z a-z 0-9 . _ -
```

São bloqueados `.` e `..`, barras e espaços. A regra evita navegação de diretórios e criação de arquivos fora de `~/.nexus/sessions`.

### 6. Composição da entrada

Quando `stdin` não está ligado a um terminal, o Nexus lê seu conteúdo:

```bash
[[ ! -t 0 ]]
```

Se também houver texto nos argumentos, a entrada recebida por pipe é colocada primeiro e a instrução complementar depois:

```text
<saída do comando>
<instrução do usuário>
```

Isso permite enviar evidência e orientação na mesma requisição.

## Roteador

### Natureza do roteamento

O modo automático não usa um classificador semântico. A decisão é feita por duas expressões regulares avaliadas em ordem.

A precedência é importante:

1. tarefas amplas de projeto são testadas primeiro e seguem para `codex`;
2. termos técnicos ou de programação seguem para `code`;
3. qualquer outra entrada segue para `generic`.

O modo `assist` não é selecionado automaticamente na versão atual.

### Rota Codex

Expressões associadas a mudanças amplas incluem, entre outras:

```text
refatoração
codebase
repositório
projeto inteiro
editar vários arquivos
pull request
merge request
review de código
reescrever módulo
analisar projeto
```

A rota apenas delega a solicitação:

```bash
codex "$USER_TEXT"
```

O código de retorno do Codex é devolvido ao shell chamador.

### Rota de código

O segundo conjunto procura linguagens, formatos, ferramentas e indícios de diagnóstico:

```text
bash, shell, zsh, script, python, php
awk, sed, regex, yaml, json, sql
api, endpoint, traceback, debug, bug
systemd, ansible, nginx, iptables, curl, jq
```

Essa lista é explícita e simples de ajustar, mas pode produzir falsos positivos e falsos negativos.

### Rotas forçadas

O usuário pode ignorar o roteador:

```bash
Nexus --mode generic "..."
Nexus --mode assist "..."
Nexus --mode code "..."
Nexus --mode codex "..."
```

## Seleção dos modelos

| Rota | Implementação | Papel |
|---|---|---|
| `generic` | `llama3:latest` | Respostas gerais e menor consumo |
| `assist` | `qwen3.5:latest` | Análise técnica aprofundada |
| `code` | `qwen3-coder:latest` | Código, automação e diagnóstico |
| `codex` | Codex CLI | Trabalho amplo em projetos |

Os nomes são configuráveis no início da função. Eles não são detectados automaticamente por capacidade.

## Integração HTTP com o Ollama

### Descoberta de modelos

Antes da geração, o Nexus consulta:

```http
GET http://localhost:11434/api/tags
```

O `jq` procura correspondência exata no campo `name`. Caso o modelo esteja ausente, o script informa o comando `ollama pull` correspondente.

### Construção da conversa

O corpo enviado a `/api/chat` segue esta estrutura:

```json
{
  "model": "llama3:latest",
  "stream": false,
  "keep_alive": "15m",
  "messages": [
    {
      "role": "system",
      "content": "instrução específica da rota"
    },
    {
      "role": "user",
      "content": "pergunta"
    }
  ]
}
```

O prompt de sistema é inserido a cada chamada e não é salvo no arquivo de sessão.

### Parâmetros operacionais

```text
connect timeout: 3 segundos
request timeout: 300 segundos
stream: false
keep_alive: 15 minutos
```

Com `stream: false`, a resposta só aparece após a geração completa.

## Gerenciamento de contexto

### Formato da sessão

Cada sessão é um array JSON com mensagens alternadas:

```json
[
  {
    "role": "user",
    "content": "pergunta"
  },
  {
    "role": "assistant",
    "content": "resposta"
  }
]
```

### Limite

O valor padrão é:

```bash
local MAX_HISTORY_MESSAGES=20
```

Como uma interação normal acrescenta duas mensagens, o limite representa aproximadamente dez pares de pergunta e resposta.

O recorte preserva as mensagens mais recentes:

```jq
if length > $max_history then .[-$max_history:] else . end
```

As mensagens removidas deixam de existir no arquivo. Não há arquivo completo, sumarização ou memória de longo prazo.

### Atualização transacional parcial

O histórico é escrito inicialmente em um arquivo temporário e depois movido:

```bash
jq ... "$SESSION_FILE" > "${SESSION_FILE}.tmp" &&
mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
```

Esse padrão evita substituir a sessão quando o `jq` falha. Entretanto, a versão atual não implementa lock; duas execuções simultâneas na mesma sessão podem disputar o arquivo.

## Separação entre Ollama e Codex

As duas rotas possuem contextos independentes.

```text
Nexus + Ollama
  - histórico em ~/.nexus/sessions
  - prompts de sistema definidos no script
  - respostas recebidas por /api/chat

Nexus + Codex CLI
  - contexto administrado pelo próprio Codex
  - possível inspeção e alteração de arquivos
  - sem gravação no histórico JSON do Ollama
```

Essa separação evita registrar no histórico local uma solicitação cuja resposta e efeitos não foram produzidos pelo Ollama.

## Segurança

As chamadas ao Ollama são destinadas a `localhost`, mas entradas e respostas ficam em texto puro. Devem ser removidos ou anonimizados:

- senhas, tokens e cookies;
- chaves privadas;
- credenciais de banco;
- dados pessoais;
- informações contratuais;
- dados de clientes;
- configurações internas sensíveis.

A porta `11434` não deve ser exposta publicamente sem autenticação, filtragem e avaliação de risco.
