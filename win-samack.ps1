# ==============================================================================
#                      Samack WinUtil - Otimizador de Windows
# ==============================================================================
# Utilitário seguro para otimização, debloat e melhoria de latência em jogos.
# Desenvolvido nativamente em PowerShell e WPF. Livre de dependências externas.
# ==============================================================================

# 1. Carrega as bibliotecas do Windows Presentation Foundation (WPF)
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# 2. Compilação do código C# para otimização de RAM (EmptyWorkingSet)
$MemoryCleanerCode = @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class MemoryCleaner {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);

    public static long Clean() {
        long bytesFreed = 0;
        foreach (Process process in Process.GetProcesses()) {
            try {
                long before = process.WorkingSet64;
                if (EmptyWorkingSet(process.Handle)) {
                    long after = process.WorkingSet64;
                    if (before > after) {
                        bytesFreed += (before - after);
                    }
                }
            } catch {
                // Ignora processos do sistema/protegidos
            }
        }
        return bytesFreed;
    }
}
"@

try {
    Add-Type -TypeDefinition $MemoryCleanerCode -ErrorAction SilentlyContinue
} catch {}

# 3. Coleta de Informações do Sistema
try {
    $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cpuInfo = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
    $osName = $osInfo.Caption
    $cpuName = ($cpuInfo | Select-Object -First 1).Name
    $totalRamGB = [Math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 1)
} catch {
    $osName = "Windows (Erro de Leitura)"
    $cpuName = "Processador Genérico"
    $totalRamGB = "N/A"
}

# Detecção precisa da versão do Windows para compatibilidade retroativa
$osVersion = [Environment]::OSVersion.Version
$global:isWindows10Or11 = $osVersion.Major -ge 10
$global:isWindows8Or81 = ($osVersion.Major -eq 6) -and ($osVersion.Minor -ge 2)
$global:isWindows7 = ($osVersion.Major -eq 6) -and ($osVersion.Minor -eq 1)

# Inicialização do Rastreamento de Ações para Frases Personalizadas de Saída
$global:actionsPerformed = New-Object System.Collections.Generic.HashSet[string]
function Register-Action($action) {
    if ($null -ne $global:actionsPerformed) {
        $null = $global:actionsPerformed.Add($action)
    }
}

# Inicializa Contador de CPU para monitoramento em tempo real
$global:cpuCounter = New-Object System.Diagnostics.PerformanceCounter("Processor", "% Processor Time", "_Total")
$null = $global:cpuCounter.NextValue() # Primeira chamada inicializa o contador

# 4. Definição do Visual (XAML)
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Samack WinUtil" Height="620" Width="880"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        WindowStartupLocation="CenterScreen">
    
    <Window.Resources>
        <!-- Estilo Customizado para a Barra de Rolagem (ScrollBar) Escura e Moderna -->
        <Style TargetType="{x:Type ScrollBar}">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Width" Value="6"/>
            <Setter Property="Height" Value="6"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ScrollBar}">
                        <Grid x:Name="Bg" Background="{TemplateBinding Background}">
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.Thumb>
                                    <Thumb Background="#475569" BorderBrush="Transparent">
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="{x:Type Thumb}">
                                                <Border CornerRadius="3" Background="{TemplateBinding Background}" SnapsToDevicePixels="True"/>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo dos Botões do Menu Lateral (Sidebar) -->
        <Style TargetType="Button" x:Key="SidebarButton">
            <Setter Property="Foreground" Value="#94A3B8"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Height" Value="45"/>
            <Setter Property="Margin" Value="5,3"/>
            <Setter Property="Padding" Value="15,0"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" CornerRadius="8" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1E293B"/>
                                <Setter Property="Foreground" Value="#F8FAFC"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo dos Botões Comuns Modernos -->
        <Style TargetType="Button" x:Key="ModernButton">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Background" Value="#3B82F6"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="16,10"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" CornerRadius="8" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#2563EB"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1D4ED8"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#334155"/>
                                <Setter Property="Foreground" Value="#94A3B8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo dos Botões com Gradiente Roxo/Azul (Ações Principais) -->
        <Style TargetType="Button" x:Key="AccentButton">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="20,12"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <Border.Background>
                                <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                    <GradientStop Color="#3B82F6" Offset="0"/>
                                    <GradientStop Color="#8B5CF6" Offset="1"/>
                                </LinearGradientBrush>
                            </Border.Background>
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.9"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.8"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#334155"/>
                                <Setter Property="Foreground" Value="#94A3B8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo dos Checkboxes Modernos -->
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#F1F5F9"/>
            <Setter Property="Margin" Value="0,8"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>

        <!-- Estilo dos Painéis de Conteúdo (Cards) -->
        <Style TargetType="Border" x:Key="CardBorder">
            <Setter Property="Background" Value="#111827"/>
            <Setter Property="BorderBrush" Value="#1F2937"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="10"/>
            <Setter Property="Padding" Value="16"/>
            <Setter Property="Margin" Value="0,0,0,16"/>
        </Style>
    </Window.Resources>

    <!-- Estrutura Principal do Aplicativo -->
    <Border x:Name="WindowBorder" CornerRadius="14" Background="#0A0F1D" BorderBrush="#252F48" BorderThickness="1.5">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="40"/> <!-- Barra de Titulo -->
                <RowDefinition Height="*"/>  <!-- Conteudo Principal -->
                <RowDefinition Height="25"/> <!-- Barra de Status Inferior -->
            </Grid.RowDefinitions>

            <!-- Barra de Título Customizada (Permite Arrastar a Janela) -->
            <Grid Grid.Row="0" x:Name="TitleBar" Background="#111827">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="15,0,0,0">
                    <TextBlock Text="⚡" Foreground="#F59E0B" FontSize="14" Margin="0,0,8,0"/>
                    <TextBlock Text="Samack WinUtil" Foreground="#F8FAFC" FontSize="13" FontWeight="Bold"/>
                    <TextBlock Text=" - Otimizador e Debloater Seguro" Foreground="#94A3B8" FontSize="12" Margin="5,0,0,0"/>
                </StackPanel>
                
                <!-- Botoes de Minimizar/Fechar da Barra de Titulo -->
                <StackPanel Grid.Column="1" Orientation="Horizontal" Margin="0,0,5,0">
                    <Button x:Name="BtnMinimize" Content="━" Foreground="#94A3B8" Background="Transparent" BorderThickness="0" Width="35" Height="30" FontSize="10" Cursor="Hand"/>
                    <Button x:Name="BtnMaximize" Content="🗖" Foreground="#94A3B8" Background="Transparent" BorderThickness="0" Width="35" Height="30" FontSize="10" Cursor="Hand"/>
                    <Button x:Name="BtnClose" Content="✕" Foreground="#94A3B8" Background="Transparent" BorderThickness="0" Width="35" Height="30" FontSize="12" Cursor="Hand"/>
                </StackPanel>
            </Grid>

            <!-- Layout Principal: Menu Lateral + Conteúdo -->
            <Grid Grid.Row="1">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="230"/> <!-- Menu Lateral -->
                    <ColumnDefinition Width="*"/>   <!-- Tela de Conteudo -->
                </Grid.ColumnDefinitions>

                <!-- Menu Lateral (Sidebar) -->
                <Border Grid.Column="0" Background="#0B0F19" BorderBrush="#1F2937" BorderThickness="0,0,1,0" Padding="8,15,8,15">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        
                        <StackPanel Grid.Row="0">
                            <Button x:Name="BtnTabPainel" Style="{StaticResource SidebarButton}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="📊" Margin="0,0,10,0"/>
                                    <TextBlock Text="Painel"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnTabDebloat" Style="{StaticResource SidebarButton}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="🧹" Margin="0,0,10,0"/>
                                    <TextBlock Text="Debloat (Apps)"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnTabDesempenho" Style="{StaticResource SidebarButton}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="⚡" Margin="0,0,10,0"/>
                                    <TextBlock Text="Desempenho &amp; Jogos"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnTabLimpeza" Style="{StaticResource SidebarButton}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="🗑️" Margin="0,0,10,0"/>
                                    <TextBlock Text="Limpeza de Disco"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnTabApps" Style="{StaticResource SidebarButton}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="📦" Margin="0,0,10,0"/>
                                    <TextBlock Text="Instalar Apps"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnTabUninstall" Style="{StaticResource SidebarButton}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="🔥" Margin="0,0,10,0"/>
                                    <TextBlock Text="Desinstalar Apps"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnTabRede" Style="{StaticResource SidebarButton}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="🌐" Margin="0,0,10,0"/>
                                    <TextBlock Text="Ferramentas de Rede"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnTabAtivacao" Style="{StaticResource SidebarButton}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="🔑" Margin="0,0,10,0"/>
                                    <TextBlock Text="Ativação"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnTabOffice" Style="{StaticResource SidebarButton}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="📂" Margin="0,0,10,0"/>
                                    <TextBlock Text="Office"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnTabLogs" Style="{StaticResource SidebarButton}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="📜" Margin="0,0,10,0"/>
                                    <TextBlock Text="Logs de Execução"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>
                        
                        <!-- Logo/Tag do Desenvolvedor -->
                        <StackPanel Grid.Row="1" VerticalAlignment="Bottom" Margin="0,0,0,12" HorizontalAlignment="Center">
                            <TextBlock Text="Criado por Felipe Samack" Foreground="#475569" FontSize="11" HorizontalAlignment="Center" Margin="0,0,0,6"/>
                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,6">
                                <!-- Botão Instagram -->
                                <Button x:Name="BtnLinkInstagram" ToolTip="Instagram: @felipe.samack" Cursor="Hand" Background="Transparent" BorderThickness="0" Padding="0" Margin="0,0,12,0">
                                    <StackPanel Orientation="Horizontal">
                                        <TextBlock Text="📸" FontSize="12" Margin="0,0,4,0"/>
                                        <TextBlock Text="@felipe.samack" Foreground="#3B82F6" FontSize="11" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                                <!-- Botão GitHub -->
                                <Button x:Name="BtnLinkGithub" ToolTip="Repositório no GitHub" Cursor="Hand" Background="Transparent" BorderThickness="0" Padding="0">
                                    <StackPanel Orientation="Horizontal">
                                        <TextBlock Text="💻" FontSize="12" Margin="0,0,4,0"/>
                                        <TextBlock Text="GitHub" Foreground="#3B82F6" FontSize="11" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                            </StackPanel>

                            <!-- Botão Doação -->
                            <Button x:Name="BtnDonate" Cursor="Hand" Background="Transparent" BorderThickness="0" Padding="0" HorizontalAlignment="Center">
                                <Button.ToolTip>
                                    <ToolTip Background="#0F172A" BorderBrush="#334155" BorderThickness="1" Padding="8">
                                        <StackPanel MaxWidth="220">
                                            <TextBlock Text="Apoie o Projeto! 💖" FontWeight="Bold" Foreground="#F8FAFC" HorizontalAlignment="Center" Margin="0,0,0,6"/>
                                            <Image x:Name="ImgQrCode" Width="180" Height="180" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality" Cursor="Hand" ToolTip="Clique para abrir o link de pagamento"/>
                                            <TextBlock Text="Escaneie para fazer um Pix" FontSize="10" Foreground="#94A3B8" HorizontalAlignment="Center" Margin="0,6,0,0"/>
                                        </StackPanel>
                                    </ToolTip>
                                </Button.ToolTip>
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="🎁" FontSize="12" Margin="0,0,4,0"/>
                                    <TextBlock Text="Doação" Foreground="#10B981" FontSize="11" FontWeight="Bold" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>
                    </Grid>
                </Border>

                <!-- Área de Telas (Grids sobrepostos que alternam visibilidade) -->
                <Grid Grid.Column="1" Margin="20">
                    <!-- TELA 1: PAINEL (DASHBOARD) -->
                    <Grid x:Name="GridPainel" Visibility="Visible">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <!-- Cabeçalho de Boas Vindas -->
                        <StackPanel Grid.Row="0" Margin="0,0,0,15">
                            <TextBlock Text="Olá! Bem-vindo ao WinUtil" FontSize="20" FontWeight="Bold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Monitore o hardware e otimize o seu sistema de forma segura." FontSize="13" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>

                        <!-- Grade de Informações e Recursos com Rolagem -->
                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,0,0,5">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="1.15*"/>
                                    <ColumnDefinition Width="1*"/>
                                </Grid.ColumnDefinitions>

                            <!-- Informações do Sistema -->
                            <StackPanel Grid.Column="0" Margin="0,0,15,0">
                                <Border Style="{StaticResource CardBorder}">
                                    <StackPanel>
                                        <TextBlock Text="Informações do Sistema" FontSize="14" FontWeight="Bold" Foreground="#8B5CF6" Margin="0,0,0,12"/>
                                        
                                        <TextBlock Text="Sistema Operacional:" FontSize="11" Foreground="#64748B"/>
                                        <TextBlock x:Name="TxtOS" Text="Carregando..." FontSize="13" Foreground="#E2E8F0" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,0,0,10"/>

                                        <TextBlock Text="Processador:" FontSize="11" Foreground="#64748B"/>
                                        <TextBlock x:Name="TxtCPU" Text="Carregando..." FontSize="13" Foreground="#E2E8F0" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,0,0,10"/>

                                        <TextBlock Text="Memória RAM Total:" FontSize="11" Foreground="#64748B"/>
                                        <TextBlock x:Name="TxtTotalRAM" Text="Carregando..." FontSize="13" Foreground="#E2E8F0" FontWeight="SemiBold" Margin="0,0,0,10"/>

                                        <TextBlock Text="Tempo de Atividade (Uptime):" FontSize="11" Foreground="#64748B"/>
                                        <TextBlock x:Name="TxtUptime" Text="Carregando..." FontSize="13" Foreground="#E2E8F0" FontWeight="SemiBold"/>
                                    </StackPanel>
                                </Border>

                                <!-- Ações Rápidas de Segurança -->
                                <Border Style="{StaticResource CardBorder}">
                                    <StackPanel>
                                        <TextBlock Text="Segurança e Backup" FontSize="14" FontWeight="Bold" Foreground="#10B981" Margin="0,0,0,8"/>
                                        <TextBlock Text="Sempre crie um ponto de restauração antes de fazer otimizações complexas." FontSize="11" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,12"/>
                                        <Button x:Name="BtnCreateRestore" Content="Criar Ponto de Restauração" Style="{StaticResource ModernButton}" Background="#059669"/>
                                    </StackPanel>
                                </Border>

                                <!-- Atalhos Rápidos de Sistema -->
                                <Border Style="{StaticResource CardBorder}" Margin="0,12,0,0">
                                    <StackPanel>
                                        <TextBlock Text="🛠️ Ferramentas de Rede/Sistema" FontSize="14" FontWeight="Bold" Foreground="#F59E0B" Margin="0,0,0,10"/>
                                        <UniformGrid Columns="2">
                                             <Button x:Name="BtnShortcutDev" Content="🎛️ Disp. Manager" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="5,6" Margin="2" FontSize="11" Height="28"/>
                                             <Button x:Name="BtnShortcutReg" Content="🔑 Registry" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="5,6" Margin="2" FontSize="11" Height="28"/>
                                             <Button x:Name="BtnShortcutDisk" Content="💾 Discos" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="5,6" Margin="2" FontSize="11" Height="28"/>
                                             <Button x:Name="BtnShortcutUser" Content="👤 Contas Usuário" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="5,6" Margin="2" FontSize="11" Height="28"/>
                                             <Button x:Name="BtnShortcutPower" Content="🔋 Opções Energia" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="5,6" Margin="2" FontSize="11" Height="28"/>
                                             <Button x:Name="BtnShortcutSys" Content="💻 Prop. Sistema" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="5,6" Margin="2" FontSize="11" Height="28"/>
                                             <Button x:Name="BtnShortcutServ" Content="⚙️ Serviços" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="5,6" Margin="2" FontSize="11" Height="28"/>
                                             <Button x:Name="BtnShortcutNetCenter" Content="🌐 Central Rede" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="5,6" Margin="2" FontSize="11" Height="28"/>
                                             <Button x:Name="BtnShortcutRes" Content="📈 Monitor Rec." Style="{StaticResource ModernButton}" Background="#1E293B" Padding="5,6" Margin="2" FontSize="11" Height="28"/>
                                             <Button x:Name="BtnShortcutPingGoogle" Content="🏓 Ping Google" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="5,6" Margin="2" FontSize="11" Height="28"/>
                                             <Button x:Name="BtnShortcutIPConfig" Content="📡 Mostrar IPs" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="5,6" Margin="2" FontSize="11" Height="28"/>
                                             <Button x:Name="BtnShortcutFlushDNS" Content="🧹 Limpar Cache DNS" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="5,6" Margin="2" FontSize="11" Height="28"/>
                                             <Button x:Name="BtnShortcutNet" Content="🔌 Conexões de Rede" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="5,6" Margin="2" FontSize="11" Height="28"/>
                                             <Button x:Name="BtnShortcutTaskMgr" Content="📊 Ger. de Tarefas" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="5,6" Margin="2" FontSize="11" Height="28"/>
                                             <Button x:Name="BtnShortcutControl" Content="🖥️ Painel Controle" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="5,6" Margin="2" FontSize="11" Height="28"/>
                                        </UniformGrid>
                                    </StackPanel>
                                </Border>
                            </StackPanel>

                            <!-- Monitor de Recursos (CPU e RAM) -->
                            <Grid Grid.Column="1">
                                <StackPanel>
                                    <Border Style="{StaticResource CardBorder}">
                                        <StackPanel>
                                            <TextBlock Text="Monitor de Recursos" FontSize="14" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,15"/>
                                            
                                            <!-- Progresso de Uso da CPU -->
                                            <StackPanel Margin="0,0,0,15">
                                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Stretch" Margin="0,0,0,5">
                                                    <TextBlock Text="Uso do Processador (CPU):" FontSize="12" Foreground="#E2E8F0"/>
                                                    <TextBlock x:Name="LblCPU" Text="0%" FontSize="12" Foreground="#3B82F6" FontWeight="Bold" Margin="10,0,0,0"/>
                                                </StackPanel>
                                                <ProgressBar x:Name="BarCPU" Height="8" Minimum="0" Maximum="100" Value="0" Background="#1E293B" Foreground="#3B82F6" BorderThickness="0"/>
                                            </StackPanel>

                                            <!-- Progresso de Uso de RAM -->
                                            <StackPanel Margin="0,0,0,15">
                                                <StackPanel Orientation="Horizontal" Margin="0,0,0,5">
                                                    <TextBlock Text="Uso de Memória RAM:" FontSize="12" Foreground="#E2E8F0"/>
                                                    <TextBlock x:Name="LblRAM" Text="0%" FontSize="12" Foreground="#EC4899" FontWeight="Bold" Margin="10,0,0,0"/>
                                                </StackPanel>
                                                <ProgressBar x:Name="BarRAM" Height="8" Minimum="0" Maximum="100" Value="0" Background="#1E293B" BorderThickness="0" Margin="0,0,0,5">
                                                    <ProgressBar.Foreground>
                                                        <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                                                            <GradientStop Color="#8B5CF6" Offset="0"/>
                                                            <GradientStop Color="#EC4899" Offset="1"/>
                                                        </LinearGradientBrush>
                                                    </ProgressBar.Foreground>
                                                </ProgressBar>
                                                <TextBlock x:Name="LblRAMDetail" Text="Carregando uso de RAM..." FontSize="11" Foreground="#94A3B8"/>
                                            </StackPanel>
                                        </StackPanel>
                                    </Border>

                                    <!-- Otimização Instantânea de RAM -->
                                    <Border Style="{StaticResource CardBorder}">
                                        <StackPanel>
                                            <TextBlock Text="Limpeza Rápida de Memória" FontSize="14" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,8"/>
                                            <TextBlock Text="Reduz o consumo de RAM liberando os conjuntos de trabalho de todos os processos em segundo plano ativos." FontSize="11" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,12"/>
                                            <Button x:Name="BtnCleanRAM" Content="⚡ Limpar Memória RAM Agora" Style="{StaticResource AccentButton}"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Processos de Alto Consumo -->
                                    <Border Style="{StaticResource CardBorder}" Margin="0,12,0,0">
                                        <StackPanel>
                                            <TextBlock Text="🔥 Processos de Alto Consumo" FontSize="14" FontWeight="Bold" Foreground="#EF4444" Margin="0,0,0,10"/>
                                            <ListView x:Name="LvTopProcesses" Height="170" Background="#111827" Foreground="#F1F5F9" BorderBrush="#1F2937" BorderThickness="1" ScrollViewer.VerticalScrollBarVisibility="Hidden">
                                                <ListView.View>
                                                    <GridView>
                                                        <GridViewColumn Header="Processo" Width="105" DisplayMemberBinding="{Binding Name}"/>
                                                        <GridViewColumn Header="RAM (MB)" Width="65" DisplayMemberBinding="{Binding RAM}"/>
                                                        <GridViewColumn Header="CPU (s)" Width="60" DisplayMemberBinding="{Binding CPU}"/>
                                                    </GridView>
                                                </ListView.View>
                                            </ListView>
                                        </StackPanel>
                                    </Border>
                                </StackPanel>
                            </Grid>
                        </Grid>
                        </ScrollViewer>
                    </Grid>

                    <!-- TELA 2: DEBLOAT (REMOÇÃO DE APLICATIVOS) -->
                    <Grid x:Name="GridDebloat" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Titulo da Aba -->
                        <StackPanel Grid.Row="0" Margin="0,0,0,15">
                            <TextBlock Text="Desinstalar Bloatwares do Windows" FontSize="18" FontWeight="Bold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Selecione abaixo os aplicativos nativos do Windows que você deseja remover permanentemente." FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>

                        <!-- Lista de Checkboxes (Com Rolar) -->
                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,0,0,15">
                            <StackPanel>
                                <Border Style="{StaticResource CardBorder}">
                                    <StackPanel>
                                        <TextBlock Text="Selecione os Aplicativos para Remoção" FontSize="13" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
                                        <CheckBox x:Name="ChkDebloatBing" Content="Microsoft Bing (Clima, Notícias, Finanças)" 
                                                  ToolTip="Remove os aplicativos MSN Clima, Notícias, Esportes e Finanças que rodam em segundo plano."/>
                                        <CheckBox x:Name="ChkDebloatXbox" Content="Aplicativos Xbox (Barra de Jogo, Live e Captura)" 
                                                  ToolTip="Remove os aplicativos integrados do Xbox. Desmarque se você usa o Xbox Game Pass ou joga na Microsoft Store."/>
                                        <CheckBox x:Name="ChkDebloatOneDrive" Content="Microsoft OneDrive (Nuvem e Inicialização Automática)" 
                                                  ToolTip="Desinstala o cliente integrado do OneDrive, interrompendo sua sincronização."/>
                                        <CheckBox x:Name="ChkDebloatFeedback" Content="Suporte e Feedback (Hub de Feedback, Ajuda)" 
                                                  ToolTip="Remove os apps 'Hub de Feedback' e 'Obter Ajuda' que coletam logs de diagnóstico."/>
                                        <CheckBox x:Name="ChkDebloatGames" Content="Solitaire Collection e Jogos Promocionais" 
                                                  ToolTip="Remove o Microsoft Solitaire (Paciência) e instaladores de jogos patrocinados pela Microsoft."/>
                                        <CheckBox x:Name="ChkDebloatMisc" Content="Contatos, Mapas, Carteira e Filmes &amp; TV" 
                                                  ToolTip="Remove utilitários redundantes como Mapas, Pessoas, Carteira do Windows e tocadores multimídia antigos."/>
                                        <CheckBox x:Name="ChkDebloatTelemetry" Content="Remover Rastreamento de Apps UWP" 
                                                  ToolTip="Desativa pacotes de rastreamento inseridos dentro dos aplicativos padrão do Windows."/>
                                    </StackPanel>
                                </Border>

                                <!-- Card: Recursos do Windows (Windows Features) -->
                                <Border Style="{StaticResource CardBorder}" Margin="0,12,0,0">
                                    <StackPanel>
                                        <TextBlock Text="🧩 Recursos Opcionais do Windows" FontSize="13" FontWeight="Bold" Foreground="#8B5CF6" Margin="0,0,0,10"/>
                                        <TextBlock Text="Ative ou desative componentes avançados nativos do Windows. Selecione e clique em 'Aplicar Recursos'." FontSize="11" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,12"/>
                                        <UniformGrid Columns="2">
                                            <CheckBox x:Name="ChkFeatureWSL" Content="WSL (Subsystem for Linux)" ToolTip="Ativa o subsistema de compatibilidade para rodar Linux no Windows."/>
                                            <CheckBox x:Name="ChkFeatureSandbox" Content="Windows Sandbox (Área Isolada)" ToolTip="Ativa um ambiente virtual descartável e seguro para rodar arquivos suspeitos."/>
                                            <CheckBox x:Name="ChkFeatureHyperV" Content="Hyper-V (Virtualização)" ToolTip="Ativa o hipervisor nativo do Windows para rodar máquinas virtuais."/>
                                            <CheckBox x:Name="ChkFeatureSMB1" Content="SMBv1 (Compartilhamento Antigo)" ToolTip="Ativa o protocolo SMB 1.0 antigo para compatibilidade com impressoras/NAS legados."/>
                                        </UniformGrid>
                                        <Button x:Name="BtnApplyFeatures" Content="🧩 Aplicar Recursos Opcionais" Style="{StaticResource ModernButton}" Background="#8B5CF6" Height="32" Padding="15,0" Margin="0,10,0,0" HorizontalAlignment="Right"/>
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                        </ScrollViewer>

                        <!-- Botoes de Acao -->
                        <Grid Grid.Row="2">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Button Grid.Column="0" x:Name="BtnSelectAllDebloat" Content="Marcar Todos" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="12,8" Margin="0,0,10,0"/>
                            <Button Grid.Column="1" x:Name="BtnDeselectAllDebloat" Content="Desmarcar Todos" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="12,8"/>
                            <Button Grid.Column="3" x:Name="BtnRunDebloat" Content="🧹 Remover Aplicativos Selecionados" Style="{StaticResource AccentButton}"/>
                        </Grid>
                    </Grid>

                    <!-- TELA 3: TWEAKS (DESEMPENHO & JOGOS) -->
                    <Grid x:Name="GridDesempenho" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Titulo da Aba -->
                        <StackPanel Grid.Row="0" Margin="0,0,0,15">
                            <TextBlock Text="Otimizações e Ajustes de Sistema" FontSize="18" FontWeight="Bold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Ajustes finos seguros para melhorar a latência de jogos, reduzir stutters e liberar CPU e RAM." FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>

                        <!-- Lista de Checkboxes -->
                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,0,0,15">
                            <StackPanel>
                                <Border Style="{StaticResource CardBorder}">
                                    <StackPanel>
                                        <TextBlock Text="Otimizações de Jogos" FontSize="13" FontWeight="Bold" Foreground="#8B5CF6" Margin="0,0,0,10"/>
                                        <CheckBox x:Name="ChkTweakGameMode" Content="Forçar Ativação do Modo de Jogo (Windows Game Mode)" IsChecked="True"
                                                  ToolTip="Dá prioridade máxima aos jogos, suspendendo atualizações e recursos de fundo enquanto você joga."/>
                                        <CheckBox x:Name="ChkTweakGameDVR" Content="Desabilitar Xbox Game DVR (Gravação em Segundo Plano)" IsChecked="True"
                                                  ToolTip="Desativa a gravação constante e oculta que ocorre por trás dos jogos. Aumenta os quadros (FPS) significativamente."/>
                                        <CheckBox x:Name="ChkTweakNetworkLatency" Content="Otimizar Latência de Rede (Desabilitar Nagle's Algorithm)" IsChecked="True"
                                                  ToolTip="Desabilita o atraso de rede padrão para pacotes pequenos (Nagle). Melhora drasticamente o ping em jogos online."/>
                                        <CheckBox x:Name="ChkTweakNetworkThrottling" Content="Desativar Limitador de Rede (Network Throttling)" IsChecked="True"
                                                  ToolTip="Impede que o Windows reduza a largura de banda de rede quando a CPU estiver muito ocupada."/>
                                        <CheckBox x:Name="ChkTweakResponsiveness" Content="Priorizar Tempo de Resposta em Jogos (Responsiveness)" IsChecked="True"
                                                  ToolTip="Ajusta o agendador de tarefas do Windows para dar 100% de prioridade à aplicação em primeiro plano (o jogo)."/>
                                        <CheckBox x:Name="ChkTweakCoreParking" Content="Desabilitar CPU Core Parking (Manter CPU ativa)" IsChecked="True"
                                                  ToolTip="Evita que o processador desative núcleos dinamicamente para economizar energia, evitando quedas de FPS por atraso de ativação."/>
                                    </StackPanel>
                                </Border>

                                <Border Style="{StaticResource CardBorder}">
                                    <StackPanel>
                                        <TextBlock Text="Otimizações de Sistema" FontSize="13" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
                                        <CheckBox x:Name="ChkTweakTelemetry" Content="Desabilitar Serviços de Telemetria e Coleta de Dados" IsChecked="True"
                                                  ToolTip="Para e desativa o serviço DiagTrack (Experiências de Usuário Conectado), economizando RAM e Internet."/>
                                        <CheckBox x:Name="ChkTweakVisuals" Content="Ajustar Efeitos Visuais para Melhor Desempenho" 
                                                  ToolTip="Desabilita animações de minimizar/restaurar e sombras pesadas de janelas, deixando o sistema muito mais fluido."/>
                                    </StackPanel>
                                </Border>

                                <!-- Card: Otimização de Rede e DNS -->
                                <Border Style="{StaticResource CardBorder}" Margin="0,12,0,0">
                                    <StackPanel>
                                        <TextBlock Text="🌐 Servidor de DNS Otimizado" FontSize="13" FontWeight="Bold" Foreground="#10B981" Margin="0,0,0,10"/>
                                        <TextBlock Text="Selecione um servidor DNS rápido para reduzir a latência de rede e acelerar a navegação web. O DNS do AdGuard também bloqueia anúncios a nível de rede." FontSize="11" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,12"/>
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <ComboBox x:Name="CbDNS" Grid.Column="0" Height="30" VerticalContentAlignment="Center" Background="#1E293B" Foreground="#F1F5F9" BorderBrush="#1F2937" BorderThickness="1.5">
                                                <ComboBoxItem Content="Padrão do Provedor (Restaurar DHCP)" IsSelected="True"/>
                                                <ComboBoxItem Content="Cloudflare DNS (1.1.1.1 / 1.0.0.1) - Recomendado p/ Ping"/>
                                                <ComboBoxItem Content="Google DNS (8.8.8.8 / 8.8.4.4) - Excelente Compatibilidade"/>
                                                <ComboBoxItem Content="AdGuard DNS (94.140.14.14) - Bloqueio de Anúncios"/>
                                                <ComboBoxItem Content="OpenDNS (208.67.222.222 / 208.67.220.220) - Segurança"/>
                                            </ComboBox>
                                            <Button x:Name="BtnApplyDNS" Content="Aplicar DNS" Grid.Column="1" Style="{StaticResource ModernButton}" Background="#10B981" Height="30" Padding="15,0" Margin="10,0,0,0" VerticalAlignment="Center"/>
                                        </Grid>
                                    </StackPanel>
                                </Border>

                                <!-- Configurações do Windows Update (Lado a Lado) -->
                                <Border Style="{StaticResource CardBorder}" Margin="0,12,0,0">
                                    <StackPanel>
                                        <TextBlock Text="Atualizações do Windows (Windows Update)" FontSize="13" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
                                        <UniformGrid Columns="3" Margin="0,5,0,0">
                                            <!-- Card 1: Padrão -->
                                            <Border BorderBrush="#1F2937" BorderThickness="1" Background="#0F172A" CornerRadius="6" Padding="10" Margin="0,0,8,0">
                                                <Grid>
                                                    <Grid.RowDefinitions>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="*"/>
                                                        <RowDefinition Height="Auto"/>
                                                    </Grid.RowDefinitions>
                                                    <Button Grid.Row="0" x:Name="BtnWUDefault" Content="Padrão do Windows" Style="{StaticResource ModernButton}" Background="#1E293B" HorizontalAlignment="Stretch" Margin="0,0,0,10"/>
                                                    <TextBlock Grid.Row="1" Text="Configuração Padrão" FontSize="11" FontWeight="Bold" Foreground="#F8FAFC" Margin="0,0,0,5"/>
                                                    <StackPanel Grid.Row="2">
                                                        <TextBlock Text="• Sem modificações nas atualizações" FontSize="10" Foreground="#94A3B8" TextWrapping="Wrap"/>
                                                        <TextBlock Text="• Remove políticas personalizadas" FontSize="10" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,2,0,0"/>
                                                    </StackPanel>
                                                    <TextBlock Grid.Row="3" Text="Restaura as configurações de fábrica do Windows Update." FontStyle="Italic" FontSize="9" Foreground="#64748B" TextWrapping="Wrap" Margin="0,10,0,0"/>
                                                </Grid>
                                            </Border>

                                            <!-- Card 2: Segurança Balanceada -->
                                            <Border BorderBrush="#1F2937" BorderThickness="1" Background="#0F172A" CornerRadius="6" Padding="10" Margin="4,0,4,0">
                                                <Grid>
                                                    <Grid.RowDefinitions>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="*"/>
                                                        <RowDefinition Height="Auto"/>
                                                    </Grid.RowDefinitions>
                                                    <Button Grid.Row="0" x:Name="BtnWUSecurity" Content="Segurança Balanceada" Style="{StaticResource ModernButton}" Background="#0369A1" HorizontalAlignment="Stretch" Margin="0,0,0,10"/>
                                                    <TextBlock Grid.Row="1" Text="Configuração Segura" FontSize="11" FontWeight="Bold" Foreground="#38BDF8" Margin="0,0,0,5"/>
                                                    <StackPanel Grid.Row="2">
                                                        <TextBlock Text="• Atualizações de recursos adiadas por 365 dias" FontSize="10" Foreground="#94A3B8" TextWrapping="Wrap"/>
                                                        <TextBlock Text="• Atualizações de segurança após 4 dias" FontSize="10" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,2,0,0"/>
                                                        <TextBlock Text="• Impede que o Windows Update instale drivers" FontSize="10" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,2,0,0"/>
                                                    </StackPanel>
                                                    <TextBlock Grid.Row="3" Text="Evita bugs em novas versões sem comprometer patches críticos." FontStyle="Italic" FontSize="9" Foreground="#64748B" TextWrapping="Wrap" Margin="0,10,0,0"/>
                                                </Grid>
                                            </Border>

                                            <!-- Card 3: Desativar Tudo -->
                                            <Border BorderBrush="#7F1D1D" BorderThickness="1" Background="#0F172A" CornerRadius="6" Padding="10" Margin="8,0,0,0">
                                                <Grid>
                                                    <Grid.RowDefinitions>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="Auto"/>
                                                        <RowDefinition Height="*"/>
                                                        <RowDefinition Height="Auto"/>
                                                    </Grid.RowDefinitions>
                                                    <Button Grid.Row="0" x:Name="BtnWUDisable" Content="Desativar Atualizações" Style="{StaticResource ModernButton}" Background="#991B1B" Foreground="#FEE2E2" HorizontalAlignment="Stretch" Margin="0,0,0,10"/>
                                                    <TextBlock Grid.Row="1" Text="!! Não Recomendado !!" FontSize="11" FontWeight="Bold" Foreground="#EF4444" Margin="0,0,0,5"/>
                                                    <StackPanel Grid.Row="2">
                                                        <TextBlock Text="• Desativa TODAS as atualizações de sistema" FontSize="10" Foreground="#94A3B8" TextWrapping="Wrap"/>
                                                        <TextBlock Text="• Aumenta riscos e vulnerabilidades" FontSize="10" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,2,0,0"/>
                                                        <TextBlock Text="• Recomendado apenas para PCs de jogos isolados" FontSize="10" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,2,0,0"/>
                                                    </StackPanel>
                                                    <TextBlock Grid.Row="3" Text="Aviso: O Windows não baixará patches de segurança." FontStyle="Italic" FontSize="9" Foreground="#EF4444" TextWrapping="Wrap" Margin="0,10,0,0"/>
                                                </Grid>
                                            </Border>
                                        </UniformGrid>
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                        </ScrollViewer>

                        <!-- Botoes de Acao -->
                        <Grid Grid.Row="2">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Button Grid.Column="0" x:Name="BtnSelectAllTweaks" Content="Marcar Todos" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="12,8" Margin="0,0,10,0"/>
                            <Button Grid.Column="1" x:Name="BtnDeselectAllTweaks" Content="Desmarcar Todos" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="12,8"/>
                            <Button Grid.Column="3" x:Name="BtnRunTweaks" Content="⚡ Aplicar Otimizações Selecionadas" Style="{StaticResource AccentButton}"/>
                        </Grid>
                    </Grid>

                    <!-- TELA 4: LIMPEZA DE DISCO -->
                    <Grid x:Name="GridLimpeza" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Titulo da Aba -->
                        <StackPanel Grid.Row="0" Margin="0,0,0,15">
                            <TextBlock Text="Limpeza Completa de Disco" FontSize="18" FontWeight="Bold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Remova arquivos temporários desnecessários e libere gigabytes de espaço no seu HD ou SSD." FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>

                        <!-- Lista de Checkboxes -->
                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,0,0,15">
                            <StackPanel>
                                <Border Style="{StaticResource CardBorder}">
                                    <StackPanel>
                                        <TextBlock Text="Selecione as Áreas para Limpeza" FontSize="13" FontWeight="Bold" Foreground="#10B981" Margin="0,0,0,10"/>
                                        <CheckBox x:Name="ChkCleanUserTemp" Content="Arquivos Temporários de Usuário (Temp)" IsChecked="True"
                                                  ToolTip="Exclui caches de programas, imagens em cache de navegadores e instaladores temporários salvos na pasta de usuário."/>
                                        <CheckBox x:Name="ChkCleanSysTemp" Content="Arquivos Temporários de Sistema" IsChecked="True"
                                                  ToolTip="Remove arquivos temporários criados por serviços do Windows e programas rodando como administradores."/>
                                        <CheckBox x:Name="ChkCleanPrefetch" Content="Limpar Pasta Prefetch" IsChecked="True"
                                                  ToolTip="Remove dados antigos sobre inicialização de programas. O Windows recriará esses dados automaticamente conforme necessário."/>
                                        <CheckBox x:Name="ChkCleanLogs" Content="Limpar Arquivos de Log (.log) e Visualizador de Eventos" IsChecked="True"
                                                  ToolTip="Exclui registros de erro acumulados e limpa todos os logs do Visualizador de Eventos do Windows."/>
                                        <CheckBox x:Name="ChkCleanUpdateCache" Content="Limpar Cache de Download do Windows Update" IsChecked="True"
                                                  ToolTip="Limpa a pasta de downloads onde ficam armazenados arquivos de atualizações antigas já instaladas."/>
                                        <CheckBox x:Name="ChkCleanRecycleBin" Content="Esvaziar Lixeira do Windows" 
                                                  ToolTip="Remove permanentemente todos os arquivos que foram excluídos e enviados para a lixeira."/>
                                    </StackPanel>
                                </Border>

                                <!-- Card: Diagnóstico e Correção de Erros -->
                                <Border Style="{StaticResource CardBorder}" Margin="0,12,0,0">
                                    <StackPanel>
                                        <TextBlock Text="🛡️ Diagnóstico e Correção de Erros" FontSize="13" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
                                        <TextBlock Text="Use as ferramentas SFC (System File Checker) e DISM (Deployment Image Servicing and Management) para verificar e reparar arquivos de sistema corrompidos e restaurar a integridade do Windows." FontSize="11" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,12"/>
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <TextBlock Text="Executar reparo completo do sistema (SFC + DISM)" VerticalAlignment="Center" Foreground="#F1F5F9" FontSize="12"/>
                                            <Button x:Name="BtnRunSystemRepair" Content="🛠️ Reparar Sistema" Grid.Column="1" Style="{StaticResource ModernButton}" Background="#3B82F6" Height="30" Padding="15,0" VerticalAlignment="Center"/>
                                        </Grid>
                                    </StackPanel>
                                </Border>

                                <!-- Card: Backup de Drivers -->
                                <Border Style="{StaticResource CardBorder}" Margin="0,12,0,0">
                                    <StackPanel>
                                        <TextBlock Text="💾 Backup de Drivers do Sistema" FontSize="13" FontWeight="Bold" Foreground="#10B981" Margin="0,0,0,10"/>
                                        <TextBlock Text="Detecta a versão do sistema operacional e faz uma cópia de segurança (exportação) de todos os drivers de terceiros instalados no PC. O backup será salvo em uma pasta organizada na sua Área de Trabalho (Desktop)." FontSize="11" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,12"/>
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <TextBlock Text="Criar backup completo dos drivers instalados" VerticalAlignment="Center" Foreground="#F1F5F9" FontSize="12"/>
                                            <Button x:Name="BtnBackupDrivers" Content="💾 Fazer Backup" Grid.Column="1" Style="{StaticResource ModernButton}" Background="#10B981" Height="30" Padding="15,0" VerticalAlignment="Center"/>
                                        </Grid>
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                        </ScrollViewer>

                        <!-- Botoes de Acao -->
                        <Grid Grid.Row="2">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Button Grid.Column="0" x:Name="BtnSelectAllLimpeza" Content="Marcar Todos" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="12,8" Margin="0,0,10,0"/>
                            <Button Grid.Column="1" x:Name="BtnDeselectAllLimpeza" Content="Desmarcar Todos" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="12,8"/>
                            <Button Grid.Column="3" x:Name="BtnRunLimpeza" Content="🗑️ Executar Limpeza de Disco" Style="{StaticResource AccentButton}"/>
                        </Grid>
                    </Grid>

                    <!-- TELA 6: FERRAMENTAS DE REDE -->
                    <Grid x:Name="GridRede" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <!-- Cabeçalho -->
                        <Border Grid.Row="0" Background="#0F172A" Padding="20,14">
                            <StackPanel>
                                <TextBlock Text="🌐 Ferramentas de Rede" FontSize="20" FontWeight="Bold" Foreground="#F8FAFC"/>
                                <TextBlock Text="Diagnóstico, monitoramento e utilitários de rede do Windows." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
                            </StackPanel>
                        </Border>

                        <!-- Conteúdo em ScrollViewer -->
                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                            <Grid Margin="20,16">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="16"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>

                                <!-- Coluna Esquerda -->
                                <StackPanel Grid.Column="0">

                                    <!-- Informações de IP -->
                                    <Border Style="{StaticResource CardBorder}" Margin="0,0,0,12">
                                        <StackPanel>
                                            <TextBlock Text="📡 Informações de IP" FontSize="14" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
                                            <TextBlock Text="Exibe as configurações de todos os adaptadores de rede ativos." FontSize="11" Foreground="#94A3B8" Margin="0,0,0,10" TextWrapping="Wrap"/>
                                            <Button x:Name="BtnRedeIPConfig" Content="🔍 Ver Configuração de IP (ipconfig)" Style="{StaticResource ModernButton}" Background="#1D4ED8" Padding="10,8" Margin="0,0,0,10"/>
                                            <Border Background="#0D1117" CornerRadius="6" Padding="10" Margin="0,0,0,0">
                                                <ScrollViewer Height="120" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto">
                                                    <TextBlock x:Name="TxtRedeIPResult" Text="Clique em 'Ver Configuração de IP' para carregar..." FontSize="10" Foreground="#94A3B8" FontFamily="Consolas" TextWrapping="NoWrap"/>
                                                </ScrollViewer>
                                            </Border>
                                        </StackPanel>
                                    </Border>

                                    <!-- Ping / Teste de Conectividade -->
                                    <Border Style="{StaticResource CardBorder}" Margin="0,0,0,12">
                                        <StackPanel>
                                            <TextBlock Text="🏓 Ping / Teste de Conectividade" FontSize="14" FontWeight="Bold" Foreground="#10B981" Margin="0,0,0,10"/>
                                            <TextBlock Text="Teste a conexão com um host ou endereço IP." FontSize="11" Foreground="#94A3B8" Margin="0,0,0,10" TextWrapping="Wrap"/>
                                            <Grid Margin="0,0,0,8">
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="*"/>
                                                    <ColumnDefinition Width="8"/>
                                                    <ColumnDefinition Width="Auto"/>
                                                </Grid.ColumnDefinitions>
                                                <TextBox x:Name="TxtRedePingHost" Grid.Column="0" Text="8.8.8.8" Background="#1E293B" Foreground="#F1F5F9" BorderBrush="#334155" Padding="8,6" FontSize="12" VerticalContentAlignment="Center"/>
                                                <Button x:Name="BtnRedePing" Grid.Column="2" Content="🏓 Pingar" Style="{StaticResource ModernButton}" Background="#059669" Padding="12,6"/>
                                            </Grid>
                                            <Border Background="#0D1117" CornerRadius="6" Padding="10">
                                                <ScrollViewer Height="100" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto">
                                                    <TextBlock x:Name="TxtRedePingResult" Text="Aguardando..." FontSize="10" Foreground="#94A3B8" FontFamily="Consolas" TextWrapping="NoWrap"/>
                                                </ScrollViewer>
                                            </Border>
                                        </StackPanel>
                                    </Border>

                                    <!-- Portas Abertas (Netstat) -->
                                    <Border Style="{StaticResource CardBorder}">
                                        <StackPanel>
                                            <TextBlock Text="🔌 Portas Abertas (Netstat)" FontSize="14" FontWeight="Bold" Foreground="#8B5CF6" Margin="0,0,0,10"/>
                                            <TextBlock Text="Lista as conexões de rede ativas e portas em escuta." FontSize="11" Foreground="#94A3B8" Margin="0,0,0,10" TextWrapping="Wrap"/>
                                            <Button x:Name="BtnRedeNetstat" Content="🔌 Ver Conexões Ativas" Style="{StaticResource ModernButton}" Background="#6D28D9" Padding="10,8" Margin="0,0,0,10"/>
                                            <Border Background="#0D1117" CornerRadius="6" Padding="10">
                                                <ScrollViewer Height="140" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto">
                                                    <TextBlock x:Name="TxtRedeNetstatResult" Text="Clique em 'Ver Conexões Ativas' para carregar..." FontSize="10" Foreground="#94A3B8" FontFamily="Consolas" TextWrapping="NoWrap"/>
                                                </ScrollViewer>
                                            </Border>
                                        </StackPanel>
                                    </Border>

                                </StackPanel>

                                <!-- Coluna Direita -->
                                <StackPanel Grid.Column="2">

                                    <!-- Flush DNS -->
                                    <Border Style="{StaticResource CardBorder}" Margin="0,0,0,12">
                                        <StackPanel>
                                            <TextBlock Text="🧹 Limpar Cache de DNS" FontSize="14" FontWeight="Bold" Foreground="#F59E0B" Margin="0,0,0,8"/>
                                            <TextBlock Text="Apaga o cache de DNS local do sistema, forçando novas resoluções de domínio. Útil quando sites não carregam corretamente." FontSize="11" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,12"/>
                                            <Button x:Name="BtnRedeFlushDNS" Content="🧹 Executar Flush DNS" Style="{StaticResource ModernButton}" Background="#D97706" Padding="10,8"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Reset de Winsock / TCP-IP -->
                                    <Border Style="{StaticResource CardBorder}" Margin="0,0,0,12">
                                        <StackPanel>
                                            <TextBlock Text="🔄 Reset de Rede (Winsock / TCP-IP)" FontSize="14" FontWeight="Bold" Foreground="#EF4444" Margin="0,0,0,8"/>
                                            <TextBlock Text="Restaura as configurações da pilha TCP/IP e Winsock para o padrão do Windows. Resolve problemas de conexão persistentes." FontSize="11" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,12"/>
                                            <Button x:Name="BtnRedeReset" Content="🔄 Resetar Rede (requer reinício)" Style="{StaticResource ModernButton}" Background="#B91C1C" Padding="10,8"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Liberar / Renovar IP (DHCP) -->
                                    <Border Style="{StaticResource CardBorder}" Margin="0,0,0,12">
                                        <StackPanel>
                                            <TextBlock Text="🔁 Liberar e Renovar IP (DHCP)" FontSize="14" FontWeight="Bold" Foreground="#06B6D4" Margin="0,0,0,8"/>
                                            <TextBlock Text="Libera o endereço IP atual e solicita um novo ao servidor DHCP. Útil ao trocar de rede ou resolver conflitos de IP." FontSize="11" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,12"/>
                                            <Button x:Name="BtnRedeRenewIP" Content="🔁 Liberar e Renovar IP" Style="{StaticResource ModernButton}" Background="#0891B2" Padding="10,8"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Traçar Rota (Tracert) -->
                                    <Border Style="{StaticResource CardBorder}">
                                        <StackPanel>
                                            <TextBlock Text="🗺️ Rastrear Rota (Tracert)" FontSize="14" FontWeight="Bold" Foreground="#A3E635" Margin="0,0,0,10"/>
                                            <TextBlock Text="Exibe o caminho de saltos entre sua máquina e o destino." FontSize="11" Foreground="#94A3B8" Margin="0,0,0,10" TextWrapping="Wrap"/>
                                            <Grid Margin="0,0,0,8">
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="*"/>
                                                    <ColumnDefinition Width="8"/>
                                                    <ColumnDefinition Width="Auto"/>
                                                </Grid.ColumnDefinitions>
                                                <TextBox x:Name="TxtRedeTracertHost" Grid.Column="0" Text="8.8.8.8" Background="#1E293B" Foreground="#F1F5F9" BorderBrush="#334155" Padding="8,6" FontSize="12" VerticalContentAlignment="Center"/>
                                                <Button x:Name="BtnRedeTracert" Grid.Column="2" Content="🗺️ Rastrear" Style="{StaticResource ModernButton}" Background="#65A30D" Padding="12,6"/>
                                            </Grid>
                                            <Border Background="#0D1117" CornerRadius="6" Padding="10">
                                                <ScrollViewer Height="120" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto">
                                                    <TextBlock x:Name="TxtRedeTracertResult" Text="Aguardando..." FontSize="10" Foreground="#94A3B8" FontFamily="Consolas" TextWrapping="NoWrap"/>
                                                </ScrollViewer>
                                            </Border>
                                        </StackPanel>
                                    </Border>

                                </StackPanel>
                            </Grid>
                        </ScrollViewer>
                    </Grid>

                    <!-- TELA 7: ATIVAÇÃO (MAS) -->
                    <Grid x:Name="GridAtivacao" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <!-- Cabeçalho -->
                        <Border Grid.Row="0" Background="#0F172A" Padding="20,14">
                            <StackPanel>
                                <TextBlock Text="🔑 Ativação de Licenças" FontSize="20" FontWeight="Bold" Foreground="#F8FAFC"/>
                                <TextBlock Text="Gerencie a ativação e licenças permanentes do seu Windows e Office." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
                            </StackPanel>
                        </Border>

                        <!-- Conteúdo -->
                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                            <StackPanel Margin="20,16" MaxWidth="800" HorizontalAlignment="Left">
                                
                                <Border Style="{StaticResource CardBorder}" Margin="0,0,0,16">
                                    <StackPanel>
                                        <TextBlock Text="⚡ Microsoft Activation Scripts (MAS)" FontSize="15" FontWeight="Bold" Foreground="#10B981" Margin="0,0,0,10"/>
                                        <TextBlock Text="Esta funcionalidade utiliza a ferramenta oficial e de código aberto MAS (Microsoft Activation Scripts) para realizar ativações seguras, permanentes e sem vírus." FontSize="12" Foreground="#CBD5E1" TextWrapping="Wrap" Margin="0,0,0,15"/>

                                        <!-- Grid com Detalhes dos Métodos -->
                                        <Grid Margin="0,0,0,20">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="15"/>
                                                <ColumnDefinition Width="*"/>
                                            </Grid.ColumnDefinitions>

                                            <!-- Métodos à Esquerda -->
                                            <StackPanel Grid.Column="0">
                                                <TextBlock Text="Métodos de Ativação:" FontSize="12" FontWeight="Bold" Foreground="#F8FAFC" Margin="0,0,0,8"/>
                                                <TextBlock Text="• HWID (Windows 10/11):" FontSize="11" FontWeight="Bold" Foreground="#E2E8F0"/>
                                                <TextBlock Text="  Ativação digital permanente vinculada à placa-mãe." FontSize="11" Foreground="#94A3B8" Margin="0,0,0,8" TextWrapping="Wrap"/>
                                                
                                                <TextBlock Text="• Ohook (Office):" FontSize="11" FontWeight="Bold" Foreground="#E2E8F0"/>
                                                <TextBlock Text="  Ativação permanente de todas as edições do Office local." FontSize="11" Foreground="#94A3B8" Margin="0,0,0,8" TextWrapping="Wrap"/>
                                            </StackPanel>

                                            <!-- Métodos à Direita -->
                                            <StackPanel Grid.Column="2">
                                                <TextBlock Text="Outros Recursos:" FontSize="12" FontWeight="Bold" Foreground="#F8FAFC" Margin="0,0,0,8"/>
                                                <TextBlock Text="• KMS38 (Win Server / LTSC):" FontSize="11" FontWeight="Bold" Foreground="#E2E8F0"/>
                                                <TextBlock Text="  Ativa o Windows Enterprise ou LTSC até o ano de 2038." FontSize="11" Foreground="#94A3B8" Margin="0,0,0,8" TextWrapping="Wrap"/>
                                                
                                                <TextBlock Text="• Status da Licença:" FontSize="11" FontWeight="Bold" Foreground="#E2E8F0"/>
                                                <TextBlock Text="  Permite checar a expiração ou validade atual das chaves." FontSize="11" Foreground="#94A3B8" Margin="0,0,0,8" TextWrapping="Wrap"/>
                                            </StackPanel>
                                        </Grid>

                                        <Border BorderBrush="#334155" BorderThickness="0,1,0,0" Padding="0,15,0,0">
                                            <StackPanel>
                                                <TextBlock Text="Como funciona?" FontSize="11" FontWeight="Bold" Foreground="#F59E0B" Margin="0,0,0,5"/>
                                                <TextBlock Text="Ao clicar no botão abaixo, uma nova janela de terminal segura do PowerShell será aberta para carregar e executar interativamente a ferramenta. Siga as instruções numéricas exibidas no console preto para ativar o que deseja." FontSize="11" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,15"/>
                                                
                                                <Button x:Name="BtnRunActivation" Content="⚡ Iniciar Ativador (MAS)" Style="{StaticResource AccentButton}" Background="#059669" Height="36" FontSize="13" FontWeight="Bold" HorizontalAlignment="Left" Padding="25,0"/>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>
                                </Border>
                                
                            </StackPanel>
                        </ScrollViewer>
                    </Grid>

                    <!-- TELA 8: DOWNLOADS DO OFFICE -->
                    <Grid x:Name="GridOffice" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <!-- Cabecalho -->
                        <Border Grid.Row="0" Background="#0F172A" Padding="20,14">
                            <StackPanel>
                                <TextBlock Text="📦 Downloads do Office" FontSize="20" FontWeight="Bold" Foreground="#F8FAFC"/>
                                <TextBlock Text="Faca o download dos instaladores oficiais do Microsoft Office." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
                            </StackPanel>
                        </Border>

                        <!-- Conteudo -->
                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                            <StackPanel Margin="20,16" MaxWidth="800" HorizontalAlignment="Left">

                                <!-- Office 2021 -->
                                <Border Style="{StaticResource CardBorder}" Margin="0,0,0,16">
                                    <StackPanel>
                                        <TextBlock Text="✨ Microsoft Office 2021 Professional Plus" FontSize="15" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
                                        <TextBlock Text="A versao mais recente da suite de escritorio classica, trazendo novos recursos de coautoria em tempo real, melhorias de desempenho, suporte a temas escuros aprimorados e novas formulas no Excel (como XLOOKUP)." FontSize="12" Foreground="#CBD5E1" TextWrapping="Wrap" Margin="0,0,0,15"/>
                                        
                                        <TextBlock Text="Links de Download:" FontSize="12" FontWeight="Bold" Foreground="#F8FAFC" Margin="0,0,0,8"/>
                                        <WrapPanel>
                                            <Button x:Name="BtnOffice2021Tiny" Content="📥 Office 2021 Tinyurl" Style="{StaticResource ModernButton}" Background="#2563EB" Padding="15,8" Margin="0,0,10,10"/>
                                            <Button x:Name="BtnOffice2021Bitly" Content="📥 Office 2021 Bitly" Style="{StaticResource ModernButton}" Background="#0284C7" Padding="15,8" Margin="0,0,10,10"/>
                                        </WrapPanel>
                                    </StackPanel>
                                </Border>

                                <!-- Office 2019 -->
                                <Border Style="{StaticResource CardBorder}" Margin="0,0,0,16">
                                    <StackPanel>
                                        <TextBlock Text="📅 Microsoft Office 2019 Professional Plus" FontSize="15" FontWeight="Bold" Foreground="#8B5CF6" Margin="0,0,0,10"/>
                                        <TextBlock Text="A suite de produtividade estavel e consolidada com os aplicativos essenciais: Word, Excel, PowerPoint, Outlook e Access. Ideal para quem busca uma versao local confiavel com excelentes recursos de transicao e escrita digital." FontSize="12" Foreground="#CBD5E1" TextWrapping="Wrap" Margin="0,0,0,15"/>
                                        
                                        <TextBlock Text="Links de Download:" FontSize="12" FontWeight="Bold" Foreground="#F8FAFC" Margin="0,0,0,8"/>
                                        <WrapPanel>
                                            <Button x:Name="BtnOffice2019Abre" Content="📥 Office 2019 Abre.ai" Style="{StaticResource ModernButton}" Background="#7C3AED" Padding="15,8" Margin="0,0,10,10"/>
                                            <Button x:Name="BtnOffice2019Tiny" Content="📥 Office 2019 Tinyurl" Style="{StaticResource ModernButton}" Background="#0D9488" Padding="15,8" Margin="0,0,10,10"/>
                                        </WrapPanel>
                                    </StackPanel>
                                </Border>

                            </StackPanel>
                        </ScrollViewer>
                    </Grid>

                    <!-- TELA 5: LOGS DE EXECUÇÃO -->
                    <Grid x:Name="GridLogs" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Titulo da Aba -->
                        <StackPanel Grid.Row="0" Margin="0,0,0,10">
                            <TextBlock Text="Console de Operações" FontSize="18" FontWeight="Bold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Acompanhe o que está acontecendo por trás das otimizações do sistema." FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>

                        <!-- Tela do Console Log -->
                        <TextBox Grid.Row="1" x:Name="TxtLogs" AcceptsReturn="True" IsReadOnly="True" 
                                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                                 Background="#030712" Foreground="#38BDF8" BorderBrush="#1F2937" 
                                 BorderThickness="1.5" FontFamily="Consolas" FontSize="12" Padding="12"
                                 Margin="0,0,0,15"/>

                        <!-- Botoes inferiores dos Logs -->
                        <Grid Grid.Row="2">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Button Grid.Column="0" x:Name="BtnCopyLogs" Content="Copiar Logs" Style="{StaticResource ModernButton}" Background="#1E293B" Margin="0,0,10,0"/>
                            <Button Grid.Column="1" x:Name="BtnClearLogs" Content="Limpar Console" Style="{StaticResource ModernButton}" Background="#1E293B"/>
                        </Grid>
                    </Grid>

                    <!-- TELA 6: INSTALADOR DE APLICATIVOS (WINGET) -->
                    <Grid x:Name="GridApps" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Cabeçalho -->
                        <StackPanel Grid.Row="0" Margin="0,0,0,12">
                            <TextBlock Text="Instalador de Programas (WinGet)" FontSize="18" FontWeight="Bold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Selecione abaixo os aplicativos que deseja baixar e instalar de forma silenciosa no seu computador." FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>

                        <!-- Área de Checkboxes com scroll -->
                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,0,0,15">
                            <StackPanel>
                                <!-- Card 1: Drivers e Runtimes Essenciais -->
                                <Border Style="{StaticResource CardBorder}" Margin="0,0,0,12">
                                    <StackPanel>
                                        <TextBlock Text="🔌 Drivers e Runtimes Essenciais" FontSize="13" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,8"/>
                                        <UniformGrid Columns="3">
                                            <CheckBox x:Name="ChkAppSnappyDriver" Content="Snappy Driver Installer" Tag="GlennDelahoy.SnappyDriverInstallerOrigin" ToolTip="Instalador e atualizador universal de drivers offline/online. ID: GlennDelahoy.SnappyDriverInstallerOrigin"/>
                                            <CheckBox x:Name="ChkAppVCRedist" Content="Visual C++ All-in-One" Tag="abbodi1406.vcredist" ToolTip="Pacote completo com todas as versões do Visual C++ Redistributable (2005-2022). ID: abbodi1406.vcredist"/>
                                            <CheckBox x:Name="ChkAppDirectX" Content="DirectX Legacy Runtime" Tag="Microsoft.DirectX" ToolTip="Instala componentes herdados do DirectX 9.0c/10/11 para compatibilidade de jogos. ID: Microsoft.DirectX"/>
                                            <CheckBox x:Name="ChkAppVCRedist2010x64" Content="Visual C++ 2010 (x64)" Tag="Microsoft.VCRedist.2010.x64" ToolTip="Microsoft Visual C++ 2010 x64 Redistributable. ID: Microsoft.VCRedist.2010.x64"/>
                                            <CheckBox x:Name="ChkAppVCRedist2010x86" Content="Visual C++ 2010 (x86)" Tag="Microsoft.VCRedist.2010.x86" ToolTip="Microsoft Visual C++ 2010 x86 Redistributable. ID: Microsoft.VCRedist.2010.x86"/>
                                            <CheckBox x:Name="ChkAppVCRedistv14x64" Content="Visual C++ v14 (x64)" Tag="Microsoft.VCRedist.2015+.x64" ToolTip="Microsoft Visual C++ v14 Redistributable (x64). ID: Microsoft.VCRedist.2015+.x64"/>
                                            <CheckBox x:Name="ChkAppVCRedistv14x86" Content="Visual C++ v14 (x86)" Tag="Microsoft.VCRedist.2015+.x86" ToolTip="Microsoft Visual C++ v14 Redistributable (x86). ID: Microsoft.VCRedist.2015+.x86"/>
                                            <CheckBox x:Name="ChkAppDotNet6" Content=".NET Desktop Runtime 6.0" Tag="Microsoft.DotNet.DesktopRuntime.6" ToolTip="Runtime oficial da Microsoft para rodar apps .NET 6.0. ID: Microsoft.DotNet.DesktopRuntime.6"/>
                                            <CheckBox x:Name="ChkAppDotNet8" Content=".NET Desktop Runtime 8.0" Tag="Microsoft.DotNet.DesktopRuntime.8" ToolTip="Runtime oficial da Microsoft para rodar apps .NET 8.0. ID: Microsoft.DotNet.DesktopRuntime.8"/>
                                            <CheckBox x:Name="ChkAppDotNet9" Content=".NET Desktop Runtime 9.0" Tag="Microsoft.DotNet.DesktopRuntime.9" ToolTip="Runtime oficial da Microsoft para rodar apps .NET 9.0. ID: Microsoft.DotNet.DesktopRuntime.9"/>
                                            <CheckBox x:Name="ChkAppDotNet10" Content=".NET Desktop Runtime 10.0" Tag="Microsoft.DotNet.DesktopRuntime.10" ToolTip="Runtime oficial da Microsoft para rodar apps .NET 10.0. ID: Microsoft.DotNet.DesktopRuntime.10"/>
                                            <CheckBox x:Name="ChkAppNVCleanstall" Content="NVCleanstall" Tag="TechPowerUp.NVCleanstall" ToolTip="Instalador customizado e limpo para drivers de vídeo NVIDIA. ID: TechPowerUp.NVCleanstall"/>
                                        </UniformGrid>
                                    </StackPanel>
                                </Border>

                                <!-- Card 2: Utilitários -->
                                <Border Style="{StaticResource CardBorder}" Margin="0,0,0,12">
                                    <StackPanel>
                                        <TextBlock Text="🛠️ Utilitários" FontSize="13" FontWeight="Bold" Foreground="#F59E0B" Margin="0,0,0,8"/>
                                        <UniformGrid Columns="3">
                                            <CheckBox x:Name="ChkApp7Zip" Content="7-Zip" Tag="7zip.7zip" ToolTip="Descompactador de arquivos leve e gratuito. ID: 7zip.7zip"/>
                                            <CheckBox x:Name="ChkAppNanaZip" Content="NanaZip" Tag="M2Team.NanaZip" ToolTip="Fork moderno do 7-Zip integrado ao Windows 11. ID: M2Team.NanaZip"/>
                                            <CheckBox x:Name="ChkAppPeaZip" Content="PeaZip" Tag="PeaZip.PeaZip" ToolTip="Compactador e descompactador open source completo. ID: PeaZip.PeaZip"/>
                                            <CheckBox x:Name="ChkAppWinRAR" Content="WinRAR" Tag="RARLab.WinRAR" ToolTip="Famoso compactador e descompactador de arquivos. ID: RARLab.WinRAR"/>
                                            <CheckBox x:Name="ChkAppBulkCrap" Content="Bulk Crap Uninstaller" Tag="Klocman.BulkCrapUninstaller" ToolTip="Desinstalador profundo e automatizado para remoção em lote. ID: Klocman.BulkCrapUninstaller"/>
                                            <CheckBox x:Name="ChkAppRevo" Content="Revo Uninstaller" Tag="RevoUninstaller.RevoUninstaller" ToolTip="Desinstala programas removendo arquivos residuais e chaves de registro. ID: RevoUninstaller.RevoUninstaller"/>
                                            <CheckBox x:Name="ChkAppWiseUninstaller" Content="Wise Program Uninstaller" Tag="WiseCleaner.WiseProgramUninstaller" ToolTip="Ferramenta gratuita para desinstalação segura e forçada. ID: WiseCleaner.WiseProgramUninstaller"/>
                                            <CheckBox x:Name="ChkAppCrystalInfo" Content="CrystalDiskInfo" Tag="CrystalDewWorld.CrystalDiskInfo" ToolTip="Utilitário de monitoramento da integridade de HDs e SSDs. ID: CrystalDewWorld.CrystalDiskInfo"/>
                                            <CheckBox x:Name="ChkAppCrystalMark" Content="CrystalDiskMark" Tag="CrystalDewWorld.CrystalDiskMark" ToolTip="Ferramenta de benchmark para testar velocidade de HDs/SSDs. ID: CrystalDewWorld.CrystalDiskMark"/>
                                            <CheckBox x:Name="ChkAppEverything" Content="VoidTools Everything" Tag="voidtools.Everything" ToolTip="Mecanismo de busca instantânea de arquivos e pastas no Windows. ID: voidtools.Everything"/>
                                            <CheckBox x:Name="ChkAppFiles" Content="Files App" Tag="Files-Community.Files" ToolTip="Gerenciador de arquivos moderno com abas e design fluente. ID: Files-Community.Files"/>
                                            <CheckBox x:Name="ChkAppNilesoftShell" Content="Nilesoft Shell" Tag="Nilesoft.Shell" ToolTip="Personalizador avançado e leve do menu de contexto do Windows. ID: Nilesoft.Shell"/>
                                            <CheckBox x:Name="ChkAppRufus" Content="Rufus" Tag="Akeo.Rufus" ToolTip="Criador de pendrives bootáveis para instalação de sistemas. ID: Akeo.Rufus"/>
                                            <CheckBox x:Name="ChkAppVentoy" Content="Ventoy" Tag="Ventoy.Ventoy" ToolTip="Ferramenta open source para criar pendrive multiboot copiando arquivos ISO. ID: Ventoy.Ventoy"/>
                                            <CheckBox x:Name="ChkAppUniGetUI" Content="UniGetUI" Tag="MartiCliment.UniGetUI" ToolTip="Interface gráfica avançada para WinGet, Chocolatey e Scoop. ID: MartiCliment.UniGetUI"/>
                                            <CheckBox x:Name="ChkAppWizTree" Content="WizTree" Tag="AntibodySoftware.WizTree" ToolTip="Analisador de espaço em disco ultrarrápido. ID: AntibodySoftware.WizTree"/>
                                            <CheckBox x:Name="ChkAppTreeSize" Content="TreeSize Free" Tag="JAMSoftware.TreeSize.Free" ToolTip="Verifique pastas que mais ocupam espaço no disco. ID: JAMSoftware.TreeSize.Free"/>
                                            <CheckBox x:Name="ChkAppTranslucentTB" Content="TranslucentTB" Tag="TranslucentTB.TranslucentTB" ToolTip="Torna a barra de tarefas do Windows transparente ou translúcida. ID: TranslucentTB.TranslucentTB"/>
                                            <CheckBox x:Name="ChkAppAutoHotkey" Content="AutoHotkey" Tag="AutoHotkey.AutoHotkey" ToolTip="Linguagem de script para automação e atalhos de teclado. ID: AutoHotkey.AutoHotkey"/>
                                            <CheckBox x:Name="ChkAppGlazeWM" Content="GlazeWM" Tag="glzr-io.glazewm" ToolTip="Gerenciador de janelas em blocos (tiling window manager) para Windows. ID: glzr-io.glazewm"/>
                                            <CheckBox x:Name="ChkAppOFGB" Content="OFGB (Remover Anúncios W11)" Tag="xM4ddy.OFGB" ToolTip="Desativa anúncios e telemetria no Explorador de Arquivos do Windows 11. ID: xM4ddy.OFGB"/>
                                            <CheckBox x:Name="ChkAppMSEdgeRedirect" Content="MSEdgeRedirect" Tag="rcmaehl.MSEdgeRedirect" ToolTip="Redireciona links do Windows (Widgets, Ajuda) para seu navegador padrão. ID: rcmaehl.MSEdgeRedirect"/>
                                            <CheckBox x:Name="ChkAppHxD" Content="HxD Hex Editor" Tag="MHNexus.HxD" ToolTip="Editor hexadecimal rápido e completo de arquivos e memória. ID: MHNexus.HxD"/>
                                            <CheckBox x:Name="ChkAppDeskflow" Content="Deskflow" Tag="Deskflow.Deskflow" ToolTip="Compartilhe mouse e teclado entre múltiplos computadores (Synergy fork). ID: Deskflow.Deskflow"/>
                                            <CheckBox x:Name="ChkAppFlux" Content="F.lux" Tag="Herf.Flux" ToolTip="Ajusta o calor da cor da tela de acordo com o horário do dia. ID: Herf.Flux"/>
                                            <CheckBox x:Name="ChkAppEnteAuth" Content="Ente Auth" Tag="ente-io.auth-desktop" ToolTip="Gerenciador open source de autenticação de 2 fatores (2FA). ID: ente-io.auth-desktop"/>
                                            <CheckBox x:Name="ChkAppKeePassXC" Content="KeePassXC" Tag="KeePassXCTeam.KeePassXC" ToolTip="Gerenciador de senhas offline criptografado e open source. ID: KeePassXCTeam.KeePassXC"/>
                                            <CheckBox x:Name="ChkAppBitwarden" Content="Bitwarden" Tag="Bitwarden.Bitwarden" ToolTip="Gerenciador de senhas em nuvem seguro e open source. ID: Bitwarden.Bitwarden"/>
                                            <CheckBox x:Name="ChkAppGoogleDrive" Content="Google Drive" Tag="Google.GoogleDrive" ToolTip="Cliente de sincronização em nuvem do Google Drive. ID: Google.GoogleDrive"/>
                                            <CheckBox x:Name="ChkAppProtonDrive" Content="Proton Drive" Tag="Proton.ProtonDrive" ToolTip="Armazenamento seguro em nuvem com criptografia de ponta a ponta. ID: Proton.ProtonDrive"/>
                                            <CheckBox x:Name="ChkAppProtonPass" Content="Proton Pass" Tag="Proton.ProtonPass" ToolTip="Gerenciador de senhas e aliases seguro do Proton. ID: Proton.ProtonPass"/>
                                            <CheckBox x:Name="ChkAppProtonAuth" Content="Proton Authenticator" Tag="Proton.ProtonAuthenticator" ToolTip="Gerenciador de autenticação de dois fatores da Proton. ID: Proton.ProtonAuthenticator"/>
                                            <CheckBox x:Name="ChkApp1Password" Content="1Password" Tag="1Password.1Password" ToolTip="Excelente gerenciador de senhas comercial. ID: 1Password.1Password"/>
                                            <CheckBox x:Name="ChkAppBlurAutoClicker" Content="Blur AutoClicker" Tag="Blur009.BlurAutoClicker" ToolTip="AutoClicker rápido de código aberto. ID: Blur009.BlurAutoClicker"/>
                                            <CheckBox x:Name="ChkAppOPAutoClicker" Content="OP AutoClicker" Tag="OPAutoClicker.OPAutoClicker" ToolTip="Autoclicker clássico simples e portátil para automações de cliques. ID: OPAutoClicker.OPAutoClicker"/>
                                            <CheckBox x:Name="ChkAppOpenRGB" Content="OpenRGB" Tag="OpenRGB.OpenRGB" ToolTip="Controle de iluminação RGB open source compatível com vários hardwares. ID: OpenRGB.OpenRGB"/>
                                            <CheckBox x:Name="ChkAppSignalRGB" Content="SignalRGB" Tag="WhirlwindFX.SignalRGB" ToolTip="Controle completo e efeitos de luz RGB em jogos e hardware. ID: WhirlwindFX.SignalRGB"/>
                                            <CheckBox x:Name="ChkAppParsec" Content="Parsec" Tag="Parsec.Parsec" ToolTip="Streaming de tela de altíssima performance para jogos e trabalho remoto. ID: Parsec.Parsec"/>
                                            <CheckBox x:Name="ChkAppVirtualBox" Content="Oracle VirtualBox" Tag="Oracle.VirtualBox" ToolTip="Software de virtualização de sistemas operacionais gratuito. ID: Oracle.VirtualBox"/>
                                            <CheckBox x:Name="ChkAppTeamViewer" Content="TeamViewer" Tag="TeamViewer.TeamViewer" ToolTip="Software tradicional para controle remoto e reuniões online. ID: TeamViewer.TeamViewer"/>
                                            <CheckBox x:Name="ChkAppTightVNC" Content="TightVNC" Tag="TightVNC.TightVNC" ToolTip="Utilitário de desktop remoto leve baseado em VNC. ID: TightVNC.TightVNC"/>
                                            <CheckBox x:Name="ChkAppTotalCommander" Content="Total Commander" Tag="Ghisler.TotalCommander" ToolTip="Gerenciador de arquivos em painel duplo clássico para power users. ID: Ghisler.TotalCommander"/>
                                            <CheckBox x:Name="ChkAppJPEGView" Content="JPEGView" Tag="sylikc.JPEGView" ToolTip="Visualizador de imagens ultrarrápido, leve e configurável. ID: sylikc.JPEGView"/>
                                        </UniformGrid>
                                    </StackPanel>
                                </Border>

                                <!-- Card 3: Ferramentas Pro e Redes -->
                                <Border Style="{StaticResource CardBorder}" Margin="0,0,0,12">
                                    <StackPanel>
                                        <TextBlock Text="🛠️ Ferramentas Pro e Redes" FontSize="13" FontWeight="Bold" Foreground="#10B981" Margin="0,0,0,8"/>
                                        <UniformGrid Columns="3">
                                            <CheckBox x:Name="ChkAppAdvancedIP" Content="Advanced IP Scanner" Tag="Famatech.AdvancedIPScanner" ToolTip="Varredura de rede local rápida e fácil de usar. ID: Famatech.AdvancedIPScanner"/>
                                            <CheckBox x:Name="ChkAppAngryIP" Content="Angry IP Scanner" Tag="angryziber.AngryIPScanner" ToolTip="Scanner de endereços IP e portas open source multiplataforma. ID: angryziber.AngryIPScanner"/>
                                            <CheckBox x:Name="ChkAppCPUZ" Content="CPU-Z" Tag="CPUID.CPU-Z" ToolTip="Exibe informações detalhadas sobre processador, placa-mãe e memória. ID: CPUID.CPU-Z"/>
                                            <CheckBox x:Name="ChkAppGPUZ" Content="GPU-Z" Tag="TechPowerUp.GPU-Z" ToolTip="Exibe dados técnicos completos sobre sua placa de vídeo. ID: TechPowerUp.GPU-Z"/>
                                            <CheckBox x:Name="ChkAppHWiNFO" Content="HWiNFO" Tag="HWiNFO.HWiNFO" ToolTip="Monitoramento de hardware avançado e relatório completo de sensores. ID: HWiNFO.HWiNFO"/>
                                            <CheckBox x:Name="ChkAppHWMonitor" Content="HWMonitor" Tag="CPUID.HWMonitor" ToolTip="Monitora temperaturas, voltagens e velocidades de ventoinhas. ID: CPUID.HWMonitor"/>
                                            <CheckBox x:Name="ChkAppDDU" Content="Display Driver Uninstaller" Tag="Wagnardsoft.DisplayDriverUninstaller" ToolTip="Remove completamente drivers de vídeo AMD/NVIDIA/Intel sem deixar resíduos. ID: Wagnardsoft.DisplayDriverUninstaller"/>
                                            <CheckBox x:Name="ChkAppMullvadVPN" Content="Mullvad VPN" Tag="Mullvad.MullvadVPN" ToolTip="Serviço de VPN open source focado em privacidade extrema. ID: Mullvad.MullvadVPN"/>
                                            <CheckBox x:Name="ChkAppProtonVPN" Content="Proton VPN" Tag="Proton.ProtonVPN" ToolTip="VPN segura com plano gratuito ilimitado desenvolvida pela Proton. ID: Proton.ProtonVPN"/>
                                            <CheckBox x:Name="ChkAppPuTTY" Content="PuTTY" Tag="SimonTatham.PuTTY" ToolTip="Cliente SSH, Telnet e Rlogin clássico para gerenciamento de servidores. ID: SimonTatham.PuTTY"/>
                                            <CheckBox x:Name="ChkAppSimplewall" Content="Simplewall" Tag="Henry++.simplewall" ToolTip="Firewall simples para bloquear tráfego de rede e telemetria do Windows. ID: Henry++.simplewall"/>
                                            <CheckBox x:Name="ChkAppWinSCP" Content="WinSCP" Tag="WinSCP.WinSCP" ToolTip="Cliente SFTP e FTP gráfico para Windows. ID: WinSCP.WinSCP"/>
                                            <CheckBox x:Name="ChkAppWireGuard" Content="WireGuard" Tag="WireGuard.WireGuard" ToolTip="Protocolo e cliente de VPN moderno de altíssima performance. ID: WireGuard.WireGuard"/>
                                            <CheckBox x:Name="ChkAppWireshark" Content="Wireshark" Tag="Wireshark.Wireshark" ToolTip="Analisador de protocolos de rede open source para auditorias. ID: Wireshark.Wireshark"/>
                                            <CheckBox x:Name="ChkAppNmap" Content="Nmap Network Scanner" Tag="Insecure.Nmap" ToolTip="Mapeador de segurança de rede e scanner de portas. ID: Insecure.Nmap"/>
                                        </UniformGrid>
                                    </StackPanel>
                                </Border>

                                <!-- Card 4: Navegadores e Internet -->
                                <Border Style="{StaticResource CardBorder}" Margin="0,0,0,12">
                                    <StackPanel>
                                        <TextBlock Text="🌐 Navegadores e Internet" FontSize="13" FontWeight="Bold" Foreground="#8B5CF6" Margin="0,0,0,8"/>
                                        <UniformGrid Columns="3">
                                            <CheckBox x:Name="ChkAppChrome" Content="Google Chrome" Tag="Google.Chrome" ToolTip="Navegador oficial do Google. ID: Google.Chrome"/>
                                            <CheckBox x:Name="ChkAppFirefox" Content="Mozilla Firefox" Tag="Mozilla.Firefox" ToolTip="Navegador livre e focado em privacidade. ID: Mozilla.Firefox"/>
                                            <CheckBox x:Name="ChkAppBrave" Content="Brave Browser" Tag="Brave.Brave" ToolTip="Navegador rápido com bloqueador de anúncios nativo. ID: Brave.Brave"/>
                                            <CheckBox x:Name="ChkAppEdge" Content="Microsoft Edge" Tag="Microsoft.Edge" ToolTip="Navegador Chromium da Microsoft. ID: Microsoft.Edge"/>
                                            <CheckBox x:Name="ChkAppVivaldi" Content="Vivaldi" Tag="Vivaldi.Vivaldi" ToolTip="Navegador flexível e cheio de recursos para usuários avançados. ID: Vivaldi.Vivaldi"/>
                                            <CheckBox x:Name="ChkAppQBit" Content="qBittorrent" Tag="qBittorrent.qBittorrent" ToolTip="Cliente de torrent open source leve e livre de propagandas. ID: qBittorrent.qBittorrent"/>
                                        </UniformGrid>
                                    </StackPanel>
                                </Border>

                                <!-- Card 5: Desenvolvimento -->
                                <Border Style="{StaticResource CardBorder}" Margin="0,0,0,12">
                                    <StackPanel>
                                        <TextBlock Text="💻 Desenvolvimento" FontSize="13" FontWeight="Bold" Foreground="#EC4899" Margin="0,0,0,8"/>
                                        <UniformGrid Columns="3">
                                            <CheckBox x:Name="ChkAppVSCode" Content="VS Code" Tag="Microsoft.VisualStudioCode" ToolTip="Editor de código leve e extensível da Microsoft. ID: Microsoft.VisualStudioCode"/>
                                            <CheckBox x:Name="ChkAppNotepadPlus" Content="Notepad++" Tag="NotepadPlusPlus.NotepadPlusPlus" ToolTip="Editor de texto e código fonte leve. ID: NotepadPlusPlus.NotepadPlusPlus"/>
                                            <CheckBox x:Name="ChkAppGit" Content="Git" Tag="Git.Git" ToolTip="Sistema de controle de versão distribuído. ID: Git.Git"/>
                                            <CheckBox x:Name="ChkAppGitHub" Content="GitHub Desktop" Tag="GitHub.GitHubDesktop" ToolTip="Interface amigável para repositórios Git/GitHub. ID: GitHub.GitHubDesktop"/>
                                            <CheckBox x:Name="ChkAppPython" Content="Python 3" Tag="Python.Python.3.12" ToolTip="Linguagem de programação limpa e poderosa. ID: Python.Python.3.12"/>
                                            <CheckBox x:Name="ChkAppNodeJS" Content="Node.js (LTS)" Tag="OpenJS.NodeJS.LTS" ToolTip="Ambiente de execução Javascript de servidor. ID: OpenJS.NodeJS.LTS"/>
                                        </UniformGrid>
                                    </StackPanel>
                                </Border>

                                <!-- Card 6: Comunicação e Multimídia -->
                                <Border Style="{StaticResource CardBorder}" Margin="0,0,0,12">
                                    <StackPanel>
                                        <TextBlock Text="🎬 Comunicação e Multimídia" FontSize="13" FontWeight="Bold" Foreground="#EF4444" Margin="0,0,0,8"/>
                                        <UniformGrid Columns="3">
                                            <CheckBox x:Name="ChkAppDiscord" Content="Discord" Tag="Discord.Discord" ToolTip="Plataforma de voz e texto para comunidades de jogos. ID: Discord.Discord"/>
                                            <CheckBox x:Name="ChkAppTelegram" Content="Telegram Desktop" Tag="Telegram.TelegramDesktop" ToolTip="Aplicativo de mensagens rápido e seguro. ID: Telegram.TelegramDesktop"/>
                                            <CheckBox x:Name="ChkAppZoom" Content="Zoom Meetings" Tag="Zoom.Zoom" ToolTip="Software de chamadas de vídeo e reuniões online. ID: Zoom.Zoom"/>
                                            <CheckBox x:Name="ChkAppTeams" Content="Microsoft Teams" Tag="Microsoft.Teams" ToolTip="Plataforma corporativa de reuniões e chat. ID: Microsoft.Teams"/>
                                            <CheckBox x:Name="ChkAppSlack" Content="Slack" Tag="Slack.Slack" ToolTip="Mensageiro corporativo para gerenciamento de projetos. ID: Slack.Slack"/>
                                            <CheckBox x:Name="ChkAppVLC" Content="VLC Media Player" Tag="VideoLAN.VLC" ToolTip="Reprodutor multimídia livre e open source de codecs universais. ID: VideoLAN.VLC"/>
                                            <CheckBox x:Name="ChkAppOBS" Content="OBS Studio" Tag="Obsproject.OBSStudio" ToolTip="Gravação de tela e transmissão de lives profissional. ID: Obsproject.OBSStudio"/>
                                            <CheckBox x:Name="ChkAppShareX" Content="ShareX" Tag="ShareX.ShareX" ToolTip="Captura de tela, upload de imagens e gravação de GIFs/Vídeos. ID: ShareX.ShareX"/>
                                            <CheckBox x:Name="ChkAppBlender" Content="Blender" Tag="BlenderFoundation.Blender" ToolTip="Modelagem 3D, animação e efeitos especiais livre. ID: BlenderFoundation.Blender"/>
                                            <CheckBox x:Name="ChkAppSteam" Content="Steam" Tag="Valve.Steam" ToolTip="Maior loja digital de jogos de PC do mundo. ID: Valve.Steam"/>
                                            <CheckBox x:Name="ChkAppEpic" Content="Epic Games Launcher" Tag="EpicGames.EpicGamesLauncher" ToolTip="Plataforma de jogos digitais e Unreal Engine. ID: EpicGames.EpicGamesLauncher"/>
                                        </UniformGrid>
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                        </ScrollViewer>

                        <!-- Botões de Ação -->
                        <Grid Grid.Row="2">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Button Grid.Column="0" x:Name="BtnSelectAllApps" Content="Marcar Todos" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="12,8" Margin="0,0,10,0"/>
                            <Button Grid.Column="1" x:Name="BtnDeselectAllApps" Content="Desmarcar Todos" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="12,8"/>
                            <Button Grid.Column="3" x:Name="BtnRunApps" Content="📦 Instalar Programas Selecionados" Style="{StaticResource AccentButton}"/>
                        </Grid>
                    </Grid>

                    <!-- TELA 7: DESINSTALADOR DE APLICATIVOS (Estilo Revo Uninstaller) -->
                    <Grid x:Name="GridUninstall" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Titulo da Aba -->
                        <StackPanel Grid.Row="0" Margin="0,0,0,10">
                            <TextBlock Text="Desinstalador de Programas" FontSize="18" FontWeight="Bold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Remova programas instalados e faça uma limpeza profunda de pastas e registros residuais." FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>

                        <!-- Barra de Pesquisa e Botão Atualizar -->
                        <Grid Grid.Row="1" Margin="0,0,0,10">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBox x:Name="TxtSearchUninstall" Grid.Column="0" 
                                     Background="#111827" Foreground="#F1F5F9" BorderBrush="#1F2937" 
                                     BorderThickness="1.5" FontSize="13" Padding="10,8" 
                                     VerticalContentAlignment="Center"
                                     Tag="🔍 Pesquisar programa instalado..."/>
                            <TextBlock x:Name="LblUninstallCount" Grid.Column="1" Foreground="#64748B" FontSize="12" VerticalAlignment="Center" Margin="12,0,0,0"/>
                            <Button Grid.Column="2" x:Name="BtnRefreshUninstall" Content="🔄 Atualizar Lista" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="12,8" Margin="10,0,0,0"/>
                        </Grid>

                        <!-- Lista de Programas e Painel de Detalhes -->
                        <Grid Grid.Row="2">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="280"/>
                            </Grid.ColumnDefinitions>

                            <!-- ListView de Programas Instalados -->
                            <ListView x:Name="LvInstalledApps" Grid.Column="0" 
                                      Background="#0D1117" Foreground="#F1F5F9" 
                                      BorderBrush="#1F2937" BorderThickness="1.5" 
                                      FontSize="13" Margin="0,0,10,0"
                                      SelectionMode="Single">
                                <ListView.View>
                                    <GridView>
                                        <GridViewColumn Header="Nome" Width="220" DisplayMemberBinding="{Binding Name}"/>
                                        <GridViewColumn Header="Publicador" Width="140" DisplayMemberBinding="{Binding Publisher}"/>
                                        <GridViewColumn Header="Tamanho" Width="80" DisplayMemberBinding="{Binding Size}"/>
                                        <GridViewColumn Header="Data" Width="90" DisplayMemberBinding="{Binding InstallDate}"/>
                                    </GridView>
                                </ListView.View>
                            </ListView>

                            <!-- Painel Lateral de Detalhes -->
                            <Border Grid.Column="1" Style="{StaticResource CardBorder}" Margin="0">
                                <ScrollViewer VerticalScrollBarVisibility="Auto">
                                    <StackPanel>
                                        <TextBlock Text="Detalhes do Programa" FontSize="14" FontWeight="Bold" Foreground="#F8FAFC" Margin="0,0,0,12"/>
                                        
                                        <TextBlock Text="Nome:" Foreground="#64748B" FontSize="11" Margin="0,0,0,2"/>
                                        <TextBlock x:Name="TxtDetailName" Text="-" Foreground="#F1F5F9" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,8"/>
                                        
                                        <TextBlock Text="Publicador:" Foreground="#64748B" FontSize="11" Margin="0,0,0,2"/>
                                        <TextBlock x:Name="TxtDetailPublisher" Text="-" Foreground="#F1F5F9" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,8"/>
                                        
                                        <TextBlock Text="Versão:" Foreground="#64748B" FontSize="11" Margin="0,0,0,2"/>
                                        <TextBlock x:Name="TxtDetailVersion" Text="-" Foreground="#F1F5F9" FontSize="12" Margin="0,0,0,8"/>
                                        
                                        <TextBlock Text="Tamanho Estimado:" Foreground="#64748B" FontSize="11" Margin="0,0,0,2"/>
                                        <TextBlock x:Name="TxtDetailSize" Text="-" Foreground="#F1F5F9" FontSize="12" Margin="0,0,0,8"/>
                                        
                                        <TextBlock Text="Data de Instalação:" Foreground="#64748B" FontSize="11" Margin="0,0,0,2"/>
                                        <TextBlock x:Name="TxtDetailDate" Text="-" Foreground="#F1F5F9" FontSize="12" Margin="0,0,0,8"/>
                                        
                                        <TextBlock Text="Local de Instalação:" Foreground="#64748B" FontSize="11" Margin="0,0,0,2"/>
                                        <TextBlock x:Name="TxtDetailLocation" Text="-" Foreground="#CBD5E1" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,12"/>

                                        <TextBlock Text="Resíduos Encontrados:" Foreground="#64748B" FontSize="11" Margin="0,0,0,2"/>
                                        <TextBlock x:Name="TxtDetailLeftovers" Text="Clique em 'Analisar Resíduos' para escanear." Foreground="#FBBF24" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,12"/>

                                        <Button x:Name="BtnScanLeftovers" Content="🔍 Analisar Resíduos" Style="{StaticResource ModernButton}" Background="#1E293B" Padding="10,8" Margin="0,0,0,8"/>
                                    </StackPanel>
                                </ScrollViewer>
                            </Border>
                        </Grid>

                        <!-- Botões de Ação -->
                        <Grid Grid.Row="3" Margin="0,12,0,0">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Button Grid.Column="0" x:Name="BtnUninstallNormal" Content="🗑️ Desinstalar" Style="{StaticResource ModernButton}" Background="#B91C1C" Padding="14,10" Margin="0,0,10,0"/>
                            <Button Grid.Column="1" x:Name="BtnUninstallDeep" Content="🔥 Desinstalar + Limpeza Profunda" Style="{StaticResource AccentButton}" Padding="14,10"/>
                        </Grid>
                    </Grid>

                </Grid>
            </Grid>

            <!-- Barra de Status Inferior -->
            <Border Grid.Row="2" Background="#111827" BorderBrush="#1F2937" BorderThickness="0,1,0,0" Padding="15,0,15,0">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column="0" x:Name="TxtStatus" Text="Pronto" Foreground="#64748B" FontSize="11" VerticalAlignment="Center"/>
                    <TextBlock Grid.Column="1" Text="v1.0.0" Foreground="#475569" FontSize="11" VerticalAlignment="Center"/>
                </Grid>
            </Border>
        </Grid>
    </Border>
</Window>
"@

# 5. Inicialização e Parsing do XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Mapeando Elementos da Barra de Título
$titleBar = $Window.FindName("TitleBar")
$btnClose = $Window.FindName("BtnClose")
$btnMinimize = $Window.FindName("BtnMinimize")
$btnMaximize = $Window.FindName("BtnMaximize")
$windowBorder = $Window.FindName("WindowBorder")

# Mapeando Abas do Menu Lateral
$btnTabPainel = $Window.FindName("BtnTabPainel")
$btnTabDebloat = $Window.FindName("BtnTabDebloat")
$btnTabDesempenho = $Window.FindName("BtnTabDesempenho")
$btnTabLimpeza = $Window.FindName("BtnTabLimpeza")
$btnTabApps = $Window.FindName("BtnTabApps")
$btnTabUninstall = $Window.FindName("BtnTabUninstall")
$btnTabRede = $Window.FindName("BtnTabRede")
$btnTabAtivacao = $Window.FindName("BtnTabAtivacao")
$btnTabLogs = $Window.FindName("BtnTabLogs")
$btnTabOffice = $Window.FindName("BtnTabOffice")

# Mapeando Links do Desenvolvedor
$btnLinkInstagram = $Window.FindName("BtnLinkInstagram")
$btnLinkGithub = $Window.FindName("BtnLinkGithub")
$btnDonate = $Window.FindName("BtnDonate")
$imgQrCode = $null
if ($null -ne $btnDonate -and $null -ne $btnDonate.ToolTip) {
    $panel = $btnDonate.ToolTip.Content
    if ($null -ne $panel) {
        foreach ($child in $panel.Children) {
            if ($child.GetType().Name -eq "Image") {
                $imgQrCode = $child
                break
            }
        }
    }
}

# Mapeando Telas (Grids)
$gridPainel = $Window.FindName("GridPainel")
$gridDebloat = $Window.FindName("GridDebloat")
$gridDesempenho = $Window.FindName("GridDesempenho")
$gridLimpeza = $Window.FindName("GridLimpeza")
$gridApps = $Window.FindName("GridApps")
$gridUninstall = $Window.FindName("GridUninstall")
$gridRede = $Window.FindName("GridRede")
$gridAtivacao = $Window.FindName("GridAtivacao")
$gridLogs = $Window.FindName("GridLogs")
$gridOffice = $Window.FindName("GridOffice")

# Mapeando controles da tela de Ativação
$btnRunActivation = $Window.FindName("BtnRunActivation")

# Mapeando controles da tela de Office
$btnOffice2021Tiny = $Window.FindName("BtnOffice2021Tiny")
$btnOffice2021Bitly = $Window.FindName("BtnOffice2021Bitly")
$btnOffice2019Abre = $Window.FindName("BtnOffice2019Abre")
$btnOffice2019Tiny = $Window.FindName("BtnOffice2019Tiny")

# Mapeando controles da tela de Ferramentas de Rede
$btnRedeIPConfig  = $Window.FindName("BtnRedeIPConfig")
$txtRedeIPResult  = $Window.FindName("TxtRedeIPResult")
$btnRedePing      = $Window.FindName("BtnRedePing")
$txtRedePingHost  = $Window.FindName("TxtRedePingHost")
$txtRedePingResult = $Window.FindName("TxtRedePingResult")
$btnRedeNetstat   = $Window.FindName("BtnRedeNetstat")
$txtRedeNetstatResult = $Window.FindName("TxtRedeNetstatResult")
$btnRedeFlushDNS  = $Window.FindName("BtnRedeFlushDNS")
$btnRedeReset     = $Window.FindName("BtnRedeReset")
$btnRedeRenewIP   = $Window.FindName("BtnRedeRenewIP")
$btnRedeTracert   = $Window.FindName("BtnRedeTracert")
$txtRedeTracertHost   = $Window.FindName("TxtRedeTracertHost")
$txtRedeTracertResult = $Window.FindName("TxtRedeTracertResult")

# Mapeando Elementos do Desinstalador de Apps
$txtSearchUninstall = $Window.FindName("TxtSearchUninstall")
$lblUninstallCount = $Window.FindName("LblUninstallCount")
$btnRefreshUninstall = $Window.FindName("BtnRefreshUninstall")
$lvInstalledApps = $Window.FindName("LvInstalledApps")
$txtDetailName = $Window.FindName("TxtDetailName")
$txtDetailPublisher = $Window.FindName("TxtDetailPublisher")
$txtDetailVersion = $Window.FindName("TxtDetailVersion")
$txtDetailSize = $Window.FindName("TxtDetailSize")
$txtDetailDate = $Window.FindName("TxtDetailDate")
$txtDetailLocation = $Window.FindName("TxtDetailLocation")
$txtDetailLeftovers = $Window.FindName("TxtDetailLeftovers")
$btnScanLeftovers = $Window.FindName("BtnScanLeftovers")
$btnUninstallNormal = $Window.FindName("BtnUninstallNormal")
$btnUninstallDeep = $Window.FindName("BtnUninstallDeep")

# Mapeando Elementos do Painel (Dashboard)
$txtOS = $Window.FindName("TxtOS")
$txtCPU = $Window.FindName("TxtCPU")
$txtTotalRAM = $Window.FindName("TxtTotalRAM")
$txtUptime = $Window.FindName("TxtUptime")
$lblCPU = $Window.FindName("LblCPU")
$lblRAM = $Window.FindName("LblRAM")
$lblRAMDetail = $Window.FindName("LblRAMDetail")
$barCPU = $Window.FindName("BarCPU")
$barRAM = $Window.FindName("BarRAM")
$btnCreateRestore = $Window.FindName("BtnCreateRestore")
$btnCleanRAM = $Window.FindName("BtnCleanRAM")
$lvTopProcesses = $Window.FindName("LvTopProcesses")
# Novos botões de atalhos rápidos do Painel
$btnShortcutDev = $Window.FindName("BtnShortcutDev")
$btnShortcutReg = $Window.FindName("BtnShortcutReg")
$btnShortcutNet = $Window.FindName("BtnShortcutNet")
$btnShortcutDisk = $Window.FindName("BtnShortcutDisk")
$btnShortcutUser = $Window.FindName("BtnShortcutUser")
$btnShortcutPower = $Window.FindName("BtnShortcutPower")
$btnShortcutSys = $Window.FindName("BtnShortcutSys")
$btnShortcutServ = $Window.FindName("BtnShortcutServ")
$btnShortcutNetCenter = $Window.FindName("BtnShortcutNetCenter")
$btnShortcutRes = $Window.FindName("BtnShortcutRes")

# Mapeando Elementos do Debloat
$chkDebloatBing = $Window.FindName("ChkDebloatBing")
$chkDebloatXbox = $Window.FindName("ChkDebloatXbox")
$chkDebloatOneDrive = $Window.FindName("ChkDebloatOneDrive")
$chkDebloatFeedback = $Window.FindName("ChkDebloatFeedback")
$chkDebloatGames = $Window.FindName("ChkDebloatGames")
$chkDebloatMisc = $Window.FindName("ChkDebloatMisc")
$chkDebloatTelemetry = $Window.FindName("ChkDebloatTelemetry")
$btnSelectAllDebloat = $Window.FindName("BtnSelectAllDebloat")
$btnDeselectAllDebloat = $Window.FindName("BtnDeselectAllDebloat")
$btnRunDebloat = $Window.FindName("BtnRunDebloat")
# Novos checkboxes e botão de recursos opcionais do Windows
$chkFeatureWSL = $Window.FindName("ChkFeatureWSL")
$chkFeatureSandbox = $Window.FindName("ChkFeatureSandbox")
$chkFeatureHyperV = $Window.FindName("ChkFeatureHyperV")
$chkFeatureSMB1 = $Window.FindName("ChkFeatureSMB1")
$btnApplyFeatures = $Window.FindName("BtnApplyFeatures")

# Mapeando Elementos de Tweaks (Desempenho)
$chkTweakGameMode = $Window.FindName("ChkTweakGameMode")
$chkTweakGameDVR = $Window.FindName("ChkTweakGameDVR")
$chkTweakNetworkLatency = $Window.FindName("ChkTweakNetworkLatency")
$chkTweakNetworkThrottling = $Window.FindName("ChkTweakNetworkThrottling")
$chkTweakResponsiveness = $Window.FindName("ChkTweakResponsiveness")
$chkTweakCoreParking = $Window.FindName("ChkTweakCoreParking")
$chkTweakTelemetry = $Window.FindName("ChkTweakTelemetry")
$chkTweakVisuals = $Window.FindName("ChkTweakVisuals")
$btnSelectAllTweaks = $Window.FindName("BtnSelectAllTweaks")
$btnDeselectAllTweaks = $Window.FindName("BtnDeselectAllTweaks")
$btnRunTweaks = $Window.FindName("BtnRunTweaks")
$btnWUDefault = $Window.FindName("BtnWUDefault")
$btnWUSecurity = $Window.FindName("BtnWUSecurity")
$btnWUDisable = $Window.FindName("BtnWUDisable")
# Novos controles de alteração de DNS
$cbDNS = $Window.FindName("CbDNS")
$btnApplyDNS = $Window.FindName("BtnApplyDNS")

# Mapeando Elementos da Limpeza de Disco
$chkCleanUserTemp = $Window.FindName("ChkCleanUserTemp")
$chkCleanSysTemp = $Window.FindName("ChkCleanSysTemp")
$chkCleanPrefetch = $Window.FindName("ChkCleanPrefetch")
$chkCleanLogs = $Window.FindName("ChkCleanLogs")
$chkCleanUpdateCache = $Window.FindName("ChkCleanUpdateCache")
$chkCleanRecycleBin = $Window.FindName("ChkCleanRecycleBin")
$btnSelectAllLimpeza = $Window.FindName("BtnSelectAllLimpeza")
$btnDeselectAllLimpeza = $Window.FindName("BtnDeselectAllLimpeza")
$btnRunLimpeza = $Window.FindName("BtnRunLimpeza")
# Novo botão para reparo completo do sistema (SFC e DISM)
$btnRunSystemRepair = $Window.FindName("BtnRunSystemRepair")
$btnBackupDrivers = $Window.FindName("BtnBackupDrivers")

# Mapeando Elementos do Instalador de Apps
$btnSelectAllApps = $Window.FindName("BtnSelectAllApps")
$btnDeselectAllApps = $Window.FindName("BtnDeselectAllApps")
$btnRunApps = $Window.FindName("BtnRunApps")

# Lista de elementos de checkboxes de aplicativos no XAML para mapeamento dinâmico
$chkAppNames = @(
    "ChkAppSnappyDriver", "ChkAppVCRedist", "ChkAppDirectX", "ChkAppVCRedist2010x64", "ChkAppVCRedist2010x86", "ChkAppVCRedistv14x64", "ChkAppVCRedistv14x86", "ChkAppDotNet6", "ChkAppDotNet8", "ChkAppDotNet9", "ChkAppDotNet10", "ChkAppNVCleanstall",
    "ChkApp7Zip", "ChkAppNanaZip", "ChkAppPeaZip", "ChkAppWinRAR", "ChkAppBulkCrap", "ChkAppRevo", "ChkAppWiseUninstaller",
    "ChkAppCrystalInfo", "ChkAppCrystalMark", "ChkAppEverything", "ChkAppFiles", "ChkAppNilesoftShell", "ChkAppRufus",
    "ChkAppVentoy", "ChkAppUniGetUI", "ChkAppWizTree", "ChkAppTreeSize", "ChkAppTranslucentTB", "ChkAppAutoHotkey",
    "ChkAppGlazeWM", "ChkAppOFGB", "ChkAppMSEdgeRedirect", "ChkAppHxD", "ChkAppDeskflow", "ChkAppFlux", "ChkAppEnteAuth",
    "ChkAppKeePassXC", "ChkAppBitwarden", "ChkAppGoogleDrive", "ChkAppProtonDrive", "ChkAppProtonPass", "ChkAppProtonAuth",
    "ChkApp1Password", "ChkAppBlurAutoClicker", "ChkAppOPAutoClicker", "ChkAppOpenRGB", "ChkAppSignalRGB", "ChkAppParsec",
    "ChkAppVirtualBox", "ChkAppTeamViewer", "ChkAppTightVNC", "ChkAppTotalCommander", "ChkAppJPEGView",
    "ChkAppAdvancedIP", "ChkAppAngryIP", "ChkAppCPUZ", "ChkAppGPUZ", "ChkAppHWiNFO", "ChkAppHWMonitor", "ChkAppDDU",
    "ChkAppMullvadVPN", "ChkAppProtonVPN", "ChkAppPuTTY", "ChkAppSimplewall", "ChkAppWinSCP", "ChkAppWireGuard",
    "ChkAppWireshark", "ChkAppNmap",
    "ChkAppChrome", "ChkAppFirefox", "ChkAppBrave", "ChkAppEdge", "ChkAppVivaldi", "ChkAppQBit",
    "ChkAppVSCode", "ChkAppNotepadPlus", "ChkAppGit", "ChkAppGitHub", "ChkAppPython", "ChkAppNodeJS",
    "ChkAppDiscord", "ChkAppTelegram", "ChkAppZoom", "ChkAppTeams", "ChkAppSlack", "ChkAppVLC", "ChkAppOBS",
    "ChkAppShareX", "ChkAppBlender", "ChkAppSteam", "ChkAppEpic"
)

$appCheckboxObjects = @()
foreach ($name in $chkAppNames) {
    $chk = $Window.FindName($name)
    if ($chk) {
        $appCheckboxObjects += $chk
    }
}

# Mapeando Elementos dos Logs e Status
$txtLogs = $Window.FindName("TxtLogs")
$btnCopyLogs = $Window.FindName("BtnCopyLogs")
$btnClearLogs = $Window.FindName("BtnClearLogs")
$txtStatus = $Window.FindName("TxtStatus")

# Preencher Informações de Hardware Iniciais
$txtOS.Text = $osName
$txtCPU.Text = $cpuName
$txtTotalRAM.Text = "$totalRamGB GB"

# 6. Funções Auxiliares de Controle de Fluxo e UI

# Mantém a UI responsiva durante loops longos
function Out-DoEvents {
    $frame = New-Object System.Windows.Threading.DispatcherFrame
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [System.Windows.Threading.DispatcherOperationCallback]{
            param($f)
            $f.Continue = $false
            return $null
        },
        $frame
    )
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
}

# Escreve no console de logs integrado
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    $prefix = "[$timestamp] [$Level]"
    $line = "$prefix $Message`r`n"
    
    $txtLogs.AppendText($line)
    $txtLogs.ScrollToEnd()
    Out-DoEvents
}

# Atualiza o texto na barra de status
function Set-Status {
    param([string]$StatusText)
    $txtStatus.Text = $StatusText
    Out-DoEvents
}

# Gerenciamento de abas
function Switch-Tab {
    param([string]$tabName)
    
    $grids = @{
        "Painel"      = $gridPainel
        "Debloat"     = $gridDebloat
        "Desempenho"  = $gridDesempenho
        "Limpeza"     = $gridLimpeza
        "Apps"        = $gridApps
        "Uninstall"   = $gridUninstall
        "Rede"        = $gridRede
        "Ativacao"    = $gridAtivacao
        "Office"      = $gridOffice
        "Logs"        = $gridLogs
    }
    
    $buttons = @{
        "Painel"      = $btnTabPainel
        "Debloat"     = $btnTabDebloat
        "Desempenho"  = $btnTabDesempenho
        "Limpeza"     = $btnTabLimpeza
        "Apps"        = $btnTabApps
        "Uninstall"   = $btnTabUninstall
        "Rede"        = $btnTabRede
        "Ativacao"    = $btnTabAtivacao
        "Office"      = $btnTabOffice
        "Logs"        = $btnTabLogs
    }
    
    foreach ($key in $grids.Keys) {
        $grids[$key].Visibility = [System.Windows.Visibility]::Collapsed
        $buttons[$key].Background = [System.Windows.Media.Brush]"#00000000"
        $buttons[$key].Foreground = [System.Windows.Media.Brush]"#94A3B8"
    }
    
    $grids[$tabName].Visibility = [System.Windows.Visibility]::Visible
    $buttons[$tabName].Background = [System.Windows.Media.Brush]"#1E293B"
    $buttons[$tabName].Foreground = [System.Windows.Media.Brush]"#F8FAFC"
}

# 7. Regras e Ações de Otimização

# Criar Ponto de Restauração
function Action-CreateRestorePoint {
    Register-Action "limpeza"
    Set-Status "Criando ponto de restauração..."
    Switch-Tab "Logs"
    Write-Log "Iniciando criação de Ponto de Restauração do Windows..."
    
    try {
        # Habilita restauração de sistema no drive principal
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Write-Log "Habilitado Restauração de Sistema para drive C:\"
        
        # Cria o ponto
        Checkpoint-Computer -Description "Otimizacao Samack WinUtil" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Ponto de Restauração criado com sucesso!" "SUCCESS"
    } catch {
        Write-Log "Erro ao criar ponto de restauração: $_. É necessário estar rodando como Administrador e que as diretivas de grupo permitam." "ERROR"
        [System.Windows.MessageBox]::Show("Não foi possível criar o ponto de restauração. Certifique-se de que o serviço de Restauração do Sistema não esteja desativado por política de grupo.", "Aviso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    }
    
    Set-Status "Pronto"
}

# Otimização Dinâmica de RAM (EmptyWorkingSets)
function Action-OptimizeRAM {
    Register-Action "limpeza"
    Set-Status "Limpando memória RAM..."
    Switch-Tab "Logs"
    Write-Log "Iniciando otimização rápida de memória RAM..."
    
    # Chama o helper compilado em C# para esvaziar working sets
    $freedBytes = [MemoryCleaner]::Clean()
    $freedMB = [Math]::Round($freedBytes / 1MB, 2)
    
    Write-Log "Memória RAM otimizada! Foram liberados cerca de $freedMB MB da área de trabalho ativa." "SUCCESS"
    
    # Atualiza as informações de recursos na UI imediatamente
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) {
        $total = $os.TotalVisibleMemorySize
        $free = $os.FreePhysicalMemory
        $used = $total - $free
        $pct = [Math]::Round(($used / $total) * 100, 0)
        $barRAM.Value = $pct
        $lblRAM.Text = "$pct%"
        $usedGB = [Math]::Round($used / 1MB, 1)
        $totalGB = [Math]::Round($total / 1MB, 1)
        $lblRAMDetail.Text = "$usedGB GB usados de $totalGB GB"
    }
    
    Set-Status "Pronto"
}

# Execução do Debloat de Aplicativos Selecionados
function Action-RunDebloat {
    Register-Action "debloat"
    Set-Status "Executando remoção de aplicativos..."
    Switch-Tab "Logs"
    Write-Log "Iniciando processo de Debloat do Windows..."
    
    # Verifica se os comandos AppX estão disponíveis no sistema atual
    if (-not (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) {
        Write-Log "Aviso: Esta versão do Windows não suporta o gerenciamento de pacotes AppX/UWP." "WARNING"
        Write-Log "Processo de debloat encerrado." "INFO"
        Set-Status "Pronto"
        [System.Windows.MessageBox]::Show("Sua versão do Windows não possui suporte para aplicativos UWP/AppX para debloat.", "Recurso não suportado", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    
    $packagesToRemove = @()

    if ($chkDebloatBing.IsChecked) {
        $packagesToRemove += @("*BingNews*", "*BingWeather*", "*BingSports*", "*BingFinance*", "*BingSearch*")
        Write-Log "Adicionado aos alvos: Microsoft Bing (Clima/Notícias/Buscas)"
    }
    if ($chkDebloatXbox.IsChecked) {
        $packagesToRemove += @("*XboxApp*", "*XboxGameOverlay*", "*XboxGamingOverlay*", "*XboxSpeechToTextOverlay*", "*XboxIdentityProvider*")
        Write-Log "Adicionado aos alvos: Componentes Xbox"
    }
    if ($chkDebloatFeedback.IsChecked) {
        $packagesToRemove += @("*WindowsFeedbackHub*", "*GetHelp*", "*Getstarted*")
        Write-Log "Adicionado aos alvos: Aplicativos de Suporte e Feedback"
    }
    if ($chkDebloatGames.IsChecked) {
        $packagesToRemove += @("*MicrosoftSolitaireCollection*", "*GamingServices*")
        Write-Log "Adicionado aos alvos: Coleção Solitaire e Serviços de Jogos"
    }
    if ($chkDebloatMisc.IsChecked) {
        $packagesToRemove += @("*People*", "*WindowsMaps*", "*Wallet*", "*ZuneMusic*", "*ZuneVideo*", "*Messaging*", "*3DBuilder*", "*YourPhone*")
        Write-Log "Adicionado aos alvos: Contatos, Mapas, Carteira e Filmes & TV"
    }

    # Desinstala os pacotes selecionados
    if ($packagesToRemove.Count -gt 0) {
        foreach ($pkg in $packagesToRemove) {
            Write-Log "Pesquisando pacote: $pkg..."
            $apps = Get-AppxPackage -AllUsers -Name $pkg -ErrorAction SilentlyContinue
            foreach ($app in $apps) {
                Write-Log "Removendo pacote do usuário: $($app.PackageFullName)"
                Remove-AppxPackage -Package $app.PackageFullName -ErrorAction SilentlyContinue
            }
            
            $provApps = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $pkg }
            foreach ($prov in $provApps) {
                Write-Log "Removendo provisão do sistema: $($prov.PackageName)"
                Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue
            }
        }
    }

    # Desinstalação do OneDrive se selecionado
    if ($chkDebloatOneDrive.IsChecked) {
        Write-Log "Iniciando desinstalação completa do OneDrive..."
        taskkill /f /im OneDrive.exe 2>$null
        Out-DoEvents
        
        $uninstallPath = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
        if (-not (Test-Path $uninstallPath)) {
            $uninstallPath = "$env:SystemRoot\System32\OneDriveSetup.exe"
        }
        
        if (Test-Path $uninstallPath) {
            Write-Log "Executando desinstalador oficial do OneDrive..."
            Start-Process -FilePath $uninstallPath -ArgumentList "/uninstall" -NoNewWindow -Wait
        }
        
        Write-Log "Limpando pastas residuais do OneDrive..."
        Remove-Item -Path "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:PROGRAMDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Telemetria UWP se selecionada
    if ($chkDebloatTelemetry.IsChecked) {
        Write-Log "Removendo recursos de Telemetria de apps instalados..."
        # Desabilita o Appx Telemetry no registro
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsAccessDiagnosticInfo" -Value 2 -Type DWord -ErrorAction SilentlyContinue
        Write-Log "Telemetria de Apps configurada para recusar logs."
    }

    Write-Log "Processo de desinstalação de bloatware concluído!" "SUCCESS"
    Set-Status "Pronto"
    [System.Windows.MessageBox]::Show("Remoção de aplicativos concluída!", "Sucesso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
}

# Execução das Otimizações (Tweaks)
function Action-RunTweaks {
    Register-Action "desempenho"
    Set-Status "Aplicando otimizações..."
    Switch-Tab "Logs"
    Write-Log "Iniciando otimizações de Desempenho e Modo de Jogo..."

    # Modo de Jogo
    if ($chkTweakGameMode.IsChecked) {
        if ($global:isWindows10Or11) {
            Write-Log "Ativando Modo de Jogo do Windows..."
            New-Item -Path "HKCU:\Software\Microsoft\GameBar" -Force | Out-Null
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Write-Log "Modo de Jogo ativado com sucesso."
        } else {
            Write-Log "Aviso: Modo de Jogo não é aplicável nesta versão do Windows." "WARNING"
        }
    }

    # Game DVR
    if ($chkTweakGameDVR.IsChecked) {
        if ($global:isWindows10Or11) {
            Write-Log "Desativando gravação de tela em segundo plano (Game DVR)..."
            New-Item -Path "HKCU:\System\GameConfigStore" -Force | Out-Null
            Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            
            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Force | Out-Null
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            Write-Log "Game DVR desativado."
        } else {
            Write-Log "Aviso: Game DVR não é aplicável nesta versão do Windows." "WARNING"
        }
    }

    # Latência de Rede (Nagle's Algorithm)
    if ($chkTweakNetworkLatency.IsChecked) {
        Write-Log "Aplicando tweaks de redução de latência TCP/IP (Nagle)..."
        $interfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        if (Test-Path $interfacesPath) {
            Get-ChildItem -Path $interfacesPath | ForEach-Object {
                Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            }
            Write-Log "Configurações de TcpAckFrequency e TCPNoDelay ajustadas para todas as interfaces de rede."
        }
    }

    # Throttling de Rede
    if ($chkTweakNetworkThrottling.IsChecked) {
        Write-Log "Desativando limitador de largura de banda de rede (Network Throttling)..."
        $profilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        if (Test-Path $profilePath) {
            Set-ItemProperty -Path $profilePath -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -ErrorAction SilentlyContinue
            Write-Log "Throttling de Rede desativado com sucesso (Index 0xFFFFFFFF)."
        }
    }

    # Tempo de Resposta (SystemResponsiveness)
    if ($chkTweakResponsiveness.IsChecked) {
        Write-Log "Configurando prioridade máxima para tarefas em primeiro plano (Responsividade)..."
        $profilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        if (Test-Path $profilePath) {
            Set-ItemProperty -Path $profilePath -Name "SystemResponsiveness" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        }
        
        $gamesTaskPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        if (Test-Path $gamesTaskPath) {
            Set-ItemProperty -Path $gamesTaskPath -Name "GPU Priority" -Value 8 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $gamesTaskPath -Name "Priority" -Value 6 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $gamesTaskPath -Name "Scheduling Category" -Value "High" -Type String -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $gamesTaskPath -Name "SFIO Priority" -Value "High" -Type String -ErrorAction SilentlyContinue
        }
        Write-Log "Prioridade de agendamento do processador ajustada para Games."
    }

    # CPU Core Parking
    if ($chkTweakCoreParking.IsChecked) {
        Write-Log "Desabilitando CPU Core Parking para estabilidade do clock..."
        # Tweak via powercfg para evitar hibernação de núcleos de processador ativos
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c3df-4b9d-a604-48f5a560406d 100 2>$null
        powercfg -setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c3df-4b9d-a604-48f5a560406d 100 2>$null
        powercfg -setactive SCHEME_CURRENT 2>$null
        Write-Log "Core Parking configurado para manter 100% de núcleos ativos sob demanda."
    }

    # Telemetria do Windows
    if ($chkTweakTelemetry.IsChecked) {
        Write-Log "Parando e desativando serviços de telemetria..."
        Stop-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
        
        Stop-Service -Name "dmwappushservice" -ErrorAction SilentlyContinue
        Set-Service -Name "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
        
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Write-Log "Telemetria de sistema desabilitada nos serviços e políticas de grupo."
    }

    # Efeitos Visuais
    if ($chkTweakVisuals.IsChecked) {
        Write-Log "Desativando efeitos visuais pesados e animações..."
        $visualFXPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        if (Test-Path $visualFXPath) {
            Set-ItemProperty -Path $visualFXPath -Name "VisualFXSetting" -Value 2 -Type DWord -ErrorAction SilentlyContinue
        }
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](144,20,3,128,16,0,0,0)) -Type Binary -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Type String -ErrorAction SilentlyContinue
        Write-Log "Efeitos visuais minimizados."
    }

    Write-Log "Otimizações aplicadas com sucesso!" "SUCCESS"
    Set-Status "Pronto"
    [System.Windows.MessageBox]::Show("Ajustes de desempenho aplicados com sucesso!", "Sucesso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
}

# Restaurar Windows Update ao Padrão de Fábrica
function Action-SetWUDefault {
    Set-Status "Restaurando Windows Update..."
    Switch-Tab "Logs"
    Write-Log "Iniciando restauração do Windows Update para as configurações de fábrica..."

    try {
        # Remove chaves de políticas do Windows Update
        Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\AU" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue

        # Restaura o tipo de inicialização dos serviços para Manual/Automático
        Set-Service -Name "wuauserv" -StartupType Manual -ErrorAction SilentlyContinue
        Set-Service -Name "bits" -StartupType Manual -ErrorAction SilentlyContinue
        Set-Service -Name "dosvc" -StartupType Manual -ErrorAction SilentlyContinue
        Set-Service -Name "UsoSvc" -StartupType Manual -ErrorAction SilentlyContinue

        # Inicia os serviços principais
        Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
        Start-Service -Name "bits" -ErrorAction SilentlyContinue
        Start-Service -Name "dosvc" -ErrorAction SilentlyContinue
        Start-Service -Name "UsoSvc" -ErrorAction SilentlyContinue

        Write-Log "Windows Update restaurado com sucesso! Nenhuma alteração ativa." "SUCCESS"
        Set-Status "Pronto"
        [System.Windows.MessageBox]::Show("Windows Update restaurado com sucesso para os padrões do sistema!", "Sucesso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        Write-Log "Erro ao restaurar o Windows Update: $_" "ERROR"
        Set-Status "Pronto"
    }
}

# Configurar Segurança Balanceada para o Windows Update
function Action-SetWUSecurity {
    Set-Status "Configurando Segurança Balanceada..."
    Switch-Tab "Logs"
    Write-Log "Iniciando aplicação da configuração de Segurança Balanceada..."

    try {
        $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        if (-not (Test-Path $wuPath)) { New-Item -Path $wuPath -Force | Out-Null }

        if ($global:isWindows10Or11) {
            # Adia grandes atualizações de recursos por 365 dias
            Set-ItemProperty -Path $wuPath -Name "DeferFeatureUpdates" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $wuPath -Name "DeferFeatureUpdatesPeriodInDays" -Value 365 -Type DWord -ErrorAction SilentlyContinue

            # Adia atualizações de segurança por 4 dias
            Set-ItemProperty -Path $wuPath -Name "DeferQualityUpdates" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $wuPath -Name "DeferQualityUpdatesPeriodInDays" -Value 4 -Type DWord -ErrorAction SilentlyContinue

            # Bloqueia a instalação de drivers através do Windows Update
            Set-ItemProperty -Path $wuPath -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        }

        # Impede reinicialização automática forçada com usuários logados
        $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        if (-not (Test-Path $auPath)) { New-Item -Path $auPath -Force | Out-Null }
        Set-ItemProperty -Path $auPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord -ErrorAction SilentlyContinue

        # Garante que os serviços de atualização e segurança estejam ativos e configurados como Manual
        Set-Service -Name "wuauserv" -StartupType Manual -ErrorAction SilentlyContinue
        Set-Service -Name "bits" -StartupType Manual -ErrorAction SilentlyContinue
        
        Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
        Start-Service -Name "bits" -ErrorAction SilentlyContinue

        if ($global:isWindows10Or11) {
            Set-Service -Name "dosvc" -StartupType Manual -ErrorAction SilentlyContinue
            Set-Service -Name "UsoSvc" -StartupType Manual -ErrorAction SilentlyContinue
            Start-Service -Name "dosvc" -ErrorAction SilentlyContinue
            Start-Service -Name "UsoSvc" -ErrorAction SilentlyContinue
        }

        Write-Log "Configurações de Segurança Balanceada aplicadas com SUCESSO!" "SUCCESS"
        Write-Log "  - Recursos (Feature Updates) adiados: 365 dias"
        Write-Log "  - Correções (Security Updates) adiadas: 4 dias"
        Write-Log "  - Atualização automática de drivers: BLOQUEADA"
        Set-Status "Pronto"
        [System.Windows.MessageBox]::Show("Configuração de Segurança Balanceada aplicada com sucesso!", "Sucesso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        Write-Log "Erro ao aplicar Segurança Balanceada: $_" "ERROR"
        Set-Status "Pronto"
    }
}

# Desativar Completamente o Windows Update
function Action-SetWUDisable {
    Set-Status "Desativando Windows Update..."
    Switch-Tab "Logs"
    Write-Log "Iniciando desativação completa do Windows Update..."

    try {
        # Para e desativa todos os serviços relacionados
        Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
        Set-Service -Name "wuauserv" -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "Serviço wuauserv (Windows Update) desativado."

        Stop-Service -Name "bits" -Force -ErrorAction SilentlyContinue
        Set-Service -Name "bits" -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "Serviço bits (Serviço de Transferência Inteligente de Plano de Fundo) desativado."

        if ($global:isWindows10Or11) {
            Stop-Service -Name "dosvc" -Force -ErrorAction SilentlyContinue
            Set-Service -Name "dosvc" -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "Serviço dosvc (Otimização de Entrega) desativado."

            Stop-Service -Name "UsoSvc" -Force -ErrorAction SilentlyContinue
            Set-Service -Name "UsoSvc" -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "Serviço UsoSvc (Update Orchestrator) desativado."
        }

        # Aplica políticas restritivas para bloquear acesso
        $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        if (-not (Test-Path $wuPath)) { New-Item -Path $wuPath -Force | Out-Null }
        Set-ItemProperty -Path $wuPath -Name "DisableWindowsUpdateAccess" -Value 1 -Type DWord -ErrorAction SilentlyContinue

        $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        if (-not (Test-Path $auPath)) { New-Item -Path $auPath -Force | Out-Null }
        Set-ItemProperty -Path $auPath -Name "NoAutoUpdate" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $auPath -Name "AUOptions" -Value 1 -Type DWord -ErrorAction SilentlyContinue

        Write-Log "Windows Update desativado com SUCESSO!" "SUCCESS"
        Write-Log "  - Serviços desativados e bloqueados."
        Write-Log "  - Acesso ao painel de atualizações bloqueado via GPO."
        Set-Status "Pronto"
        [System.Windows.MessageBox]::Show("Windows Update desativado com sucesso! Lembre-se de reativar no futuro para atualizar o sistema.", "Sucesso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        Write-Log "Erro ao desativar o Windows Update: $_" "ERROR"
        Set-Status "Pronto"
    }
}

# Aplica a configuração do DNS selecionado
function Action-ApplyDNS {
    Register-Action "desempenho"
    Set-Status "Aplicando DNS..."
    Switch-Tab "Logs"
    Write-Log "Iniciando configuração de DNS..."

    $selIndex = $cbDNS.SelectedIndex
    if ($selIndex -lt 0) { $selIndex = 0 }

    # Define os IPs correspondentes ao índice selecionado
    $dnsAddresses = $null
    $dnsName = ""

    switch ($selIndex) {
        0 { $dnsName = "Padrão (DHCP)" }
        1 { $dnsName = "Cloudflare DNS (1.1.1.1 / 1.0.0.1)"; $dnsAddresses = @("1.1.1.1", "1.0.0.1") }
        2 { $dnsName = "Google DNS (8.8.8.8 / 8.8.4.4)"; $dnsAddresses = @("8.8.8.8", "8.8.4.4") }
        3 { $dnsName = "AdGuard DNS (94.140.14.14 / 94.140.15.15)"; $dnsAddresses = @("94.140.14.14", "94.140.15.15") }
        4 { $dnsName = "OpenDNS (208.67.222.222 / 208.67.220.220)"; $dnsAddresses = @("208.67.222.222", "208.67.220.220") }
    }

    Write-Log "DNS selecionado: $dnsName"

    try {
        # Obtém todos os adaptadores de rede ativos e habilitados
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        if ($adapters.Count -eq 0) {
            Write-Log "Nenhum adaptador de rede ativo encontrado!" "WARNING"
            Set-Status "Pronto"
            return
        }

        foreach ($adapter in $adapters) {
            Write-Log "Configurando adaptador: $($adapter.Name) (Índice: $($adapter.InterfaceIndex))...."
            if ($null -eq $dnsAddresses) {
                # DHCP / reset
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction Stop
                Write-Log "  DNS redefinido para automático (DHCP)." "SUCCESS"
            } else {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $dnsAddresses -ErrorAction Stop
                Write-Log "  DNS configurado para: $($dnsAddresses -join ', ')." "SUCCESS"
            }
        }
        Write-Log "Configuração de DNS concluída com SUCESSO!" "SUCCESS"
        [System.Windows.MessageBox]::Show("DNS configurado com sucesso para: $dnsName", "Sucesso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        Write-Log "Erro ao configurar DNS: $_" "ERROR"
        [System.Windows.MessageBox]::Show("Erro ao configurar o DNS. Verifique se o programa foi iniciado como Administrador.", "Erro", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }

    Set-Status "Pronto"
}

# Executa SFC e DISM para reparar o sistema
function Action-RunSystemRepair {
    Register-Action "limpeza"
    Set-Status "Reparando sistema..."
    Switch-Tab "Logs"
    Write-Log "=== INICIANDO REPARO COMPLETO DO SISTEMA ===" "INFO"
    Write-Log "Este processo pode demorar alguns minutos. Por favor, não feche o programa." "WARNING"

    # Salva o estado original do serviço wuauserv (Windows Update)
    # pois o DISM /RestoreHealth precisa dele ativo para baixar arquivos limpos do servidor da Microsoft
    $originalWUStartType = "Manual"
    $originalWUState = "Stopped"
    $wuService = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue
    if ($null -ne $wuService) {
        $originalWUState = $wuService.Status
        try {
            $originalWUStartType = (Get-CimInstance Win32_Service -Filter "Name='wuauserv'" -ErrorAction SilentlyContinue).StartMode
        } catch {}
        
        if ($originalWUStartType -eq "Disabled") {
            Write-Log "Habilitando temporariamente o serviço Windows Update para permitir o reparo do DISM..."
            Set-Service -Name "wuauserv" -StartupType Manual -ErrorAction SilentlyContinue
        }
        if ($originalWUState -ne "Running") {
            Write-Log "Iniciando temporariamente o serviço Windows Update..."
            Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
        }
    }

    # Passo 1: Executar SFC /scannow
    Write-Log "[Passo 1/2] Iniciando SFC /scannow (System File Checker)..."
    try {
        $procSFC = Start-Process sfc.exe -ArgumentList "/scannow" -NoNewWindow -PassThru -Wait
        if ($procSFC.ExitCode -eq 0) {
            Write-Log "SFC concluído: Nenhum arquivo corrompido ou integridade restaurada com sucesso." "SUCCESS"
        } else {
            Write-Log "SFC finalizado com código de saída: $($procSFC.ExitCode)." "WARNING"
        }
    } catch {
        Write-Log "Erro ao executar SFC: $_" "ERROR"
    }

    Out-DoEvents

    # Passo 2: Executar DISM /Online /Cleanup-Image /RestoreHealth (ou ScanHealth no Windows 7)
    if ($global:isWindows7) {
        Write-Log "[Passo 2/2] Iniciando DISM /Online /Cleanup-Image /ScanHealth (Windows 7)..."
        try {
            $procDISM = Start-Process dism.exe -ArgumentList "/Online /Cleanup-Image /ScanHealth" -NoNewWindow -PassThru -Wait
            if ($procDISM.ExitCode -eq 0) {
                Write-Log "DISM ScanHealth concluído com SUCESSO! A saúde da imagem do sistema está íntegra." "SUCCESS"
            } else {
                Write-Log "DISM finalizado com código de saída: $($procDISM.ExitCode)." "WARNING"
            }
        } catch {
            Write-Log "Erro ao executar DISM: $_" "ERROR"
        }
    } else {
        Write-Log "[Passo 2/2] Iniciando DISM /Online /Cleanup-Image /RestoreHealth..."
        try {
            $procDISM = Start-Process dism.exe -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -NoNewWindow -PassThru -Wait
            if ($procDISM.ExitCode -eq 0) {
                Write-Log "DISM RestoreHealth concluído com SUCESSO! Armazenamento de componentes reparado." "SUCCESS"
            } else {
                # Se falhar, tenta com o parâmetro /LimitAccess caso o Windows Update esteja indisponível
                Write-Log "DISM falhou com código: $($procDISM.ExitCode). Tentando reparo local com /LimitAccess..." "WARNING"
                $procDISM2 = Start-Process dism.exe -ArgumentList "/Online /Cleanup-Image /RestoreHealth /LimitAccess" -NoNewWindow -PassThru -Wait
                if ($procDISM2.ExitCode -eq 0) {
                    Write-Log "DISM RestoreHealth local (/LimitAccess) concluído com SUCESSO!" "SUCCESS"
                } else {
                    Write-Log "DISM com /LimitAccess finalizado com código de saída: $($procDISM2.ExitCode)." "WARNING"
                }
            }
        } catch {
            Write-Log "Erro ao executar DISM: $_" "ERROR"
        }
    }

    # Restaura o estado original do serviço Windows Update
    if ($null -ne $wuService) {
        Write-Log "Restaurando o estado original do serviço Windows Update..."
        if ($originalWUState -ne "Running") {
            Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
        }
        if ($originalWUStartType -eq "Disabled") {
            Set-Service -Name "wuauserv" -StartupType Disabled -ErrorAction SilentlyContinue
        }
    }

    Write-Log "=== REPARO DO SISTEMA CONCLUÍDO ===" "SUCCESS"
    Set-Status "Pronto"
    [System.Windows.MessageBox]::Show("Diagnóstico e reparo do sistema concluídos! Verifique o console de logs para detalhes.", "Sucesso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
}

function Action-BackupDrivers {
    Register-Action "limpeza"
    Set-Status "Iniciando backup de drivers..."
    Switch-Tab "Logs"
    Write-Log "=== INICIANDO BACKUP COMPLETO DE DRIVERS ===" "INFO"

    # Define o nome da pasta de destino com os detalhes da máquina e sistema
    $userName = $env:USERNAME
    $computerName = $env:COMPUTERNAME
    $sanitizedOS = $global:osName -replace '[^a-zA-Z0-9_ -]', ''
    $dateStr = Get-Date -Format "yyyy-MM-dd_HH-mm"
    
    $folderName = "Backup_Drivers_${userName}_${computerName}_${sanitizedOS}_${dateStr}"
    # Substitui espaços por underscores no nome da pasta
    $folderName = $folderName -replace ' ', '_'
    
    $desktopPath = [System.IO.Path]::Combine([Environment]::GetFolderPath("Desktop"), $folderName)
    
    Write-Log "Destino do Backup: $desktopPath" "INFO"
    
    try {
        if (-not (Test-Path $desktopPath)) {
            $null = New-Item -ItemType Directory -Path $desktopPath -Force
        }
        
        Write-Log "Identificando versão do Windows para exportação..." "INFO"
        if ($global:isWindows7) {
            Write-Log "Detectado Windows 7. Utilizando DISM.exe para exportação de drivers de terceiros..." "WARNING"
            $proc = Start-Process dism.exe -ArgumentList "/Online /Export-Driver /Destination:`"$desktopPath`"" -NoNewWindow -PassThru -Wait
            if ($proc.ExitCode -eq 0) {
                Write-Log "Backup de drivers concluído com sucesso via DISM!" "SUCCESS"
            } else {
                Write-Log "DISM finalizado com código de erro: $($proc.ExitCode)." "ERROR"
            }
        } else {
            Write-Log "Detectado Windows 8.1/10/11. Utilizando cmdlet nativo Export-WindowsDriver..." "INFO"
            $exported = Export-WindowsDriver -Online -Destination $desktopPath -ErrorAction Stop
            $count = ($exported | Measure-Object).Count
            Write-Log "Backup concluído com sucesso! $count drivers de terceiros foram exportados para a pasta no Desktop." "SUCCESS"
        }
        
        Set-Status "Pronto"
        [System.Windows.MessageBox]::Show("Backup de drivers concluído com sucesso!`n`nSalvo na pasta:`n$desktopPath", "Backup de Drivers", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        Write-Log "Erro ao realizar backup de drivers: $_" "ERROR"
        Set-Status "Pronto"
        [System.Windows.MessageBox]::Show("Erro ao realizar o backup dos drivers:`n$_", "Erro no Backup", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
}

# Ativa ou desativa recursos opcionais do Windows
function Action-ApplyFeatures {
    Register-Action "debloat"
    Set-Status "Aplicando recursos..."
    Switch-Tab "Logs"
    Write-Log "=== CONFIGURANDO RECURSOS OPCIONAIS DO WINDOWS ===" "INFO"

    $features = @(
        @{ Name = "WSL (Subsystem for Linux)"; Key = "Microsoft-Windows-Subsystem-Linux"; Checked = $chkFeatureWSL.IsChecked }
        @{ Name = "Windows Sandbox"; Key = "Containers-DisposableVM"; Checked = $chkFeatureSandbox.IsChecked }
        @{ Name = "Hyper-V"; Key = "Microsoft-Hyper-V-All"; Checked = $chkFeatureHyperV.IsChecked }
        @{ Name = "SMBv1 (Compartilhamento)"; Key = "SMB1Protocol"; Checked = $chkFeatureSMB1.IsChecked }
    )

    foreach ($f in $features) {
        $stateName = if ($f.Checked) { "ATIVAR" } else { "DESATIVAR" }
        Write-Log "Processando: $($f.Name) -> $stateName..."

        try {
            if ($f.Checked) {
                # Ativa o recurso usando dism.exe
                $proc = Start-Process dism.exe -ArgumentList "/online /enable-feature /featurename:$($f.Key) /all /norestart" -NoNewWindow -PassThru -Wait
                if ($proc.ExitCode -eq 0) {
                    Write-Log "  $($f.Name) ATIVADO com sucesso!" "SUCCESS"
                } else {
                    Write-Log "  Aviso ao ativar $($f.Name). Código de saída: $($proc.ExitCode)" "WARNING"
                }
            } else {
                # Desativa o recurso usando dism.exe
                $proc = Start-Process dism.exe -ArgumentList "/online /disable-feature /featurename:$($f.Key) /norestart" -NoNewWindow -PassThru -Wait
                if ($proc.ExitCode -eq 0) {
                    Write-Log "  $($f.Name) DESATIVADO com sucesso!" "SUCCESS"
                } else {
                    Write-Log "  Aviso ao desativar $($f.Name). Código de saída: $($proc.ExitCode)" "WARNING"
                }
            }
        } catch {
            Write-Log "  Erro ao processar $($f.Name): $_" "ERROR"
        }
        Out-DoEvents
    }

    Write-Log "=== CONFIGURAÇÃO DE RECURSOS CONCLUÍDA ===" "SUCCESS"
    Write-Log "Recomenda-se reiniciar o computador para aplicar todas as alterações." "WARNING"
    Set-Status "Pronto"
    [System.Windows.MessageBox]::Show("Configuração de recursos concluída! Verifique o console de logs para detalhes.", "Sucesso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
}

# Atualiza a lista dos processos que mais consomem memória na máquina
function Action-UpdateTopProcesses {
    try {
        # Obtém os processos ativos, ordena por uso de RAM (WorkingSet64) decrescente e pega os 7 primeiros
        $processes = [System.Diagnostics.Process]::GetProcesses() | 
            Sort-Object WorkingSet64 -Descending | 
            Select-Object -First 7

        $null = $lvTopProcesses.Dispatcher.Invoke([Action]{
            $lvTopProcesses.Items.Clear()
            foreach ($proc in $processes) {
                $ramMB = [Math]::Round($proc.WorkingSet64 / 1MB, 0)
                $cpuSec = try { [Math]::Round($proc.TotalProcessorTime.TotalSeconds, 0) } catch { 0 }
                
                # Trunca o nome do processo se for muito longo
                $procName = $proc.ProcessName
                if ($procName.Length -gt 15) {
                    $procName = $procName.Substring(0, 13) + ".."
                }
                
                $itemObj = [PSCustomObject]@{
                    Name = $procName
                    RAM  = "$ramMB MB"
                    CPU  = "$cpuSec s"
                }
                $null = $lvTopProcesses.Items.Add($itemObj)
            }
        })
    } catch {
        # Ignora falhas se algum processo fechar durante a consulta
    }
}

# Execução da Limpeza de Disco
function Action-RunLimpeza {
    Register-Action "limpeza"
    Set-Status "Executando limpeza de disco..."
    Switch-Tab "Logs"
    Write-Log "Iniciando Limpeza Completa de Disco..."
    
    $hasErrors = $false

    # Temporários de Usuário
    if ($chkCleanUserTemp.IsChecked) {
        Write-Log "Limpando arquivos temporários do Usuário..."
        $userTemp = $env:TEMP
        if (Test-Path $userTemp) {
            $files = Get-ChildItem -Path $userTemp -Recurse -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                try {
                    Remove-Item $file.FullName -Force -Recurse -ErrorAction SilentlyContinue
                } catch {
                    $hasErrors = $true
                }
            }
        }
        Write-Log "Temporários do Usuário limpos."
    }

    # Temporários do Sistema
    if ($chkCleanSysTemp.IsChecked) {
        Write-Log "Limpando arquivos temporários do Sistema..."
        $sysTemp = "$env:SystemRoot\Temp"
        if (Test-Path $sysTemp) {
            $files = Get-ChildItem -Path $sysTemp -Recurse -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                try {
                    Remove-Item $file.FullName -Force -Recurse -ErrorAction SilentlyContinue
                } catch {
                    $hasErrors = $true
                }
            }
        }
        Write-Log "Temporários do Sistema limpos."
    }

    # Prefetch
    if ($chkCleanPrefetch.IsChecked) {
        Write-Log "Limpando pasta Prefetch..."
        $prefetch = "$env:SystemRoot\Prefetch"
        if (Test-Path $prefetch) {
            $files = Get-ChildItem -Path $prefetch -Recurse -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                try {
                    Remove-Item $file.FullName -Force -Recurse -ErrorAction SilentlyContinue
                } catch {
                    $hasErrors = $true
                }
            }
        }
        Write-Log "Pasta Prefetch limpa."
    }

    # Logs do Windows e Visualizador de Eventos
    if ($chkCleanLogs.IsChecked) {
        Write-Log "Limpando arquivos de Log do Windows (.log)..."
        # Coleta arquivos de log em locais seguros e específicos
        $logFiles = @()
        $logFiles += Get-ChildItem -Path "$env:SystemRoot\*.log" -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
        $logFiles += Get-ChildItem -Path "$env:SystemRoot\Logs\*" -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
        $logFiles += Get-ChildItem -Path "$env:SystemRoot\system32\LogFiles\*" -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
        
        foreach ($log in $logFiles) {
            try {
                Remove-Item $log.FullName -Force -Confirm:$false -ErrorAction SilentlyContinue
            } catch {
                $hasErrors = $true
            }
        }

        Write-Log "Limpando logs do Visualizador de Eventos..."
        # Limpeza de logs de Eventos do Windows
        try {
            wevtutil.exe el | ForEach-Object { wevtutil.exe cl "$_" 2>$null }
            Write-Log "Todos os registros do Visualizador de Eventos limpos."
        } catch {
            Write-Log "Erro ao limpar alguns logs do Visualizador de Eventos." "WARNING"
        }
    }

    # Cache do Windows Update (SoftwareDistribution\Download)
    if ($chkCleanUpdateCache.IsChecked) {
        Write-Log "Parando serviço do Windows Update temporariamente..."
        Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
        Out-DoEvents
        
        Write-Log "Limpando pasta de downloads do Windows Update..."
        $updateDownload = "$env:SystemRoot\SoftwareDistribution\Download"
        if (Test-Path $updateDownload) {
            $files = Get-ChildItem -Path $updateDownload -Recurse -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                try {
                    Remove-Item $file.FullName -Force -Recurse -ErrorAction SilentlyContinue
                } catch {
                    $hasErrors = $true
                }
            }
        }
        
        Write-Log "Reiniciando serviço do Windows Update..."
        Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
        Write-Log "Cache do Windows Update limpo."
    }

    # Esvaziar Lixeira
    if ($chkCleanRecycleBin.IsChecked) {
        Write-Log "Esvaziando lixeira do Windows..."
        try {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            Write-Log "Lixeira esvaziada."
        } catch {
            Write-Log "Erro ou lixeira já estava vazia." "WARNING"
        }
    }

    if ($hasErrors) {
        Write-Log "Alguns arquivos ou logs estão em uso ativo pelo sistema e foram mantidos para evitar travamentos." "INFO"
    }

    Write-Log "Limpeza de disco concluída com sucesso!" "SUCCESS"
    Set-Status "Pronto"
    [System.Windows.MessageBox]::Show("Limpeza de disco concluída!", "Sucesso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
}

# Execução da Instalação de Programas via Winget
function Action-InstallApps {
    Register-Action "instalador"
    Set-Status "Instalando programas..."
    Switch-Tab "Logs"
    Write-Log "Iniciando processo de instalação de programas via WinGet..."

    # Verifica se o winget está disponível
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log "WinGet não encontrado no sistema!" "ERROR"
        Write-Log "Tentando instalar o WinGet automaticamente..."
        try {
            $url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
            $dest = "$env:TEMP\winget.msixbundle"
            Write-Log "Baixando pacote WinGet..."
            Invoke-WebRequest -Uri $url -OutFile $dest -ErrorAction Stop
            Write-Log "Executando instalação silenciosa..."
            Add-AppxPackage -Path $dest -ErrorAction Stop
            Write-Log "WinGet instalado com sucesso! Reinicie o programa para utilizar o instalador." "SUCCESS"
            [System.Windows.MessageBox]::Show("WinGet instalado! Reinicie o utilitário para começar a instalar os programas.", "Sucesso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            Set-Status "Pronto"
            return
        } catch {
            Write-Log "Falha ao instalar o WinGet automaticamente: $_." "ERROR"
            Write-Log "Por favor, instale o 'App Installer' na Microsoft Store para ter suporte ao WinGet."
            [System.Windows.MessageBox]::Show("Não foi possível encontrar ou instalar o WinGet. Por favor, instale-o pela Microsoft Store antes de usar esta aba.", "Erro", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            Set-Status "Pronto"
            return
        }
    }

    # Coleta todas as checkboxes marcadas na aba de apps
    $appsToInstall = @()
    
    foreach ($chk in $appCheckboxObjects) {
        if ($chk.IsChecked) {
            $appsToInstall += $chk
        }
    }

    if ($appsToInstall.Count -eq 0) {
        Write-Log "Nenhum aplicativo foi selecionado para instalação." "WARNING"
        Set-Status "Pronto"
        [System.Windows.MessageBox]::Show("Por favor, selecione pelo menos um programa para instalar.", "Aviso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    Write-Log "Total de programas a instalar: $($appsToInstall.Count)"

    foreach ($chk in $appsToInstall) {
        $appName = $chk.Content
        $appId = $chk.Tag
        
        Write-Log "Iniciando download e instalação de: $appName (ID: $appId)..."
        
        # Executa winget silenciosamente e captura saída linha por linha para manter interativo
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "winget"
        $processInfo.Arguments = "install --id $appId --silent --accept-package-agreements --accept-source-agreements"
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        
        try {
            [void]$process.Start()
            
            # Lê a saída enquanto instala
            while (-not $process.HasExited) {
                $line = $process.StandardOutput.ReadLine()
                if ($line) {
                    $cleanLine = $line -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
                    $cleanLine = $cleanLine -replace '[\b\r\n]', ''
                    $cleanLine = $cleanLine.Trim()
                    
                    # Filtra ruídos de progresso do WinGet (spinners, barras de bloco corrompidas e porcentagens)
                    $isNoise = $false
                    if ([string]::IsNullOrWhiteSpace($cleanLine)) {
                        $isNoise = $true
                    } elseif ($cleanLine -match '^[\s\-\|\\/]*$') {
                        $isNoise = $true
                    } elseif ($cleanLine -match 'Ôûê|ÔûÆ|█|░|▒|▓|■') {
                        $isNoise = $true
                    } elseif ($cleanLine -match '^\d+%\s*$') {
                        $isNoise = $true
                    }
                    
                    if (-not $isNoise) {
                        Write-Log "  [WinGet] $cleanLine"
                    }
                }
                Out-DoEvents
            }
            
            if ($process.ExitCode -eq 0) {
                Write-Log "Instalação de $appName finalizada com SUCESSO!" "SUCCESS"
            } else {
                # Alguns códigos de erro do winget podem indicar que já está instalado (ex: 0x8A15002B)
                # Vamos verificar se o retorno indica sucesso alternativo ou erro real
                $exitHex = "0x" + $process.ExitCode.ToString("X")
                if ($process.ExitCode -eq -1978335189) { # 0x8A15002B: already installed
                    Write-Log "$appName já está instalado no sistema." "SUCCESS"
                } else {
                    Write-Log "Falha na instalação de $appName. Código de saída: $exitHex" "WARNING"
                }
            }
        } catch {
            Write-Log "Erro ao tentar executar winget para ${appName}: $_" "ERROR"
        }
        
        Out-DoEvents
    }

    Write-Log "Todos os processos de instalação foram concluídos!" "SUCCESS"
    Set-Status "Pronto"
    # Mensagem de sucesso removida a pedido do usuário
}

# Variáveis globais do desinstalador
$global:allInstalledApps = @()
$global:currentLeftovers = @()

# Carrega lista de todos os programas instalados do Registro do Windows
function Action-LoadInstalledApps {
    Set-Status "Carregando programas instalados..."
    $global:allInstalledApps = @()

    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $regPaths) {
        try {
            $items = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                if (-not [string]::IsNullOrWhiteSpace($item.DisplayName)) {
                    # Formata o tamanho
                    $sizeText = ""
                    if ($item.EstimatedSize) {
                        $sizeKB = [int]$item.EstimatedSize
                        if ($sizeKB -ge 1024) {
                            $sizeMB = [Math]::Round($sizeKB / 1024, 1)
                            $sizeText = "$sizeMB MB"
                        } else {
                            $sizeText = "$sizeKB KB"
                        }
                    }

                    # Formata a data
                    $dateText = ""
                    if ($item.InstallDate) {
                        try {
                            $d = $item.InstallDate
                            if ($d.Length -eq 8) {
                                $dateText = "$($d.Substring(6,2))/$($d.Substring(4,2))/$($d.Substring(0,4))"
                            } else {
                                $dateText = $d
                            }
                        } catch { $dateText = $item.InstallDate }
                    }

                    $appObj = [PSCustomObject]@{
                        Name            = $item.DisplayName
                        Publisher       = if ($item.Publisher) { $item.Publisher } else { "-" }
                        Size            = $sizeText
                        InstallDate     = $dateText
                        Version         = if ($item.DisplayVersion) { $item.DisplayVersion } else { "-" }
                        InstallLocation = if ($item.InstallLocation) { $item.InstallLocation } else { "" }
                        UninstallString = if ($item.UninstallString) { $item.UninstallString } else { "" }
                        QuietUninstall  = if ($item.QuietUninstallString) { $item.QuietUninstallString } else { "" }
                        RegistryKey     = $item.PSPath
                    }

                    $global:allInstalledApps += $appObj
                }
            }
        } catch {}
    }

    # Remove duplicatas por nome
    $global:allInstalledApps = $global:allInstalledApps | Sort-Object Name -Unique

    # Atualiza a ListView
    Action-FilterInstalledApps ""
    $lblUninstallCount.Text = "$($global:allInstalledApps.Count) programas encontrados"
    Set-Status "Pronto"
}

# Filtra a lista de programas baseado no texto de pesquisa
function Action-FilterInstalledApps {
    param([string]$filter)

    $lvInstalledApps.Items.Clear()

    $filtered = $global:allInstalledApps
    if (-not [string]::IsNullOrWhiteSpace($filter)) {
        $filtered = $global:allInstalledApps | Where-Object { $_.Name -like "*$filter*" -or $_.Publisher -like "*$filter*" }
    }

    foreach ($app in $filtered) {
        $null = $lvInstalledApps.Items.Add($app)
    }

    $lblUninstallCount.Text = "$($filtered.Count) de $($global:allInstalledApps.Count) programas"
}

# Escaneia resíduos de um programa selecionado (pastas em AppData, ProgramData, etc.)
function Action-ScanLeftovers {
    $sel = $lvInstalledApps.SelectedItem
    if (-not $sel) {
        [System.Windows.MessageBox]::Show("Selecione um programa na lista para analisar resíduos.", "Aviso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    Set-Status "Escaneando resíduos de: $($sel.Name)..."
    $global:currentLeftovers = @()
    $appName = $sel.Name

    # Gera termos de busca inteligentes a partir do nome do programa
    $searchTerms = @($appName)
    # Remove palavras genéricas para buscar pasta mais precisamente
    $cleanedName = $appName -replace '\s*(x64|x86|64-bit|32-bit|\(.*?\))\s*', '' -replace '\s+', ' '
    $cleanedName = $cleanedName.Trim()
    if ($cleanedName -ne $appName) {
        $searchTerms += $cleanedName
    }
    # Extrai primeira palavra significativa (geralmente o nome do fabricante ou produto)
    $firstWord = ($cleanedName -split '\s+')[0]
    if ($firstWord.Length -ge 3 -and $firstWord -ne $cleanedName) {
        $searchTerms += $firstWord
    }

    # Lista de diretórios a escanear
    $scanDirs = @(
        "$env:APPDATA",
        "$env:LOCALAPPDATA",
        "$env:ProgramData",
        "$env:ProgramFiles",
        "${env:ProgramFiles(x86)}",
        "$env:USERPROFILE\Documents",
        "$env:TEMP"
    )

    foreach ($dir in $scanDirs) {
        if (-not (Test-Path $dir)) { continue }
        try {
            $children = Get-ChildItem -Path $dir -Directory -ErrorAction SilentlyContinue
            foreach ($child in $children) {
                foreach ($term in $searchTerms) {
                    if ($child.Name -like "*$term*") {
                        $folderSize = 0
                        try {
                            $folderSize = (Get-ChildItem -Path $child.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                        } catch {}
                        $sizeMB = [Math]::Round($folderSize / 1MB, 2)
                        $global:currentLeftovers += [PSCustomObject]@{
                            Path = $child.FullName
                            SizeMB = $sizeMB
                            Type = "Pasta"
                        }
                        break
                    }
                }
            }
        } catch {}
    }

    # Escaneia chaves de registro residuais
    $regScanPaths = @(
        "HKCU:\SOFTWARE",
        "HKLM:\SOFTWARE"
    )
    foreach ($regPath in $regScanPaths) {
        try {
            $regChildren = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
            foreach ($regChild in $regChildren) {
                foreach ($term in $searchTerms) {
                    if ($regChild.PSChildName -like "*$term*") {
                        $global:currentLeftovers += [PSCustomObject]@{
                            Path = $regChild.Name
                            SizeMB = 0
                            Type = "Registro"
                        }
                        break
                    }
                }
            }
        } catch {}
    }

    # Inclui o local de instalação original se existir
    if (-not [string]::IsNullOrWhiteSpace($sel.InstallLocation) -and (Test-Path $sel.InstallLocation)) {
        $alreadyFound = $global:currentLeftovers | Where-Object { $_.Path -eq $sel.InstallLocation }
        if (-not $alreadyFound) {
            $folderSize = 0
            try {
                $folderSize = (Get-ChildItem -Path $sel.InstallLocation -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            } catch {}
            $sizeMB = [Math]::Round($folderSize / 1MB, 2)
            $global:currentLeftovers += [PSCustomObject]@{
                Path = $sel.InstallLocation
                SizeMB = $sizeMB
                Type = "Pasta (Instalação)"
            }
        }
    }

    if ($global:currentLeftovers.Count -eq 0) {
        $txtDetailLeftovers.Text = "Nenhum resíduo encontrado."
        $txtDetailLeftovers.Foreground = [System.Windows.Media.Brush]"#22C55E"
    } else {
        $totalSizeMB = ($global:currentLeftovers | Where-Object { $_.Type -like "Pasta*" } | Measure-Object -Property SizeMB -Sum).Sum
        $lines = @()
        $folderCount = ($global:currentLeftovers | Where-Object { $_.Type -like "Pasta*" }).Count
        $regCount = ($global:currentLeftovers | Where-Object { $_.Type -eq "Registro" }).Count
        $lines += "$folderCount pasta(s), $regCount chave(s) de registro"
        $lines += "Tamanho total: $([Math]::Round($totalSizeMB, 2)) MB"
        $lines += ""
        foreach ($lo in $global:currentLeftovers) {
            if ($lo.Type -like "Pasta*") {
                $lines += "[Pasta] $($lo.Path) ($($lo.SizeMB) MB)"
            } else {
                $lines += "[Reg] $($lo.Path)"
            }
        }
        $txtDetailLeftovers.Text = ($lines -join "`n")
        $txtDetailLeftovers.Foreground = [System.Windows.Media.Brush]"#FBBF24"
    }

    Set-Status "Pronto"
}

# Desinstalação normal (usa o desinstalador nativo do programa)
function Action-UninstallNormal {
    Register-Action "desinstalador"
    $sel = $lvInstalledApps.SelectedItem
    if (-not $sel) {
        [System.Windows.MessageBox]::Show("Selecione um programa para desinstalar.", "Aviso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $confirm = [System.Windows.MessageBox]::Show("Deseja desinstalar '$($sel.Name)'?`n`nIsto executará o desinstalador nativo do programa.", "Confirmar Desinstalação", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

    Switch-Tab "Logs"
    Set-Status "Desinstalando: $($sel.Name)..."
    Write-Log "Iniciando desinstalação de: $($sel.Name)..."

    $uninstCmd = if (-not [string]::IsNullOrWhiteSpace($sel.QuietUninstall)) { $sel.QuietUninstall } else { $sel.UninstallString }

    if ([string]::IsNullOrWhiteSpace($uninstCmd)) {
        Write-Log "Nenhum comando de desinstalação encontrado no registro para '$($sel.Name)'." "ERROR"
        Set-Status "Pronto"
        return
    }

    Write-Log "Comando: $uninstCmd"

    try {
        # Detecta se é um MsiExec ou executável direto
        if ($uninstCmd -match 'msiexec') {
            $uninstCmd = $uninstCmd -replace '/I', '/X'
            if ($uninstCmd -notmatch '/quiet') {
                $uninstCmd = "$uninstCmd /quiet /norestart"
            }
            Write-Log "Executando MsiExec silencioso: $uninstCmd"
            cmd /c $uninstCmd 2>&1 | ForEach-Object { Write-Log "  $_" }
        } else {
            # Tenta executar o desinstalador
            $exePath = $uninstCmd -replace '"', ''
            if (Test-Path $exePath) {
                Write-Log "Executando desinstalador: $exePath"
                Start-Process -FilePath $exePath -Wait -ErrorAction Stop
            } else {
                Write-Log "Executando via cmd: $uninstCmd"
                cmd /c $uninstCmd 2>&1 | ForEach-Object { Write-Log "  $_" }
            }
        }
        Write-Log "Desinstalação de '$($sel.Name)' concluída." "SUCCESS"
    } catch {
        Write-Log "Erro durante desinstalação de '$($sel.Name)': $_" "ERROR"
    }

    Set-Status "Pronto"
    # Recarrega a lista
    Action-LoadInstalledApps
}

# Desinstalação com limpeza profunda (desinstala + remove resíduos)
function Action-UninstallDeep {
    Register-Action "desinstalador"
    $sel = $lvInstalledApps.SelectedItem
    if (-not $sel) {
        [System.Windows.MessageBox]::Show("Selecione um programa para desinstalar.", "Aviso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $confirm = [System.Windows.MessageBox]::Show("Deseja desinstalar '$($sel.Name)' COM LIMPEZA PROFUNDA?`n`nIsto irá:`n1. Executar o desinstalador nativo`n2. Escanear e remover pastas residuais`n3. Limpar chaves de registro órfãs`n`nEsta ação é IRREVERSÍVEL.", "Confirmar Limpeza Profunda", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

    Switch-Tab "Logs"
    Set-Status "Desinstalação profunda: $($sel.Name)..."
    Write-Log "=== DESINSTALAÇÃO PROFUNDA: $($sel.Name) ===" "INFO"

    # Passo 1: Desinstalar normalmente
    $uninstCmd = if (-not [string]::IsNullOrWhiteSpace($sel.QuietUninstall)) { $sel.QuietUninstall } else { $sel.UninstallString }

    if (-not [string]::IsNullOrWhiteSpace($uninstCmd)) {
        Write-Log "[Passo 1/3] Executando desinstalador nativo..."
        try {
            if ($uninstCmd -match 'msiexec') {
                $uninstCmd = $uninstCmd -replace '/I', '/X'
                if ($uninstCmd -notmatch '/quiet') {
                    $uninstCmd = "$uninstCmd /quiet /norestart"
                }
                cmd /c $uninstCmd 2>&1 | ForEach-Object { Write-Log "  $_" }
            } else {
                $exePath = $uninstCmd -replace '"', ''
                if (Test-Path $exePath) {
                    Start-Process -FilePath $exePath -Wait -ErrorAction Stop
                } else {
                    cmd /c $uninstCmd 2>&1 | ForEach-Object { Write-Log "  $_" }
                }
            }
            Write-Log "Desinstalador nativo finalizado." "SUCCESS"
        } catch {
            Write-Log "Falha no desinstalador nativo: $_ (continuando limpeza...)" "WARNING"
        }
    } else {
        Write-Log "[Passo 1/3] Nenhum desinstalador nativo encontrado. Pulando..." "WARNING"
    }

    Out-DoEvents

    # Passo 2: Escanear e remover pastas residuais
    Write-Log "[Passo 2/3] Escaneando e removendo pastas residuais..."
    
    # Escaneia resíduos
    Action-ScanLeftovers

    $foldersRemoved = 0
    $regKeysRemoved = 0

    foreach ($leftover in $global:currentLeftovers) {
        if ($leftover.Type -like "Pasta*") {
            if (Test-Path $leftover.Path) {
                try {
                    Remove-Item -Path $leftover.Path -Recurse -Force -ErrorAction Stop
                    Write-Log "  Pasta removida: $($leftover.Path) ($($leftover.SizeMB) MB)" "SUCCESS"
                    $foldersRemoved++
                } catch {
                    Write-Log "  Falha ao remover pasta: $($leftover.Path) - $_" "WARNING"
                }
            }
        }
    }

    Out-DoEvents

    # Passo 3: Limpar chaves de registro residuais
    Write-Log "[Passo 3/3] Removendo chaves de registro residuais..."
    foreach ($leftover in $global:currentLeftovers) {
        if ($leftover.Type -eq "Registro") {
            try {
                $regPath = "Registry::$($leftover.Path)"
                if (Test-Path $regPath) {
                    Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
                    Write-Log "  Registro removido: $($leftover.Path)" "SUCCESS"
                    $regKeysRemoved++
                }
            } catch {
                Write-Log "  Falha ao remover registro: $($leftover.Path) - $_" "WARNING"
            }
        }
    }

    # Tenta remover a chave principal de desinstalação do registro
    if (-not [string]::IsNullOrWhiteSpace($sel.RegistryKey)) {
        try {
            if (Test-Path $sel.RegistryKey) {
                Remove-Item -Path $sel.RegistryKey -Recurse -Force -ErrorAction Stop
                Write-Log "  Chave de desinstalação removida do registro." "SUCCESS"
                $regKeysRemoved++
            }
        } catch {
            Write-Log "  Falha ao remover chave de desinstalação: $_" "WARNING"
        }
    }

    Write-Log ""
    Write-Log "=== LIMPEZA PROFUNDA CONCLUÍDA ===" "SUCCESS"
    Write-Log "  Pastas removidas: $foldersRemoved" "INFO"
    Write-Log "  Chaves de registro removidas: $regKeysRemoved" "INFO"

    Set-Status "Pronto"
    # Recarrega a lista
    Action-LoadInstalledApps
}

# 8. Eventos de UI e Associações de Botões

# Fechar, Minimizar e Maximizar Janela
$btnClose.Add_Click({ $Window.Close() })
$btnMinimize.Add_Click({ $Window.WindowState = [System.Windows.WindowState]::Minimized })

$btnMaximize.Add_Click({
    if ($Window.WindowState -eq [System.Windows.WindowState]::Maximized) {
        $Window.WindowState = [System.Windows.WindowState]::Normal
        $windowBorder.CornerRadius = New-Object System.Windows.CornerRadius(14)
        $windowBorder.BorderThickness = New-Object System.Windows.Thickness(1.5)
        $btnMaximize.Content = "🗖"
    } else {
        $Window.WindowState = [System.Windows.WindowState]::Maximized
        $windowBorder.CornerRadius = New-Object System.Windows.CornerRadius(0)
        $windowBorder.BorderThickness = New-Object System.Windows.Thickness(0)
        $btnMaximize.Content = "🗗"
    }
})

# Evento para arrastar a janela (Necessário por causa do WindowStyle="None") e maximizar com clique duplo
$titleBar.add_MouseDown({
    if ($args[1].LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed) {
        if ($args[1].ClickCount -eq 2) {
            if ($Window.WindowState -eq [System.Windows.WindowState]::Maximized) {
                $Window.WindowState = [System.Windows.WindowState]::Normal
                $windowBorder.CornerRadius = New-Object System.Windows.CornerRadius(14)
                $windowBorder.BorderThickness = New-Object System.Windows.Thickness(1.5)
                $btnMaximize.Content = "🗖"
            } else {
                $Window.WindowState = [System.Windows.WindowState]::Maximized
                $windowBorder.CornerRadius = New-Object System.Windows.CornerRadius(0)
                $windowBorder.BorderThickness = New-Object System.Windows.Thickness(0)
                $btnMaximize.Content = "🗗"
            }
        } else {
            if ($Window.WindowState -ne [System.Windows.WindowState]::Maximized) {
                $Window.DragMove()
            }
        }
    }
})

# Navegação por Abas
$btnTabPainel.Add_Click({ Switch-Tab "Painel" })
$btnTabDebloat.Add_Click({ Switch-Tab "Debloat" })
$btnTabDesempenho.Add_Click({ Switch-Tab "Desempenho" })
$btnTabLimpeza.Add_Click({ Switch-Tab "Limpeza" })
$btnTabRede.Add_Click({ Switch-Tab "Rede" })
$btnTabAtivacao.Add_Click({ Switch-Tab "Ativacao" })
$btnTabOffice.Add_Click({ Switch-Tab "Office" })
$btnTabLogs.Add_Click({ Switch-Tab "Logs" })
$btnTabApps.Add_Click({ Switch-Tab "Apps" })
$btnTabUninstall.Add_Click({ Switch-Tab "Uninstall"; Action-LoadInstalledApps })

# Eventos de Links do Desenvolvedor
$btnLinkInstagram.Add_Click({ Start-Process "https://www.instagram.com/felipe.samack/" })
$btnLinkGithub.Add_Click({ Start-Process "https://github.com/rgis-samack/win-samack" })
$btnDonate.Add_Click({
    Start-Process "https://nubank.com.br/cobrar/jdnam/6a449332-0732-43dc-9cfe-946bd2eee5fa"
})

# Eventos da Tela de Office
$btnOffice2021Tiny.Add_Click({ Start-Process "https://tinyurl.com/samackoffice2021" })
$btnOffice2021Bitly.Add_Click({ Start-Process "https://bit.ly/samackoffice" })
$btnOffice2019Abre.Add_Click({ Start-Process "https://abre.ai/samackofficergis" })
$btnOffice2019Tiny.Add_Click({ Start-Process "https://tinyurl.com/samackofficergis" })

# Vincula clique do QR Code se ele foi carregado
if ($null -ne $imgQrCode) {
    $imgQrCode.add_MouseDown({
        Start-Process "https://nubank.com.br/cobrar/jdnam/6a449332-0732-43dc-9cfe-946bd2eee5fa"
    })
}

# Interceptação de Fechamento da Janela (25 Frases Baseadas em Ações Reais)
$Window.add_Closing({
    param($sender, $e)
    
    # Detecção dinâmica do SO do usuário para piadas personalizadas
    $osName = "Windows"
    $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($null -ne $osInfo) {
        if ($osInfo.Caption -like "*Windows 11*") { $osName = "Windows 11" }
        elseif ($osInfo.Caption -like "*Windows 10*") { $osName = "Windows 10" }
        elseif ($osInfo.Caption -like "*Windows 7*") { $osName = "Windows 7" }
    }

    # Dicionário de Frases Tematizadas (Totalizando 25 frases estruturadas)
    $frasesPorAcao = @{
        "geral" = @(
            "Você abriu a ferramenta e não aplicou nenhuma otimização? Seus componentes continuam em silêncio... Mas e um Pix de apoio para incentivar novas atualizações? 😉",
            "Dizem que o melhor suporte de TI é o que resolve os problemas antes de você perceber. Deixe uma contribuição voluntária para apoiar o Felipe Samack!",
            "TI é a arte de automatizar o que é chato. O Samack WinUtil poupou seu tempo! Que tal demonstrar o seu reconhecimento com qualquer valor?",
            "Café é o combustível que transforma linhas de código em facilidade para o seu dia a dia. Pague um café para o desenvolvedor!",
            "Apoiar o software livre e independente garante que utilitários diretos e sem anúncios continuem existindo. Faça sua doação!"
        );
        "limpeza" = @(
            "Seu PC estava sufocando e agora respira aliviado com a limpeza de RAM e remoção de caches do seu $osName! Que tal um Pix de gratidão?",
            "O script varreu gigabytes de lixo do seu HD/SSD e consertou erros do sistema. Considere fazer uma doação para manter esse faxineiro ativo!",
            "Limpamos arquivos temporários e logs inúteis que só ocupavam espaço. Seu SSD agradece! Retribua com o valor de um cafezinho.",
            "Deixar o $osName limpo de verdade demoraria muito tempo. A ferramenta limpou tudo em segundos! Que tal apoiar o criador?"
        );
        "desempenho" = @(
            "Latência de rede reduzida, otimizações aplicadas e ping ajustado! Agora o lag não é desculpa para perder a partida. Apoie o desenvolvedor!",
            "Seus núcleos de processador estão prontos para o desempenho máximo do $osName! Que tal dar um 'boost' na carteira do Felipe Samack?",
            "Modo Jogo ativado e rede configurada para menor ping. Se o seu FPS subiu nos jogos, faça o seu Pix de agradecimento!",
            "As otimizações de resposta do sistema foram aplicadas com sucesso. Deixe uma contribuição voluntária para apoiar novas atualizações."
        );
        "debloat" = @(
            "Cortana, Bing e bloatwares indesejados removidos! O seu $osName agora é seu de verdade, sem a Microsoft te espionar. Apoie essa liberdade!",
            "Nada de telemetria secreta ou serviços inúteis rodando em segundo plano. Seu PC está mais seguro e leve. Faça uma contribuição!",
            "Desativar a telemetria pesada e apps pré-instalados deu uma nova vida à sua máquina. Demonstre seu apoio ao projeto!",
            "Removemos os apps inúteis que ocupavam memória RAM atoa. Se o sistema ficou limpo e leve, colabore com uma doação via Pix!"
        );
        "instalador" = @(
            "Você instalou seus programas favoritos silenciosamente sem instaladores chatos ou ofertas de antivírus de brinde! Que tal doar o valor de um refri?",
            "Instalação múltipla e silenciosa de apps via WinGet economizou cliques e tempo precioso. Considere apoiar o projeto!",
            "Instalar ferramentas de desenvolvimento e utilitários em lote nunca foi tão simples. Um Pix de qualquer valor apoia o desenvolvedor!",
            "Seus aplicativos de comunicação e mídia foram instalados de uma vez só! Apoie o criador voluntário que facilitou essa tarefa."
        );
        "desinstalador" = @(
            "O desinstalador avançado varreu o registro e limpou todos os resíduos órfãos do programa! Nada de lixo oculto no Windows. Faça uma doação!",
            "Remover programas pela metade deixa o sistema lento. Nosso desinstalador limpou tudo profundamente! Fortaleça o projeto.",
            "Varredura de sobras de pastas AppData e chaves do registro finalizada. Seu Windows agradece! Colabore com o desenvolvedor.",
            "Desinstalação limpa no estilo Revo Uninstaller. Você economizou na licença de softwares de limpeza! Retribua com um Pix voluntário."
        );
        "ativacao" = @(
            "Ativação concluída! Você economizou a grana preta de uma licença profissional do $osName. Que tal doar uma fração dessa economia?",
            "Windows ou Office ativados permanentemente via MAS com total segurança! Um Pix voluntário ajuda a manter o projeto vivo.",
            "PIX: a única chave de ativação que faz o desenvolvedor sorrir de verdade! 😉 Considere apoiar o criador da ferramenta.",
            "Economizou horas pesquisando ativadores duvidosos na internet e ativou de forma limpa. Ajude a manter o projeto ativo com uma doação!"
        )
    }

    # Determina o tema da frase baseada no que o usuário realizou
    $temaSelecionado = "geral"
    
    # Se houver alguma ação no hashset, seleciona uma delas para exibir a frase correspondente
    if ($global:actionsPerformed.Count -gt 0) {
        # Converte para array e pega um elemento aleatório da lista de ações reais feitas
        $listaAcoes = @($global:actionsPerformed)
        $temaSelecionado = $listaAcoes[(Get-Random -Minimum 0 -Maximum $listaAcoes.Count)]
    }

    # Pega as frases do tema selecionado
    $frasesDisponiveis = $frasesPorAcao[$temaSelecionado]
    if ($null -eq $frasesDisponiveis -or $frasesDisponiveis.Count -eq 0) {
        $frasesDisponiveis = $frasesPorAcao["geral"]
    }
    $randomFrase = $frasesDisponiveis[(Get-Random -Minimum 0 -Maximum $frasesDisponiveis.Count)]
    
    # Exibe a caixa de mensagem antes de fechar o processo
    [System.Windows.MessageBox]::Show($randomFrase, "Apoie o Samack WinUtil", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

# ── Ativação (MAS) ──────────────────────────────────────────────────────────
$btnRunActivation.Add_Click({
    Register-Action "ativacao"
    Set-Status "Iniciando Microsoft Activation Scripts..."
    Write-Log "Iniciando Microsoft Activation Scripts (MAS) em console externo..." "INFO"
    try {
        $masArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "iex (curl.exe -s --doh-url https://1.1.1.1/dns-query https://get.activated.win | Out-String)")
        $null = Start-Process powershell.exe -ArgumentList $masArgs
        Write-Log "MAS iniciado com sucesso em janela de console externa." "SUCCESS"
    } catch {
        Write-Log "Erro ao iniciar MAS: $_" "ERROR"
    }
    Set-Status "Pronto"
})

# ── Ferramentas de Rede ──────────────────────────────────────────────────────
$btnRedeIPConfig.Add_Click({
    Register-Action "rede"
    Set-Status "Obtendo configurações de IP..."
    $result = (ipconfig /all) -join "`n"
    $txtRedeIPResult.Text = $result
    Set-Status "Pronto"
})

$btnRedePing.Add_Click({
    Register-Action "rede"
    $targetHost = $txtRedePingHost.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($targetHost)) { $targetHost = "8.8.8.8" }
    Set-Status "Pingando $targetHost..."
    $txtRedePingResult.Text = "Pingando $targetHost, aguarde..."
    Out-DoEvents
    $tmpFile = Join-Path $env:TEMP "ping_out.txt"
    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c ping $targetHost -n 4 > `"$tmpFile`"" -WindowStyle Hidden -PassThru
    while (-not $proc.HasExited) {
        Out-DoEvents
        Start-Sleep -Milliseconds 100
    }
    $txtRedePingResult.Text = Get-Content $tmpFile -Raw
    Set-Status "Pronto"
})

$btnRedeNetstat.Add_Click({
    Register-Action "rede"
    Set-Status "Obtendo conexões ativas..."
    $txtRedeNetstatResult.Text = "Carregando..."
    $result = (netstat -ano) -join "`n"
    $txtRedeNetstatResult.Text = $result
    Set-Status "Pronto"
})

$btnRedeFlushDNS.Add_Click({
    Register-Action "rede"
    Set-Status "Limpando cache de DNS..."
    $null = ipconfig /flushdns
    Write-Log "DNS Cache limpo com sucesso (ipconfig /flushdns)." "SUCCESS"
    Set-Status "Pronto"
    [System.Windows.MessageBox]::Show("Cache de DNS limpo com sucesso!", "Flush DNS", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

$btnRedeReset.Add_Click({
    Register-Action "rede"
    $confirm = [System.Windows.MessageBox]::Show("Isso irá resetar o Winsock e o TCP/IP. O computador precisará ser reiniciado.`n`nDeseja continuar?", "Reset de Rede", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
    if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
        Set-Status "Resetando pilha de rede..."
        Switch-Tab "Logs"
        Write-Log "=== RESET DE REDE ===" "INFO"
        try {
            $p1 = Start-Process netsh.exe -ArgumentList "winsock reset" -NoNewWindow -PassThru -Wait
            Write-Log "Winsock reset: código de saída $($p1.ExitCode)." $(if ($p1.ExitCode -eq 0) { "SUCCESS" } else { "WARNING" })
            $p2 = Start-Process netsh.exe -ArgumentList "int ip reset" -NoNewWindow -PassThru -Wait
            Write-Log "TCP/IP reset: código de saída $($p2.ExitCode)." $(if ($p2.ExitCode -eq 0) { "SUCCESS" } else { "WARNING" })
            Write-Log "Reset de rede concluído. Reinicie o computador para aplicar." "WARNING"
        } catch {
            Write-Log "Erro ao resetar rede: $_" "ERROR"
        }
        Set-Status "Pronto"
        [System.Windows.MessageBox]::Show("Reset de rede executado! Reinicie o computador para aplicar as alterações.", "Reset Concluído", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

$btnRedeRenewIP.Add_Click({
    Register-Action "rede"
    Set-Status "Liberando e renovando IP..."
    Switch-Tab "Logs"
    Write-Log "=== LIBERAR E RENOVAR IP (DHCP) ===" "INFO"
    try {
        $p1 = Start-Process ipconfig.exe -ArgumentList "/release" -NoNewWindow -PassThru -Wait
        Write-Log "IP liberado: código $($p1.ExitCode)." $(if ($p1.ExitCode -eq 0) { "SUCCESS" } else { "WARNING" })
        Start-Sleep -Milliseconds 800
        $p2 = Start-Process ipconfig.exe -ArgumentList "/renew" -NoNewWindow -PassThru -Wait
        Write-Log "IP renovado: código $($p2.ExitCode)." $(if ($p2.ExitCode -eq 0) { "SUCCESS" } else { "WARNING" })
        Write-Log "Endereço IP renovado com sucesso." "SUCCESS"
    } catch {
        Write-Log "Erro ao renovar IP: $_" "ERROR"
    }
    Set-Status "Pronto"
    [System.Windows.MessageBox]::Show("IP liberado e renovado com sucesso!", "Renovar IP", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

$btnRedeTracert.Add_Click({
    Register-Action "rede"
    $targetHost = $txtRedeTracertHost.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($targetHost)) { $targetHost = "8.8.8.8" }
    Set-Status "Rastreando rota para $targetHost (pode demorar)..."
    $txtRedeTracertResult.Text = "Rastreando $targetHost, aguarde..."
    Out-DoEvents
    $tmpFile = Join-Path $env:TEMP "tracert_out.txt"
    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c tracert -d -h 15 $targetHost > `"$tmpFile`"" -WindowStyle Hidden -PassThru
    while (-not $proc.HasExited) {
        Out-DoEvents
        Start-Sleep -Milliseconds 100
    }
    $txtRedeTracertResult.Text = Get-Content $tmpFile -Raw
    Set-Status "Pronto"
})

# Botões da Tela Inicial (Painel)
$btnCreateRestore.Add_Click({ Action-CreateRestorePoint })
$btnCleanRAM.Add_Click({ Action-OptimizeRAM })

# Botões da Tela de Debloat
$btnSelectAllDebloat.Add_Click({
    $chkDebloatBing.IsChecked = $true
    $chkDebloatXbox.IsChecked = $true
    $chkDebloatOneDrive.IsChecked = $true
    $chkDebloatFeedback.IsChecked = $true
    $chkDebloatGames.IsChecked = $true
    $chkDebloatMisc.IsChecked = $true
    $chkDebloatTelemetry.IsChecked = $true
})
$btnDeselectAllDebloat.Add_Click({
    $chkDebloatBing.IsChecked = $false
    $chkDebloatXbox.IsChecked = $false
    $chkDebloatOneDrive.IsChecked = $false
    $chkDebloatFeedback.IsChecked = $false
    $chkDebloatGames.IsChecked = $false
    $chkDebloatMisc.IsChecked = $false
    $chkDebloatTelemetry.IsChecked = $false
})
$btnRunDebloat.Add_Click({ Action-RunDebloat })

# Botões da Tela de Desempenho
$btnSelectAllTweaks.Add_Click({
    $chkTweakGameMode.IsChecked = $true
    $chkTweakGameDVR.IsChecked = $true
    $chkTweakNetworkLatency.IsChecked = $true
    $chkTweakNetworkThrottling.IsChecked = $true
    $chkTweakResponsiveness.IsChecked = $true
    $chkTweakCoreParking.IsChecked = $true
    $chkTweakTelemetry.IsChecked = $true
    $chkTweakVisuals.IsChecked = $true
})
$btnDeselectAllTweaks.Add_Click({
    $chkTweakGameMode.IsChecked = $false
    $chkTweakGameDVR.IsChecked = $false
    $chkTweakNetworkLatency.IsChecked = $false
    $chkTweakNetworkThrottling.IsChecked = $false
    $chkTweakResponsiveness.IsChecked = $false
    $chkTweakCoreParking.IsChecked = $false
    $chkTweakTelemetry.IsChecked = $false
    $chkTweakVisuals.IsChecked = $false
})
$btnRunTweaks.Add_Click({ Action-RunTweaks })
$btnWUDefault.Add_Click({ Action-SetWUDefault })
$btnWUSecurity.Add_Click({ Action-SetWUSecurity })
$btnWUDisable.Add_Click({ Action-SetWUDisable })

# Botões da Tela de Limpeza
$btnSelectAllLimpeza.Add_Click({
    $chkCleanUserTemp.IsChecked = $true
    $chkCleanSysTemp.IsChecked = $true
    $chkCleanPrefetch.IsChecked = $true
    $chkCleanLogs.IsChecked = $true
    $chkCleanUpdateCache.IsChecked = $true
    $chkCleanRecycleBin.IsChecked = $true
})
$btnDeselectAllLimpeza.Add_Click({
    $chkCleanUserTemp.IsChecked = $false
    $chkCleanSysTemp.IsChecked = $false
    $chkCleanPrefetch.IsChecked = $false
    $chkCleanLogs.IsChecked = $false
    $chkCleanUpdateCache.IsChecked = $false
    $chkCleanRecycleBin.IsChecked = $false
})
$btnRunLimpeza.Add_Click({ Action-RunLimpeza })

# Botões da Tela de Instalação de Apps
$btnSelectAllApps.Add_Click({
    foreach ($chk in $appCheckboxObjects) {
        $chk.IsChecked = $true
    }
})

$btnDeselectAllApps.Add_Click({
    foreach ($chk in $appCheckboxObjects) {
        $chk.IsChecked = $false
    }
})

$btnRunApps.Add_Click({ Action-InstallApps })

# Botões do Terminal de Logs
$btnCopyLogs.Add_Click({
    if (-not [string]::IsNullOrEmpty($txtLogs.Text)) {
        [System.Windows.Clipboard]::SetText($txtLogs.Text)
        Set-Status "Logs copiados para a área de transferência!"
        Start-Sleep -Milliseconds 500
        Set-Status "Pronto"
    }
})
$btnClearLogs.Add_Click({
    $txtLogs.Clear()
})

# Botões e Eventos da Tela de Desinstalação de Apps
$txtSearchUninstall.Add_TextChanged({
    Action-FilterInstalledApps $txtSearchUninstall.Text
})

$lvInstalledApps.Add_SelectionChanged({
    $sel = $lvInstalledApps.SelectedItem
    if ($sel) {
        $txtDetailName.Text = $sel.Name
        $txtDetailPublisher.Text = $sel.Publisher
        $txtDetailVersion.Text = $sel.Version
        $txtDetailSize.Text = if ($sel.Size) { $sel.Size } else { "Não informado" }
        $txtDetailDate.Text = if ($sel.InstallDate) { $sel.InstallDate } else { "Não informada" }
        $txtDetailLocation.Text = if ($sel.InstallLocation) { $sel.InstallLocation } else { "Não informado" }
        $txtDetailLeftovers.Text = "Clique em 'Analisar Resíduos' para escanear."
        $txtDetailLeftovers.Foreground = [System.Windows.Media.Brush]"#FBBF24"
        $global:currentLeftovers = @()
    }
})

$btnScanLeftovers.Add_Click({ Action-ScanLeftovers })
$btnRefreshUninstall.Add_Click({ Action-LoadInstalledApps })
$btnUninstallNormal.Add_Click({ Action-UninstallNormal })
$btnUninstallDeep.Add_Click({ Action-UninstallDeep })

# Eventos adicionados de Recursos, DNS, Atalhos e Reparo do Sistema
$btnShortcutDev.Add_Click({ Start-Process devmgmt.msc })
$btnShortcutReg.Add_Click({ Start-Process regedit.exe })
$btnShortcutNet.Add_Click({ Start-Process ncpa.cpl })
$btnShortcutDisk.Add_Click({ Start-Process diskmgmt.msc })
$btnShortcutUser.Add_Click({ Start-Process control.exe -ArgumentList "/name Microsoft.UserAccounts" })
$btnShortcutPower.Add_Click({ Start-Process control.exe -ArgumentList "/name Microsoft.PowerOptions" })
$btnShortcutSys.Add_Click({ Start-Process sysdm.cpl })
$btnShortcutServ.Add_Click({ Start-Process services.msc })
$btnShortcutNetCenter.Add_Click({ Start-Process control.exe -ArgumentList "/name Microsoft.NetworkAndSharingCenter" })
$btnShortcutRes.Add_Click({ Start-Process resmon.exe })

# Novos atalhos de Rede/Sistema no Painel
$btnShortcutPingGoogle = $Window.FindName("BtnShortcutPingGoogle")
$btnShortcutIPConfig   = $Window.FindName("BtnShortcutIPConfig")
$btnShortcutFlushDNS   = $Window.FindName("BtnShortcutFlushDNS")
$btnShortcutTaskMgr    = $Window.FindName("BtnShortcutTaskMgr")
$btnShortcutControl    = $Window.FindName("BtnShortcutControl")

$btnShortcutPingGoogle.Add_Click({
    Set-Status "Pingando Google (8.8.8.8)..."
    $result = (ping 8.8.8.8 -n 4) -join "`n"
    [System.Windows.MessageBox]::Show($result, "Ping Google (8.8.8.8)", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    Set-Status "Pronto"
})

$btnShortcutIPConfig.Add_Click({
    Switch-Tab "Rede"
    Set-Status "Obtendo configurações de IP..."
    $result = (ipconfig /all) -join "`n"
    $txtRedeIPResult.Text = $result
    Set-Status "Pronto"
})

$btnShortcutFlushDNS.Add_Click({
    Set-Status "Limpando cache de DNS..."
    $null = ipconfig /flushdns
    Write-Log "DNS Cache limpo com sucesso via atalho rápido (ipconfig /flushdns)." "SUCCESS"
    Set-Status "Pronto"
    [System.Windows.MessageBox]::Show("Cache de DNS limpo com sucesso!", "Flush DNS", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

$btnShortcutTaskMgr.Add_Click({ Start-Process taskmgr.exe })
$btnShortcutControl.Add_Click({ Start-Process control.exe })

$btnApplyFeatures.Add_Click({ Action-ApplyFeatures })
$btnApplyDNS.Add_Click({ Action-ApplyDNS })
$btnRunSystemRepair.Add_Click({ Action-RunSystemRepair })
$btnBackupDrivers.Add_Click({ Action-BackupDrivers })

# 9. Inicialização dos Timers de Monitoramento de Hardware

# Timer para monitorar CPU, RAM e Uptime em tempo real
$hardwareTimer = New-Object System.Windows.Threading.DispatcherTimer
$hardwareTimer.Interval = [TimeSpan]::FromMilliseconds(1500)
$hardwareTimer.Add_Tick({
    try {
        # Atualiza uso da CPU
        $cpuVal = [Math]::Round($global:cpuCounter.NextValue(), 0)
        $BarCPU.Value = $cpuVal
        $lblCPU.Text = "$cpuVal%"
        
        # Atualiza uso da RAM
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $total = $os.TotalVisibleMemorySize
            $free = $os.FreePhysicalMemory
            $used = $total - $free
            $pct = [Math]::Round(($used / $total) * 100, 0)
            $BarRAM.Value = $pct
            $lblRAM.Text = "$pct%"
            
            $usedGB = [Math]::Round($used / 1MB, 1)
            $totalGB = [Math]::Round($total / 1MB, 1)
            $lblRAMDetail.Text = "$usedGB GB usados de $totalGB GB"
        }
        
        # Atualiza Tempo de Atividade (Uptime)
        $uptime = (Get-Date) - ([Management.ManagementDateTimeConverter]::ToDateTime((Get-CimInstance Win32_OperatingSystem).LastBootUpTime))
        $txtUptime.Text = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
    } catch {
        # Ignora falhas temporarias de leitura de contadores
    }
})

# Adaptações de UI dinâmicas conforme a versão do Windows
if (-not $global:isWindows10Or11) {
    # Windows 7, 8 ou 8.1: Oculta abas de debloat UWP e instalação de apps WinGet
    $btnTabDebloat.Visibility = [System.Windows.Visibility]::Collapsed
    $btnTabApps.Visibility = [System.Windows.Visibility]::Collapsed
    Write-Log "Windows antigo detectado: Ocultando abas de Debloat UWP e Instalação de Apps (WinGet)." "WARNING"
}

# Inicia o Timer e define a Aba Inicial (Painel)
$hardwareTimer.Start()

# Timer separado para monitorar os processos de alto consumo (mais lento, evita sobrecarga)
$processTimer = New-Object System.Windows.Threading.DispatcherTimer
$processTimer.Interval = [TimeSpan]::FromSeconds(5)
$processTimer.Add_Tick({ Action-UpdateTopProcesses })
$processTimer.Start()

# Popula a lista de processos imediatamente na abertura
Action-UpdateTopProcesses

# Carregamento do QR Code em Memória via Base64 (Hospedado nativamente no script)
$base64QrCode = "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"

if ($base64QrCode -and $base64QrCode -ne "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ZxYBnFgGcWAZxYBnFgGcWAZxYBnFgGcWAZxYBnFgGcWAZxYBnFgGcWAZxYBnFgGcWAZxYBnFgGcWAZxYBnFgGcWAZxYBnFgGcWAZxYBnFgGcWAZxYBnFgGcWAZxYBnFgGcWAZuPFPfffgPv+wB7lOaY58v57ggdQ6EAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGU5pjny/nuCB1DoQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAZTmmOfL+eroxHTugLoxAujEC6MQLoxAujEC6MQLoxAujEC6MQLoxAujEC6MQLoxAujEC6MQLoxAujEC6MQLoxAujEC6MQLoxAujEC6MQLoxAujEC6MQLoxAujEC6MQLoxAujEC6MQLoxAujEC6MQLoxAujEC6MQLoxAujEC6MQLoxAujEC6MQLoxAujEC6MQLoxAlOocx59//9oADAMBAAIRAxIAACH77777777777777777777777777777777777777777777777774L77777777777777777777777777777777777777777777777774L77777777777777777777777777777777777777777777777774L79z333333333333333333333333333333333333333333313f4Khzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz18Kzy7/8A/wDvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvlPNQvvPvAAAAAFPPIAALGPIANPLEPAAAAHMOAAHKAAPPJAAAAANFPFQvvPvFMMMCEENMMIOBGMIAMAAMAGPBOMMMMAAOAFHFHMMNIFFPFQvvPvFIAAKACADDHLAIDGBKADADJOFDGCADKJGANMFPAAFAFFPFQvvPvFAAAKAKADPMMIABJFIFJAGFMFPALBMJEFAONFPAAFAFFPFQvvPvFNPOKECPGPAAKPFKPADBPPIELPPPPNJEBKPPFPNPKAFFPFQvvPuAAAAIANNIICABGAMKKFAKHFHIIAAPPIAPALEFIAAAAFFPFQvvPuAAAACIEABAJAOKEEAKFBIEEMOICFMMAIOANGMCCACDPFPFQvvPuDDDCLCAAADDDLPCDNLFBDDBDENACNDDBOPPNGLGAPHNFPFQvvPrFMJLEOIAPMPPIGJJAFPAPMDIBPFJHMNGAGIEOMPAMMHFPFQvvPrEAJKGHPPIIPLCEEPLHDKKAFPFEMLLPKGCMNPFKFPPENFPFQvvPvAFHODCHFKDPPIDGOFNKKHBFPHDDPCDPDFAFPALJDHJFFPFQvvPvCAAAPAPFOMCBIMKAPIEPPCFBAPPKPPOMHAFNGIFFPAFFPFQvvPvDICEJIPABIJPDAFPIFODPBPPFBPGPPCEIFPPLDFPOPPFPFQvvPvHKCLCENHPPLLDCNPAFOEAJLBBDHDPPOCDPPPEDIAAANFPFQvvPrMLKMECOJEMJOCMMNKHMMMEDMANOMPOCKFMOCPMCAMKFFPFQvvPuFPIDJDOMAEPOOKAIAFLAADFEMMDDCPIGGBPMPMFBDFPFPFQvvPrPIGKDIBFPAPKCKADDHLBJDKFDDHOOPPLBDKCPBDDDFPFPFQvvPvDDCMPPHFPAMMGPHPIMBEHPIEMHPKAMPKIAPDPONFPMFFPFQvvPvAPKFDCPFJDDAHPKCJCDDOJLDPNEKKAOPCBNHNKFDLDHFPFQvvPuAPKBPDNFAFLBMIAODCHKPPEOGCBLNKLIMAHOEKHPPCFFPFQvvPvAODBMNENFNGMHPEMOMNAMMDIMPAPEPAHJAPOMMKFMFHFPFQvvPrAMIAKIKAAPPLADMAAAFAKNAFDHOELKAALAMNBPAAPJPFPFQvvPvBGCAIILAENPPCIDDADPBEEAEAAAFDDDDFAHOAEEENFPFPFQvvPvHPLDDCCACFPPJDDKFPMDDCAFMPBKDPLGBAMIADCBDHNFPFQvvPvBAADDAKGALDDNDIAADBDPAADOPDOAJAIBDDAAHFADLHFPFQvvPvHEFPPMEMAFIPKPCALHLKMFDMJENPHPKIHPOAEPFFLFPFPFQvvPrOAGMMKEAAEAPLEMEPFKMBEOBEINPHPKDLMLCAMBEMEPFPFQvvPvEMPPOCAAACAPKOABFPLAAHFNAAAMNPLIDAPPAPEDFCHFPFQvvPvAAFLIHPPAFPLGKEAAHPFAACFKAKAAPAKJCCKAHBPPFPFPFQvvPvDHPPAIPPAAHKALMAFHLADIFPHDLAAILPMJDHFIPIAFPFPPQvvPvMONPLDNOOLOMOPEEHOHHPIAMINFHDLLHAHPNDBNDDHFFPPQvvPvACFOBAPOAFAAPPBDHCPPODDCAHPDOKBGOPOJNPABDHPFPPQvvPuCLKJICDGKFJAIDAMBAPPIOMNCDCJMIBCOMDCLMBEMDFFPPQvvPvPAEKGCPPHHPPGMEPAHNLKHOAAMMLFHPGDALDPKAFPMFFPPQvvPvAGIEAFJACMMLKHJEPIDEMEBPMMNBIIDECHDBMNNHKOFFPPQvvPvKFCDABHBDAFKKOHEMCPBJAMIAAIBNIPINHHKAMLGMCHFPPQvvPvPKLPDCMHMAPKDCBBBPNADDAAHNACFPJHBHOIDDADAHPFPPQvvPvMMMMMAPLGIKEMIBPAPHAGPBPPPDIFEMBPPAANHABPFHFPPQvvPvNOMNABCJGCLOGMFPAPOAAEHPNOPBIPIHPEIAEEBEIPPFPPQvvPvFIAAAAKBKLNLNDPPIFJABCMOHJMHDPCJDACEDCBDDNPFPPQvvPvFAAAAALGJHPKBOBCFMDAOAENBGBMNJMMMBPIMLNOMGPFPPQvvPvFLDDAAOMAPKMEDEMMDBHKIJDFAACPPPGLMDHDHPJDBHFPPQvvPvIAAAIAKAIAPHIAFHAPCAHDDBDDGAJNLDLCIAKABFLHPFPPQvvPvPPPPPHHPPPHLPPLLPPPPHPPPPPPPLPPPPHPPLHLPPPPFPPQvvPDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDHPHwrmfPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPOvwvr7DTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTXvfgvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvgvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvggQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQf/aAAwDAQACEQMSAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJjxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxBsAADiAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQpAQAVyyyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxCAKACAVUAAAAAgAAsAAEsAoAoAQAAAAAAogUAAAQAAAAQAAAAAgCAoACAVUIIAEIUUowAsEwQkQwIEE8MIAcowoAAk00MEIAIIAAAACAoACAVUoAAEoQ8oEMYQ4IUYIAMc8wwA0MA0AM8Ig8ckAoAAEAACAoACAVUoAAUoQoAYAMMQAAcgoUYAkMYUAMQEEsMUAA4AoAAUAACAoACAVUoU8coEgAwgAA8AAckoUAMMgQIAsAoMYEsAAAAoEMMAACAoACAVQMMMMMcgY0s0QosockooA8AA0UIsIkIkAAAAwEsMMMsACAoACAVQAAAAIQkgcgwA884wIgoEwAEUYMwAUAwAAEIUUIEIEAACAoACAVQMMIUoAAAAIAA0MoEAggAAAEEQIAAsAAYIEMA4AscYsICAoACAVUI84EUscAs8gQQkw8ooAAA0go0oQsU8sEMsscwU8scsoCAoACAVQIkQUUgQwQgAAkA0wwAsk8AAg8gwgAwkgEA4w8AIgUggCAoACAVAoA8E88ckYMIAQMwAcAUQcIYAQAAAA8wgUgUoAgQ08ggCAoACAVUAYYUIU8UEMAA0MQAEgQAAIYAAoAUUAEMUAQs4AUgAAICAoACAVAwEQkcU8QY4kU8woAIgQ0AQgUU48wUAwgUgAU8QgAEgACAoACAVAgEAQowgwAAQQQAgAYoYAAYkUMYQwYAEkwgAAg4AAAAACAoACAVU0Ak0Ikcw8wwQcgcwMAgAAgoUAgIAoYcQkwwQAYkAAgACAoACAVUoEYYkYsIwMAAMAMcAokAIMUQMMEMMAoEYEIwAEUgMoACAoACAVEMwMAMsAUAoAAggEEoosEY8IUAAAQMAUAQ0YkAgc84oACAoACAVQAAUUwgUUAogA8wgA4AYAIwgQAoAUAgAAAAQwAAE4wgACAoACAVUwAUAw88EwoEEAM8kcIoEQQkAEkQU0IEkIEUYcAYAAMICAoACAVUAAUUMQwU4AQQEMAMsAQcgMAYcsIUQkUMAAQs8AsMMMICAoACAVAoEEQAEIAsgoAkwAAcIIEAA8UcoAAMAQAEAA4AAAUAYACAoACAVUggAUIU4AUAAUwYIQogoAIoAEwgEAUIAAQgQUwIAUUYgCAoACAVUoccUgw0AEgAA0wsU8AgEQAAU880MsgAA4IQYwAMAQoACAoACAVUgAQMMMAEIAIAcMYQoAIMMIIEAAAUMAsEEAIoAEMMMgICAoACAVUcoAMM0o08kwg0McAowEcAAEwYA0EcYsUYwIwYIU4MwoCAoACAVAgUQAAwQwAAgQkoUAwA8UwIkwE44Agg4AAAoQwoUoEoACAoACAVE0cEww84AAwsAw4ssMIogA4wQc8sA4gEAMww084U00sACAoACAVUoEIAIEMMAMIU8AsIoAsEMgEQMMMAsAcMEAAEMoUocMACAoACAVUAUAQ4gAAYoAQkAEwwoE4ww04cwUAAAUwoI8cwg4AUoACAoACAVAAQAAUc8U84gAgIoA4AEgAgwAgAQAAQwAwoQAAwAwgoACAAACAVUAgAEoA8QMAIA8gwUQI0QAggAUIwYAMMoAAEAggUkMoADAAACAVAoYMEU48cAoIUEMgMgIAAIMMIAEIYAoEEAAAoEAAsMsIDAAACAVAocYUUkAQUoYUcAQEoIAAsIAQMAEQcgIUAIAEAAMgAIgDAAACAVAAAUE008AwAAAEw0QogUQYgAAwwgQUowEAoAgAAAoAQoDAAACAVEI4cMsI0AMkIQAIMcQg0AMMIEMMIMAgIQMgAEMAMAEEoDAAACAVQIgQw088AY4wAck08MIUA0w0M4ws4YAkY8IAowMEkMQADAAACAVAAQcAUY4cMoAAMAIAEAUEMMIA0IEYUooIIgEgMMIMAgADAAACAVUwwwww88QUAUAwgAgow0AoA4wwAQkUQgAAQgAQIQAkYADAAACAVUY888EokMYoA0c0AA8oEAssoUMgIUswMIMoAE8sUUYAADAAACAVUowwkU84kQMIQA8MMYooA4wIEcwAw8sE0woIc84U84AADAAACAVUoAAUU8oUYgMEQIoEoAMEoAsQEIAAIgIEIoAkMAAAUoIDAAACAVUogAQU84Q8AkAEgYAwg0QIgQQ8AQEEgwQQoQAwAAgEogDAAACAVQQwwwg8oAQwYgAwU0AIIwYwgwQwYg0gQwwoQwQ4kIQAADAAACAVQwwwwwgQwwwAQwwgQwgQwAAAgAAwgAAAAAQwwgwwAAAADAAACAQDDDDDDD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AU6kLKPCyjwso8LKPCyjwmwtoR6gQJbgFOpCyjwso8J5J41Yd0EDxmYJJiftllHhZR4WUeEATEjCnCRBGqAcH6KyjwgLADoAO3CVF6pGJ+yFlHhZR4Q8gUZkAd0gSTOBsi7gMnCXYfAG2IAB0Kyjwso8LKPCyjwso8LKPCAAAAAEgBQLahQA6FZR4WUeEWBACKESO3w68GVs/wDQiguvBlbOAUGYgIDkQ44AIpKZP2S57puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabmm5puabg2wTmSOAVOSAFqBCbn1H/oaIKVqHU8AqjQ9hlDYgCCABwRMEGhB/8+CaaPNoG5Rpexfg4RRdlA1g2QaBOAgne33/AOdI2Kkly2FSrYbWr+p4xXWM050dkNSDVw5kIf8AylVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVf/lKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq8KqqqqoKZ3dBQTrP6Ec18FF3/wDwcFChQoUKs2bNmzZs2bNmzZs2bNmzZs2bNmzZs2bNmzZ/+JZs2bNmzZs2bNmzZs2bNmzZs2bNmzZs2bNmzZs2bNmz/wDCs2bNmzZs2bNmzZs2bNmzZs2bNmzZs2bNmzZs2bNkhk6iZvy/d1///gADAP/Z") {
    try {
        $imageBytes = [System.Convert]::FromBase64String($base64QrCode)
        $tempFile = Join-Path $env:TEMP "qrcode_samack.jpeg"
        [System.IO.File]::WriteAllBytes($tempFile, $imageBytes)
        
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.UriSource = New-Object System.Uri($tempFile)
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.EndInit()
        $imgQrCode.Source = $bitmap
    } catch {
        Write-Log "Não foi possível carregar o QR Code do Pix: $_" "WARNING"
    }
}

Switch-Tab "Painel"
Write-Log "Sistema inicializado com sucesso. Pronto para execução."

# 10. Executa o Loop da Janela WPF
$Window.ShowDialog() | Out-Null
$hardwareTimer.Stop()
$processTimer.Stop()

# Fechar o PowerShell completamente ao sair
Stop-Process -Id $PID -Force

