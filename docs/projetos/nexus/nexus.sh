# =========================================================
# Nexus - Assistente local com Ollama + roteamento para Codex
# Dependências:
#   - curl
#   - jq
#   - ollama
#   - codex   (opcional, para integração com Codex CLI)
#
# Modelos utilizados no Ollama:
#   - qwen3.5:latest       # modo assist
#   - llama3:latest        # modo generic
#   - qwen3-coder:latest   # modo code
#
# Modelo reservado para evolução futura:
#   - embeddinggemma:latest   # embeddings, RAG e memória semântica
# =========================================================

Nexus() {
  local MAX_HISTORY_MESSAGES=20
  local BASE_DIR="${HOME}/.nexus"
  local SESSION_NAME="default"
  local MODE="auto"
  local SESSION_FILE=""
  local NEW_SESSION=0
  local OLLAMA_BASE_URL="http://localhost:11434"
  local OLLAMA_URL="${OLLAMA_BASE_URL}/api/chat"

  local MODEL_ASSIST="qwen3.5:latest"
  local MODEL_GENERIC="llama3:latest"
  local MODEL_CODE="qwen3-coder:latest"

  local INPUT=""
  local USER_TEXT=""
  local ROUTE=""
  local MODEL=""
  local TMP_BODY=""
  local RESPONSE=""
  local ANSWER=""
  
  mkdir -p "$BASE_DIR/sessions" || return 1
  chmod 700 "$BASE_DIR" "$BASE_DIR/sessions" || return 1

  # -----------------------------
  # Verificações básicas
  # -----------------------------
  if ! command -v jq >/dev/null 2>&1; then
    echo "Erro: jq não encontrado."
    return 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "Erro: curl não encontrado."
    return 1
  fi

  if ! command -v ollama >/dev/null 2>&1; then
    echo "Erro: ollama não encontrado."
    return 1
  fi

  # -----------------------------
  # Parse de opções
  # -----------------------------
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --new)
        NEW_SESSION=1
        shift
        ;;
      --session)
        shift
        [[ -z "$1" ]] && { echo "Erro: faltou nome após --session"; return 1; }
        SESSION_NAME="$1"
        shift
        ;;
      --mode)
        shift
        [[ -z "$1" ]] && { echo "Erro: faltou valor após --mode"; return 1; }
        MODE="$1"
        shift
        ;;
      --help|-h)
        cat <<'EOF'
Uso:
  Nexus "pergunta"
  echo "texto" | Nexus "instrução complementar"

Opções:
  --new                inicia sessão nova
  --session NOME       usa sessão separada
  --mode auto          decide entre generic, code e codex
  --mode assist        força assistente especialista
  --mode generic       força assistente generalista
  --mode code          força modelo coder local
  --mode codex         força Codex CLI

Exemplos:
  Nexus "explique DRBD split brain"
  Nexus --mode code "crie um shell script para rotacionar logs"
  Nexus --session linux "como vejo portas UDP abertas?"
  echo "saída do erro" | Nexus --mode code "diagnostique isso"
  Nexus --new --session projetoX "vamos começar do zero"
EOF
        return 0
        ;;
      *)
        if [[ -n "$INPUT" ]]; then
          INPUT="${INPUT} $1"
        else
          INPUT="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$SESSION_NAME" == "." || "$SESSION_NAME" == ".." ||
      ! "$SESSION_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
    echo "Erro: nome de sessão inválido." >&2
    echo "Use apenas letras, números, ponto, hífen e sublinhado." >&2
    return 1
  fi
  SESSION_FILE="$BASE_DIR/sessions/${SESSION_NAME}.json"
  if (( NEW_SESSION )); then
    rm -f "$SESSION_FILE"
  fi

  # -----------------------------
  # Lê stdin, se houver pipe
  # -----------------------------
  if [[ ! -t 0 ]]; then
    local STDIN_DATA
    STDIN_DATA="$(cat)"
    if [[ -n "$STDIN_DATA" ]]; then
      if [[ -n "$INPUT" ]]; then
        INPUT="${STDIN_DATA}"$'\n'"${INPUT}"
      else
        INPUT="${STDIN_DATA}"
      fi
    fi
  fi

  # -----------------------------
  # Validação
  # -----------------------------
  if [[ -z "$INPUT" ]]; then
    echo "Uso: Nexus [--new] [--session nome] [--mode auto|assist|generic|code|codex] 'pergunta'"
    return 1
  fi

  USER_TEXT="$INPUT"

  # -----------------------------
  # Inicializa sessão
  # -----------------------------
  if [[ ! -f "$SESSION_FILE" ]]; then
    cat > "$SESSION_FILE" <<'EOF'
[]
EOF
  fi
  chmod 600 "$SESSION_FILE" || return 1

  # -----------------------------
  # Router
  # -----------------------------
  case "$MODE" in
    assist)
      ROUTE="assist"
      ;;
    generic)
      ROUTE="generic"
      ;;
    code)
      ROUTE="code"
      ;;
    codex)
      ROUTE="codex"
      ;;
    auto)
      if printf '%s\n' "$USER_TEXT" | grep -Eqi \
        '(refator(ar|ação)|codebase|repositório|repositorio|projeto inteiro|editar arquivo|editar vários arquivos|editar varios arquivos|feature|pull request|merge request|review de código|review de codigo|reescrever módulo|reescrever modulo|analisar projeto|mexer no projeto)'; then
        ROUTE="codex"
      elif printf '%s\n' "$USER_TEXT" | grep -Eqi \
        '(bash|shell|zsh|script|python|php|perl|awk|sed|regex|expressão regular|expressao regular|yaml|json|toml|ini|sql|html|css|javascript|typescript|código|codigo|função|funcao|classe|método|metodo|api|endpoint|stack trace|traceback|erro|debug|bug|logrotate|systemd|ansible|dockerfile|nginx|apache|iptables|nft|curl|jq)'; then
        ROUTE="code"
      else 
        ROUTE="generic"
      fi
      ;;
    *)
      echo "Erro: modo inválido em --mode. Use: auto | assist | generic | code | codex"
      return 1
      ;;
  esac

  # -----------------------------
  # Execução via Codex
  # -----------------------------
  if [[ "$ROUTE" == "codex" ]]; then
    if ! command -v codex >/dev/null 2>&1; then
        echo "Erro: Codex CLI não encontrado no PATH."
        echo "Instale e autentique o Codex CLI antes de usar --mode codex."
        return 1
    fi

    codex "$USER_TEXT"
    return $?
  fi

  # -----------------------------
  # Seleciona modelo Ollama
  # -----------------------------
  if [[ "$ROUTE" == "code" ]]; then
    MODEL="$MODEL_CODE"
  elif [[ "$ROUTE" == "assist" ]]; then
    MODEL="$MODEL_ASSIST"
  else
    MODEL="$MODEL_GENERIC"
  fi

  local AVAILABLE_MODELS=""

  if ! AVAILABLE_MODELS="$(
    curl -fsS \
      --connect-timeout 3 \
      --max-time 5 \
      "${OLLAMA_BASE_URL}/api/tags"
  )"; then
    echo "Erro: API do Ollama não está acessível em ${OLLAMA_BASE_URL}." >&2
    echo "Verifique se o serviço está em execução." >&2
    return 1
  fi

  if ! printf '%s\n' "$AVAILABLE_MODELS" |
    jq -e --arg model "$MODEL" \
      '.models[]? | select(.name == $model)' >/dev/null; then
    echo "Erro: modelo '$MODEL' não está instalado no Ollama." >&2
    echo "Instale com:" >&2
    echo "  ollama pull $MODEL" >&2
    return 1
  fi

  # -----------------------------
  # Monta prompt de sistema
  # -----------------------------
  local SYSTEM_PROMPT=""
  case "$ROUTE" in
    code)
      SYSTEM_PROMPT="Você é um assistente técnico especializado em programação, automação, Linux, shell script, Python, diagnóstico e correção de código. Forneça soluções práticas, comandos reproduzíveis e não invente saídas, arquivos ou resultados."
      ;;
    assist)
      SYSTEM_PROMPT="Você é um assistente técnico especializado em Linux, infraestrutura, redes, armazenamento, virtualização, observabilidade e diagnóstico de sistemas. Analise o problema com profundidade, apresente hipóteses verificáveis e priorize procedimentos seguros e reproduzíveis."
      ;;
    generic)
      SYSTEM_PROMPT="Você é um assistente geral, objetivo e econômico no uso de recursos. Responda com clareza e precisão, priorizando explicações diretas e úteis."
      ;;
  esac

  # -----------------------------
  # Monta JSON da conversa
  # -----------------------------
  TMP_BODY="$(mktemp)"

  jq \
    --arg model "$MODEL" \
    --arg system_prompt "$SYSTEM_PROMPT" \
    --arg user_text "$USER_TEXT" \
    --argjson max_history "$MAX_HISTORY_MESSAGES" \
    '
    {
      model: $model,
      stream: false,
      keep_alive: "15m",
      messages:
        (
          [{"role":"system","content":$system_prompt}]
          + (if length > $max_history then .[-$max_history:] else . end)
          + [{"role":"user","content":$user_text}]
        )
    }
    ' "$SESSION_FILE" > "$TMP_BODY" || {
      echo "Erro montando JSON da requisição."
      rm -f "$TMP_BODY"
      return 1
    }

  # -----------------------------
  # Chama Ollama API
  # -----------------------------
  RESPONSE="$(
    curl \
      --silent \
      --show-error \
      --fail-with-body \
      --connect-timeout 3 \
      --max-time 300 \
      "$OLLAMA_URL" \
      -H 'Content-Type: application/json' \
      -d @"$TMP_BODY"
  )"
  local CURL_STATUS=$?

  rm -f "$TMP_BODY"

  if (( CURL_STATUS != 0 )); then
    echo "Erro: falha ao consultar a API do Ollama." >&2
    echo "Código de retorno do curl: $CURL_STATUS" >&2

    if [[ -n "$RESPONSE" ]]; then
      echo "Resposta recebida:" >&2
      printf '%s\n' "$RESPONSE" >&2
    fi

    return "$CURL_STATUS"
  fi

  ANSWER="$(printf '%s\n' "$RESPONSE" | jq -r '.message.content // empty')"

  if [[ -z "$ANSWER" ]]; then
    echo "Erro: resposta inválida do Ollama."
    echo "$RESPONSE"
    return 1
  fi

  # -----------------------------
  # Exibe resposta
  # -----------------------------
  echo "$ANSWER"

  # -----------------------------
  # Atualiza histórico
  # -----------------------------
  jq \
  --arg user "$USER_TEXT" \
  --arg assistant "$ANSWER" \
  --argjson max_history "$MAX_HISTORY_MESSAGES" \
  '
  (
    . + [
      {"role":"user","content":$user},
      {"role":"assistant","content":$assistant}
    ]
  )
  | if length > $max_history then .[-$max_history:] else . end
  ' "$SESSION_FILE" > "${SESSION_FILE}.tmp" &&
  mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
}
