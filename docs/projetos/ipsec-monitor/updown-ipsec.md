# Script updown-ipsec.sh

> Esta página documenta o comportamento do script. Antes de reutilizar o arquivo em outro ambiente, revise valores fixos, rotas, DNS, validação TLS e política de logs.

## Objetivo

O `updown-ipsec.sh` é um script de integração com StrongSwan executado pelo mecanismo `leftupdown` durante a subida e a queda de um túnel IPsec.

Sua responsabilidade é preparar o ambiente de rede local depois que o StrongSwan recebe os parâmetros do túnel, criando uma interface lógica `ipsec0`, carregando rotas em uma tabela de roteamento separada e ajustando a resolução DNS durante a conexão.

Esse comportamento não corresponde ao fluxo padrão de uma distribuição Linux. Ele é uma adaptação operacional específica para concentrar o tráfego IPsec em uma interface local controlada e em uma tabela de roteamento própria.

## Contexto

Em uma configuração StrongSwan tradicional, o túnel pode ser estabelecido sem a criação de uma interface Linux dedicada. O tráfego é tratado pela pilha XFRM/IPsec do kernel e pelas políticas instaladas pelo StrongSwan.

Este script adota outro modelo operacional: cria uma interface `dummy` chamada `ipsec0`, atribui a ela o IP recebido pelo cliente IPsec e direciona rotas específicas para uma tabela separada chamada `ipsec`.

Essa abordagem facilita inspeção, separação de rotas, aplicação de regras por origem/destino e limpeza operacional ao desconectar o túnel.

## Ambientes validados

O uso do `updown-ipsec.sh` foi validado nos seguintes sistemas:

* Debian 11;
* Debian 12;
* Debian 13;
* Ubuntu 22.04;
* Ubuntu 24.04.

Em todos os testes, o StrongSwan utilizado foi o pacote fornecido pela própria distribuição. Não foi usada versão compilada manualmente nem pacote externo ao repositório padrão do sistema operacional.

Essa validação cobre o comportamento do script com o StrongSwan dessas distribuições, incluindo o acionamento por `leftupdown`, a criação da interface `ipsec0`, o uso da tabela de roteamento separada e o carregamento de rotas externas.

## Responsabilidade

O script é responsável por:

* receber variáveis de ambiente fornecidas pelo StrongSwan, como `PLUTO_VERB`, `PLUTO_INTERFACE`, `PLUTO_ME`, `PLUTO_PEER`, `PLUTO_MY_SOURCEIP`, `PLUTO_PEER_CLIENT` e `PLUTO_MY_ID`;
* criar e remover a interface lógica `ipsec0`;
* atribuir o IP recebido pelo túnel à interface `ipsec0`;
* criar ou localizar a tabela de roteamento separada `ipsec`;
* usar o ID numérico `220` como tabela de roteamento quando o alias `ipsec` não estiver disponível;
* adicionar regras `ip rule` para tráfego de origem e destino associado ao IP do túnel;
* carregar rotas obtidas de um servidor HTTPS externo;
* remover rotas default que tenham sido criadas para a interface ou para a tabela do IPsec;
* ajustar DNS via `systemd-resolved` ou `/etc/resolv.conf`;
* registrar execução e variáveis em `/var/log/ipsec-updown.log`.

## Fora do escopo

O script não:

* estabelece o túnel IPsec por conta própria;
* autentica usuários;
* valida credenciais;
* define parâmetros criptográficos;
* cria uma configuração StrongSwan completa;
* substitui a análise de segurança das rotas carregadas;
* valida a integridade do conteúdo baixado do servidor de rotas.

## Acionamento pelo StrongSwan

O uso esperado é por meio da diretiva `leftupdown` no bloco `conn` do `/etc/ipsec.conf`.

Exemplo:

```text
conn Minha_VPN
  leftupdown=/etc/ipsec.d/updown-ipsec.sh
```

O script reage ao valor da variável `PLUTO_VERB`:

```text
up-client
down-client
```

Quando recebe `up-client`, executa a função `start`. Quando recebe `down-client`, executa a função `stop`.

## Interface ipsec0

Durante a subida do túnel, o script verifica se a interface `ipsec0` existe. Se não existir, cria uma interface do tipo `dummy`:

```bash
ip link add ipsec0 type dummy
```

Depois, ativa a interface com MTU 1400:

```bash
ip link set ipsec0 up mtu 1400
```

O IP recebido do StrongSwan em `PLUTO_MY_SOURCEIP` é configurado como endereço `/32` nessa interface.

Esse comportamento é relevante porque a distribuição padrão não cria essa interface para túneis IPsec tradicionais. A interface é uma abstração local criada pelo pacote para concentrar o endereço e as rotas da VPN em um ponto operacional visível.

## Tabela de roteamento separada

O script usa uma tabela de roteamento dedicada para o tráfego associado ao IPsec.

Os valores usados são:

```text
Nome da tabela: ipsec
ID da tabela: 220
Arquivo de registro: /etc/iproute2/rt_tables
```

Quando `/etc/iproute2/rt_tables` existe e já possui uma tabela chamada `ipsec`, o script usa esse nome.

Quando o arquivo ou o alias não estão disponíveis, o script usa o ID numérico `220` como fallback. Em ambientes onde `/etc/iproute2` ainda não existe, o script tenta criar o diretório e um `rt_tables` mínimo.

Essa decisão evita misturar as rotas do túnel na tabela `main` e permite limpar a tabela do IPsec durante a desconexão.

## Regras de roteamento

Durante a conexão, o script cria regras com `ip rule` para direcionar tráfego relacionado ao IP do túnel para a tabela separada:

```bash
ip rule add from ${PLUTO_MY_SOURCEIP} lookup ipsec
ip rule add to ${PLUTO_MY_SOURCEIP} lookup ipsec
```

Também adiciona uma regra para manter o tráfego destinado ao peer remoto na tabela principal:

```bash
ip rule add to ${PLUTO_PEER} lookup main
```

Na desconexão, essas regras são removidas e a tabela separada é esvaziada.

## Fonte externa de rotas

Além da rota inicial, o script consulta um servidor HTTPS definido na variável `SRVROTAS`.

No código analisado, esse servidor é um valor operacional fixo. Na versão pública, o endereço real foi omitido e representado pelo exemplo abaixo:

```text
198.51.100.36
```

Antes de carregar rotas, o script testa conectividade TCP na porta `443`:

```bash
nc -z -w3 "${SRVROTAS}" "443"
```

Se o servidor não responder, a configuração é interrompida com erro.

As rotas adicionais são baixadas por HTTPS:

```text
https://${SRVROTAS}/Ipsec_Routes
```

Cada item retornado é tratado como uma rota e adicionado à tabela separada:

```bash
ip route add ${ROUTE_IPSEC} dev ipsec0 table ipsec
```

## Formato esperado das rotas

O endpoint de rotas deve retornar uma lista simples, consumível por expansão de shell no laço `for`.

Exemplo esperado:

```text
198.51.100.0/24
203.0.113.0/24
192.0.2.10/32
```

Cada linha ou item deve ser aceito pelo comando `ip route add`.

O script não valida o conteúdo antes de executar o comando `ip route add`; portanto, a fonte de rotas deve ser considerada parte confiável da operação.

## DNS

Antes de alterar DNS, o script salva a configuração atual em:

```text
/etc/ipsec.d/resolv.conf_save
```

Quando `systemd-resolved` está ativo, ele usa `resolvectl` para registrar DNS e domínio na interface `ipsec0`.

Quando `systemd-resolved` não está ativo, o script substitui temporariamente `/etc/resolv.conf` pelo conteúdo obtido em:

```text
https://${SRVROTAS}/Ipsec_DNS
```

Na desconexão, tenta restaurar a configuração salva.

## Remoção de rota default

O script remove rotas default associadas à interface `ipsec0` ou à tabela separada `ipsec`.

Essa decisão impede que o túnel assuma todo o tráfego do host por padrão. O comportamento esperado é carregar apenas as redes explicitamente retornadas pela fonte externa de rotas, além da rota inicial configurada pelo script.

## Fluxo de subida

O fluxo executado em `up-client` é:

1. Salvar DNS atual.
2. Criar a interface `ipsec0`, se necessário.
3. Ativar `ipsec0` com MTU 1400.
4. Atribuir o IP do túnel à interface.
5. Preparar a tabela de roteamento `ipsec` ou `220`.
6. Limpar a tabela de roteamento separada.
7. Adicionar a rota inicial.
8. Criar regras `ip rule`.
9. Remover o IP da interface padrão recebida em `PLUTO_INTERFACE`.
10. Ajustar parâmetros `rp_filter` e `accept_local`.
11. Validar se a interface `ipsec0` está disponível.
12. Validar conectividade com o servidor de rotas.
13. Baixar e carregar rotas adicionais.
14. Remover rotas default indesejadas.
15. Aplicar DNS recebido do servidor de rotas.
16. Registrar o resultado em `/var/log/ipsec-updown.log`.

## Fluxo de queda

O fluxo executado em `down-client` é:

1. Remover regras `ip rule` associadas ao IP do túnel.
2. Esvaziar a tabela de roteamento separada.
3. Desativar a interface `ipsec0`.
4. Remover a interface `ipsec0`.
5. Restaurar DNS salvo.
6. Registrar a remoção da interface.

## Dependências externas

O script depende de:

* StrongSwan chamando o script com variáveis `PLUTO_*`;
* `iproute2`;
* `systemctl`;
* `resolvectl`, quando `systemd-resolved` está ativo;
* `wget`;
* `nc`;
* `awk`;
* `grep`;
* acesso HTTPS ao servidor definido em `SRVROTAS`;
* permissão de escrita em `/var/log/ipsec-updown.log`;
* permissão para alterar interfaces, rotas, regras de roteamento e DNS.

## Tratamento de erros

O script interrompe a configuração quando:

* a interface `ipsec0` não aparece após cinco tentativas;
* o servidor de rotas não responde na porta `443`.

Falhas ao adicionar rotas adicionais são contabilizadas, mas não interrompem necessariamente a execução. O script registra a quantidade de rotas carregadas e a quantidade de falhas.

## Decisões de projeto

A criação da interface `ipsec0` é uma decisão operacional para tornar o tráfego IPsec mais explícito no sistema Linux, mesmo quando o modelo padrão do StrongSwan não cria uma interface dedicada.

O uso da tabela separada `ipsec` evita poluir a tabela principal e permite limpar rotas do túnel de forma concentrada na desconexão.

O uso do ID `220` como fallback mantém compatibilidade com ambientes em que o alias da tabela ainda não foi registrado.

A fonte externa de rotas permite alterar redes acessíveis pela VPN sem reconstruir o pacote e sem editar manualmente cada estação. Essa decisão exige que o servidor de rotas seja confiável e disponível durante a subida do túnel.

> Motivo da decisão ainda não documentado: uso de um endereço padrão fixo como servidor de rotas.

## Limitações conhecidas

O script possui valores operacionais fixos, como `SRVROTAS`, `IPSEC_IF`, `IPSEC_TABLE_ID` e `IPSEC_TABLE_NAME`.

O valor inicial de `PLUTO_PEER_CLIENT` é sobrescrito no código por:

```bash
IPSEC_ROUTE="198.51.100.0/24"
```

Portanto, a rota inicial documentada pelo StrongSwan não é usada diretamente no comportamento atual.

O script calcula a variável `grupo_vpn` a partir de `PLUTO_MY_ID`, mas a URL de rotas usa `${grupo_vpnx:-}`. Como `grupo_vpnx` não é definida no script, o sufixo por grupo não é aplicado no carregamento atual das rotas.

O download das rotas usa `wget --no-check-certificate`, portanto a validação de certificado TLS é desabilitada.

O conteúdo retornado pelo servidor de rotas é usado diretamente em comandos `ip route add`.

O script substitui `/etc/resolv.conf` quando `systemd-resolved` não está ativo.

## Aspectos de segurança

O servidor de rotas é uma dependência crítica. Quem controla esse endpoint controla quais rotas serão carregadas na tabela do IPsec.

Antes de uso fora de ambiente controlado, é recomendável revisar:

* origem e autenticação do servidor de rotas;
* validação TLS;
* formato permitido para rotas;
* remoção de valores fixos;
* comportamento de DNS;
* necessidade real de criar uma interface `dummy`;
* política de logs em `/var/log/ipsec-updown.log`, pois o script registra o ambiente recebido do StrongSwan.

## Relação com outros componentes

O script é referenciado pelo arquivo de exemplo `_sample_ipsec.conf` por meio de `leftupdown`.

O pacote também instala ajustes de AppArmor para permitir sua execução pelo processo `charon` do StrongSwan.
