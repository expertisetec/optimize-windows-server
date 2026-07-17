# Contribuindo

Guia rápido para propor mudanças ou novos scripts para a série de automações
de TI / NOC da Expertise Tecnologia.

## Fluxo básico

1. Crie uma branch a partir de `main`.
2. Faça as alterações, testando localmente antes de abrir o PR.
3. Atualize o [CHANGELOG.md](CHANGELOG.md) com a mudança (ver seção
   [Changelog](#changelog) abaixo).
4. Abra um Pull Request para `main` descrevendo o quê e o porquê da mudança.

## Novo script

Todo script novo da série deve nascer a partir dos templates em
[`templates/`](templates/):

- [`templates/Script-Header-Template.ps1`](templates/Script-Header-Template.ps1)
  — cabeçalho padrão (autor, empresa, setor, versão, licença, links).
- [`templates/README-Template.md`](templates/README-Template.md) — README
  padrão do repositório/pasta do script.

Preencha os campos `{{...}}` e mantenha as seções na mesma ordem — isso é o
que garante que todos os scripts da Expertise Tecnologia tenham a mesma cara,
independente de quem escreveu.

## Versionamento (SemVer)

A série segue [Versionamento Semântico](https://semver.org/lang/pt-BR/):
`MAJOR.MINOR.PATCH` (ex.: `1.2.0`).

- **MAJOR** — mudança que quebra compatibilidade: remove um passo existente,
  muda um parâmetro obrigatório, muda comportamento padrão de forma que um
  uso anterior do script passa a se comportar diferente.
- **MINOR** — nova funcionalidade compatível com o uso anterior: novo passo
  de limpeza, novo parâmetro opcional, nova opção de log.
- **PATCH** — correção de bug, ajuste de texto/log, pequena melhoria interna
  que não muda o comportamento observável do script.

Sempre que a versão for incrementada, atualize **os dois lugares** no
script (ver [Fonte única da versão](#fonte-única-da-versão-no-script)) e
registre a mudança no `CHANGELOG.md`.

## Fonte única da versão no script

Cada script tem a versão em dois lugares que precisam ficar sincronizados:

1. O campo `Versao` no cabeçalho de comentário (topo do arquivo).
2. A variável `$ScriptVersion` no bloco de configuração inicial.

O campo `$ScriptVersion` é a fonte que o script realmente usa em tempo de
execução (logs, relatório). O cabeçalho existe para leitura humana rápida —
por isso os dois precisam bater. Ao rodar localmente (não via `irm | iex`),
o script confere isso sozinho e emite um aviso (`Write-Warning`) se
divergirem — mas a checagem automática não substitui a atenção ao atualizar
os dois campos juntos ao publicar uma nova versão.

## Changelog

Não documente histórico de versões dentro do próprio `.ps1`. O bloco
`HISTORICO DE VERSOES` do cabeçalho deve apontar para o `CHANGELOG.md` do
repositório, e é lá que cada entrada de versão é detalhada (Adicionado /
Alterado / Corrigido / Removido), seguindo
[Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/).

## Social preview (GitHub)

Depois de incrementar `$ScriptVersion`, rode:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Update-SocialPreview.ps1
```

Isso atualiza a versão exibida em `assets/social-preview-source.html` e
re-renderiza `assets/social-preview.png` (1280×640, requer Chrome ou Edge
instalado). Faça commit do PNG junto com a mudança de versão.

O GitHub **não** tem API para o campo Social Preview — mesmo com o PNG do
repositório atualizado, o passo final continua manual: Settings → General →
Social preview → Edit → Upload an image.

## Passos que instalam/alteram software no servidor

O `WindowsOptimizerCleanup.ps1` tem um passo (verificação/atualização do
PowerShell 7) que baixa e instala software a partir da internet, sem pedir
confirmação do operador. Isso é aceitável **apenas** porque:

- O script é usado conscientemente por analistas de TI que já sabem o que
  ele faz (não é distribuído para usuários finais sem supervisão).
- A ação nunca bloqueia a finalidade principal do script (limpeza): falha
  de rede/instalação vira `ALERTA` no resumo e o script segue em frente.
- O software instalado (PowerShell 7) é lado a lado com o que já existe —
  não substitui, não remove, não força reinicialização do próprio motor
  do script.

Se um novo script da série precisar de um passo parecido (instalar/atualizar
algo automaticamente), siga o mesmo padrão: **nunca** deixe uma falha de
rede ou de instalação interromper o restante do script, e documente a
decisão aqui.

Sobre `winget`: **não use** como único mecanismo de instalação nesta série.
A documentação da Microsoft confirma que `winget` não vem por padrão no
Windows Server 2022 ou anterior — que é justamente o público-alvo declarado
destes scripts. Prefira MSI com instalação silenciosa (`msiexec /quiet`),
que é o que a própria Microsoft recomenda para servidores.
