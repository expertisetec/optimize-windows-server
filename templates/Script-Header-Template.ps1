<#
===============================================================================
  EXPERTISE TECNOLOGIA
===============================================================================
  Script      : {{NomeDoScript}}.ps1
  Descricao   : {{Descricao objetiva do que o script faz, em uma ou duas
                linhas.}}
  Setor       : Tecnologia da Informacao / NOC
  Autor       : {{Nome do Autor}}
  Empresa     : Expertise Tecnologia
  Versao      : {{X.Y.Z}}
  Data        : {{DD/MM/AAAA}}
  Licenca     : Expertise4All - uso publico e liberado (ver arquivo LICENSE)
  Requisitos  : {{ex: Windows Server 2016 ou superior | PowerShell 5.1+}}
                {{ex: Executar como Administrador}}
  Uso         : powershell -ExecutionPolicy Bypass -File .\{{NomeDoScript}}.ps1
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
$ScriptVersion = '{{X.Y.Z}}'

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
