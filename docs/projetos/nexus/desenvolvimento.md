# Desenvolvimento

## Organização do código

A implementação atual é uma única função de shell. Internamente, ela pode ser entendida em blocos:

```text
Nexus()
├── configuração e variáveis
├── preparação dos diretórios
├── validação de dependências
├── parser de opções
├── validação da sessão
├── leitura de stdin
├── inicialização do histórico
├── roteador
├── execução pelo Codex
├── seleção do modelo Ollama
├── verificação da API e do modelo
├── definição do prompt de sistema
├── montagem do JSON
├── chamada HTTP
├── extração da resposta
└── atualização da sessão
```

A organização linear facilita auditoria e instalação, mas aumenta o acoplamento. Evoluções maiores devem considerar a divisão em funções auxiliares.

## Decisões de implementação

### Função carregada pelo shell

A escolha evita criar um executável separado e permite uso imediato em pipelines. Em contrapartida, a função herda ambiente, diretório atual, limites e peculiaridades do shell chamador.

### Configuração embutida

Modelos, URL e limite de histórico ficam no código. Isso simplifica a primeira versão, mas obriga a editar o script para qualquer ajuste.

### JSON como formato de sessão

O JSON permite inspeção direta com `jq`, integração simples com a API e preservação dos papéis `user` e `assistant`.

### Roteamento por regex

As regras são rápidas, auditáveis e não exigem uma inferência adicional. O custo é a baixa compreensão semântica.

### Chamada síncrona

A função aguarda o término da resposta. O comportamento é previsível em scripts, mas não oferece feedback progressivo durante gerações longas.

### Separação do Codex

A rota `codex` retorna diretamente após executar a CLI. Ela não grava pergunta ou resposta no histórico do Ollama, pois o contexto e os efeitos pertencem a outro mecanismo.

## Pontos técnicos relevantes

### Arquivo temporário da requisição

O corpo HTTP é montado em arquivo criado por `mktemp`:

```bash
TMP_BODY="$(mktemp)"
```

O arquivo é removido após a chamada. Há tratamento explícito para falha na montagem do JSON, mas a versão atual não instala `trap`; uma interrupção abrupta pode deixar o temporário no sistema.

### Atualização do histórico

A sessão é atualizada por arquivo temporário seguido de `mv`. Isso protege contra substituição quando o `jq` falha, mas não resolve concorrência entre processos.

### Verificação exata do modelo

O nome retornado por `/api/tags` deve ser idêntico ao configurado. Tags equivalentes ou nomes sem tag não são normalizados.

### Código de retorno

Falhas do `curl` e do Codex são propagadas. Erros internos de validação normalmente retornam `1`.

## Limitações conhecidas

1. O roteamento usa palavras e expressões regulares, não classificação semântica.
2. O modo `assist` só é escolhido explicitamente.
3. A resposta do Ollama não usa streaming.
4. O histórico é limitado por mensagens, não por tokens.
5. Mensagens antigas são descartadas, não resumidas.
6. Não existe `--no-history`.
7. Não existe limite de tamanho para a entrada recebida por `stdin`.
8. Não existe RAG nem busca em documentação local.
9. O `embeddinggemma` não participa do fluxo.
10. O histórico é armazenado sem criptografia.
11. Não há lock para execuções concorrentes na mesma sessão.
12. Não há `trap` para limpeza garantida do arquivo temporário.
13. A integração com Codex não compartilha contexto com o Ollama.
14. A implementação não registra métricas de duração, rota ou volume de dados.
15. A função assume a presença de recursos comuns a Bash/Zsh, mas não possui suíte de compatibilidade automatizada.

## Roadmap proposto

### Etapa 1 — Robustez operacional

Prioridade alta, sem alterar o modelo arquitetural:

- adicionar `trap` para limpeza de temporários;
- validar o JSON da sessão antes da chamada;
- restaurar permissões após cada substituição do arquivo;
- implementar lock por sessão;
- limitar o volume de entrada por bytes;
- melhorar a separação entre mensagens de `stdout` e `stderr`;
- criar testes para parser, roteador e nomes de sessão.

### Etapa 2 — Configuração externa

Mover parâmetros para um arquivo como:

```text
~/.config/nexus/config
```

Itens configuráveis:

```text
OLLAMA_BASE_URL
MODEL_GENERIC
MODEL_ASSIST
MODEL_CODE
MAX_HISTORY_MESSAGES
KEEP_ALIVE
CONNECT_TIMEOUT
REQUEST_TIMEOUT
```

A configuração externa deve usar um formato simples e seguro, sem executar conteúdo arbitrário quando isso puder ser evitado.

### Etapa 3 — Controle de contexto

- adicionar `--no-history`;
- adicionar opção para listar e remover sessões;
- limitar contexto por tokens;
- preservar um histórico completo separado do contexto ativo;
- resumir mensagens antigas antes de descartá-las.

### Etapa 4 — Experiência de uso

- implementar streaming;
- exibir opcionalmente rota e modelo selecionados;
- adicionar modo silencioso e modo verboso;
- aceitar prompt a partir de arquivo;
- permitir saída estruturada quando solicitada;
- oferecer conclusão de opções no shell.

### Etapa 5 — Roteamento aprimorado

Substituir ou complementar regex com um classificador local curto:

```text
entrada
  -> regras explícitas de alta prioridade
  -> classificador local
  -> fallback generic
```

As regras explícitas devem continuar existindo para decisões previsíveis, especialmente a delegação ao Codex.

### Etapa 6 — Memória semântica e RAG

Usar embeddings para indexar:

- sessões anteriores;
- documentação técnica;
- arquivos Markdown;
- playbooks Ansible;
- scripts;
- estudos de caso;
- manuais internos.

Fluxo possível:

```text
pergunta
  -> geração de embedding
  -> busca local por similaridade
  -> seleção de trechos
  -> composição do contexto
  -> chamada ao modelo
```

Essa evolução exige decisões adicionais sobre armazenamento vetorial, atualização de índices, origem dos documentos e proteção de dados.

### Etapa 7 — Auditoria e observabilidade

Registrar separadamente:

```text
data e hora
sessão
rota escolhida
modelo
latência
tamanho da entrada
código de retorno
resultado da persistência
```

O log de auditoria não deve duplicar conteúdo sensível por padrão.

## Estratégia de refatoração

Uma evolução sem ruptura pode extrair funções auxiliares mantendo `Nexus` como interface pública:

```bash
_nexus_parse_args
_nexus_validate_session
_nexus_read_input
_nexus_route
_nexus_check_ollama
_nexus_build_request
_nexus_call_ollama
_nexus_update_history
Nexus
```

A ordem recomendada é:

1. criar testes de comportamento da versão atual;
2. extrair funções sem mudar saídas nem códigos de retorno;
3. introduzir configuração externa;
4. adicionar novas capacidades de forma incremental.

## Testes recomendados

### Parser

- ausência de valor após `--session`;
- ausência de valor após `--mode`;
- opção desconhecida tratada como texto;
- combinação de múltiplos argumentos;
- ordem entre `--new` e `--session`.

### Sessões

- nomes válidos e inválidos;
- criação com permissões corretas;
- reinício de sessão;
- JSON corrompido;
- concorrência entre duas chamadas.

### Roteador

- precedência de `codex` sobre `code`;
- termos acentuados e sem acento;
- falsos positivos conhecidos;
- modo forçado ignorando regex.

### HTTP

- API indisponível;
- modelo ausente;
- erro HTTP com corpo;
- timeout;
- JSON sem `.message.content`;
- resposta válida.

### Persistência

- limite de vinte mensagens;
- manutenção da ordem;
- falha do `jq` sem perda do arquivo anterior;
- permissões após `mv`.

## Critério de evolução

O projeto deve preservar sua principal qualidade: ser compreensível por inspeção. Recursos como classificação semântica, RAG e auditoria devem ser adicionados sem transformar o Nexus em uma camada opaca ou difícil de operar no terminal.
