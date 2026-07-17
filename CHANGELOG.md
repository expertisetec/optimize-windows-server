# Changelog

Todas as mudanças relevantes deste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/)
(ver regras em [CONTRIBUTING.md](CONTRIBUTING.md#versionamento-semver)).

## [1.3.0] - 2026-07-17

### Adicionado

- Novo Passo 1: **Verificar/atualizar PowerShell 7**. Consulta a API do
  GitHub pela versão estável mais recente, compara com a versão instalada
  (`pwsh.exe`) e, se ausente ou desatualizada, baixa o MSI oficial e
  instala silenciosamente (`msiexec /quiet`) — o método que a própria
  Microsoft recomenda para servidores (`winget` não está disponível por
  padrão no Windows Server 2022 ou anterior).
- Os passos antigos 1–9 foram renumerados para 2–10 para abrir espaço
  para o novo Passo 1.

### Alterado

- Este passo roda sem confirmação do operador (uso consciente por
  analistas de TI) e **nunca bloqueia a limpeza**: falha de rede, GitHub
  inacessível ou erro na instalação viram `ALERTA` no resumo (detalhes no
  log), mas os passos seguintes rodam normalmente.
- O PowerShell 7 é instalado lado a lado com o Windows PowerShell 5.1 —
  o restante do script continua rodando no mesmo motor que já estava em
  uso (sem relançamento sob `pwsh.exe`).

## [1.2.0] - 2026-07-17

### Adicionado

- Detecção real de reparo do SFC: `Test-SfcMadeRepairs` lê o `CBS.log`
  (tags internas `[SR]`, não localizadas — ao contrário do texto que o
  `sfc.exe` imprime no console) para confirmar se o `/scannow` reparou
  algum arquivo desde o início daquele passo.

### Alterado

- A recomendação de reinicialização no relatório final agora é
  condicional ao resultado real do SFC: só recomenda quando houve reparo
  confirmado; quando não há reparo, informa que não é necessário; quando
  não é possível confirmar (`CBS.log` ausente/ilegível), erra para o
  lado seguro e recomenda mesmo assim.
- A tela final não reexibe mais o menu de passos numerado (que já tinha
  sido mostrado durante a execução) — agora limpa a tela e mostra só o
  resumo final, sem duplicidade.

## [1.1.0] - 2026-07-17

### Adicionado

- Novo passo de limpeza: cache de disco dos navegadores mais comuns
  (Internet Explorer, Google Chrome, Mozilla Firefox, Microsoft Edge e
  Opera), para todos os perfis de usuário em `C:\Users`.
- Menu fixo de passos no console: mostra os 9 passos com status
  (`Pendente`/`Executando...`/`OK`/`ALERTA`/`FALHA`) e a porcentagem ao
  vivo durante os passos de DISM, em vez de despejar dezenas de linhas de
  progresso no terminal.
- Resumo final na tela (status de cada passo + relatório de espaço),
  seguido de uma pergunta ao operador se deseja manter ou descartar o
  arquivo de log.
- Campo `Setor` no cabeçalho do script (acima do `Autor`), passando a ser
  padrão em todos os scripts da série (ver `templates/`).

### Alterado

- `Write-Log` agora grava só no arquivo — a tela é controlada pelo menu de
  passos, para manter o console limpo.
- Mensagem final recomenda reiniciar o **Sistema Operacional** (em vez de
  "o servidor"), já que o script pode rodar em qualquer Windows.
- Passos de DISM passaram a rodar via `Start-Process` com saída
  redirecionada para leitura de porcentagem, em vez de `Tee-Object`
  direto no console (causa da poluição de tela na versão anterior).
- Escopo de compatibilidade ampliado de "Windows Server 2016 ou superior"
  para "Windows 10/11 ou Windows Server 2016 ou superior": nenhum passo do
  script depende de recursos exclusivos de Server, então a declaração de
  requisitos (cabeçalho do script e README) passou a refletir isso.

## [1.0.1] - 2026-07-17

### Alterado

- Renomeado de `Optimize-WindowsServer.ps1` para `WindowsOptimizerCleanup.ps1`
  (padronização de nomenclatura da série de scripts de TI).
- Padronizado o cabeçalho do script e do README (autor, empresa, setor,
  versão, licença Expertise4All e links das plataformas da Expertise
  Tecnologia).

### Adicionado

- Arquivo `LICENSE` (Expertise4All).
- Templates reutilizáveis de README e de cabeçalho de script em `templates/`.

## [1.0.0] - 2026-07-16

### Adicionado

- Versão inicial do script de limpeza e otimização de Windows Server:
  limpeza de temporários, Lixeira e cache do Windows Update; limpeza de
  logs/caches secundários; `sfc /scannow`; e passos de `DISM`
  (`AnalyzeComponentStore`, `StartComponentCleanup`, `RestoreHealth`).
