# Autenticação e autorização

Uma base de auditoria contém informações de diversos usuários e compartilhamentos. Autenticar alguém não significa conceder acesso a toda a massa de dados.

``` text
autenticação → quem é o usuário?
autorização  → quais compartilhamentos pode administrar?
```

Como os registros de auditoria podem conter informações sensíveis sobre arquivos e usuários, não é desejável que qualquer pessoa autenticada tenha acesso a todos os compartilhamentos.

O projeto utiliza LDAP para autenticação e relaciona os grupos administrativos com a configuração existente no Samba.

A aplicação pode utilizar essa associação para determinar quais compartilhamentos um determinado usuário está autorizado a administrar e, consequentemente, quais informações de auditoria podem ser apresentadas.

Isso permite aproveitar a estrutura de grupos que já faz parte da administração do servidor de arquivos

## LDAP

A autenticação é realizada através de LDAP. Depois, a aplicação utiliza os grupos do usuário para relacioná-lo aos compartilhamentos administrados.

## Relação com o Samba

Exemplo:

``` ini
[Sistemas]
admin users = @smb_sistemas_admin
```

O fluxo conceitual é:

``` text
usuário
  ↓
LDAP
  ↓
grupos
  ↓
grupos administrativos
  ↓
admin users do smb.conf
  ↓
compartilhamentos autorizados
  ↓
dados de auditoria permitidos
```

A solução aproveita a estrutura administrativa já existente no Samba em
vez de criar uma segunda definição independente de administradores.

LDAP não participa da ingestão dos eventos; atua na camada de acesso às
informações já armazenadas.


[Próxima camada: alertas](08-alertas.md)
