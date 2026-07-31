# Nexus

| Informação | Valor |
|---|---|
| Tipo | Projeto / ferramenta de terminal |
| Categoria | Linux / Shell / Inteligência Artificial |
| Implementação | Função compatível com Zsh e Bash |
| Versão documentada | 0.1 |
| Estado | Funcional, em evolução |

## Visão geral

O **Nexus** é uma camada leve de orquestração para uso de modelos de linguagem diretamente no shell Linux. Ele recebe perguntas, comandos, logs e saídas de programas, identifica a natureza da solicitação e escolhe uma rota de execução compatível.

A versão atual integra dois mecanismos distintos:

- **Ollama local**, usado para consultas gerais, análise técnica e geração pontual de código;
- **Codex CLI**, usado opcionalmente para tarefas amplas sobre projetos e repositórios.

O diferencial do projeto não está apenas em permitir perguntas pelo terminal. Seu núcleo é o fluxo interno que combina parsing de opções, leitura de `stdin`, roteamento heurístico, escolha de modelo, construção de contexto, chamada HTTP e persistência de sessões.

## Problema resolvido

O uso convencional de uma interface web exige copiar comandos, logs e mensagens de erro para outro ambiente. Isso interrompe o fluxo operacional e separa a análise do local em que o problema está sendo investigado.

Com o Nexus, a interação permanece no terminal:

```bash
Nexus "explique como funciona o DRBD split brain"
```

Saídas de comandos também podem ser enviadas diretamente:

```bash
journalctl -u nginx --since today | Nexus --mode code "analise os erros"
```

O projeto também mantém contextos separados por sessão:

```bash
Nexus --session storage "estamos analisando uma estrutura iSCSI"
Nexus --session storage "agora avalie o comportamento do multipath"
```

## Capacidades atuais

- entrada por argumentos, pipe ou redirecionamento;
- sessões independentes armazenadas em JSON;
- roteamento automático por expressões regulares;
- três perfis locais de modelo: `generic`, `assist` e `code`;
- delegação opcional de projetos ao Codex CLI;
- validação de dependências e modelos instalados;
- tratamento de indisponibilidade e erros HTTP;
- proteção básica dos arquivos locais por permissões Unix;
- limite de histórico para controlar o crescimento do contexto.

## O que o Nexus não é

O Nexus ainda não é:

- um agente autônomo;
- uma plataforma RAG;
- uma memória semântica de longo prazo;
- um substituto para ferramentas administrativas;
- uma camada de segurança para dados sensíveis;
- uma sessão compartilhada entre Ollama e Codex.

Ele deve ser entendido como uma interface funcional e extensível entre o shell e diferentes mecanismos de assistência por IA.

## Componentes principais

| Componente | Responsabilidade |
|---|---|
| Função `Nexus` | Orquestração geral no shell |
| Parser de opções | Interpretação de modo, sessão e reinício |
| Roteador | Classificação heurística da solicitação |
| Ollama | Inferência local e API HTTP |
| Codex CLI | Trabalho amplo em código e repositórios |
| `jq` | Construção, leitura e atualização de JSON |
| `curl` | Comunicação HTTP com o Ollama |
| Sessões JSON | Persistência do contexto recente |

## Estrutura desta documentação

- [Arquitetura](arquitetura.md): fluxo interno, roteamento, modelos e contexto;
- [Instalação](instalacao.md): dependências, modelos e carregamento no shell;
- [Uso](uso.md): sintaxe, modos, sessões e exemplos;
- [Desenvolvimento](desenvolvimento.md): organização do código, decisões, limitações e roadmap.

## Princípio de projeto

A versão 0.1 prioriza simplicidade, transparência e controle explícito. Cada decisão importante pode ser observada diretamente no código: as rotas são regras declaradas, os modelos são variáveis, as sessões são arquivos JSON e a integração HTTP pode ser reproduzida com ferramentas comuns do Linux.
