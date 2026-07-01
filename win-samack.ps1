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
    <Border CornerRadius="14" Background="#0A0F1D" BorderBrush="#252F48" BorderThickness="1.5">
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
                            <Button x:Name="BtnTabLogs" Style="{StaticResource SidebarButton}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="📜" Margin="0,0,10,0"/>
                                    <TextBlock Text="Logs de Execução"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>
                        
                        <!-- Logo/Tag do Desenvolvedor -->
                        <TextBlock Grid.Row="1" Text="Criado por Samack" Foreground="#475569" FontSize="11" HorizontalAlignment="Center" Margin="0,0,0,10"/>
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
                                                    <TextBlock x:Name="TxtRedeIPResult" Text="Clique em 'Ver Configuração de IP' para carregar..." FontSize="10" Foreground="#94A3B8" FontFamily="Consolas" TextWrapping="Wrap"/>
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
                                                <ScrollViewer Height="100" VerticalScrollBarVisibility="Auto">
                                                    <TextBlock x:Name="TxtRedePingResult" Text="Aguardando..." FontSize="10" Foreground="#94A3B8" FontFamily="Consolas" TextWrapping="Wrap"/>
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
                                                    <TextBlock x:Name="TxtRedeNetstatResult" Text="Clique em 'Ver Conexões Ativas' para carregar..." FontSize="10" Foreground="#94A3B8" FontFamily="Consolas" TextWrapping="Wrap"/>
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
                                                    <TextBlock x:Name="TxtRedeTracertResult" Text="Aguardando..." FontSize="10" Foreground="#94A3B8" FontFamily="Consolas" TextWrapping="Wrap"/>
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

# Mapeando controles da tela de Ativação
$btnRunActivation = $Window.FindName("BtnRunActivation")

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

# Ativa ou desativa recursos opcionais do Windows
function Action-ApplyFeatures {
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

# Fechar e Minimizar Janela
$btnClose.Add_Click({ $Window.Close() })
$btnMinimize.Add_Click({ $Window.WindowState = [System.Windows.WindowState]::Minimized })

# Evento para arrastar a janela (Necessário por causa do WindowStyle="None")
$titleBar.add_MouseDown({
    if ($args[1].LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed) {
        $Window.DragMove()
    }
})

# Navegação por Abas
$btnTabPainel.Add_Click({ Switch-Tab "Painel" })
$btnTabDebloat.Add_Click({ Switch-Tab "Debloat" })
$btnTabDesempenho.Add_Click({ Switch-Tab "Desempenho" })
$btnTabLimpeza.Add_Click({ Switch-Tab "Limpeza" })
$btnTabRede.Add_Click({ Switch-Tab "Rede" })
$btnTabAtivacao.Add_Click({ Switch-Tab "Ativacao" })
$btnTabLogs.Add_Click({ Switch-Tab "Logs" })
$btnTabApps.Add_Click({ Switch-Tab "Apps" })
$btnTabUninstall.Add_Click({ Switch-Tab "Uninstall"; Action-LoadInstalledApps })

# ── Ativação (MAS) ──────────────────────────────────────────────────────────
$btnRunActivation.Add_Click({
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
    Set-Status "Obtendo configurações de IP..."
    $result = (ipconfig /all) -join "`n"
    $txtRedeIPResult.Text = $result
    Set-Status "Pronto"
})

$btnRedePing.Add_Click({
    $host = $txtRedePingHost.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($host)) { $host = "8.8.8.8" }
    Set-Status "Pingando $host..."
    $txtRedePingResult.Text = "Pingando $host..."
    $result = (ping $host -n 4) -join "`n"
    $txtRedePingResult.Text = $result
    Set-Status "Pronto"
})

$btnRedeNetstat.Add_Click({
    Set-Status "Obtendo conexões ativas..."
    $txtRedeNetstatResult.Text = "Carregando..."
    $result = (netstat -ano) -join "`n"
    $txtRedeNetstatResult.Text = $result
    Set-Status "Pronto"
})

$btnRedeFlushDNS.Add_Click({
    Set-Status "Limpando cache de DNS..."
    $null = ipconfig /flushdns
    Write-Log "DNS Cache limpo com sucesso (ipconfig /flushdns)." "SUCCESS"
    Set-Status "Pronto"
    [System.Windows.MessageBox]::Show("Cache de DNS limpo com sucesso!", "Flush DNS", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

$btnRedeReset.Add_Click({
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
    $host = $txtRedeTracertHost.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($host)) { $host = "8.8.8.8" }
    Set-Status "Rastreando rota para $host (pode demorar)..."
    $txtRedeTracertResult.Text = "Rastreando $host, aguarde..."
    Out-DoEvents
    $result = (tracert -d -h 15 $host) -join "`n"
    $txtRedeTracertResult.Text = $result
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

Switch-Tab "Painel"
Write-Log "Sistema inicializado com sucesso. Pronto para execução."

# 10. Executa o Loop da Janela WPF
$Window.ShowDialog() | Out-Null
$hardwareTimer.Stop()
$processTimer.Stop()

