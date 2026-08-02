# Configuração PAM/MFA

## Objetivo

Integrar o login SSH ao segundo fator TOTP usando PAM e o módulo `pam_google_authenticator.so`.

## Contrato do componente

Depois que o OpenSSH valida a chave pública, o PAM deve solicitar um código TOTP válido para o usuário. Somente após esse passo o OpenSSH deve entregar a sessão e aplicar o chroot configurado.

## Exemplo

```text
auth required pam_google_authenticator.so nullok
```

Esse exemplo exige validação na distribuição alvo. A posição da linha na pilha PAM altera o comportamento de autenticação.

## Parâmetro `nullok`

`nullok` permite que usuários sem arquivo `.google_authenticator` autentiquem sem segundo fator. Isso pode ser útil em transição, mas enfraquece a garantia de MFA.

Se `nullok` for usado, deve existir controle operacional para identificar usuários ainda sem segredo TOTP e remover o parâmetro quando a migração terminar.

## Arquivo do usuário

O `google-authenticator` cria o arquivo `.google_authenticator` no home do usuário. Esse arquivo contém segredo e parâmetros de validação. Ele deve ter propriedade e permissões compatíveis com o usuário e com o módulo PAM.

## Geração do segredo

Comando histórico:

```bash
google-authenticator -t -d -f -r 3 -R 30 -W -C
```

O resultado pode incluir:

- URL `otpauth`;
- QR Code;
- códigos de emergência;
- configuração de janela e rate limit.

Essas saídas são sensíveis e não devem aparecer em documentação pública, logs ou evidências não sanitizadas.

## Entrega ao usuário

No ambiente montado, scripts enviam o QR Code por e-mail via SMTP. Todo o tráfego de e-mail ocorre em um ambiente interno controlado. Dependendo da implementação, esse fluxo deve ser tratado como risco, porque o e-mail pode expor o segredo inicial do segundo fator.

Alternativas a avaliar em revisão humana:

- entrega presencial ou canal seguro;
- QR Code exibido uma única vez em sessão controlada;
- registro de aceite e revogação;
- recriação obrigatória quando houver dúvida de exposição.

## Validação operacional

- manter sessão administrativa paralela;
- testar usuário com segredo TOTP já criado;
- testar usuário sem segredo quando `nullok` estiver habilitado;
- confirmar logs de falha e sucesso;
- validar sincronismo de horário.

## Fora do escopo

Este documento não define política corporativa de MFA nem MFA para contas Google. O foco é o módulo PAM compatível com aplicativos TOTP.
