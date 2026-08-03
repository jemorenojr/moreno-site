# ipsec-monitor: controle local de IPsec/StrongSwan via systray

> Esta página não é uma documentação oficial do StrongSwan, do IPsec ou de qualquer distribuição Linux.
> Trata-se de uma documentação autoral sobre uma ferramenta pessoal para facilitar o controle local de túneis IPsec em ambientes desktop Linux.

## Download

 - [ipsec-monitor_1.5.0_all.deb](https://github.com/jemorenojr/ipsec-monitor/raw/refs/heads/main/binary/ipsec-monitor_1.5.0_all.deb)

## Objetivo

O `ipsec-monitor` é um pacote Debian que instala um aplicativo de systray para acompanhar e controlar túneis IPsec/StrongSwan já existentes no computador.

Ele foi criado para reduzir operações manuais repetitivas, como iniciar o serviço IPsec, selecionar um túnel configurado, conectar, desconectar e visualizar o estado geral da VPN pela área de notificação do ambiente gráfico.

## Problema que resolve

Em ambientes desktop Linux, o controle de túneis IPsec configurados com StrongSwan normalmente exige o uso de terminal e comandos como:

```bash
sudo ipsec start
sudo ipsec up Nome_Do_Tunel
sudo ipsec down Nome_Do_Tunel
sudo ipsec stop
```

O `ipsec-monitor` encapsula esse fluxo em um ícone de systray, mantendo o controle sobre configurações já existentes no sistema.

## O que o pacote faz

O pacote instala:

* aplicativo gráfico de systray para controle local do IPsec;
* atalho de autostart para iniciar o tray na sessão gráfica;
* ícones de estado para IPsec parado, IPsec ativo e VPN ativa;
* seleção de túneis encontrados em `/etc/ipsec.conf`;
* comandos para iniciar e parar o serviço IPsec;
* comandos para conectar e desconectar o túnel selecionado;
* utilitário gráfico para alterar senha XAUTH existente em `/etc/ipsec.secrets`;
* binário auxiliar `ipsec_kill`;
* regra de sudo limitada aos comandos usados pelo controle local;
* ajustes de AppArmor usados pelo pacote;
* arquivos `_sample_*` como exemplos de configuração.

## O que o pacote não faz

O `ipsec-monitor` não provisiona VPN automaticamente.

Ele não:

* substitui `/etc/ipsec.conf`;
* substitui `/etc/ipsec.secrets`;
* substitui `/etc/strongswan.conf`;
* cria credenciais;
* escolhe gateway remoto;
* define política oficial de criptografia;
* garante compatibilidade com todos os modelos possíveis de IPsec;
* substitui a documentação oficial do StrongSwan;
* valida se uma configuração de VPN é segura para produção.

## Compatibilidade esperada

A compatibilidade principal é com instalações StrongSwan que usam o modelo clássico baseado em `starter` e nos arquivos:

```text
/etc/ipsec.conf
/etc/ipsec.secrets
```

O tray lista túneis procurando blocos `conn` em `/etc/ipsec.conf`.

Exemplo:

```text
conn Minha_VPN
  auto=start
  keyexchange=ikev1
  authby=psk
  left=%defaultroute
  right=203.0.113.10
```

Quando o usuário seleciona um túnel, o pacote executa comandos do próprio StrongSwan:

```bash
sudo ipsec up Minha_VPN
sudo ipsec down Minha_VPN
```

Portanto, se o StrongSwan instalado no sistema aceita o túnel via `ipsec up <nome>` e `ipsec down <nome>`, o controle básico do `ipsec-monitor` tende a funcionar.

## Ambientes validados

O `ipsec-monitor` foi validado nos seguintes sistemas:

* Debian 11;
* Debian 12;
* Debian 13;
* Ubuntu 22.04;
* Ubuntu 24.04.

Nessas validações, o StrongSwan utilizado foi o pacote fornecido pela própria distribuição. Não foi usada versão compilada manualmente nem pacote externo ao repositório padrão do sistema operacional.

Essa validação indica compatibilidade prática com os ambientes listados, mas não substitui teste local antes de uso em produção.

## Compatibilidade não garantida

O pacote não deve ser tratado como uma interface universal para StrongSwan.

A compatibilidade não está garantida para:

* configurações baseadas somente em `swanctl.conf`;
* uso direto de VICI;
* ambientes sem suporte funcional a systray/AppIndicator;
* túneis route-based complexos com VTI ou XFRM;
* túneis site-to-site sem IP local identificável no `ip addr`;
* instalações que não disponibilizam o comando `ipsec`;
* saídas de `ipsec status` muito diferentes das esperadas pelo script.

Nesses casos, o túnel ainda pode funcionar no StrongSwan, mas o tray pode não listar, controlar ou detectar corretamente o estado da conexão.

## Configurações de exemplo

O pacote não instala configurações ativas de VPN.

Os exemplos ficam em:

```text
/usr/share/ipsec-monitor/_sample_ipsec.conf
/usr/share/ipsec-monitor/_sample_ipsec.secrets
/usr/share/ipsec-monitor/_sample_strongswan.conf
```

Durante a instalação, o pacote também cria cópias em:

```text
/etc/ipsec.d/ipsec-monitor-samples/_sample_ipsec.conf
/etc/ipsec.d/ipsec-monitor-samples/_sample_ipsec.secrets
/etc/ipsec.d/ipsec-monitor-samples/_sample_strongswan.conf
```

Essas cópias são criadas somente se ainda não existirem. O objetivo é permitir que o usuário consulte um exemplo sem sobrescrever configurações existentes.

## Script updown-ipsec.sh

O pacote inclui o script `updown-ipsec.sh`, usado pelo StrongSwan por meio da diretiva `leftupdown`.

Esse script possui comportamento próprio e deve ser analisado separadamente antes de uso em outro ambiente. Ele cria a interface lógica `ipsec0`, usa uma tabela de roteamento separada chamada `ipsec` ou o ID numérico `220`, consulta um servidor HTTPS como fonte de rotas e ajusta DNS durante a conexão.

A documentação detalhada desse componente está em [updown-ipsec.md](updown-ipsec.md).

## Instalação

Depois de baixar o pacote `.deb`, a instalação pode ser feita com:

```bash
sudo dpkg -i ipsec-monitor_1.5.0_all.deb
sudo apt-get install -f
```

O primeiro comando instala o pacote. O segundo resolve dependências pendentes, caso a distribuição precise instalar bibliotecas ou programas usados pelo tray.

Durante a instalação, o pacote solicita o usuário local que poderá operar o controle IPsec pelo ambiente gráfico. Esse usuário é incluído no grupo local `ipsec`.

Após a inclusão no grupo, pode ser necessário encerrar e abrir novamente a sessão gráfica para que a permissão tenha efeito.

## Operação básica

Depois da instalação e de uma nova sessão gráfica, o ícone do IPsec Control deve aparecer na área de notificação.

Pelo menu do ícone, o usuário pode:

* selecionar um túnel encontrado em `/etc/ipsec.conf`;
* iniciar o serviço IPsec;
* parar o serviço IPsec;
* iniciar a VPN selecionada;
* parar a VPN selecionada;
* abrir a tela de alteração de senha XAUTH;
* sair do aplicativo.

O estado visual é inferido a partir de `ipsec status` e da verificação de endereços locais com `ip addr`.

## Segurança

O pacote instala uma regra de sudo para permitir que membros do grupo `ipsec` executem, sem senha, somente os comandos necessários ao controle local:

```text
/usr/sbin/ipsec start
/usr/sbin/ipsec stop
/usr/sbin/ipsec up *
/usr/sbin/ipsec down *
/usr/local/bin/ipsec_kill
```

Essa permissão deve ser revisada antes de uso em ambientes compartilhados ou de produção.

Arquivos de segredo do StrongSwan devem permanecer protegidos. Quando existir `/etc/ipsec.secrets`, a permissão esperada normalmente é restrita ao usuário `root`.

## Limitações conhecidas

O `ipsec-monitor` resolve um problema específico: controlar, pelo systray, túneis StrongSwan já configurados no modelo clássico de `/etc/ipsec.conf`.

Ele não tenta cobrir todos os modelos possíveis de IPsec. A detecção visual de VPN ativa pode falhar quando o túnel não cria um IP local fácil de associar a uma interface, mesmo que o túnel esteja funcional.

## Decisão de projeto

A partir da versão `1.5.0`, o pacote foi generalizado para publicação. Por esse motivo, deixou de instalar configurações ativas de VPN e passou a distribuir somente exemplos `_sample_*`.

Essa decisão evita que a instalação substitua configurações existentes do usuário e deixa claro que qualquer adaptação de VPN deve ser feita manualmente, de acordo com o ambiente de destino.

## Aviso final

Use esta ferramenta como apoio operacional, não como fonte normativa de configuração IPsec.

Para desenho criptográfico, parâmetros de segurança, interoperabilidade com outros fabricantes e configurações avançadas, consulte a documentação oficial do StrongSwan e valide o ambiente antes de usar em produção.
