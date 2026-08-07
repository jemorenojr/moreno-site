# Parser --- interpretação e normalização

## A fronteira entre log e informação estruturada

O componente:

``` text
bin/filtro_samba_audit_v3.py
```

recebe em `127.0.0.1:780/udp` os eventos encaminhados pelo rsyslog.

Sua função é interpretar o registro e separar informações úteis para a auditoria, como usuário, domínio, IP, máquina de origem, arquitetura, compartilhamento, operação e detalhes do evento.


## Preservação do evento bruto

O banco não substitui o log original.

``` text
                evento recebido
                      │
              ┌───────┴────────┐
              ▼                ▼
        registro bruto     interpretação
        preservado             │
                               ▼
                        dados estruturados
                               │
                               ▼
                            MariaDB
```

O sistema mantém o dado bruto em log e grava uma cópia interpretada no banco.

## Por que normalizar

No log, a informação está preparada para registro sequencial. Para investigação, interessa responder:

``` text
quem?
quando?
de onde?
em qual compartilhamento?
qual operação?
sobre qual objeto?
```

O parser faz essa mudança de representação. Entre suas responsabilidades estão:

- interpretação dos registros de auditoria;
- normalização dos dados;
- identificação de usuários;
- identificação da máquina de origem;
- identificação do endereço IP;
- associação com o compartilhamento;
- classificação das ações;
- armazenamento no banco;
- tratamento das informações relacionadas aos alertas.

Ele não é a interface de auditoria; sua responsabilidade termina ao preservar, interpretar e entregar os dados estruturados para persistência.


O parser é executado como serviço `systemd`, independente da aplicação Web.

[Próxima camada: persistência e histórico](04-persistencia-e-historico.md)
