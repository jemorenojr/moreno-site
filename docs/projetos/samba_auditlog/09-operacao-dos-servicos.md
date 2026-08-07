# Operação --- separação dos serviços

O Samba Auditlog não é um processo monolítico. Cada componente possui responsabilidade operacional própria.

``` text
Samba       → geração dos eventos
rsyslog     → seleção e transporte
Parser      → interpretação e normalização
MariaDB     → persistência
Flask       → aplicação e consultas
LDAP        → autenticação e autorização
smbstatus   → estado atual
Gunicorn    → servidor WSGI
Supervisor  → supervisão da aplicação Web
Nginx       → publicação HTTP/HTTPS
cron        → execução periódica das notificações
Telegram    → canal de alerta
```

## Ciclos independentes

O parser é executado por `systemd`. A aplicação Flask é servida por Gunicorn e supervisionada pelo Supervisor. O Nginx atua como frontend. A rotina de Telegram é executada periodicamente pelo cron.

Essa divisão impede que toda a solução seja tratada como um único processo.

## Troubleshooting por fronteiras

``` text
Samba
  ↓
rsyslog
  ↓
UDP/780
  ↓
parser
  ↓
MariaDB
  ↓
Flask
  ↓
Gunicorn
  ↓
Nginx
```

Se um evento não aparece na interface, cada fronteira pode ser verificada isoladamente.

A mesma lógica vale para alertas:

``` text
dados processados
  ↓
telegram_avisos.py
  ↓
Telegram Bot API
```

O serviço de arquivos permanece responsável por servir arquivos. Coleta, transporte, interpretação, persistência, consulta e notificação permanecem separados.

## Código e instalação

Repositório: https://github.com/jemorenojr/Samba_Auditlog

Para implantação, consulte `README.md` e `INSTALL.md`.
