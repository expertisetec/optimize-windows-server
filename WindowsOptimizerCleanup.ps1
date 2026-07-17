<#
===============================================================================
  EXPERTISE TECNOLOGIA
===============================================================================
  Script      : WindowsOptimizerCleanup.ps1
  Descricao   : Limpeza e otimizacao de Windows com aplicacao de boas
                praticas Microsoft (temporarios, cache de navegadores,
                Lixeira, cache do Windows Update, SFC e DISM), com log e
                relatorio de espaco.
  Setor       : Tecnologia da Informacao / NOC
  Autor       : Pablo Fernando Schutz
  Empresa     : Expertise Tecnologia
  Versao      : 1.2.0
  Data        : 17/07/2026
  Licenca     : Expertise4All - uso publico e liberado (ver arquivo LICENSE)
  Requisitos  : Windows 10/11 ou Windows Server 2016 ou superior | PowerShell 5.1+
                Executar como Administrador
  Uso         : powershell -ExecutionPolicy Bypass -File .\WindowsOptimizerCleanup.ps1
-------------------------------------------------------------------------------
  Site        : https://www.expertise.tec.br/
  LinkedIn    : https://www.linkedin.com/company/expertisetec/
  Instagram   : https://www.instagram.com/expertisetec
  GitHub      : https://github.com/expertisetec
===============================================================================
  HISTORICO DE VERSOES: ver CHANGELOG.md na raiz do repositorio.
===============================================================================
#>

#Requires -RunAsAdministrator

# -----------------------------------------------------------------------------
# CONFIGURACAO INICIAL E LOG
# -----------------------------------------------------------------------------
$ErrorActionPreference = 'Continue'
$ScriptVersion = '1.2.0'
$LogDir  = 'C:\Expertise\Logs'
$LogFile = Join-Path $LogDir ("WindowsOptimizerCleanup_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }

# $ScriptVersion (acima) e' a fonte de verdade em tempo de execucao. O campo
# "Versao" no cabecalho existe para leitura humana e precisa ser mantido
# igual manualmente. Quando executado como arquivo local (nao via irm | iex,
# onde nao ha arquivo para ler), avisa se os dois divergirem.
if ($PSCommandPath) {
    $headerMatch = Select-String -Path $PSCommandPath -Pattern 'Versao\s*:\s*(\S+)' | Select-Object -First 1
    if ($headerMatch -and $headerMatch.Matches[0].Groups[1].Value -ne $ScriptVersion) {
        Write-Warning "Versao do cabecalho ($($headerMatch.Matches[0].Groups[1].Value)) difere de `$ScriptVersion ($ScriptVersion). Corrija antes de publicar."
    }
}

# -----------------------------------------------------------------------------
# FUNCOES AUXILIARES
# -----------------------------------------------------------------------------

function Write-Log {
    <#  Grava apenas no arquivo de log (o console e' controlado pelo menu de
        passos em Show-StepMenu, para manter a tela limpa). #>
    param([string]$Message, [string]$Level = 'INFO')
    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $LogFile -Value $line
}

function Get-FreeSpaceGB {
    [math]::Round((Get-PSDrive -Name C).Free / 1GB, 2)
}

function Clear-Folder {
    <#  Remove o CONTEUDO de uma pasta de forma segura (a pasta em si e mantida).
        Arquivos em uso sao ignorados sem interromper o script. #>
    param([string]$Path, [string]$Description)
    if (Test-Path $Path) {
        Write-Log "Limpando: $Description ($Path)"
        Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Log "Pasta nao encontrada, ignorando: $Path" 'WARN'
    }
}

function Get-UserProfileFolders {
    Get-ChildItem -Path 'C:\Users' -Directory -ErrorAction SilentlyContinue
}

# --- Menu fixo de passos (evita poluir o console com dezenas de linhas) ------
# Obs: as chaves de $Steps/$StepStatus sao strings ('1', '2', ...) de proposito.
# Um [ordered]@{} com chaves inteiras e' indexado POSICIONALMENTE pelo
# PowerShell ($h[1] retorna o 2o item, nao o item de chave 1), o que quebraria
# a busca por chave usada abaixo.

$Steps = [ordered]@{
    '1' = 'Limpeza de temporarios'
    '2' = 'Cache de navegadores'
    '3' = 'Lixeira'
    '4' = 'Cache do Windows Update'
    '5' = 'Logs e caches secundarios'
    '6' = 'SFC /scannow'
    '7' = 'DISM - AnalyzeComponentStore'
    '8' = 'DISM - StartComponentCleanup'
    '9' = 'DISM - RestoreHealth'
}
$StepStatus = [ordered]@{}
foreach ($key in $Steps.Keys) { $StepStatus[$key] = 'Pendente' }

function Format-StepLine {
    param([string]$Label, [string]$Status)
    $width = 42
    $dots = if ($Label.Length -lt $width) { '.' * ($width - $Label.Length) } else { '..' }
    return "  $Label $dots $Status"
}

function Show-StepMenu {
    param(
        [string]$CurrentStep = '0',
        [string]$CurrentDetail = ''
    )
    Clear-Host
    Write-Host '===============================================================' -ForegroundColor Cyan
    Write-Host ' EXPERTISE TECNOLOGIA - WindowsOptimizerCleanup' -ForegroundColor Cyan
    Write-Host " Setor: Tecnologia da Informacao / NOC | Versao: $ScriptVersion" -ForegroundColor Cyan
    Write-Host " Computador: $env:COMPUTERNAME | Usuario: $env:USERNAME" -ForegroundColor Cyan
    Write-Host '===============================================================' -ForegroundColor Cyan
    foreach ($key in $Steps.Keys) {
        $status = $StepStatus[$key]
        $detail = if ($key -eq $CurrentStep) { $CurrentDetail } else { '' }
        $line = Format-StepLine -Label ("[{0}] {1}" -f $key, $Steps[$key]) -Status "$status$detail"
        switch -Regex ($status) {
            '^OK$'            { Write-Host $line -ForegroundColor Green }
            '^ALERTA$'        { Write-Host $line -ForegroundColor Yellow }
            '^FALHA$'         { Write-Host $line -ForegroundColor Red }
            '^Executando'     { Write-Host $line -ForegroundColor Yellow }
            default           { Write-Host $line -ForegroundColor DarkGray }
        }
    }
    Write-Host '===============================================================' -ForegroundColor Cyan
    Write-Host " Log: $LogFile" -ForegroundColor DarkGray
    Write-Host ''
}

function Invoke-Step {
    <#  Executa um passo, atualizando o menu antes/depois. O scriptblock pode
        ajustar $StepStatus[$StepKey] para 'ALERTA' (ex: exit code != 0) sem
        que isso seja tratado como falha do script. #>
    param(
        [Parameter(Mandatory)] [string]$StepKey,
        [Parameter(Mandatory)] [scriptblock]$Action
    )
    $StepStatus[$StepKey] = 'Executando...'
    Show-StepMenu -CurrentStep $StepKey
    try {
        & $Action
        if ($StepStatus[$StepKey] -eq 'Executando...') { $StepStatus[$StepKey] = 'OK' }
    } catch {
        Write-Log "Passo $StepKey ($($Steps[$StepKey])) falhou: $($_.Exception.Message)" 'ERRO'
        $StepStatus[$StepKey] = 'FALHA'
    }
    Show-StepMenu -CurrentStep $StepKey
}

function Invoke-DismStep {
    <#  Roda o DISM redirecionando a saida para um arquivo temporario e le a
        ultima porcentagem reportada, atualizando o menu fixo em vez de
        imprimir uma linha nova no console a cada atualizacao (comportamento
        padrao do DISM quando a saida e' redirecionada/tee'ada). #>
    param(
        [Parameter(Mandatory)] [string]$StepKey,
        [Parameter(Mandatory)] [string[]]$ArgumentList
    )
    $tmpOut = [System.IO.Path]::GetTempFileName()
    $lastPercent = $null
    $exitCode = -1
    try {
        $proc = Start-Process -FilePath 'dism.exe' -ArgumentList $ArgumentList -NoNewWindow -PassThru -RedirectStandardOutput $tmpOut
        while (-not $proc.HasExited) {
            Start-Sleep -Milliseconds 400
            $raw = Get-Content -Path $tmpOut -Raw -ErrorAction SilentlyContinue
            if ($raw) {
                $percentMatches = [regex]::Matches($raw, '(\d{1,3}[.,]\d)\s*%')
                if ($percentMatches.Count -gt 0) {
                    $percent = $percentMatches[$percentMatches.Count - 1].Groups[1].Value
                    if ($percent -ne $lastPercent) {
                        $lastPercent = $percent
                        Show-StepMenu -CurrentStep $StepKey -CurrentDetail " ($percent%)"
                    }
                }
            }
        }
        $proc.WaitForExit()
        $exitCode = $proc.ExitCode
    } finally {
        if (Test-Path $tmpOut) {
            $rawOut = Get-Content -Path $tmpOut -Raw -ErrorAction SilentlyContinue
            if ($rawOut) { Add-Content -Path $LogFile -Value $rawOut }
            Remove-Item -Path $tmpOut -Force -ErrorAction SilentlyContinue
        }
    }
    return $exitCode
}

# --- Cache de navegadores (por perfil de usuario) ----------------------------

$BrowserCachePatterns = @(
    @{ Browser = 'Internet Explorer'; RelativePath = 'AppData\Local\Microsoft\Windows\INetCache' }
    @{ Browser = 'Internet Explorer'; RelativePath = 'AppData\Local\Microsoft\Windows\WebCache' }
    @{ Browser = 'Google Chrome';     RelativePath = 'AppData\Local\Google\Chrome\User Data\Default\Cache' }
    @{ Browser = 'Google Chrome';     RelativePath = 'AppData\Local\Google\Chrome\User Data\Default\Code Cache' }
    @{ Browser = 'Google Chrome';     RelativePath = 'AppData\Local\Google\Chrome\User Data\Profile *\Cache' }
    @{ Browser = 'Mozilla Firefox';   RelativePath = 'AppData\Local\Mozilla\Firefox\Profiles\*\cache2' }
    @{ Browser = 'Microsoft Edge';    RelativePath = 'AppData\Local\Microsoft\Edge\User Data\Default\Cache' }
    @{ Browser = 'Microsoft Edge';    RelativePath = 'AppData\Local\Microsoft\Edge\User Data\Default\Code Cache' }
    @{ Browser = 'Microsoft Edge';    RelativePath = 'AppData\Local\Microsoft\Edge\User Data\Profile *\Cache' }
    @{ Browser = 'Opera';             RelativePath = 'AppData\Local\Opera Software\Opera Stable\Cache' }
    @{ Browser = 'Opera';             RelativePath = 'AppData\Local\Opera Software\Opera Stable\Code Cache' }
)

function Clear-BrowserCaches {
    param([string]$ProfilePath, [string]$UserName)
    foreach ($item in $BrowserCachePatterns) {
        $pattern = Join-Path $ProfilePath $item.RelativePath
        Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Clear-Folder -Path $_.FullName -Description "Cache do $($item.Browser) ($UserName)"
        }
    }
}

function Test-SfcMadeRepairs {
    <#  Verifica no CBS.log se o SFC reparou algum arquivo desde $Since.
        Usa as tags internas "[SR]" do CBS.log (fixas em ingles, nao
        localizadas) em vez do texto que o sfc.exe imprime no console
        (esse sim varia conforme o idioma do Windows). Retorna $true
        (reparou), $false (nao reparou) ou $null (nao foi possivel
        confirmar - CBS.log ausente/ilegivel ou fora da janela lida). #>
    param([datetime]$Since)
    $cbsLog = 'C:\Windows\Logs\CBS\CBS.log'
    if (-not (Test-Path $cbsLog)) { return $null }
    try {
        $lines = Get-Content -Path $cbsLog -Tail 50000 -ErrorAction Stop | Where-Object { $_ -match '\[SR\]' }
    } catch {
        return $null
    }
    $found = $false
    foreach ($line in $lines) {
        if ($line.Length -lt 19) { continue }
        $ts = [datetime]::MinValue
        $parsed = [datetime]::TryParseExact(
            $line.Substring(0, 19), 'yyyy-MM-dd HH:mm:ss', $null,
            [System.Globalization.DateTimeStyles]::None, [ref]$ts)
        if ($parsed -and $ts -ge $Since -and ($line -match 'Repairing corrupted file' -or $line -match 'Cannot repair member file')) {
            $found = $true
        }
    }
    return $found
}

# -----------------------------------------------------------------------------
# INICIO DA EXECUCAO
# -----------------------------------------------------------------------------
Write-Log '==============================================================='
Write-Log ' EXPERTISE TECNOLOGIA - Limpeza e Otimizacao de Windows'
Write-Log " Setor: Tecnologia da Informacao / NOC | Autor: Pablo Fernando Schutz | Versao: $ScriptVersion"
Write-Log '==============================================================='
Write-Log "Computador: $env:COMPUTERNAME | Usuario: $env:USERNAME"
Write-Log "Log salvo em: $LogFile"

$FreeBefore = Get-FreeSpaceGB
Write-Log "Espaco livre em C: ANTES da limpeza: $FreeBefore GB"
$SfcRepairResult = $null

Show-StepMenu -CurrentStep '0'

# -----------------------------------------------------------------------------
# PASSO 1 - LIMPEZA DE ARQUIVOS TEMPORARIOS
# Descricao: Remove os arquivos temporarios do usuario atual (%TEMP%),
# de todos os perfis de usuario e do sistema operacional (C:\Windows\Temp).
# Equivalente a: del /q /f /s %TEMP%\*  e  del /q /f /s C:\Windows\Temp\*
#
# Boas praticas / recomendacoes:
# - Rode em janela de manutencao ou fora do horario de pico: em servidores
#   RDS/Terminal Server, usuarios com sessao ativa podem estar usando
#   arquivos dentro do proprio %TEMP%.
# - Arquivos bloqueados (em uso por processos ativos) sao ignorados
#   automaticamente (-ErrorAction SilentlyContinue) e nao interrompem o
#   script - por isso e' normal o espaco recuperado variar entre execucoes.
# - O %TEMP% do processo reflete apenas o perfil que executa o script
#   (normalmente Administrador/SYSTEM); por isso iteramos manualmente por
#   todos os perfis em C:\Users, essencial em servidores multiusuario.
# - Evite rodar durante instalacoes/atualizacoes em andamento (Windows
#   Update, instaladores MSI) para nao remover um temporario em uso por um
#   processo em curso.
# -----------------------------------------------------------------------------
Invoke-Step -StepKey '1' -Action {
    Clear-Folder -Path $env:TEMP -Description 'Temporarios do usuario atual (%TEMP%)'
    Clear-Folder -Path 'C:\Windows\Temp' -Description 'Temporarios do sistema (C:\Windows\Temp)'
    foreach ($profileFolder in (Get-UserProfileFolders)) {
        $userTemp = Join-Path $profileFolder.FullName 'AppData\Local\Temp'
        if (Test-Path $userTemp) {
            Clear-Folder -Path $userTemp -Description "Temporarios do perfil $($profileFolder.Name)"
        }
    }
}

# -----------------------------------------------------------------------------
# PASSO 2 - CACHE DE NAVEGADORES
# Descricao: Remove o cache de disco dos navegadores mais comuns (Internet
# Explorer, Google Chrome, Mozilla Firefox, Microsoft Edge e Opera) de todos
# os perfis de usuario em C:\Users. Favoritos, senhas e historico nao sao
# afetados - apenas as pastas de cache/Code Cache de cada navegador.
# -----------------------------------------------------------------------------
Invoke-Step -StepKey '2' -Action {
    foreach ($profileFolder in (Get-UserProfileFolders)) {
        Clear-BrowserCaches -ProfilePath $profileFolder.FullName -UserName $profileFolder.Name
    }
}

# -----------------------------------------------------------------------------
# PASSO 3 - ESVAZIAR A LIXEIRA DE TODOS OS USUARIOS
# Descricao: Remove o conteudo de C:\$Recycle.Bin (Lixeira) de todas as
# unidades. Equivalente a: rd /s /q C:\$Recycle.bin
# -----------------------------------------------------------------------------
Invoke-Step -StepKey '3' -Action {
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Log 'Lixeira esvaziada com sucesso.'
    } catch {
        Write-Log "Clear-RecycleBin indisponivel, usando metodo alternativo: $($_.Exception.Message)" 'WARN'
        Remove-Item 'C:\$Recycle.Bin\*' -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# -----------------------------------------------------------------------------
# PASSO 4 - LIMPEZA DO CACHE DO WINDOWS UPDATE
# Descricao: Para os servicos de update, limpa C:\Windows\SoftwareDistribution
# \Download (pacotes de update ja instalados/baixados) e reinicia os servicos.
# Boa pratica Microsoft para recuperar espaco e corrigir updates corrompidos.
# -----------------------------------------------------------------------------
Invoke-Step -StepKey '4' -Action {
    $updateServices = 'wuauserv', 'bits'
    foreach ($svc in $updateServices) { Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue; Write-Log "Servico parado: $svc" }
    Clear-Folder -Path 'C:\Windows\SoftwareDistribution\Download' -Description 'Cache de download do Windows Update'
    foreach ($svc in $updateServices) { Start-Service -Name $svc -ErrorAction SilentlyContinue; Write-Log "Servico iniciado: $svc" }
}

# -----------------------------------------------------------------------------
# PASSO 5 - LIMPEZA DE LOGS E CACHES SECUNDARIOS
# Descricao: Remove relatorios de erro do Windows (WER), arquivos Prefetch
# e logs CBS antigos (>30 dias), que podem crescer muito em servidores.
# -----------------------------------------------------------------------------
Invoke-Step -StepKey '5' -Action {
    Clear-Folder -Path 'C:\ProgramData\Microsoft\Windows\WER\ReportQueue'   -Description 'Relatorios de erro (WER - fila)'
    Clear-Folder -Path 'C:\ProgramData\Microsoft\Windows\WER\ReportArchive' -Description 'Relatorios de erro (WER - arquivo)'
    Clear-Folder -Path 'C:\Windows\Prefetch' -Description 'Arquivos Prefetch'

    Write-Log 'Removendo logs CBS com mais de 30 dias...'
    Get-ChildItem 'C:\Windows\Logs\CBS' -Filter '*.log' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

# -----------------------------------------------------------------------------
# PASSO 6 - SFC /SCANNOW
# Descricao: O System File Checker verifica a integridade de todos os
# arquivos protegidos do sistema e repara automaticamente os corrompidos
# usando o repositorio local (WinSxS). Ao final, $SfcRepairResult guarda se
# houve reparo de fato (ver Test-SfcMadeRepairs), usado no relatorio final
# para so recomendar reinicializacao quando fizer sentido.
# -----------------------------------------------------------------------------
Invoke-Step -StepKey '6' -Action {
    Write-Log 'Executando SFC /scannow...'
    $sfcStart = Get-Date
    $sfc = Start-Process -FilePath 'sfc.exe' -ArgumentList '/scannow' -Wait -PassThru -NoNewWindow
    Write-Log "SFC finalizado. Codigo de saida: $($sfc.ExitCode)"
    if ($sfc.ExitCode -ne 0) { $StepStatus['6'] = 'ALERTA' }

    $script:SfcRepairResult = Test-SfcMadeRepairs -Since $sfcStart
    switch ($script:SfcRepairResult) {
        $true   { Write-Log 'SFC reparou arquivos (detectado via CBS.log).' }
        $false  { Write-Log 'SFC nao encontrou/reparou arquivos (confirmado via CBS.log).' }
        default { Write-Log 'Nao foi possivel confirmar reparo do SFC via CBS.log.' 'WARN' }
    }
}

# -----------------------------------------------------------------------------
# PASSO 7 - DISM /AnalyzeComponentStore
# Descricao: Analisa o repositorio de componentes (WinSxS) e informa se a
# limpeza e recomendada e quanto espaco pode ser recuperado.
# -----------------------------------------------------------------------------
Invoke-Step -StepKey '7' -Action {
    $exit = Invoke-DismStep -StepKey '7' -ArgumentList '/Online', '/Cleanup-Image', '/AnalyzeComponentStore'
    Write-Log "DISM AnalyzeComponentStore finalizado. Codigo de saida: $exit"
    if ($exit -ne 0) { $StepStatus['7'] = 'ALERTA' }
}

# -----------------------------------------------------------------------------
# PASSO 8 - DISM /StartComponentCleanup
# Descricao: Remove versoes antigas e substituidas de componentes do WinSxS,
# reduzindo o tamanho da pasta. Boa pratica Microsoft de manutencao.
# Obs: NAO usamos /ResetBase por padrao, pois ele impede a desinstalacao
# de updates ja instalados (descomente abaixo se desejar ganho maximo).
# -----------------------------------------------------------------------------
Invoke-Step -StepKey '8' -Action {
    $exit = Invoke-DismStep -StepKey '8' -ArgumentList '/Online', '/Cleanup-Image', '/StartComponentCleanup'
    # $exit = Invoke-DismStep -StepKey '8' -ArgumentList '/Online','/Cleanup-Image','/StartComponentCleanup','/ResetBase'  # <- opcional, ganho maximo, irreversivel
    Write-Log "DISM StartComponentCleanup finalizado. Codigo de saida: $exit"
    if ($exit -ne 0) { $StepStatus['8'] = 'ALERTA' }
}

# -----------------------------------------------------------------------------
# PASSO 9 - DISM /RestoreHealth
# Descricao: Verifica e repara corrupcoes na imagem do Windows usando o
# Windows Update como fonte. Complementa o SFC (repara o proprio repositorio
# que o SFC usa). Requer acesso ao Windows Update ou fonte WSUS/ISO.
# -----------------------------------------------------------------------------
Invoke-Step -StepKey '9' -Action {
    $exit = Invoke-DismStep -StepKey '9' -ArgumentList '/Online', '/Cleanup-Image', '/RestoreHealth'
    Write-Log "DISM RestoreHealth finalizado. Codigo de saida: $exit"
    if ($exit -ne 0) { $StepStatus['9'] = 'ALERTA' }
}

# -----------------------------------------------------------------------------
# RELATORIO FINAL
# -----------------------------------------------------------------------------
$FreeAfter = Get-FreeSpaceGB
$Recovered = [math]::Round($FreeAfter - $FreeBefore, 2)

Write-Log '==============================================================='
Write-Log ' RELATORIO FINAL'
Write-Log "  Espaco livre ANTES : $FreeBefore GB"
Write-Log "  Espaco livre DEPOIS: $FreeAfter GB"
Write-Log "  Espaco recuperado  : $Recovered GB"
Write-Log "  Log completo       : $LogFile"
Write-Log '==============================================================='

# Tela final: limpa o console e mostra SO o resumo (nao reexibe o menu de
# passos com numeracao/caixa - isso duplicaria a mesma informacao).
Clear-Host
Write-Host '===============================================================' -ForegroundColor Cyan
Write-Host ' EXPERTISE TECNOLOGIA - WindowsOptimizerCleanup' -ForegroundColor Cyan
Write-Host " Versao: $ScriptVersion | Computador: $env:COMPUTERNAME" -ForegroundColor Cyan
Write-Host '===============================================================' -ForegroundColor Cyan
Write-Host ''

Write-Host 'Resumo da execucao:' -ForegroundColor Cyan
foreach ($key in $Steps.Keys) {
    $status = $StepStatus[$key]
    $color = switch ($status) {
        'OK'     { 'Green' }
        'ALERTA' { 'Yellow' }
        'FALHA'  { 'Red' }
        default  { 'DarkGray' }
    }
    Write-Host (Format-StepLine -Label $Steps[$key] -Status $status) -ForegroundColor $color
}
Write-Host ''

Write-Host 'Relatorio final:' -ForegroundColor Cyan
Write-Host ("  Espaco livre ANTES  : {0} GB" -f $FreeBefore)
Write-Host ("  Espaco livre DEPOIS : {0} GB" -f $FreeAfter)
Write-Host ("  Espaco recuperado   : {0} GB" -f $Recovered)
Write-Host ''

# Reinicializacao: so recomendamos de fato quando o SFC comprovadamente
# reparou algo. Quando nao da' para confirmar (CBS.log ausente/ilegivel),
# erramos para o lado seguro e recomendamos mesmo assim.
if ($SfcRepairResult -eq $false) {
    Write-Host 'SFC nao encontrou nem reparou arquivos de sistema - reinicializacao' -ForegroundColor Green
    Write-Host 'nao e necessaria por causa do SFC.' -ForegroundColor Green
} elseif ($SfcRepairResult -eq $true) {
    Write-Host 'SFC reparou arquivos de sistema - recomenda-se reiniciar o Sistema' -ForegroundColor Yellow
    Write-Host 'Operacional em janela de manutencao.' -ForegroundColor Yellow
} else {
    Write-Host 'Nao foi possivel confirmar pelo CBS.log se o SFC reparou arquivos -' -ForegroundColor Yellow
    Write-Host 'por seguranca, recomenda-se reiniciar o Sistema Operacional em' -ForegroundColor Yellow
    Write-Host 'janela de manutencao e revisar o log.' -ForegroundColor Yellow
}
Write-Host ''
Write-Host 'Concluido.' -ForegroundColor Cyan
Write-Host ''

# -----------------------------------------------------------------------------
# DESTINO DO LOG
# -----------------------------------------------------------------------------
if ([Environment]::UserInteractive) {
    $resposta = Read-Host "Deseja manter o log salvo em '$LogFile'? (S/N)"
    if ($resposta -match '^(n|nao|não)$') {
        Remove-Item -Path $LogFile -Force -ErrorAction SilentlyContinue
        Write-Host 'Log descartado.' -ForegroundColor DarkGray
    } else {
        Write-Host "Log mantido em: $LogFile" -ForegroundColor DarkGray
    }
} else {
    Write-Host "Execucao nao-interativa detectada. Log mantido em: $LogFile" -ForegroundColor DarkGray
}
