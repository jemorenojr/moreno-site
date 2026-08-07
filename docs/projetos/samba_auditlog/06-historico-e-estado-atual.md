# Histórico e estado atual

A aplicação trabalha com duas naturezas de informação.

``` text
MariaDB                         smbstatus
   │                                │
   ▼                                ▼
histórico                       estado atual
   │                                │
   ▼                                ▼
o que aconteceu?             o que está acontecendo?
```

## Histórico

O MariaDB mantém eventos já processados: operações, usuários, arquivos, caminhos, compartilhamentos e períodos. Eles permanecem disponíveis mesmo depois que a sessão SMB termina.

## Estado atual

A aplicação também utiliza `smbstatus` para consultar informações correntes do Samba e acompanhar o estado atual dos compartilhamentos e conexões.

Uma sessão ativa não representa todo o histórico de um usuário, assim como um evento histórico não significa que a sessão ainda esteja ativa.

Por isso:

``` text
auditoria histórica ≠ estado atual
```

A interface reúne as duas perspectivas sem confundir suas responsabilidades.

[Próxima camada: autenticação e autorização](07-autenticacao-e-autorizacao.md)
