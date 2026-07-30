# LVM na prática

## Problema resolvido

Administradores Linux frequentemente precisam aumentar espaço de diretórios como `/var`, `/home`, `/srv` ou áreas de dados sem reinstalar o sistema e sem copiar tudo para outro disco.

O LVM ajuda nesse cenário porque cria uma camada flexível entre discos físicos e sistemas de arquivos. Com ele é possível agrupar dispositivos, criar volumes lógicos e expandir esses volumes quando houver espaço disponível.

Este artigo mostra um fluxo prático para criar e expandir volumes LVM em Linux, usando nomes genéricos e comandos reproduzíveis.

---

## Público

Este conteúdo foi escrito para administradores Linux, analistas de infraestrutura e profissionais que precisam operar storage local em servidores físicos, virtuais ou ambientes de laboratório.

O foco é operação prática. Os exemplos usam comandos diretos e validações simples, sem depender de uma distribuição específica além das ferramentas comuns do LVM.

---

## Ambiente de exemplo

Exemplo utilizado:

```text
Disco novo:       /dev/sdb
Volume group:    vg_dados
Logical volume:  lv_aplicacao
Ponto de montagem: /srv/aplicacao
Sistema de arquivos: ext4
```

> Ajuste os nomes conforme o padrão do ambiente. Antes de executar qualquer comando destrutivo, confirme o dispositivo correto com `lsblk`.

---

## Conceitos necessários

### Physical Volume

Um Physical Volume, ou PV, é o dispositivo preparado para uso pelo LVM. Pode ser um disco inteiro, uma partição, um volume virtual ou outro dispositivo de bloco.

### Volume Group

Um Volume Group, ou VG, agrupa um ou mais PVs e forma um conjunto de espaço disponível para criação de volumes lógicos.

### Logical Volume

Um Logical Volume, ou LV, é o volume entregue ao sistema operacional para receber sistema de arquivos e ser montado em um diretório.

Fluxo resumido:

```text
Disco ou partição -> PV -> VG -> LV -> Sistema de arquivos -> Montagem
```

---

## Procedimento

### 1. Identificar o disco disponível

Liste os dispositivos de bloco:

```bash
lsblk
```

Exemplo de saída esperada:

```text
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   40G  0 disk
├─sda1   8:1    0  512M  0 part /boot
└─sda2   8:2    0 39.5G  0 part /
sdb      8:16   0  100G  0 disk
```

Neste exemplo, o disco livre é `/dev/sdb`.

### 2. Criar o Physical Volume

```bash
pvcreate /dev/sdb
```

Saída esperada:

```text
Physical volume "/dev/sdb" successfully created.
```

Valide:

```bash
pvs
```

### 3. Criar o Volume Group

```bash
vgcreate vg_dados /dev/sdb
```

Saída esperada:

```text
Volume group "vg_dados" successfully created
```

Valide:

```bash
vgs
```

### 4. Criar o Logical Volume

Crie um volume lógico de 40 GB:

```bash
lvcreate -n lv_aplicacao -L 40G vg_dados
```

Saída esperada:

```text
Logical volume "lv_aplicacao" created.
```

Valide:

```bash
lvs
```

O caminho do volume será:

```text
/dev/vg_dados/lv_aplicacao
```

### 5. Criar o sistema de arquivos

```bash
mkfs.ext4 /dev/vg_dados/lv_aplicacao
```

### 6. Criar o ponto de montagem

```bash
mkdir -p /srv/aplicacao
```

### 7. Montar o volume

```bash
mount /dev/vg_dados/lv_aplicacao /srv/aplicacao
```

Valide:

```bash
df -h /srv/aplicacao
```

### 8. Configurar montagem persistente

Obtenha o UUID:

```bash
blkid /dev/vg_dados/lv_aplicacao
```

Exemplo:

```text
/dev/vg_dados/lv_aplicacao: UUID="11111111-2222-3333-4444-555555555555" TYPE="ext4"
```

Inclua no `/etc/fstab`:

```text
UUID=11111111-2222-3333-4444-555555555555 /srv/aplicacao ext4 defaults 0 2
```

Teste a configuração antes de reiniciar:

```bash
umount /srv/aplicacao
mount -a
df -h /srv/aplicacao
```

---

## Expansão de volume

### Cenário

O volume `/srv/aplicacao` foi criado com 40 GB e precisa crescer para 60 GB.

Confira o estado atual:

```bash
lvs
df -h /srv/aplicacao
```

### Expandir o Logical Volume

```bash
lvextend -L 60G /dev/vg_dados/lv_aplicacao
```

Saída esperada:

```text
Size of logical volume vg_dados/lv_aplicacao changed from 40.00 GiB to 60.00 GiB.
Logical volume vg_dados/lv_aplicacao successfully resized.
```

### Expandir o sistema de arquivos ext4

```bash
resize2fs /dev/vg_dados/lv_aplicacao
```

Valide:

```bash
df -h /srv/aplicacao
lvs
```

### Alternativa em um único comando

Em muitos ambientes, é possível expandir o LV e o sistema de arquivos juntos:

```bash
lvextend -r -L 60G /dev/vg_dados/lv_aplicacao
```

O parâmetro `-r` aciona a expansão do sistema de arquivos quando suportado.

---

## Adicionando um novo disco ao Volume Group

Quando o VG não possui espaço livre suficiente, adicione outro disco.

Exemplo com `/dev/sdc`:

```bash
lsblk
pvcreate /dev/sdc
vgextend vg_dados /dev/sdc
vgs
```

Depois disso, o espaço passa a estar disponível para novos LVs ou expansão dos existentes.

---

## Validação

Comandos úteis para revisão:

```bash
pvs
vgs
lvs
lsblk
df -h
findmnt /srv/aplicacao
```

Pontos que devem ser confirmados:

* o PV aparece associado ao VG correto;
* o VG possui o tamanho esperado;
* o LV aparece com o tamanho configurado;
* o filesystem está montado no diretório correto;
* o `/etc/fstab` monta o volume sem erro com `mount -a`.

---

## Cuidados operacionais

Antes de executar comandos LVM em produção:

* confirme o nome do disco com `lsblk`, `blkid` e documentação do ambiente;
* valide se o disco não possui dados úteis antes de usar `pvcreate`;
* mantenha backup atualizado antes de expandir volumes críticos;
* teste o `/etc/fstab` com `mount -a` antes de reiniciar o servidor;
* monitore espaço livre no VG com `vgs`;
* documente o padrão de nomes dos VGs e LVs;
* evite misturar discos de finalidades muito diferentes no mesmo VG sem necessidade operacional.

Para filesystems XFS, a expansão usa outro comando:

```bash
xfs_growfs /srv/aplicacao
```

O XFS cresce montado, mas não reduz tamanho. Essa diferença deve ser considerada no planejamento.

---

## Conclusão

O LVM permite administrar storage local com mais flexibilidade do que o particionamento tradicional. O fluxo básico envolve preparar o disco como PV, criar ou expandir um VG, criar um LV, formatar, montar e validar.

Na prática, o maior cuidado não está no comando em si, mas na identificação correta dos dispositivos, na validação do ponto de montagem e na existência de backup antes de qualquer alteração em ambiente produtivo.

---
