# Uso

## Sintaxe

```text
Nexus [--new] [--session NOME] [--mode MODO] "pergunta"
```

A entrada também pode ser recebida por `stdin`:

```text
comando | Nexus [opções] "instrução complementar"
```

## Opções

| Opção | Descrição |
|---|---|
| `--new` | Remove o histórico da sessão selecionada antes da execução |
| `--session NOME` | Seleciona uma sessão independente |
| `--mode auto` | Escolhe entre `generic`, `code` e `codex` |
| `--mode assist` | Força o assistente técnico especializado |
| `--mode generic` | Força o modelo generalista |
| `--mode code` | Força o modelo local especializado em código |
| `--mode codex` | Encaminha a tarefa ao Codex CLI |
| `--help`, `-h` | Exibe a ajuda incorporada |

## Modos de operação

### `auto`

É o modo padrão. O texto é examinado por expressões regulares:

- tarefas amplas de projeto seguem para `codex`;
- programação e diagnóstico técnico seguem para `code`;
- demais solicitações seguem para `generic`.

O modo automático não seleciona `assist` na versão atual.

### `generic`

Indicado para perguntas gerais e tarefas que não exigem um modelo especializado em código.

```bash
Nexus --mode generic "qual é a diferença entre RAID 5 e RAID 10?"
```

### `assist`

Indicado para análise técnica mais profunda em Linux, infraestrutura, redes, storage, virtualização e observabilidade.

```bash
Nexus --mode assist "analise os riscos de um DRBD em split brain"
```

### `code`

Indicado para scripts, configurações, automação, revisão de código e diagnóstico de erros.

```bash
Nexus --mode code "crie um script para validar certificados TLS"
```

### `codex`

Indicado para tarefas que exigem inspeção de repositório, edição de múltiplos arquivos ou implementação de funcionalidades.

```bash
Nexus --mode codex "revise este repositório e corrija os testes quebrados"
```

A execução ocorre no diretório atual do shell. Portanto, antes de delegar uma tarefa, confirme o diretório:

```bash
pwd
git status
```

## Entrada por pipe

### Diagnóstico de serviço

```bash
systemctl status nginx |
  Nexus --mode code "diagnostique o serviço"
```

### Logs de uma unidade systemd

```bash
journalctl -u zabbix-agent2 -n 200 --no-pager |
  Nexus --session zabbix "identifique a causa mais provável"
```

### Revisão de configuração

```bash
cat /etc/nginx/nginx.conf |
  Nexus --mode code "revise esta configuração e aponte riscos"
```

### Saída extensa

A versão atual não limita bytes nem tokens antes de montar a requisição. Para evitar entradas excessivas, reduza a evidência no próprio pipeline:

```bash
journalctl -u nginx -n 300 --no-pager |
  Nexus --mode code "analise as falhas recentes"
```

```bash
grep -E 'ERROR|WARN|FATAL' aplicacao.log | tail -n 500 |
  Nexus --mode code "agrupe os erros por causa provável"
```

## Sessões

### Sessão padrão

Sem `--session`, o arquivo usado é:

```text
~/.nexus/sessions/default.json
```

### Sessão nomeada

```bash
Nexus --session iscsi "o target possui três LUNs"
Nexus --session iscsi "considere agora dois initiators com multipath"
```

Arquivo correspondente:

```text
~/.nexus/sessions/iscsi.json
```

### Reinício

```bash
Nexus --new --session iscsi "inicie uma nova análise"
```

A sessão anterior é removida antes da nova chamada.

### Nomes válidos

```text
default
linux
storage-01
cliente_teste
rede.lab
```

Nomes inválidos incluem espaços, barras, `.` isolado e `..`.

## Exemplos práticos

### Consulta geral

```bash
Nexus "explique a diferença entre processo e thread"
```

### Geração de shell script

```bash
Nexus --mode code \
  "crie um shell script que verifique um serviço systemd e retorne códigos compatíveis com monitoramento"
```

### Análise de disco

```bash
lsblk -f | Nexus --mode assist \
  "interprete a organização dos discos e aponte inconsistências"
```

### Sessão de investigação

```bash
Nexus --session mysql "o servidor apresenta aumento de I/O"

iostat -xz 1 5 |
  Nexus --session mysql --mode assist \
  "relacione estas métricas com a hipótese anterior"
```

### Delegação explícita ao Codex

```bash
cd ~/projetos/minha-aplicacao
Nexus --mode codex \
  "analise a estrutura, identifique duplicações e proponha uma refatoração por etapas"
```

## Comportamento de saída

A resposta do Ollama é impressa em `stdout`. Mensagens de falha da chamada HTTP e detalhes operacionais são enviadas predominantemente a `stderr`.

Isso permite redirecionar a resposta:

```bash
Nexus --mode assist "gere um checklist de validação" > checklist.txt
```

Entretanto, o conteúdo salvo continua sendo texto livre produzido pelo modelo e deve ser revisado antes de execução ou publicação.

## Boas práticas

- force o modo quando a classificação automática puder ser ambígua;
- use sessões diferentes para assuntos independentes;
- reduza logs antes de enviá-los;
- anonimize dados de clientes e credenciais;
- confirme o diretório atual antes de usar o Codex;
- valide comandos destrutivos antes de executá-los;
- não trate a resposta do modelo como evidência de que uma ação foi executada.
