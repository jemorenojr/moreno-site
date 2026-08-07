# Persistência --- construção do histórico

Os dados interpretados são armazenados no MariaDB, no banco:

``` text
Samba_Audit_Log
```

O repositório contém o schema e as procedures em `Instalacao/SQLs/`.

## Por que um banco

A finalidade não é simplesmente trocar arquivo por tabela. O banco permite observar a mesma massa de eventos por diferentes eixos.

No log:

``` text
evento 1
evento 2
evento 3
evento 4
...
```

Na base estruturada:

``` text
por usuário
por arquivo
por compartilhamento
por período
por operação
por remoção
```

Uma investigação pode começar pelo usuário e chegar aos arquivos, ou começar pelo arquivo e descobrir usuários, períodos e operações.

## Três responsabilidades distintas

``` text
log bruto        → referência original
MariaDB          → representação estruturada
aplicação Web    → instrumento de investigação
```

O histórico estruturado não elimina a fonte bruta; ele torna a informação pesquisável.

[Próxima camada: consulta e investigação](05-consulta-e-investigacao.md)
