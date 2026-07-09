# ⚡ Samack WinUtil

> **Desenvolvido por Felipe Samack**
> 📸 Instagram: [@felipe.samack](https://www.instagram.com/felipe.samack/) | 💻 GitHub: [rgis-samack/win-samack](https://github.com/rgis-samack/win-samack)
> 🎁 **Ajude a manter o projeto vivo! Faça uma doação via PIX clicando no botão "Doação" dentro do aplicativo ou escaneando o QR Code na barra de status.**

---

## 🇧🇷 Português

O **Samack WinUtil** é uma suíte completa e portátil de otimização, debloat e gerenciamento do sistema Windows. Desenvolvido nativamente em **PowerShell** com uma interface moderna e responsiva construída em **WPF (Windows Presentation Foundation)**, o utilitário permite fazer limpezas profundas, desinstalações limpas de softwares, diagnósticos de rede e ativações seguras de forma prática e rápida.

---

### 🚀 Como Executar Online (Sem Baixar Arquivos)

Abra o seu PowerShell como **Administrador** e execute o seguinte comando:

```powershell
irm https://raw.githubusercontent.com/rgis-samack/win-samack/refs/heads/main/win-samack.ps1 | iex
```

Ou através do link encurtado oficial:

```powershell
irm https://bit.ly/win-samack | iex
```

> 💡 **Nota de Compatibilidade:** O carregador em código ASCII puro contorna erros de codificação de caracteres em qualquer versão do Windows, puxando o script em codificação UTF-8 com BOM direto da memória.

---

### 📋 Guia Detalhado de Funcionalidades

#### 💻 1. Painel Principal (Dashboard)
* **Monitoramento em Tempo Real:** Acompanhe gráficos simples de consumo do processador (CPU), uso de memória RAM (tanto em porcentagem quanto em GB consumidos) e tempo de atividade do sistema (Uptime).
* **Limpeza Rápida de Memória RAM:** Libera os conjuntos de trabalho (Working Sets) de todos os processos em segundo plano, liberando imediatamente espaço na RAM física sem fechar os seus aplicativos abertos.
* **Processos de Alto Consumo:** Lista em tempo real os processos que mais estão consumindo CPU e Memória RAM no momento, permitindo que você identifique rapidamente gargalos de desempenho.

#### 🧹 2. Debloat (Remoção de Aplicativos Nativos)
* **Desinstalação de Bloatware:** Remova aplicativos nativos do Windows que vêm pré-instalados de fábrica e que raramente são usados, como Cortana, Bing Weather, Xbox App, OneDrive, e outros utilitários redundantes.
* **Desativação de Telemetria:** Desativa serviços e chaves de registro responsáveis por coletar e enviar dados de diagnóstico para a Microsoft, melhorando a privacidade do usuário e reduzindo o tráfego de rede em segundo plano.
* **Otimização de Serviços:** Desativa serviços secundários desnecessários que iniciam junto com o Windows para acelerar a inicialização do sistema.

#### 🎮 3. Desempenho & Jogos (Tweaks)
* **Plano de Energia de Alto Desempenho:** Habilita e ativa o perfil de energia "Desempenho Máximo" (Ultimate Performance) oculto do Windows para garantir que o processador trabalhe sem limitações.
* **Otimização de Latência (Input Lag):** Aplica ajustes de registro no subsistema do mouse e do teclado para reduzir o atraso de resposta física nos comandos.
* **Desativação do Xbox Game Bar & DVR:** Desativa recursos nativos de gravação de tela em segundo plano que consomem muitos recursos de GPU e CPU durante os jogos.
* **Agendamento de GPU (HAGS):** Ativa ou otimiza o Agendamento de GPU Acelerado por Hardware nas chaves de registro do Windows para placas de vídeo compatíveis.

#### 🧹 4. Limpeza de Disco (Disk Cleanup)
* **Remoção de Arquivos Temporários:** Varre e exclui pastas temporárias do usuário (`%temp%`) e do sistema (`C:\Windows\Temp`).
* **Limpeza do Windows Update:** Limpa a pasta `SoftwareDistribution` (cache de atualizações antigas), o que costuma liberar vários gigabytes de espaço em disco após grandes atualizações do sistema.
* **Cache do Sistema:** Apaga arquivos de cache antigos (Prefetch, Log files, Error reports, Memory dumps) que ficam acumulados no disco rígido sem utilidade.

#### 📥 5. Instalar Apps (Central de Downloads)
* **Instalação Silenciosa e Automatizada:** Interface gráfica intuitiva integrada ao gerenciador de pacotes oficial do Windows (WinGet) que permite selecionar e instalar dezenas de aplicativos populares (como Chrome, Firefox, VSCode, VLC, Discord, Steam) de forma totalmente automatizada e sem telas de instaladores chatos.

#### 🗑️ 6. Desinstalar Apps (Desinstalador Avançado)
* **Varredura Completa de Registro:** Detecta todos os softwares instalados em nível de usuário e máquina (32-bit e 64-bit).
* **Filtro em Tempo Real:** Caixa de busca rápida para localizar softwares pelo nome instantaneamente.
* **Limpeza Profunda:** Diferente do desinstalador padrão do Windows, esta ferramenta remove pastas órfãs nas pastas `AppData` e limpa chaves redundantes remanescentes no registro.

#### 🌐 7. Ferramentas de Rede
* **Configurações de IP (IPConfig):** Exibe as informações completas de IP, gateway e máscara de todos os adaptadores de rede.
* **Ping e Tracert (Assíncronos):** Teste a latência e trace a rota de conexões em tempo real. O processo roda de forma independente, permitindo que a interface do aplicativo continue fluida e responsiva sem congelar a tela.
* **Portas Abertas (Netstat):** Exibe todas as portas ativas no momento, conexões de IP estabelecidas e os IDs de processos (PIDs) que as estão utilizando.
* **Limpar Cache DNS (Flush DNS):** Redefine o cache DNS do sistema para corrigir falhas ao carregar páginas.
* **Reset de Rede:** Restaura completamente as tabelas de roteamento IP e reinicializa a pilha Winsock para os valores padrão de fábrica.

#### 🔑 8. Ativação de Licenças (MAS)
* **Microsoft Activation Scripts (MAS):** Executa de forma segura e interativa o ativador oficial MAS em um terminal externo.
* ** HWID:** Ativa permanentemente o Windows 10 e Windows 11 com licenças digitais gratuitas vinculadas à placa-mãe.
* **Ohook:** Ativa de forma definitiva todas as versões instaladas localmente do Microsoft Office.

#### 📦 9. Downloads do Office
* **Downloads Diretos Oficiais:** Baixe as imagens originais de instalação do **Microsoft Office 2019** e **Microsoft Office 2021** diretamente dos servidores da Microsoft.
* **Links Espelho Alternativos:** Botões integrados com os encurtadores TinyURL, Bitly e Abre.ai para garantir que você sempre consiga baixar os instaladores mesmo que um dos links caia.

#### 📜 10. Logs de Execução
* **Auditoria de Ações:** Registra cada clique e comando executado com carimbo de data/hora, exibindo logs formatados com cores (INFO, SUCCESS, WARNING, ERROR) para que você saiba exatamente o que foi alterado.

---

## 🇺🇸 English

**Samack WinUtil** is a comprehensive, portable optimization, debloat, and management tool for Windows operating systems. Natively built in **PowerShell** with a modern, responsive **WPF (Windows Presentation Foundation)** user interface, it allows users to perform deep disk cleanups, clean software uninstalls, network diagnostics, and secure OS/Office activations quickly and safely.

---

### 🚀 How to Run Online (Without Downloading Files)

Open your PowerShell as **Administrator** and run the following command:

```powershell
irm https://raw.githubusercontent.com/rgis-samack/win-samack/refs/heads/main/win-samack.ps1 | iex
```

Or through the official shortlink:

```powershell
irm https://bit.ly/win-samack | iex
```

---

### 📋 Detailed Feature Guide

#### 💻 1. Main Dashboard
* **Real-time Monitoring:** Keep track of CPU usage percentage, RAM consumption (both in percentage and GB used), and system Uptime.
* **Quick RAM Cleaner:** Releases working sets of background processes, immediately freeing up physical memory without closing active applications.
* **High-Consumption Processes:** Lists the most resource-intensive processes currently running, helping you quickly identify performance bottlenecks.

#### 🧹 2. Debloat (Built-in App Removal)
* **Bloatware Uninstaller:** Cleanly remove pre-installed Windows apps that are rarely used (e.g., Cortana, Xbox App, OneDrive, Bing Weather).
* **Disable Telemetry:** Turns off telemetry and diagnostic services to improve user privacy and save network bandwidth in the background.
* **Service Optimizer:** Disables unnecessary background services to accelerate Windows startup times.

#### 🎮 3. Performance & Gaming (Tweaks)
* **Ultimate Performance Power Plan:** Enables the hidden Ultimate Performance power plan to ensure your hardware runs at peak capacity.
* **Latency Reduction (Input Lag):** Applies registry tweaks to keyboard and mouse drivers to lower response latency.
* **Disable Xbox Game Bar & DVR:** Prevents background screen recording from capturing system resources while gaming.
* **Hardware-Accelerated GPU Scheduling (HAGS):** Configures and enables HAGS in the registry for compatible GPUs.

#### 🧹 4. Disk Cleanup
* **Temp File Cleaner:** Cleans user temporary directories (`%temp%`) and system temp folders (`C:\Windows\Temp`).
* **Windows Update Cleanup:** Clears the `SoftwareDistribution` cache to recover gigabytes of storage after major Windows updates.
* **System Cache Removal:** Wipes useless log files, error reports, system dumps, and prefetch files.

#### 📥 5. Install Apps (Batch Downloader)
* **Silent & Automated Installation:** A clean UI wrapper around Windows Package Manager (WinGet), enabling you to install dozens of popular tools (Chrome, Firefox, VSCode, Discord, VLC, Steam) simultaneously without installer prompts.

#### 🗑️ 6. Uninstall Apps (Advanced Uninstaller)
* **Registry Deep Scan:** Scans user and machine uninstall keys (for both 32-bit and 64-bit programs).
* **Real-time Search:** A responsive filter to find apps instantly.
* **Leftover Cleanup:** Searches for and removes orphaned `AppData` files and residual registry keys left behind by native uninstallers.

#### 🌐 7. Network Tools
* **IP Configuration (IPConfig):** Displays detailed adapter network configurations.
* **Asynchronous Ping & Tracert:** Runs ping tests and route traces dynamically. Because the tasks are run asynchronously, the UI remains perfectly fluid and never freezes.
* **Open Ports (Netstat):** Lists active TCP/UDP ports, established connections, and their corresponding process IDs (PIDs).
* **Flush DNS:** Flushes the system resolver cache to fix connection issues.
* **Network Reset:** Restores TCP/IP and Winsock configurations back to original factory defaults.

#### 🔑 8. License Activation (MAS)
* **Microsoft Activation Scripts:** Launches the official open-source MAS tool safely in an external console.
* **HWID:** Permanently activates Windows 10/11 using motherboard-tied digital licenses.
* **Ohook:** Permanently activates local Microsoft Office installations.

#### 📦 9. Office Downloads
* **Official Downloads:** Download untouched setups of **Microsoft Office 2019** and **Microsoft Office 2021** directly from Microsoft CDN servers.
* **Alternative Mirror Links:** Quick buttons utilizing TinyURL, Bitly, and Abre.ai shortlinks to guarantee download availability.

#### 📜 10. Execution Logs
* **System Auditing:** Records actions with exact timestamps, categorizing logs with colors (INFO, SUCCESS, WARNING, ERROR) so you can review exactly what adjustments were made.

---

## 🎁 Support the Project

If this tool helped you save time or speed up your PC, consider supporting its development with a donation!

* **Donation Key (NuBank):** Click the **Donation** button inside the app to load the payment page, or scan the QR Code shown on the status bar.
* **NuBank Direct Payment Link:** [Make a Donation via NuBank](https://nubank.com.br/cobrar/jdnam/6a449332-0732-43dc-9cfe-946bd2eee5fa)
