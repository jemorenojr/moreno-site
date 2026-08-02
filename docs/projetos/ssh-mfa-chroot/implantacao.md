# Implantação

> Conteúdo extraído de material histórico. As configurações devem ser validadas por distribuição e versão antes de uso real.

## Sequência recomendada

O procedimento replicável está no documento inicial [MFA Google e Jail](index.md). Esta página funciona como mapa de implantação e critério de conclusão.

1. Confirmar requisitos do sistema e dependências.
2. Preparar conta administrativa de contingência.
3. Configurar e validar OpenSSH.
4. Configurar e validar PAM/MFA.
5. Construir o diretório base do chroot.
6. Provisionar um usuário de teste.
7. Testar login com sessão administrativa paralela aberta.
8. Validar comandos mínimos dentro do jail.
9. Registrar a implantação e pendências.

## Documentos da implantação

- [Pré-requisitos](index.md): lista o que precisa existir antes da configuração.
- [Configuração OpenSSH](configuracao_openssh_explicacao.md): descreve diretivas globais e blocos `Match`.
- [Configuração PAM/MFA](configuracao-pam-mfa.md): descreve a integração do segundo fator.
- [Construção do chroot](construcao-chroot.md): descreve árvore, binários, bibliotecas e arquivos mínimos.

## Critério de conclusão

A implantação só deve ser considerada pronta quando:

- `sshd_config` foi validado antes de recarregar o serviço;
- a pilha PAM foi testada com usuário controlado;
- a conta de contingência foi validada;
- o usuário de teste acessou o jail;
- comandos mínimos funcionaram dentro do jail;
- falhas previsíveis foram registradas em [Operação e diagnóstico](operacao-diagnostico.md);
- riscos aceitos foram registrados em [Segurança e limitações](seguranca-limitacoes.md).
