# ⚡ Win-Samack Optimizer

[**Português**](#-português) | [**English**](#-english)

---

## 🇧🇷 Português

O **Win-Samack Optimizer** é uma ferramenta de otimização de sistema completa, desenvolvida em PowerShell nativo com interface gráfica moderna em WPF. Ela reúne recursos de limpeza profunda, gerenciamento de privacidade, desinstalação avançada (estilo Revo Uninstaller), utilitários de rede e ajustes finos de desempenho para Windows 7, 8, 8.1, 10 e 11.

### 🚀 Como Executar Direto no PowerShell

Abra o PowerShell como **Administrador** e execute o comando abaixo:

```powershell
irm https://raw.githubusercontent.com/rgis-samack/win-samack/main/win-samack.ps1 | iex
```

---

### 🌟 Funcionalidades Principais

#### 1. 🖥️ Painel (Dashboard)
* **Monitoramento em Tempo Real:** Gráficos e progresso de uso da CPU, Memória RAM e Tempo de Atividade (Uptime).
* **Processos de Alto Consumo:** Lista em tempo real os 7 processos que mais estão consumindo RAM e tempo de processamento.
* **Limpeza Rápida de RAM:** Libera instantaneamente a memória ocupada por processos em segundo plano.
* **Ponto de Restauração:** Criação de pontos de backup do sistema com um clique.
* **Atalhos de Rede e Sistema:** Acesso imediato a 16 ferramentas nativas do Windows (Gerenciador de Dispositivos, Registro, ncpa.cpl, Monitor de Recursos, Gerenciador de Tarefas, Painel de Controle, teste de Ping, Flush DNS, etc.).

#### 2. 🛡️ Debloat (Apenas Windows 10/11)
* **Remoção de Apps Nativos:** Desinstalação segura de bloatwares como Bing, Xbox, OneDrive, Cortana e pacotes de telemetria.
* **Recursos Opcionais:** Ativação/desativação rápida via DISM de recursos avançados (WSL, Sandbox, Hyper-V, SMBv1).

#### 3. ⚙️ Desempenho e Ajustes
* **Otimização do Sistema:** Melhora o tempo de resposta do Windows e reduz travamentos.
* **Rede:** Desativação de Throttling e ajustes para menor latência em jogos.
* **Modo Jogo & DVR:** Otimizações exclusivas de registros para melhorar a taxa de quadros (FPS).
* **Atualizações do Windows:** Controle completo para pausar ou desativar o Windows Update.

#### 4. 🧹 Limpeza de Disco
* Limpeza profunda de temporários do Usuário e do Windows.
* Remoção de logs de erro do sistema e cache de atualizações do Windows (SoftwareDistribution).
* Esvaziamento seguro da Lixeira.

#### 5. 📦 Instalação de Apps (Winget)
* Instalador silencioso em lote de softwares essenciais (Chrome, Firefox, 7-Zip, VS Code, Git, VLC, Steam, Discord).

#### 6. 🔥 Desinstalador Avançado (Estilo Revo)
* Lista todos os programas instalados.
* Varredura profunda após desinstalação para encontrar e apagar pastas órfãs (AppData, ProgramData) e chaves de registro restantes.

#### 7. 🌐 Ferramentas de Rede
* Diagnóstico completo de IP (`ipconfig /all`).
* Testador de conectividade (Ping) e rotas (Tracert) com campos personalizados.
* Monitor de portas ativas (`netstat -ano`).
* Reset de rede Winsock/TCP-IP e renovação de IP (DHCP).

---

## 🇺🇸 English

**Win-Samack Optimizer** is a complete system optimization tool built in native PowerShell with a modern WPF graphical user interface. It combines deep cleanup, privacy management, advanced program uninstallation (Revo Uninstaller style), network utilities, and fine-tuned performance tweaks for Windows 7, 8, 8.1, 10, and 11.

### 🚀 How to Run Directly in PowerShell

Open PowerShell as **Administrator** and run the following command:

```powershell
irm https://raw.githubusercontent.com/rgis-samack/win-samack/main/win-samack.ps1 | iex
```

---

### 🌟 Key Features

#### 1. 🖥️ Dashboard
* **Real-Time Monitoring:** Live CPU, RAM usage, and System Uptime trackers.
* **High Consumption Processes:** Real-time list of the top 7 processes consuming the most RAM and processor time.
* **Quick RAM Cleaner:** Instantly releases memory occupied by background processes.
* **System Restore Point:** Create system backup points with a single click.
* **Network & System Shortcuts:** Quick access to 16 native Windows tools (Device Manager, Registry Editor, ncpa.cpl, Resource Monitor, Task Manager, Control Panel, Ping test, Flush DNS, etc.).

#### 2. 🛡️ Debloat (Windows 10/11 only)
* **Bloatware Removal:** Safe uninstallation of native apps like Bing, Xbox, OneDrive, Cortana, and telemetry packages.
* **Optional Features:** Quick toggle via DISM for advanced features (WSL, Windows Sandbox, Hyper-V, SMBv1).

#### 3. ⚙️ Performance & Tweaks
* **System Optimization:** Improves Windows response time and reduces stutters.
* **Network Tweaks:** Disables network throttling and optimizes registry settings for gaming.
* **Game Mode & DVR:** Custom registry tweaks to improve in-game FPS.
* **Windows Updates:** Full control to pause or disable automatic updates.

#### 4. 🧹 Disk Cleanup
* Deep cleanup of Windows Temp and User Temp folders.
* Removal of system error logs and Windows Update cache (SoftwareDistribution).
* Safe emptying of the Recycle Bin.

#### 5. 📦 App Installer (Winget)
* Silent batch installer for essential software (Chrome, Firefox, 7-Zip, VS Code, Git, VLC, Steam, Discord).

#### 6. 🔥 Advanced Uninstaller (Revo Style)
* Lists all installed programs with instant search.
* Deep leftover scanner to find and remove orphaned folders (AppData, ProgramData) and residual registry keys.

#### 7. 🌐 Network Tools
* Complete IP configuration diagnostics (`ipconfig /all`).
* Connectivity (Ping) and route (Tracert) testers with custom destination inputs.
* Active network connections and listening ports monitor (`netstat -ano`).
* Winsock/TCP-IP network stack reset and DHCP IP renewal.
