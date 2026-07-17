<div align="center">

# 🧹 WindowsOptimizerCleanup

**Expertise Tecnologia** · Setor de TI / NOC

Script de limpeza e otimização de Windows (Server e Desktop) com boas práticas Microsoft.

[![Versão](https://img.shields.io/badge/vers%C3%A3o-1.1.0-blue)](./CHANGELOG.md)
[![Licença](https://img.shields.io/badge/licen%C3%A7a-Expertise4All-brightgreen)](./LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](#requisitos)

🌐 [Site](https://www.expertise.tec.br/) · 💼 [LinkedIn](https://www.linkedin.com/company/expertisetec/) · 📷 [Instagram](https://www.instagram.com/expertisetec) · 🐙 [GitHub](https://github.com/expertisetec)

</div>

---

| | |
|---|---|
| **Autor**   | Pablo Fernando Schütz |
| **Empresa** | Expertise Tecnologia |
| **Setor**   | TI / NOC |
| **Versão**  | 1.1.0 |
| **Licença** | [Expertise4All](./LICENSE) — uso público e liberado |

---

## O que o script faz (em ordem)

1. **Temporários** — limpa `%TEMP%`, `C:\Windows\Temp` e a pasta Temp de todos os perfis de usuário (útil em RDS).
2. **Cache de navegadores** — limpa o cache dos navegadores mais comuns (Internet Explorer, Google Chrome, Mozilla Firefox, Microsoft Edge e Opera) de todos os perfis de usuário. Favoritos, senhas e histórico não são afetados.
3. **Lixeira** — esvazia `C:\$Recycle.Bin` de todos os usuários.
4. **Cache do Windows Update** — para `wuauserv`/`bits`, limpa `SoftwareDistribution\Download` e reinicia os serviços.
5. **Logs e caches secundários** — WER (relatórios de erro), Prefetch e logs CBS com mais de 30 dias.
6. **`sfc /scannow`** — verifica e repara arquivos de sistema.
7. **`DISM /AnalyzeComponentStore`** — analisa o WinSxS.
8. **`DISM /StartComponentCleanup`** — remove componentes substituídos do WinSxS.
9. **`DISM /RestoreHealth`** — repara a imagem do Windows via Windows Update.

Todos os passos rodam com aprovação automática (sem prompts). Durante a execução, o console mostra
um menu fixo com o status de cada passo (e a porcentagem ao vivo nos passos de DISM) em vez de
despejar dezenas de linhas de progresso na tela. O log completo é sempre gravado em
`C:\Expertise\Logs\` e, ao final, o script pergunta se você deseja mantê-lo ou descartá-lo.

## Requisitos

- Windows 10/11 ou Windows Server 2016 ou superior (PowerShell 5.1+)
- Executar como **Administrador**
- Acesso ao Windows Update (ou WSUS) para o passo `RestoreHealth`

## Como executar

Localmente:

```powershell
powershell -ExecutionPolicy Bypass -File .\WindowsOptimizerCleanup.ps1
```

Direto do GitHub (uma linha, para o time de TI):

```powershell
irm https://raw.githubusercontent.com/expertisetec/windows-optimizer-cleanup/main/WindowsOptimizerCleanup.ps1 | iex
```


## Recomendações

- Execute em **janela de manutenção**: SFC e DISM podem levar de 15 a 60+ minutos e consomem CPU/disco.
- Reinicie o **Sistema Operacional** após a execução caso reparos tenham sido aplicados (o script roda em qualquer Windows, não apenas Server).
- Faça snapshot/backup antes da primeira execução em servidores críticos.
- A opção `DISM /ResetBase` está comentada no script: libera mais espaço, porém impede desinstalar updates já aplicados.

## Changelog

O histórico de versões fica em [CHANGELOG.md](CHANGELOG.md).

## Contribuindo

Quer propor uma mudança ou criar um novo script para a série? Veja
[CONTRIBUTING.md](CONTRIBUTING.md) — inclui o padrão de cabeçalho, a
convenção de versionamento (SemVer) e como registrar mudanças no changelog.

## Licença

Distribuído sob a licença **[Expertise4All](./LICENSE)** — pública e de uso liberado, resultado
dos trabalhos de melhoria contínua e aplicação de boas práticas da Expertise Tecnologia em
ambientes MSP.

## Expertise Tecnologia

Setor de TI / NOC.

🌐 [www.expertise.tec.br](https://www.expertise.tec.br/) · 💼 [LinkedIn](https://www.linkedin.com/company/expertisetec/) · 📷 [Instagram](https://www.instagram.com/expertisetec) · 🐙 [GitHub](https://github.com/expertisetec)
