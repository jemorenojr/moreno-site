# Origem do projeto --- quando registrar não é suficiente

## O Samba já possui auditoria

O Samba Auditlog não surgiu por falta de mecanismos de auditoria no Samba. O módulo `vfs_full_audit` pode registrar operações realizadas nos compartilhamentos.

``` ini
vfs objects = full_audit
full_audit:prefix = %d - %u - %I - %m - %a - %S -
full_audit:success = all
full_audit:failure = none
full_audit:facility = LOCAL5
full_audit:priority = WARNING
```

O prefixo fornece contexto como domínio, usuário, endereço IP, máquina cliente, arquitetura e compartilhamento.

## O problema é reconstruir a atividade

Uma auditoria normalmente começa com perguntas:

-   quem acessou determinado arquivo?
-   quando?
-   de qual estação?
-   quais diretórios percorreu?
-   quais arquivos manipulou?
-   o que determinado usuário fez durante um período?
-   quem removeu determinado objeto?

O log possui os eventos necessários, mas eles estão organizados como uma sequência técnica e cronológica. Quanto maior o volume, mais difícil se torna correlacioná-los manualmente.

Conceitualmente:

``` text
timestamp host smbd_audit:
domínio - usuário - IP - estação - arquitetura -
compartilhamento - operação - objeto
```

Existe diferença entre **registrar uma operação** e **conseguir
reconstruir rapidamente uma atividade**. O primeiro problema é resolvido
pelo Samba; o segundo é o problema tratado pelo Samba Auditlog.

## Estratégia

``` text
evento original
      │
      ├────────► preservar o bruto
      ▼
interpretar
      ▼
separar campos
      ▼
armazenar estruturado
      ▼
consultar por diferentes perspectivas
```

A fonte continua sendo o Samba. O sistema cria uma representação adicional voltada à investigação.

[Próxima camada: coleta e transporte](02-coleta-e-transporte.md)
