# Segurança e limitações

## Reduções de risco

A arquitetura reduz riscos por combinar:

- entrada centralizada;
- autenticação por chave pública;
- segundo fator TOTP;
- redução do ambiente pós-login;
- menor exposição direta dos servidores internos.

Esses ganhos dependem da configuração correta de OpenSSH, PAM, permissões do chroot, gestão de chaves e operação da Jump Server.

## Limitações do chroot

Chroot não é isolamento absoluto. Ele restringe a visão do sistema de arquivos, mas não isola por completo kernel, processos, rede, capacidades ou todos os efeitos de binários disponíveis.

O jail deve ser tratado como controle de redução de superfície, não como barreira equivalente a container ou máquina virtual.

## Riscos operacionais

- Comprometimento da Jump Server compromete o ponto central da arquitetura.
- Erro em PAM ou OpenSSH pode bloquear acessos administrativos.
- Conta de contingência mal protegida vira bypass da solução.
- Cada binário adicional no jail amplia possibilidades de uso indevido.
- Bibliotecas desatualizadas dentro do jail podem manter vulnerabilidades após atualização do sistema base.
- `authorized_keys` pode conter opções perigosas se não houver política de validação.
- Encaminhamento SSH e agentes podem ampliar alcance do usuário se não forem tratados por política.
- Regras específicas dentro de blocos `Match` podem ter efeito diferente do esperado se a ordem do arquivo não for revisada.

## Riscos do MFA

- O segredo TOTP é sensível.
- QR Code e códigos de emergência não devem ser registrados em logs ou documentação.
- Enviar o segredo por e-mail pode expor o segundo fator.
- `nullok` pode permitir autenticação sem MFA para usuários ainda não provisionados.
- Recriação de MFA deve invalidar o segredo anterior e ser registrada.

## Riscos do relay SMTP

- O relay pode aceitar a conexão, mas rejeitar destinatários ou mensagem.
- O envio manual via SMTP pode aparentar sucesso sem validação das respostas.
- A mensagem pode trafegar ou ser armazenada em sistemas de correio.
- Anexos com QR Code carregam o segredo inicial do segundo fator.

## Riscos dos scripts históricos

Os scripts alteram usuários, grupos, home, chroot, dispositivos e arquivos de autenticação. A execução sem validação pode deixar estado parcial.

Pontos que exigem análise posterior:

- ausência de rollback completo;
- expansão de variáveis em comandos destrutivos;
- uso de `rm -rf`;
- arquivos temporários com dados sensíveis;
- envio SMTP sem validação de resposta;
- dependência de comandos e caminhos específicos de distribuição.

## Auditoria

O material consolidado recomenda registrar:

- autenticações SSH;
- falhas de MFA;
- alterações de usuários;
- alterações no jail;
- operações de revogação;
- falhas de envio do QR Code.

Não foi encontrada, nesta etapa, implementação completa de auditoria de comandos executados dentro do jail.

## Controles recomendados para revisão

- Definir política para opções permitidas em `authorized_keys`.
- Restringir forwarding quando não for necessário.
- Definir processo seguro de entrega do MFA.
- Revisar a lista de binários permitidos no jail.
- Definir reconstrução dos jails após atualização relevante do sistema.
- Testar conta administrativa de contingência periodicamente.

## Restrições para publicação

Antes de publicação pública, remover ou substituir:

- domínios internos;
- endereços IP reais;
- nomes de servidores;
- e-mails corporativos;
- nomes de usuários reais;
- URLs internas;
- capturas com QR Code ou segredo TOTP;
- referências que revelem topologia administrativa.
