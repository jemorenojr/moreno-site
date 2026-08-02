# Conceitos

## Jump Server e Bastion Host

Uma Jump Server, ou bastion host, é um servidor intermediário usado como ponto controlado de entrada para uma rede administrativa. No material original, ela concentra autenticação e acesso aos servidores internos.

## OpenSSH

OpenSSH fornece o serviço SSH usado para autenticação, sessão remota e encaminhamento do acesso administrativo. A configuração histórica usa autenticação por chave pública e integração com PAM.

## Chave pública

A chave pública é o primeiro fator de autenticação. Ela é registrada em `authorized_keys` no diretório do usuário. A chave privada correspondente permanece com o usuário.

## PAM

PAM é a camada de autenticação usada por serviços Linux. Neste desenho, o OpenSSH utiliza PAM para chamar o módulo de autenticação multifator.

## TOTP

TOTP é um código temporário baseado em segredo compartilhado e tempo. O código muda periodicamente e funciona como segundo fator.

## Google Authenticator PAM

O módulo `pam_google_authenticator.so` valida códigos TOTP gerados por aplicativos compatíveis com Google Authenticator. A documentação derivada trata o módulo PAM, não o MFA de contas Google em serviços como Gmail ou Drive.

## Chroot Jail

Chroot altera a raiz aparente do sistema de arquivos para um processo e seus descendentes. No login SSH, `ChrootDirectory` entrega ao usuário uma árvore restrita.

Chroot reduz o acesso acidental ou direto ao sistema de arquivos real, mas não é um sandbox absoluto.

## Chroot, namespace, container e máquina virtual

| Técnica | Isolamento principal | Observação |
|---------|----------------------|------------|
| Chroot | Sistema de arquivos | Simples, mas não isola todos os recursos do kernel. |
| Namespace | Recursos do kernel | Pode isolar PID, rede, mount e outros domínios. |
| Container | Conjunto de namespaces, cgroups e rootfs | Mais completo que chroot, ainda compartilha kernel. |
| Máquina virtual | Hardware virtualizado | Isolamento mais forte, maior custo operacional. |

## Relação entre os conceitos

Na solução histórica, OpenSSH autentica por chave, PAM solicita TOTP, e Chroot restringe o ambiente após o login. São camadas complementares: autenticação, segundo fator e confinamento de ambiente.
