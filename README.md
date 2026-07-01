# ⚡ Samack WinUtil Optimizer

[**Português**](#-português) | [**English**](#-english)

---

## 🇧🇷 Português

O **Samack WinUtil** é uma suíte completa de otimização e gerenciamento do sistema Windows. Desenvolvido nativamente em **PowerShell** com uma interface moderna e responsiva construída em **WPF (Windows Presentation Foundation)**, o utilitário permite fazer limpezas profundas, desinstalações avançadas, diagnósticos de rede, ajustes de privacidade (debloat) e otimizações de performance para jogos em computadores com **Windows 7, 8, 8.1, 10 e 11**.

---

### 🚀 Como Executar Online (Sem Baixar Arquivos)

Abra o seu PowerShell como **Administrador** e execute o seguinte comando:

```powershell
irm https://raw.githubusercontent.com/rgis-samack/win-samack/refs/heads/main/win-samack.ps1 | iex
```

> 💡 **Nota de Compatibilidade:** O link acima utiliza um carregador especial em código ASCII puro que contorna erros de codificação de caracteres em qualquer versão do Windows, puxando o script em codificação UTF-8 pura direto da memória.

---

### 🌟 Funcionalidades Detalhadas

#### 1. 🖥️ Painel Principal (Dashboard)
* **Monitoramento em Tempo Real:** Acompanhamento dinâmico do uso de CPU (%), uso de RAM (%) e Tempo de Atividade do Sistema (Uptime).
* **Processos de Alto Consumo:** Monitor que exibe os **7 processos mais pesados** em uso de memória RAM ativa e tempo de CPU acumulado em tempo real, atualizando a cada 5 segundos de forma silenciosa.
* **Limpeza Rápida de RAM:** Libera memória RAM imediatamente limpando o conjunto de trabalho (working set) de processos inativos e serviços em segundo plano.
* **Ponto de Restauração:** Atalho rápido para criar um Ponto de Restauração do sistema antes de aplicar otimizações avançadas.
* **16 Atalhos Rápidos de Sistema/Rede:**
  * **🎛️ Disp. Manager:** Gerenciador de Dispositivos clássico.
  * **🔑 Registry:** Editor do Registro do Windows (`regedit`).
  * **💾 Discos:** Gerenciamento de Disco (`diskmgmt.msc`).
  * **👤 Contas Usuário:** Painel clássico de contas locais de usuário.
  * **🔋 Opções Energia:** Configurações clássicas do plano de energia.
  * **💻 Prop. Sistema:** Propriedades avançadas do sistema (`sysdm.cpl`).
  * **⚙️ Serviços:** Gerenciador de Serviços do Windows (`services.msc`).
  * **🌐 Central Rede:** Central de Rede e Compartilhamento clássica.
  * **📈 Monitor Rec.:** Monitor de Recursos completo do Windows (`resmon.exe`).
  * **📊 Ger. de Tarefas:** Gerenciador de Tarefas nativo.
  * **🖥️ Painel Controle:** Painel de Controle geral do Windows.
  * **🏓 Ping Google:** Teste rápido de ping para o DNS do Google (`8.8.8.8`).
  * **📡 Mostrar IPs:** Atalho para consultar adaptadores de rede.
  * **🧹 Limpar Cache DNS:** Flush DNS instantâneo no sistema.
  * **🔌 Conexões de Rede:** Adaptadores de rede (`ncpa.cpl`).

#### 2. 🛡️ Debloat (Apenas Windows 10/11)
* **Remoção de Bloatwares:** Desinstalação limpa e em lote de apps pré-instalados inúteis da Microsoft (Xbox, Cortana, Skype, OneDrive, Bing, Mapas, etc.).
* **Recursos Opcionais do Windows:** Habilite ou desabilite recursos avançados nativos via DISM (WSL - Subsistema Windows para Linux, Windows Sandbox, Hyper-V e SMBv1).

#### 3. ⚙️ Desempenho & Jogos
* **Otimização Geral:** Ajustes na fila do processador para melhorar a resposta geral do Windows.
* **Melhorias de Rede:** Desativação do Throttling de rede e otimização do índice de tráfego para reduzir latência em jogos (Ping).
* **Modo Jogo & DVR:** Ajustes de chaves de registro para otimizar o FPS e desativar o gravador de jogos em segundo plano do Xbox.
* **Serviços de Telemetria:** Parada de serviços de coleta de dados em segundo plano.
* **Controle do Windows Update:** Opção rápida para ativar, pausar ou desativar atualizações automáticas.

#### 4. 🧹 Limpeza de Disco
* **Arquivos Temporários:** Exclusão de caches e pastas temporárias de usuários e do sistema (`Temp` e `Prefetch`).
* **Logs e Relatórios:** Limpeza de registros de erros acumulados do Windows.
* **Cache do Windows Update:** Esvaziamento da pasta `SoftwareDistribution` (libera muito espaço em disco).
* **Lixeira:** Limpeza completa e segura de arquivos apagados.

#### 5. 📦 Instalar Apps (Winget)
* **Instalador Silencioso em Lote:** Selecione e instale programas populares automaticamente com apenas um clique:
  * **Navegadores:** Google Chrome, Firefox, Opera GX, Brave.
  * **Ferramentas:** 7-Zip, Notepad++, VS Code, Git.
  * **Mídia e Jogos:** VLC, Steam, Discord.

#### 6. 🔥 Desinstalador Avançado (Estilo Revo)
* **Varredura Completa:** Além de rodar o desinstalador padrão do programa, faz uma busca agressiva no disco (pastas `AppData` e `ProgramData`) e no Registro do Windows em busca de chaves e pastas órfãs deixadas para trás.

#### 7. 🌐 Ferramentas de Rede
* **ipconfig /all:** Exibe dados completos de IP, Gateway, Máscara e servidores DNS de forma formatada.
* **Ping Customizado:** Campo para digitar qualquer host/IP e pingar dinamicamente.
* **Portas Abertas (Netstat):** Exibe conexões TCP/UDP e portas ativas com seus respectivos PIDs.
* **Rota (Tracert):** Rastreia os saltos de rede de forma interativa.
* **Reset de Rede:** Executa o reset da pilha TCP/IP e do Winsock.
* **Renovar IP:** Libera e solicita um novo IP via DHCP (`release` / `renew`).

#### 8. 🔑 Ativação (MAS Integrado)
* **Ativação de Licenças:** Integração nativa com a ferramenta de código aberto **MAS (Microsoft Activation Scripts)**.
* **Abertura em Console Externo:** Abre uma janela de terminal PowerShell separada para rodar a ferramenta MAS de forma totalmente interativa, permitindo ativar Windows (via HWID permanente) ou Office (via Ohook) com segurança.

---

## 🇺🇸 English

**Samack WinUtil** is a complete suite of optimization and system management tools for Windows. Developed natively in **PowerShell** with a modern and responsive **WPF (Windows Presentation Foundation)** user interface, this utility allows you to perform deep cleanups, advanced uninstallation (Revo Uninstaller style), network diagnostics, privacy tweaks (debloat), and gaming performance optimizations for **Windows 7, 8, 8.1, 10, and 11**.

---

### 🚀 How to Run Online (Without Downloading Files)

Open PowerShell as **Administrator** and run the following command:

```powershell
irm https://raw.githubusercontent.com/rgis-samack/win-samack/refs/heads/main/win-samack.ps1 | iex
```

> 💡 **Compatibility Note:** The link above uses a special raw ASCII loader script that bypasses character encoding issues across all Windows versions by loading the main script in pure UTF-8 directly from memory.

---

### 🌟 Detailed Features

#### 1. 🖥️ Dashboard
* **Real-Time Monitoring:** Dynamic monitoring of CPU usage (%), RAM usage (%), and System Uptime.
* **High Consumption Processes:** Displays the **top 7 processes** consuming the most RAM and CPU time in real-time, updating silently every 5 seconds.
* **Quick RAM Cleaner:** Instantly releases RAM by clearing the working set of idle processes and background services.
* **System Restore Point:** Quick shortcut to create a Restore Point before applying advanced tweaks.
* **16 System/Network Quick Shortcuts:**
  * **🎛️ Disp. Manager:** Classic Device Manager.
  * **🔑 Registry:** Windows Registry Editor (`regedit`).
  * **💾 Discos:** Disk Management (`diskmgmt.msc`).
  * **👤 Contas Usuário:** Classic local user accounts panel.
  * **🔋 Opções Energia:** Classic power plan settings.
  * **💻 Prop. Sistema:** Advanced system properties (`sysdm.cpl`).
  * **⚙️ Serviços:** Services Manager (`services.msc`).
  * **🌐 Central Rede:** Network and Sharing Center.
  * **📈 Monitor Rec.:** Complete Windows Resource Monitor (`resmon.exe`).
  * **📊 Ger. de Tarefas:** Native Task Manager.
  * **🖥️ Painel Controle:** Classic Control Panel.
  * **🏓 Ping Google:** Tests latency for Google DNS (`8.8.8.8`).
  * **📡 Mostrar IPs:** Shows active network adapters.
  * **🧹 Limpar Cache DNS:** Instant DNS flush.
  * **🔌 Conexões de Rede:** Network adapters (`ncpa.cpl`).

#### 2. 🛡️ Debloat (Windows 10/11 only)
* **Bloatware Removal:** Safe batch uninstallation of pre-installed Microsoft apps (Xbox, Cortana, Skype, OneDrive, Bing, Maps, etc.).
* **Windows Optional Features:** Quickly toggle native features via DISM (WSL - Windows Subsystem for Linux, Windows Sandbox, Hyper-V, and SMBv1).

#### 3. ⚙️ Performance & Tweaks
* **General Optimization:** Tweaks processor scheduling to improve system responsiveness.
* **Network Tweaks:** Disables network throttling and optimizes network index to reduce gaming latency (ping).
* **Game Mode & DVR:** Registry modifications to optimize FPS and disable background DVR recordings.
* **Telemetry Services:** Disables background tracking services.
* **Windows Update Controller:** Pauses, activates, or completely disables automatic updates.

#### 4. 🧹 Disk Cleanup
* **Temporary Files:** Cleans Windows Temp, User Temp, and Prefetch directories.
* **Logs & Reports:** Removes error reporting and diagnostics logs.
* **Windows Update Cache:** Safely empties the `SoftwareDistribution` folder.
* **Recycle Bin:** Empties and frees space safely.

#### 5. 📦 App Installer (Winget)
* **Silent Batch Installer:** Easily install popular software in one click:
  * **Browsers:** Google Chrome, Firefox, Opera GX, Brave.
  * **Developer Tools:** 7-Zip, Notepad++, VS Code, Git.
  * **Media & Gaming:** VLC, Steam, Discord.

#### 6. 🔥 Advanced Uninstaller (Revo Style)
* **Leftovers Scanner:** Runs the standard uninstaller and automatically scans for leftover folders (`AppData`, `ProgramData`) and registry keys.

#### 7. 🌐 Network Tools
* **ipconfig /all:** Displays detailed IP address, gateway, and DNS server info.
* **Custom Ping:** Field to input any IP/host and test latency dynamically.
* **Active Connections (Netstat):** Lists active TCP/UDP connections and PIDs.
* **Route Trace (Tracert):** Interactive network path tracing.
* **Network Reset:** Resets Winsock and TCP/IP stack.
* **Renew IP:** Releases and renews IP address via DHCP.

#### 8. 🔑 Activation (MAS Integration)
* **License Activation:** Native integration with the open-source **MAS (Microsoft Activation Scripts)** tool.
* **External Console Launch:** Spawns a separate PowerShell window to run MAS interactively, enabling Windows (permanent HWID) and Office (permanent Ohook) activation safely.
