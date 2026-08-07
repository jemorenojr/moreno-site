# Coleta e transporte --- vfs_full_audit e rsyslog

## Responsabilidade

Esta camada faz o Samba produzir o evento e transporta esse evento até o parser. Ela não interpreta a auditoria nem grava diretamente no banco.

## Geração

Nos compartilhamentos auditados, `vfs_full_audit` produz os eventos. O formato de `full_audit:prefix` é relevante porque carrega o contexto que será interpretado posteriormente.

## Transporte

O projeto fornece:

``` text
etc/rsyslog.d/samba_audit.conf
```

O rsyslog seleciona eventos cujo `programname` é:

``` text
smbd_audit
```

e os encaminha para:

``` text
127.0.0.1:780/udp
```

utilizando um template com timestamp RFC 3339.

``` text
Samba
  ↓
vfs_full_audit
  ↓
rsyslog
  ↓
filtro smbd_audit
  ↓
UDP 127.0.0.1:780
  ↓
Parser
```

O Samba não conhece MariaDB, Flask ou a interface. Ele apenas produz o evento. O rsyslog faz o transporte, mantendo o serviço de arquivos desacoplado das camadas seguintes.

Essa fronteira também permite testar separadamente geração, seleção, encaminhamento e recepção dos eventos.

[Próxima camada: parser e normalização](03-parser-e-normalizacao.md)
