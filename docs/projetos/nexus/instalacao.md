# Instalação

## Pré-requisitos

O Nexus depende de um ambiente Linux com Bash ou Zsh e dos seguintes componentes:

| Componente | Obrigatório | Função |
|---|---:|---|
| `curl` | Sim | Chamadas HTTP ao Ollama |
| `jq` | Sim | Construção e manipulação de JSON |
| Ollama | Sim | Execução dos modelos locais |
| Codex CLI | Não | Delegação de projetos e repositórios |

## Instalação das dependências auxiliares

### Debian e Ubuntu

```bash
sudo apt update
sudo apt install curl jq
```

### Fedora, Rocky Linux e AlmaLinux

```bash
sudo dnf install curl jq
```

### Arch Linux

```bash
sudo pacman -S curl jq
```

## Ollama

Instale o Ollama pelo procedimento oficial adequado à distribuição. Depois, confirme o serviço:

```bash
systemctl status ollama
```

Valide a API local:

```bash
curl -fsS http://localhost:11434/api/tags | jq
```

Também é possível verificar a porta:

```bash
ss -lntp | grep 11434
```

## Modelos

A versão documentada usa:

```bash
ollama pull llama3:latest
ollama pull qwen3.5:latest
ollama pull qwen3-coder:latest
```

Confira a instalação:

```bash
ollama list
```

Mapeamento padrão:

| Modo | Modelo |
|---|---|
| `generic` | `llama3:latest` |
| `assist` | `qwen3.5:latest` |
| `code` | `qwen3-coder:latest` |

O modelo `embeddinggemma:latest` é apenas uma reserva para futuras funções de embeddings, RAG ou memória semântica. O código atual não o utiliza.

## Instalação do Nexus

O arquivo distribuído contém apenas a função e seus comentários. Ele deve ser mantido separado do arquivo principal de configuração do shell.

### Zsh

```bash
mkdir -p ~/.config/nexus
cp nexus.sh ~/.config/nexus/nexus.zsh
chmod 600 ~/.config/nexus/nexus.zsh
```

Acrescente ao `~/.zshrc`:

```bash
source ~/.config/nexus/nexus.zsh
```

Recarregue:

```bash
source ~/.zshrc
```

### Bash

```bash
mkdir -p ~/.config/nexus
cp nexus.sh ~/.config/nexus/nexus.sh
chmod 600 ~/.config/nexus/nexus.sh
```

Acrescente ao `~/.bashrc`:

```bash
source ~/.config/nexus/nexus.sh
```

Recarregue:

```bash
source ~/.bashrc
```

## Validação

Confirme que a função foi carregada:

```bash
type Nexus
```

Exiba a ajuda:

```bash
Nexus --help
```

Teste uma chamada simples:

```bash
Nexus --mode generic "responda apenas: Nexus operacional"
```

## Codex CLI

A integração com Codex é opcional. Sem ela, os modos locais continuam operacionais.

Valide uma instalação existente:

```bash
command -v codex
codex --version
```

A autenticação e o provedor usados pelo Codex são administrados pela própria ferramenta. Não se deve assumir que essa rota processa tudo localmente.

## Arquivos criados em tempo de execução

Na primeira chamada, o Nexus cria:

```text
~/.nexus/
└── sessions/
    └── default.json
```

As permissões esperadas são:

```bash
stat -c '%a %n' ~/.nexus ~/.nexus/sessions ~/.nexus/sessions/default.json
```

Resultado esperado:

```text
700 ~/.nexus
700 ~/.nexus/sessions
600 ~/.nexus/sessions/default.json
```

## Ajustes de configuração

Na versão 0.1, a configuração permanece no início da função:

```bash
local MAX_HISTORY_MESSAGES=20
local OLLAMA_BASE_URL="http://localhost:11434"
local MODEL_ASSIST="qwen3.5:latest"
local MODEL_GENERIC="llama3:latest"
local MODEL_CODE="qwen3-coder:latest"
```

Após qualquer alteração, recarregue o arquivo do shell.

## Diagnóstico de instalação

### `jq` não encontrado

```bash
command -v jq
jq --version
```

### `curl` não encontrado

```bash
command -v curl
curl --version
```

### Ollama não encontrado

```bash
command -v ollama
ollama --version
```

### API indisponível

```bash
systemctl status ollama
ss -lntp | grep 11434
curl -v http://localhost:11434/api/tags
```

### Modelo ausente

```bash
ollama list
ollama pull NOME_DO_MODELO
```

### Sessão inválida

```bash
jq . ~/.nexus/sessions/default.json
```

Para descartá-la e iniciar novamente:

```bash
Nexus --new --session default "inicie uma nova conversa"
```
