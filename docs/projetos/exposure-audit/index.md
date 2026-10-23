# Auditoria de exposição de serviços Linux: correlacionando firewall, sockets e validação externa

> Projeto disponível em: [https://github.com/jemorenojr/Exposure_Audit](https://github.com/jemorenojr/Exposure_Audit)

Auditar a exposição de um serviço de rede parece simples até tentarmos responder, com evidência suficiente, a uma pergunta objetiva:

> Este serviço está ativo, de onde ele pode ser acessado e existe evidência externa de que esse acesso realmente ocorre?

Verificar apenas se uma porta está em `LISTEN` não responde isso. Executar um `nmap` externo também não. Consultar o firewall isoladamente tampouco é suficiente.

O projeto **Exposure Audit** foi criado para correlacionar essas diferentes fontes de informação e produzir uma classificação explicável por serviço. A ferramenta trabalha em modo somente leitura e tenta responder à exposição observada sem transformar ausência de informação em uma conclusão favorável.

```text
PORTA EM LISTEN   != PORTA EXPOSTA
PORTA FILTRADA    != SERVIÇO SEGURO
```

Este artigo apresenta a arquitetura, o modelo de decisão, o fluxo de auditoria e as limitações dessa abordagem.

## Objetivo

O objetivo é analisar serviços de rede em hosts Linux combinando quatro perspectivas:

1. estado local do serviço;
2. endereço em que o processo está escutando;
3. política efetiva do firewall e possíveis traduções de endereço;
4. observação realizada por um scanner realmente externo ao ambiente.

Ao final, cada serviço recebe uma das seguintes classificações:

| Classificação | Significado |
|---|---|
| `PROTEGIDO` | Existem evidências suficientes de que o serviço não está disponível diretamente para a Internet. |
| `PARCIAL` | O serviço pode ser alcançado apenas por origens específicas ou existe alguma restrição relevante que ainda exige avaliação. |
| `EXPOSTO` | A exposição externa foi observada ou a combinação de evidências demonstra acesso amplo. |
| `INDETERMINADO` | As evidências disponíveis não permitem concluir com segurança. |

!!! note "Escopo"
    O Exposure Audit não é um scanner de vulnerabilidades, SIEM, EDR ou ferramenta de pentest. Ele não executa exploits, brute force ou autenticação contra os serviços encontrados.

## Por que uma única fonte não basta

### Porta em `LISTEN`

Um processo pode estar escutando em `0.0.0.0:443`, mas isso não significa necessariamente que a porta esteja acessível pela Internet. O firewall local pode bloquear o tráfego, o host pode estar atrás de NAT ou outro controle pode existir a montante.

O inverso também ocorre: uma porta pode não existir diretamente no host e ainda assim aparecer externamente devido a DNAT, publicação de container ou redirecionamento realizado em outro equipamento.

### Firewall local

Uma regra de `DROP` é uma evidência importante, mas a interpretação precisa considerar o caminho real do pacote. Docker, DNAT e chains de usuário podem deslocar a decisão de `INPUT` para `FORWARD`, por exemplo.

Buscar uma porta com algo como:

```bash
iptables -L -n | grep 443
```

é insuficiente para determinar a exposição efetiva. É necessário considerar sequência de regras, chains, policies, jumps, origem, destino, interface, estado da conexão e tradução de endereço.

### Scanner externo

Um scanner externo fornece a evidência que falta à visão interna: o que de fato pode ser alcançado a partir de outro ponto da Internet.

Mas até mesmo um resultado `filtered` precisa ser interpretado com cuidado. O filtro pode estar no host, em um firewall upstream, em um security group, em uma VPN ou em outro ponto da rede.

Por isso, o modelo adotado evita a equivalência:

```text
filtered == protegido
```

Essa conclusão só é aceita quando existem outras evidências que a sustentam.

## Arquitetura

A arquitetura separa coleta, normalização, validação externa e decisão.

```text
                  +------------------- pipeline -------------------+
                  |                                                |
inventario ------>| collector ---> normalizacao ---> HostState     |
                  |      |                                         |
                  |      +--> sockets                              |
                  |      +--> rede                                 |
                  |      +--> firewall                             |
                  |      +--> NAT / Docker                         |
                  |                                                |
                  | scanner externo ---> ExternalEvidence          |
                  |                                                |
                  | HostState + ExternalEvidence                   |
                  |              |                                 |
                  |              v                                 |
                  |        correlator/classifier                   |
                  +--------------+---------------------------------+
                                 |
                                 v
                        TXT / JSON / CSV / resumo
```

A principal decisão de projeto foi manter o correlator desacoplado dos mecanismos de coleta. Ele recebe modelos normalizados e aplica regras determinísticas. Isso permite substituir coletores ou scanners sem reescrever a lógica de classificação.

## Fluxo da auditoria

Para cada host, o processo pode ser resumido nas seguintes etapas:

1. conectar ao host auditado;
2. identificar interfaces, endereços e rotas;
3. identificar sockets TCP e UDP;
4. determinar binds e famílias IPv4/IPv6;
5. coletar regras de firewall disponíveis;
6. identificar NAT e publicações Docker;
7. normalizar essas informações em uma representação comum;
8. determinar quais portas precisam ser validadas externamente;
9. executar os testes a partir do scanner externo;
10. correlacionar as evidências;
11. classificar cada família IP;
12. agregar o resultado por serviço;
13. gerar relatórios e evidências para auditoria posterior.

## Pré-requisitos

### Controlador

- Python 3.10 ou superior;
- cliente OpenSSH;
- acesso SSH aos hosts auditados;
- acesso SSH ao scanner externo, quando utilizado.

### Hosts auditados

Os hosts precisam fornecer, conforme aplicável:

- `iproute2` (`ip` e `ss`);
- `iptables` e/ou `nftables`;
- `ipset`, quando usado pelas regras;
- Docker, quando existirem containers publicados;
- `sudo`, caso a coleta de firewall e processos exija privilégio.

### Scanner externo

O scanner precisa ter:

- `nmap`;
- acesso de rede ao endereço público do alvo;
- preferencialmente privilégio para uso de SYN scan e UDP;
- caminho independente da rede corporativa auditada.

!!! warning "Posicionamento do scanner"
    O scanner deve estar fora da rede auditada e, idealmente, fora de VPN ou IPsec com o ambiente analisado. Caso contrário, o teste pode validar um caminho interno e produzir uma interpretação incorreta da exposição pública.

## Instalação

No diretório do projeto:

```bash
. ./ambiente.sh
```

O script cria ou ativa o ambiente virtual e instala o pacote.

A instalação manual equivalente é:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -e .
```

Após a instalação, o comando `exposure-audit` fica disponível no ambiente.

## Inventário

O projeto aceita inventário em texto ou CSV, além de hosts informados diretamente pela linha de comando.

Um inventário simples pode conter um host por linha:

```text
srv-web-01.example.net
srv-db-01.example.net
srv-pbx-01.example.net
```

O inventário é utilizado como ponto de entrada. Durante a coleta, informações adicionais do sistema são obtidas diretamente do host.

## Execução

Um exemplo básico:

```bash
exposure-audit \
    --hosts hosts.txt \
    --external-scanner scanner.example.net \
    --output output/
```

Algumas opções relevantes:

| Opção | Função |
|---|---|
| `--hosts ARQ` | Define o inventário. |
| `--host H` | Adiciona um host individualmente. |
| `--external-scanner H` | Define o scanner externo. |
| `--output DIR` | Define o diretório de saída. |
| `--workers N` | Número de hosts processados em paralelo. |
| `--timeout S` | Timeout da coleta. |
| `--scan-max-rate N` | Limite de pacotes por segundo do Nmap. |
| `--scan-timeout S` | Timeout do scan. |
| `--no-ipv6` | Desativa apenas a validação externa IPv6. |
| `--no-fullscan` | Desativa o scan independente de todas as portas TCP. |
| `--no-udp-scan` | Desativa testes UDP. |
| `--identify-services` | Executa identificação leve de serviços com `-sV --version-light`. |
| `--ask-sudo-password` | Solicita uma senha de sudo para hosts que não aceitam `sudo -n`. |

Sem scanner externo, a ferramenta continua avaliando as evidências locais, mas serviços que dependam de confirmação externa tendem a permanecer como `INDETERMINADO`.

## Coleta local

### Sockets

Os listeners são obtidos com `ss` e classificados conforme o endereço de bind.

| Bind | Interpretação |
|---|---|
| `127.0.0.0/8`, `::1` | `LOCAL_ONLY` |
| RFC 1918, CGNAT, ULA e link-local | `PRIVATE_BIND` |
| endereço público específico | `PUBLIC_BIND` |
| `0.0.0.0` | `ALL_IPV4` |
| `::` | `ALL_IPV6` |

Quando existem múltiplos sockets para o mesmo serviço e família, prevalece o bind mais amplo.

Um serviço escutando apenas em loopback é uma evidência forte de proteção local. Um serviço em `0.0.0.0`, por outro lado, apenas indica que o kernel aceita conexões destinadas aos endereços IPv4 locais; ainda é necessário analisar o firewall e o caminho externo.

## Análise do firewall

O projeto suporta cenários com iptables, iptables-nft, iptables-legacy e nftables coexistindo no mesmo host.

Entre as fontes coletadas estão:

```bash
iptables -V
iptables-save
ip6tables-save
iptables-legacy-save
ip6tables-legacy-save
nft -j list ruleset
nft list ruleset
ipset save
```

O objetivo não é apenas localizar regras que mencionem determinada porta. O avaliador tenta simular o percurso de um pacote `NEW` destinado ao serviço.

São considerados, entre outros elementos:

- protocolo;
- porta de destino;
- endereço de origem;
- endereço de destino;
- interfaces;
- `ct state`;
- `ct status dnat`;
- jumps e gotos;
- retorno de chains;
- policy da base chain;
- conjuntos de endereços;
- regras NAT;
- publicação de containers.

### Resultado normalizado do firewall

O resultado da análise é reduzido a uma das classes:

| Estado | Significado |
|---|---|
| `ANY` | origem externa arbitrária pode ser aceita; |
| `RESTRICTED_SOURCE` | apenas origens específicas, incluindo redes públicas; |
| `PRIVATE_ONLY` | apenas redes privadas; |
| `LOCAL_ONLY` | apenas loopback; |
| `BLOCKED` | nenhuma origem externa é aceita pelo caminho analisado; |
| `UNKNOWN` | dados insuficientes ou regra não interpretável. |

Essa normalização permite que o correlator não dependa diretamente da sintaxe de iptables ou nftables.

## NAT, Docker e `FORWARD`

Publicações de containers são um caso importante porque o tráfego pode não passar pela chain `INPUT`.

Quando existe DNAT para outro endereço, o serviço é avaliado no caminho de encaminhamento, considerando `FORWARD`, `DOCKER-USER`, `DOCKER` e outras chains relevantes.

O projeto diferencia três situações:

- `local`: existe listener no próprio host;
- `forwarded`: o tráfego é encaminhado por DNAT;
- `external-only`: a porta foi observada externamente, mas não existe listener ou NAT local que explique a exposição.

O último caso é especialmente útil para detectar elementos fora do escopo do host, como DNAT em firewall de borda ou outro equipamento respondendo pelo IP auditado.

## Validação externa

O scanner externo usa Nmap como fonte de evidência, não como mecanismo de decisão.

A arquitetura recomendada é:

```text
Controlador -------- SSH --------> Host auditado
    |
    +------------- SSH ----------> Scanner externo
                                      |
                                      +---- Internet ----> IP publico do alvo
```

O scanner executa, conforme configuração:

- scan direcionado das portas conhecidas;
- scan TCP independente de todas as portas;
- teste UDP;
- identificação leve de serviços.

Exemplo conceitual da base utilizada pelo scanner:

```text
-n -Pn -oX - --max-retries 2 --max-rate N
```

Para TCP é usado SYN scan quando há privilégio. Sem privilégio, o scanner pode cair para connect scan. UDP é omitido quando não existem permissões suficientes.

Nenhum script NSE é executado nessa etapa.

## Normalização dos estados externos

Os estados do Nmap são convertidos para uma representação menor:

| Nmap | Estado interno |
|---|---|
| `open` | `OPEN` |
| `closed` | `CLOSED` |
| `filtered` | `FILTERED` |
| `open|filtered` | `UNKNOWN` |
| `closed|filtered` | `UNKNOWN` |
| `unfiltered` | `UNKNOWN` |
| host `down` | `UNREACHABLE` |

UDP merece atenção especial: `open|filtered` é comum e não fornece evidência suficiente para afirmar que o serviço está aberto ou protegido.

## Modelo de classificação

Cada família IP é avaliada separadamente.

O correlator considera três informações principais:

```text
bind + firewall + evidencia externa
```

Alguns exemplos ilustram o comportamento.

### Serviço restrito a loopback

```text
bind:     LOCAL_ONLY
externo:  diferente de OPEN
```

Resultado:

```text
PROTEGIDO
```

### Serviço liberado para qualquer origem e observado externamente

```text
bind:      ALL_IPV4
firewall:  ANY
externo:   OPEN
```

Resultado:

```text
EXPOSTO
```

### Serviço limitado a origens públicas específicas

```text
firewall:  RESTRICTED_SOURCE
externo:   OPEN
```

Resultado:

```text
PARCIAL
```

A exposição existe, mas a restrição de origem precisa ser considerada na análise.

### Firewall aparentemente bloqueia, mas scanner observa `OPEN`

```text
firewall:  BLOCKED
externo:   OPEN
```

Resultado:

```text
INDETERMINADO
```

Essa é uma inconsistência real e não deve ser escondida. Possíveis explicações incluem:

- NAT não modelado;
- scanner localizado em rede autorizada;
- outro equipamento respondendo pelo endereço;
- caminho não observado pelo coletor.

### Firewall amplo e resultado externo `FILTERED`

```text
firewall:  ANY
externo:   FILTERED
```

Resultado:

```text
INDETERMINADO
```

O filtro pode existir fora do host. Portanto, o scan negativo não comprova que a proteção está sob controle do servidor auditado.

## IPv4 e IPv6

IPv4 e IPv6 são avaliados de forma independente.

Isso evita um erro comum: considerar um serviço protegido porque o IPv4 está corretamente filtrado enquanto o IPv6 permanece aberto.

Depois da avaliação por família, o estado agregado usa a seguinte ordem de gravidade:

```text
EXPOSTO > INDETERMINADO > PARCIAL > PROTEGIDO
```

Assim, por exemplo:

```text
IPv4: PROTEGIDO
IPv6: EXPOSTO
```

resulta em:

```text
EXPOSTO
```

para o serviço como um todo.

## Exemplo de relatório

O projeto gera um relatório por host. O exemplo abaixo utiliza dados de teste anonimizados:

```text
HOST: srv-web-01
SO: Debian GNU/Linux 12 (bookworm)
IP INTERNO: 203.0.113.5
IP PUBLICO: 203.0.113.5, 2001:db8:10::5

5432/tcp POSTGRESQL (postgres)
LOCAL:          ATIVO
BIND:           10.0.0.5
FIREWALL:       SOMENTE REDES PRIVADAS
EXTERNO:        FILTERED
CLASSIFICACAO:  PROTEGIDO
MOTIVO:         firewall permite somente redes privadas; teste externo FILTERED
```

O relatório detalhado também registra as evidências que levaram à decisão, incluindo a família IP, a regra de classificação aplicada e trechos relevantes da análise do firewall.

Esse detalhe é importante porque uma classificação sem justificativa teria pouco valor operacional.

## Saídas

Cada execução é gravada em um diretório próprio:

```text
output/
└── 20261019140509/
    ├── raw/
    │   └── <host>.json
    ├── reports/
    │   └── <host>.txt
    ├── exposicao.csv
    ├── resumo.txt
    └── audit.log
```

### JSON

Contém evidências brutas, informações normalizadas e a decisão final. É a melhor saída para investigação detalhada ou integração com outras ferramentas.

### TXT por host

Apresenta a análise de forma legível para operação e revisão manual.

### CSV consolidado

Possui uma linha por serviço e facilita filtros, planilhas, ingestão em banco ou geração de indicadores.

### Resumo

Apresenta contadores e serviços agrupados por host e família IP.

### Log operacional

`audit.log` registra erros de coleta, falhas SSH, timeouts, comandos ausentes, problemas de privilégio e falhas do scanner. O log operacional fica separado da conclusão técnica.

## Sudo e segurança operacional

Parte da coleta pode exigir privilégio, principalmente para obter regras completas de firewall, informações de processos ou Docker.

Quando `sudo -n` funciona, ele é utilizado sem senha.

Caso o ambiente não permita sudo sem senha, pode-se usar:

```bash
exposure-audit \
    --hosts hosts.txt \
    --ask-sudo-password \
    --output output/
```

A senha é solicitada sem eco e usada somente em memória durante a execução. Ela não deve aparecer em argumentos, variáveis de ambiente, JSON ou relatórios.

!!! warning
    Uma única senha é aplicada aos hosts que não aceitam `sudo -n`. Em ambientes onde cada servidor possui credenciais diferentes, esses hosts precisam ser tratados separadamente ou seguir sem coleta privilegiada.

Sem privilégio suficiente, o projeto prefere degradar a qualidade da evidência e classificar o firewall como `UNKNOWN` em vez de assumir que não existem regras.

## O significado de `INDETERMINADO`

`INDETERMINADO` não representa falha da ferramenta. Em vários cenários ele é a conclusão tecnicamente correta.

Considere:

```text
host local:   aceita qualquer origem
scan externo: filtered
```

Existem pelo menos duas interpretações possíveis:

1. existe um filtro upstream protegendo o serviço;
2. o teste ocorreu por um caminho que não representa a Internet pública real.

Sem observar o elemento responsável pelo filtro, declarar `PROTEGIDO` seria uma suposição.

A ferramenta adota deliberadamente a regra:

> ausência de evidência não se transforma em evidência de proteção.

## Situações que exigem análise posterior

Mesmo classificações corretas podem exigir revisão humana.

Exemplos:

- serviço aberto apenas para um conjunto público de IPs;
- serviço em rede privada, mas acessível por VPN;
- NAT externo não visível no host;
- firewall upstream;
- coexistência complexa de iptables e nftables;
- múltiplas base chains no mesmo hook;
- publicação de containers;
- divergência entre IPv4 e IPv6;
- `OPEN` observado externamente em conflito com firewall local bloqueando;
- UDP com estado inconclusivo.

A intenção da ferramenta não é esconder essas ambiguidades, mas apresentá-las como parte da decisão.

## Limitações conhecidas

Nenhuma análise feita exclusivamente a partir do host consegue observar toda a infraestrutura de rede.

Entre as limitações atuais estão:

- firewall upstream, security groups, balanceadores e proxies não são diretamente observáveis;
- hooks de filtragem em `prerouting` e `netdev ingress` não são avaliados;
- tabelas `raw` e `mangle` não participam da decisão de filtragem;
- policy routing e XFRM são coletados como contexto, mas não totalmente modelados;
- DNAT envolvendo faixas muito grandes ou sem porta específica é apenas registrado;
- interseções complexas de conjuntos de origem não são resolvidas por aritmética completa de conjuntos;
- algumas extensões `xtables` não traduzidas pelo nftables geram estado desconhecido;
- UDP frequentemente permanece inconclusivo;
- a origem do scanner não é automaticamente comparada com todos os conjuntos de origem permitidos pelo firewall;
- controles existentes fora do host podem alterar completamente o resultado observado.

Uma característica importante dessas limitações é que, sempre que possível, elas tendem a **superestimar a exposição ou produzir `INDETERMINADO`**, em vez de criar uma falsa sensação de proteção.

## Testes

O projeto possui testes unitários e de pipeline com fixtures baseadas nos formatos reais das ferramentas utilizadas:

- `ss`;
- `ip`;
- `iptables-save`;
- `nft -j`;
- `ipset`;
- `docker inspect`;
- XML do Nmap.

Os testes são executados com:

```bash
python -m unittest discover -s tests -t tests
```

Na versão analisada para este artigo, a suíte executou **65 testes com sucesso**.

Os endereços utilizados nas fixtures pertencem às faixas reservadas para documentação, evitando dependência de dados reais da infraestrutura.

## O que esta abordagem acrescenta

Existem boas ferramentas para cada etapa isoladamente:

- `ss` informa sockets;
- iptables e nftables mostram regras locais;
- Nmap mostra o comportamento observado a partir de uma origem;
- Docker informa publicações de containers.

O problema operacional aparece quando precisamos transformar todas essas observações em uma resposta única e auditável.

O Exposure Audit tenta resolver exatamente essa camada de correlação.

Em vez de perguntar apenas:

```text
Quais portas estão abertas?
```

passamos a perguntar:

```text
Qual serviço está ativo?
Onde ele está escutando?
Qual caminho de firewall se aplica?
Existe NAT?
Quem pode iniciar a conexão?
O acesso foi realmente observado externamente?
IPv4 e IPv6 apresentam o mesmo comportamento?
As evidências são suficientes para uma conclusão?
```

Essa mudança de perspectiva transforma uma listagem de portas em uma auditoria de superfície de exposição.

## Conclusão

Avaliar exposição de serviços exige mais do que verificar listeners ou executar um scanner externo.

Uma porta pode estar aberta localmente e protegida por outro controle. Pode estar filtrada externamente sem que o host tenha qualquer proteção configurada. Pode existir uma publicação Docker que desvia o tráfego de `INPUT` para `FORWARD`. Pode estar segura em IPv4 e exposta em IPv6.

Por isso, a análise precisa correlacionar evidências e, principalmente, reconhecer quando elas não são suficientes.

O ponto central do projeto pode ser resumido em duas regras:

```text
EVIDENCIA POSITIVA DE EXPOSICAO NAO DEVE SER IGNORADA.
FALTA DE EVIDENCIA NAO DEVE VIRAR CONCLUSAO FAVORAVEL.
```

Esse modelo não elimina a análise humana. O objetivo é entregar ao administrador uma base objetiva, reproduzível e justificável para decidir onde realmente existe exposição e quais casos precisam de investigação adicional.

## Próximos aprofundamentos

Este artigo apresenta a visão geral do projeto. Alguns pontos merecem tratamento separado em materiais específicos:

- avaliação efetiva de regras iptables e nftables;
- correlação de Docker, DNAT e chains de `FORWARD`;
- diferenças práticas entre IPv4 e IPv6 na auditoria de exposição;
- interpretação de `filtered`, `closed` e `open|filtered` no contexto da auditoria;
- construção de um modelo determinístico de classificação baseado em evidências.
