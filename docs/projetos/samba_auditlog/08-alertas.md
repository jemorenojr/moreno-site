# Alertas --- acompanhamento operacional

Além das consultas Web, determinados eventos podem ser tratados como alertas.

Dessa forma, a auditoria deixa de funcionar exclusivamente como ferramenta de investigação posterior.

Eventos considerados relevantes podem também produzir notificações para acompanhamento operacional.

A auditoria pode ser utilizada depois de um fato:

``` text
evento → armazenamento → consulta posterior
```

O projeto também trata informações relacionadas a alertas e fornece:

``` text
bin/telegram_avisos.py
```

para integração com a Telegram Bot API.

## Fluxo

``` text
evento
  ↓
parser
  ├── armazenamento
  └── informação de alerta
             ↓
      telegram_avisos.py
             ↓
      Telegram Bot API
```

A notificação é separada do Samba e da interface Web. O canal de alerta trabalha sobre informações já processadas pelo sistema.

Na implantação documentada, `telegram_avisos.py` é executado periodicamente pelo `cron`.

[Próxima camada: operação dos serviços](09-operacao-dos-servicos.md)
