# Consulta e investigação --- diferentes visões da mesma auditoria

Depois da persistência, o problema deixa de ser coleta e passa a ser investigação.

A aplicação Flask possui módulos para dashboard, pesquisa por usuário, pesquisa por arquivo, itens removidos, acompanhamento de compartilhamentos, monitoramento e alertas.

## Por usuário

``` text
usuário
  ├── período
  ├── origem
  ├── compartilhamento
  ├── caminhos
  └── operações
```

A pergunta passa a ser: **o que este usuário fez?**

## Por arquivo

``` text
arquivo
  ├── quem acessou
  ├── quando
  ├── de onde
  └── qual operação
```

A investigação pode começar pelo objeto sem conhecer antecipadamente os usuários envolvidos.

## Itens removidos

Eventos de remoção possuem uma visão específica, permitindo partir da operação relevante em vez de percorrer toda a atividade.

## Dashboard

O dashboard oferece leitura agregada da massa histórica e serve como ponto de entrada para investigações mais específicas.

## Uma base, várias projeções

``` text
                  MariaDB
                     │
       ┌─────────────┼──────────────┐
       ▼             ▼              ▼
   usuário         arquivo       removidos
       └─────────────┼──────────────┘
                     ▼
                  auditoria
```

Não são fontes diferentes: são formas diferentes de consultar os mesmos eventos normalizados.

[Próxima camada: histórico e estado atual](06-historico-e-estado-atual.md)
