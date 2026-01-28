# RemoteAdmin Viewer - V4 (PS 5.1, WPF)
# Tabs: Startseite, Computer, Software
# Login = nur im RAM, wird für WinRM verwendet.
# VNC: Öffnet IMMER C:\RemoteAdminLite\VNC\<Name>.vnc (wie Doppelklick)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

# ----------------- State & Pfade -----------------
$Global:State = [ordered]@{
  Cred          = $null
  Computers     = @()
  ComputersPath = 'C:\RemoteAdminLite\View\Computers.json'
  VncDir        = 'C:\RemoteAdminLite\VNC'
}

# Ordner sicherstellen
$dirs = @(
  (Split-Path $Global:State.ComputersPath -Parent),
  $Global:State.VncDir,
  'C:\RemoteAdminLite\Logs'
) | Sort-Object -Unique

foreach ($d in $dirs) {
  if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# Beispiel-Computers.json anlegen (falls fehlt)
if (-not (Test-Path $Global:State.ComputersPath)) {
@'
[
  { "Name": "Test-Laptop", "Host": "Prahavin", "Port": 5900, "Tags": "Home", "Notes": "Prahavin daheim" },
  { "Name": "Handy", "Host": "192.168.254.4", "Port": 5900, "Tags": "Mobile", "Notes": "Valts Smartphone" }
]
'@ | Set-Content -Path $Global:State.ComputersPath -Encoding UTF8
}


# ----------------- Logging -----------------
$Global:LogDir = 'C:\RemoteAdminLite\Logs'
if (-not (Test-Path $Global:LogDir)) { New-Item -ItemType Directory -Path $Global:LogDir -Force | Out-Null }

function Get-AdminUser {
  if ($Global:State.Cred -and $Global:State.Cred.UserName) { return [string]$Global:State.Cred.UserName }
  return [string]$env:USERNAME
}

function Write-Log([string]$Action, [string]$Target, [string]$Status, [string]$Detail) {
  try {
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $pc = [string]$env:COMPUTERNAME
    $user = Get-AdminUser
    $file = Join-Path $Global:LogDir ("Viewer_{0}.log" -f (Get-Date -Format 'yyyy-MM-dd'))
    $d = if ($Detail) { ($Detail -replace "`r"," " -replace "`n"," ").Trim() } else { "" }
    $line = "{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}" -f $ts,$pc,$user,$Action,$Target,$Status,$d
    Add-Content -Path $file -Value $line -Encoding UTF8
  } catch { }
}
# ----------------- XAML -----------------
# ACHTUNG: < und > in Texten müssen escaped werden (&lt; &gt;) -> sonst XAML kaputt.
$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="RemoteAdmin Viewer" Height="720" Width="1120"
        WindowStartupLocation="CenterScreen"
        Background="#0B0F14"
        Foreground="#E5E7EB">

  <Window.Resources>

    <!-- Farben (Rot/Blau/Gelb + Weiss/Schwarz/Hellgrau) -->
    <SolidColorBrush x:Key="Bg" Color="#0B0F14"/>
    <SolidColorBrush x:Key="Panel" Color="#111827"/>
    <SolidColorBrush x:Key="Panel2" Color="#0F172A"/>
    <SolidColorBrush x:Key="Border" Color="#1F2937"/>
    <SolidColorBrush x:Key="TextDim" Color="#CBD5E1"/>

    <SolidColorBrush x:Key="Blue" Color="#3B82F6"/>
    <SolidColorBrush x:Key="Red" Color="#EF4444"/>
    <SolidColorBrush x:Key="Yellow" Color="#F59E0B"/>

    <!-- Button Style -->
    <Style TargetType="Button">
      <Setter Property="Background" Value="{StaticResource Panel2}"/>
      <Setter Property="Foreground" Value="#E5E7EB"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="12,8"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="10">
              <ContentPresenter HorizontalAlignment="Center"
                                VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="BorderBrush" Value="{StaticResource Blue}"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter Property="Background" Value="#0B1220"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.55"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- TextBox Style -->
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#0B1220"/>
      <Setter Property="Foreground" Value="#E5E7EB"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,7"/>
      <Setter Property="FontSize" Value="13"/>
    </Style>

    <!-- PasswordBox Style -->
    <Style TargetType="PasswordBox">
      <Setter Property="Background" Value="#0B1220"/>
      <Setter Property="Foreground" Value="#E5E7EB"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,7"/>
      <Setter Property="FontSize" Value="13"/>
    </Style>

    <!-- TabControl -->
    <Style TargetType="TabControl">
      <Setter Property="Background" Value="{StaticResource Panel}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border}"/>
      <Setter Property="BorderThickness" Value="1"/>
    </Style>

    <!-- DataGrid -->
    <Style TargetType="DataGrid">
      <Setter Property="Background" Value="#0B0F14"/>
      <Setter Property="Foreground" Value="#E5E7EB"/>
      <Setter Property="RowBackground" Value="#0B0F14"/>
      <Setter Property="AlternatingRowBackground" Value="#111827"/>
      <Setter Property="GridLinesVisibility" Value="None"/>
      <Setter Property="HeadersVisibility" Value="Column"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border}"/>
      <Setter Property="BorderThickness" Value="1"/>
    </Style>

    <Style TargetType="TextBlock">
      <Setter Property="TextOptions.TextFormattingMode" Value="Display"/>
      <Setter Property="TextOptions.TextRenderingMode" Value="ClearType"/>
    </Style>

  </Window.Resources>

  <Grid Margin="14">
    <!-- MAIN -->
    <Grid x:Name="MainGrid" Visibility="Collapsed">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <!-- Header -->
      <Border Background="{StaticResource Panel}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="14" Padding="14" Grid.Row="0" Margin="0,0,0,12">
        <DockPanel>
          <StackPanel Orientation="Horizontal">
            <TextBlock Text="RemoteAdmin" FontSize="18" FontWeight="Bold" Margin="0,0,10,0"/>
            <Border Background="{StaticResource Yellow}" CornerRadius="8" Padding="8,2" Margin="0,2,0,0">
              <TextBlock Text="Viewer" Foreground="#0B0F14" FontWeight="Bold"/>
            </Border>
          </StackPanel>

          <DockPanel DockPanel.Dock="Right" LastChildFill="False">
            <TextBlock x:Name="TxtLoginInfo" Foreground="{StaticResource TextDim}" VerticalAlignment="Center" Margin="0,0,10,0" Text="Nicht angemeldet"/>
            <Button x:Name="BtnReload" Content="Neu laden" Margin="8,0,0,0"/>
            <Button x:Name="BtnLogout" Content="Abmelden" Margin="8,0,0,0" Background="{StaticResource Red}" BorderBrush="{StaticResource Red}"/>
          </DockPanel>
        </DockPanel>
      </Border>

      <!-- Tabs -->
      <TabControl x:Name="MainTabs" Grid.Row="1">
        <TabItem Header="Startseite">
          <Grid Margin="12">
            <Border Background="{StaticResource Panel}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="14" Padding="18">
              <StackPanel>
                <TextBlock Text="Übersicht" FontSize="22" FontWeight="Bold" Margin="0,0,0,10"/>
                <TextBlock x:Name="TxtStatus" Text="Status: bereit" Foreground="{StaticResource TextDim}" FontSize="14" Margin="0,0,0,6"/>
                <TextBlock x:Name="TxtCounts" Text="Computer: 0" Foreground="{StaticResource TextDim}" FontSize="14" Margin="0,0,0,14"/>
                <Border Background="#0B1220" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="12" Padding="12">
                  <StackPanel>
                    <TextBlock Text="VNC-Profil-Regel" FontWeight="Bold" Margin="0,0,0,6"/>
                    <TextBlock Text="C:\RemoteAdminLite\VNC\&lt;Name&gt;.vnc" Foreground="{StaticResource Blue}"/>
                    <TextBlock Text="Beispiel: Handy -> Handy.vnc, Test-Laptop -> Test-Laptop.vnc" Foreground="{StaticResource TextDim}" Margin="0,6,0,0"/>
                  </StackPanel>
                </Border>
              </StackPanel>
            </Border>
          </Grid>
        </TabItem>

        <TabItem Header="Computer">
          <Grid Margin="12">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="2*"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Background="{StaticResource Panel}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="14" Padding="12" Margin="0,0,12,0">
              <DataGrid x:Name="DgComputers" AutoGenerateColumns="False" CanUserAddRows="False"
                        IsReadOnly="True" SelectionMode="Single">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="*"/>
                  <DataGridTextColumn Header="Host" Binding="{Binding Host}" Width="*"/>
                  <DataGridTextColumn Header="Port" Binding="{Binding Port}" Width="80"/>
                  <DataGridTextColumn Header="Tags" Binding="{Binding Tags}" Width="*"/>
                  <DataGridTextColumn Header="Notes" Binding="{Binding Notes}" Width="2*"/>
                </DataGrid.Columns>
              </DataGrid>
            </Border>

            <Border Grid.Column="1" Background="{StaticResource Panel}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="14" Padding="14">
              <StackPanel>
                <TextBlock Text="Aktionen" FontWeight="Bold" FontSize="16" Margin="0,0,0,10"/>

                <Button x:Name="BtnWsman" Content="WinRM testen" Margin="0,0,0,8" Background="{StaticResource Blue}" BorderBrush="{StaticResource Blue}"/>
                <Button x:Name="BtnMsg" Content="Nachricht senden" Margin="0,0,0,8"/>
                <Button x:Name="BtnVnc" Content="VNC starten (.vnc)" Margin="0,0,0,8" Background="{StaticResource Yellow}" BorderBrush="{StaticResource Yellow}" Foreground="#0B0F14"/>

                <Button x:Name="BtnLockWin" Content="PC sperren (Win+L)" Margin="0,0,0,8"/>
                <Button x:Name="BtnShutdownWin" Content="PC ausschalten" Margin="0,0,0,8" Background="{StaticResource Red}" BorderBrush="{StaticResource Red}"/>
                <Button x:Name="BtnRestartWin" Content="PC neu starten" Margin="0,0,0,8" Background="{StaticResource Blue}" BorderBrush="{StaticResource Blue}"/>

                <Separator Margin="0,10,0,10"/>

                <TextBlock Text="Nachricht:" Foreground="{StaticResource TextDim}"/>
                <TextBox x:Name="TbMessage" Height="110" TextWrapping="Wrap" AcceptsReturn="True" Margin="0,6,0,0"/>
              </StackPanel>
            </Border>
          </Grid>
        </TabItem>

        <TabItem Header="Software">
          <Grid Margin="12">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <Border Background="{StaticResource Panel}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="14" Padding="12" Grid.Row="0" Margin="0,0,0,12">
              <DockPanel>
                <TextBlock Text="Remote Software-Inventar" FontWeight="Bold" VerticalAlignment="Center"/>
                <Button x:Name="BtnLoadSoftware" Content="Inventar laden" DockPanel.Dock="Right" Background="{StaticResource Blue}" BorderBrush="{StaticResource Blue}"/>
              </DockPanel>
            </Border>

            <Border Background="{StaticResource Panel}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="14" Padding="12" Grid.Row="1">
              <DataGrid x:Name="DgSoftware" AutoGenerateColumns="True"/>
            </Border>
          </Grid>
        </TabItem>
        <TabItem Header="Chat">
          <Grid Margin="12">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="2*"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Background="{StaticResource Panel}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="14" Padding="12" Margin="0,0,12,0">
              <DockPanel LastChildFill="True">
                <TextBlock DockPanel.Dock="Top" Text="Chat" FontWeight="Bold" FontSize="16" Margin="0,0,0,10"/>
                <ListBox x:Name="LbChat" Background="#0B0F14" BorderBrush="{StaticResource Border}" BorderThickness="1" Padding="6"/>
              </DockPanel>
            </Border>

            <Border Grid.Column="1" Background="{StaticResource Panel}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="14" Padding="14">
              <StackPanel>
                <TextBlock Text="Verbindung" FontWeight="Bold" FontSize="16" Margin="0,0,0,10"/>
                <TextBlock x:Name="TxtChatStatus" Text="Status: getrennt" Foreground="{StaticResource TextDim}" Margin="0,0,0,10"/>
                <Button x:Name="BtnChatConnect" Content="Verbinden" Background="{StaticResource Blue}" BorderBrush="{StaticResource Blue}" Margin="0,0,0,8"/>
                <Button x:Name="BtnChatDisconnect" Content="Trennen" Background="{StaticResource Red}" BorderBrush="{StaticResource Red}" Margin="0,0,0,14"/>

                <Separator Margin="0,10,0,10"/>

                <TextBlock Text="Text:" Foreground="{StaticResource TextDim}"/>
                <TextBox x:Name="TbChatInput" Height="110" TextWrapping="Wrap" AcceptsReturn="True" Margin="0,6,0,8"/>
                <Button x:Name="BtnChatSend" Content="Senden" Background="{StaticResource Yellow}" BorderBrush="{StaticResource Yellow}" Foreground="#0B0F14"/>
              
                <Separator Margin="0,12,0,10"/>

                <TextBlock Text="Geräte-Befehle (nur wenn Chat verbunden)" FontWeight="Bold" FontSize="14" Margin="0,0,0,8"/>
                <Button x:Name="BtnCmdLock" Content="Handy sperren (Android)" Margin="0,0,0,8"/>
                <Button x:Name="BtnCmdShutdown" Content="Handy ausschalten (Android, Root nötig)" Margin="0,0,0,8" Background="{StaticResource Red}" BorderBrush="{StaticResource Red}"/>
                <Button x:Name="BtnCmdPing" Content="Ping (Test)" Margin="0,0,0,8"/>
</StackPanel>
            </Border>
          </Grid>
        </TabItem>



      </TabControl>
    </Grid>

    <!-- LOGIN -->
    <Grid x:Name="LoginGrid">
      <Border Background="{StaticResource Panel}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="16" Padding="26" Width="460" HorizontalAlignment="Center" VerticalAlignment="Center">
        <StackPanel>

          <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
            <Border Background="{StaticResource Red}" CornerRadius="10" Padding="10,6" Margin="0,0,10,0">
              <TextBlock Text="LOGIN" Foreground="White" FontWeight="Bold"/>
            </Border>
            <TextBlock Text="RemoteAdmin Viewer" FontSize="20" FontWeight="Bold" VerticalAlignment="Center"/>
          </StackPanel>

          <TextBlock Text="Benutzer" Foreground="{StaticResource TextDim}"/>
          <TextBox x:Name="TbUser" Margin="0,6,0,12" />

          <TextBlock Text="Passwort" Foreground="{StaticResource TextDim}"/>
          <PasswordBox x:Name="TbPass" Margin="0,6,0,14" />

          <StackPanel Orientation="Horizontal">
            <Button x:Name="BtnLogin" Content="Anmelden" Background="{StaticResource Blue}" BorderBrush="{StaticResource Blue}" />
            <Button x:Name="BtnQuit" Content="Beenden" Margin="10,0,0,0" />
          </StackPanel>

          <TextBlock x:Name="TxtLoginError" Foreground="{StaticResource Red}" Margin="0,14,0,0" TextWrapping="Wrap"/>

        </StackPanel>
      </Border>
    </Grid>

  </Grid>
</Window>
"@

# ----------------- XAML laden -----------------
try {
  $xmlObj = New-Object System.Xml.XmlDocument
  $xmlObj.LoadXml($Xaml)
  $reader = New-Object System.Xml.XmlNodeReader($xmlObj)
  $Window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
  throw ("XAML kaputt: {0}" -f $_.Exception.Message)
}

# ----------------- Controls -----------------
$MainGrid      = $Window.FindName('MainGrid')
$LoginGrid     = $Window.FindName('LoginGrid')

$TxtLoginInfo  = $Window.FindName('TxtLoginInfo')
$TxtStatus     = $Window.FindName('TxtStatus')
$TxtCounts     = $Window.FindName('TxtCounts')

$BtnReload     = $Window.FindName('BtnReload')
$BtnLogout     = $Window.FindName('BtnLogout')

$DgComputers   = $Window.FindName('DgComputers')
$BtnWsman      = $Window.FindName('BtnWsman')
$BtnMsg        = $Window.FindName('BtnMsg')
$BtnVnc        = $Window.FindName('BtnVnc')
$BtnLockWin    = $Window.FindName('BtnLockWin')
$BtnShutdownWin = $Window.FindName('BtnShutdownWin')
$BtnRestartWin  = $Window.FindName('BtnRestartWin')

$TbMessage     = $Window.FindName('TbMessage')

$BtnLoadSoftware = $Window.FindName('BtnLoadSoftware')
$DgSoftware      = $Window.FindName('DgSoftware')

$LbChat        = $Window.FindName('LbChat')
$TxtChatStatus = $Window.FindName('TxtChatStatus')
$BtnChatConnect = $Window.FindName('BtnChatConnect')
$BtnChatDisconnect = $Window.FindName('BtnChatDisconnect')
$TbChatInput   = $Window.FindName('TbChatInput')
$BtnChatSend   = $Window.FindName('BtnChatSend')
$BtnCmdLock     = $Window.FindName('BtnCmdLock')
$BtnCmdShutdown = $Window.FindName('BtnCmdShutdown')
$BtnCmdPing     = $Window.FindName('BtnCmdPing')


$TbUser        = $Window.FindName('TbUser')
$TbPass        = $Window.FindName('TbPass')
$BtnLogin      = $Window.FindName('BtnLogin')
$BtnQuit       = $Window.FindName('BtnQuit')
$TxtLoginError = $Window.FindName('TxtLoginError')

# Safety: wenn irgendwas null ist -> sofort Fehler, statt still kaputt.
$must = @('MainGrid','LoginGrid','TxtLoginInfo','TxtStatus','TxtCounts','BtnReload','BtnLogout','DgComputers','BtnWsman','BtnMsg','BtnVnc','TbMessage','BtnLoadSoftware','DgSoftware','TbUser','TbPass','BtnLogin','BtnQuit','TxtLoginError','LbChat','TxtChatStatus','BtnChatConnect','BtnChatDisconnect','TbChatInput','BtnChatSend')
foreach ($n in $must) {
  if ($null -eq (Get-Variable -Name $n -ValueOnly -ErrorAction SilentlyContinue)) {
    throw ("WPF Control fehlt (FindName): {0}" -f $n)
  }
}

# ----------------- UI Helper -----------------
function Show-Info([string]$msg) { $TxtStatus.Text = ("Status: {0}" -f $msg) }

function Alert([string]$m) {
  [System.Windows.MessageBox]::Show($m, 'Hinweis', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
}
function AlertErr([string]$m) {
  [System.Windows.MessageBox]::Show($m, 'Fehler', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
}

# ----------------- Data Helper -----------------
function Load-Computers {
  try {
    $json  = Get-Content $Global:State.ComputersPath -Raw -ErrorAction Stop
    $items = $json | ConvertFrom-Json
    if ($items -isnot [System.Collections.IEnumerable]) { $items = @($items) }
    $Global:State.Computers = @($items)
    $DgComputers.ItemsSource = $Global:State.Computers
    $TxtCounts.Text = ('Computer: {0}' -f $Global:State.Computers.Count)
    Show-Info 'Computerliste geladen'
  } catch {
    AlertErr ("Computers.json konnte nicht geladen werden:`n{0}`n`nPfad: {1}" -f $_.Exception.Message, $Global:State.ComputersPath)
  }
}

function Get-SelectedRow {
  $row = $DgComputers.SelectedItem
  if (-not $row) { Alert "Bitte erst einen Computer wählen."; return $null }
  if (-not $row.Name) { Alert "In der Zeile fehlt 'Name'."; return $null }
  return $row
}


function Is-MobileTarget($row) {
  try {
    $t = [string]$row.Tags
    $n = [string]$row.Name
    return ($t -match '(?i)mobile|android|handy' -or $n -match '(?i)handy|android')
  } catch { return $false }
}

function Confirm-Action([string]$text, [string]$title) {
  $r = [System.Windows.MessageBox]::Show($text, $title, [System.Windows.MessageBoxButton]::OKCancel, [System.Windows.MessageBoxImage]::Warning)
  return ($r -eq [System.Windows.MessageBoxResult]::OK)
}
function Ensure-Cred {
  if ($null -eq $Global:State.Cred) { Alert "Bitte erst anmelden."; return $false }
  return $true
}

function Get-VncProfilePath([string]$name) {
  $safe = ($name -replace '[\\/:*?"<>|]', '_')
  Join-Path $Global:State.VncDir ($safe + '.vnc')
}

function Start-VncProfile([string]$name) {
  $vncFile = Get-VncProfilePath -name $name
  if (-not (Test-Path $vncFile)) {
    AlertErr ("VNC-Profil fehlt:`n{0}`n`nErstelle es im UltraVNC Viewer -> Save as -> genau dieser Pfad." -f $vncFile)
    return
  }

  try {
    # EXAKT wie Doppelklick (funktioniert bei dir nachweislich):
    Start-Process -FilePath $vncFile | Out-Null
    Show-Info ("VNC gestartet: {0}" -f (Split-Path $vncFile -Leaf))
  } catch {
    AlertErr ("VNC Start fehlgeschlagen:`n{0}" -f $_.Exception.Message)
  }
}


# ----------------- Chat (TCP) -----------------
# Idee: Viewer verbindet sich auf Port 5050/TCP zu einem Chat-Host (separates Script).
# Protokoll: pro Zeile 1 Nachricht (Plain Text). Einfach und stabil.

$Global:Chat = [ordered]@{
  Port      = 5050
  Client    = $null
  Reader    = $null
  Writer    = $null
  ReadTask  = $null
  Target    = $null
  Connected = $false
}

function Chat-UiAdd([string]$line) {
  # UI Update immer über Dispatcher (Thread-safe)
  $Window.Dispatcher.Invoke([action]{
    $LbChat.Items.Add($line) | Out-Null
    if ($LbChat.Items.Count -gt 0) {
      $LbChat.ScrollIntoView($LbChat.Items[$LbChat.Items.Count-1])
    }
  })
}

function Chat-SetStatus([string]$s) {
  $Window.Dispatcher.Invoke([action]{
    $TxtChatStatus.Text = ("Status: {0}" -f $s)
  })
}

function Chat-Disconnect {
  try { $Global:Chat.Connected = $false } catch {}
  try { if ($Global:Chat.Reader) { $Global:Chat.Reader.Close() } } catch {}
  try { if ($Global:Chat.Writer) { $Global:Chat.Writer.Close() } } catch {}
  try { if ($Global:Chat.Client) { $Global:Chat.Client.Close() } } catch {}

  $Global:Chat.Client   = $null
  $Global:Chat.Reader   = $null
  $Global:Chat.Writer   = $null
  $Global:Chat.ReadTask = $null
  $Global:Chat.Target   = $null

  Chat-SetStatus "getrennt"
}

function Chat-Connect([string]$target) {
  Chat-Disconnect

  if ([string]::IsNullOrWhiteSpace($target)) { throw "Kein Host angegeben." }

  $client = New-Object System.Net.Sockets.TcpClient
  $ar = $client.BeginConnect($target, [int]$Global:Chat.Port, $null, $null)
  if (-not $ar.AsyncWaitHandle.WaitOne(3000, $false)) {
    try { $client.Close() } catch {}
    throw ("Timeout: Keine Verbindung zu {0}:{1}" -f $target, $Global:Chat.Port)
  }
  $client.EndConnect($ar)

  $stream = $client.GetStream()
  $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
  $writer = New-Object System.IO.StreamWriter($stream, [System.Text.Encoding]::UTF8)
  $writer.AutoFlush = $true

  $Global:Chat.Client    = $client
  $Global:Chat.Reader    = $reader
  $Global:Chat.Writer    = $writer
  $Global:Chat.Target    = $target
  $Global:Chat.Connected = $true

  Write-Log "CHAT_CONNECT" $target "OK" ""
  Chat-SetStatus ("verbunden mit {0}:{1}" -f $target, $Global:Chat.Port)
  Chat-UiAdd ("[{0}] System: verbunden" -f (Get-Date -Format "HH:mm:ss"))

  # Reader-Loop in Hintergrundtask
  $w  = $Window
  $lb = $LbChat
  $txt = $TxtChatStatus

  $Global:Chat.ReadTask = [System.Threading.Tasks.Task]::Run([Action]{
    try {
      while ($true) {
        $line = $reader.ReadLine()
        if ($null -eq $line) { break }
        Write-Log "CHAT_RECV" ($Global:Chat.Target) "RECV" $line
        Chat-UiAdd($line)
      }
    } catch {
      # ignorieren -> meist disconnect
    } finally {
      try { $client.Close() } catch {}
      $w.Dispatcher.Invoke([action]{
        $txt.Text = "Status: getrennt"
      })
    }
  })
}


function Chat-SendCommand([string]$cmd) {
  if (-not $Global:Chat.Connected -or -not $Global:Chat.Writer) {
    Alert "Chat ist nicht verbunden."
    return
  }
  if ([string]::IsNullOrWhiteSpace($cmd)) { return }
  $admin = Get-AdminUser
  $line = "__CMD__|{0}|{1}" -f $admin, $cmd.Trim()
  try {
    $Global:Chat.Writer.WriteLine($line)
    Chat-UiAdd(("[{0}] System -> CMD: {1}" -f (Get-Date -Format "HH:mm:ss"), $cmd))
    Write-Log "CHAT_CMD" ($Global:Chat.Target) "SENT" $cmd
  } catch {
    Write-Log "CHAT_CMD" ($Global:Chat.Target) "ERR" $_.Exception.Message
    AlertErr ("CMD senden fehlgeschlagen:`n{0}" -f $_.Exception.Message)
    Chat-Disconnect
  }
}
function Chat-Send([string]$text) {
  if (-not $Global:Chat.Connected -or -not $Global:Chat.Writer) {
    Alert "Chat ist nicht verbunden."
    return
  }
  if ([string]::IsNullOrWhiteSpace($text)) { return }

  $me = if ($Global:State.Cred) { $Global:State.Cred.UserName } else { "Viewer" }
  $line = ("[{0}] {1}: {2}" -f (Get-Date -Format "HH:mm:ss"), $me, $text.Replace("`r"," ").Replace("`n"," "))
  try {
    Write-Log "CHAT_SEND" ($Global:Chat.Target) "SENT" $text
    $Global:Chat.Writer.WriteLine($line)
    Chat-UiAdd($line)
  } catch {
    Write-Log "WIN_MSG" $target "ERR" $_.Exception.Message
    AlertErr ("Senden fehlgeschlagen:`n{0}" -f $_.Exception.Message)
    Chat-Disconnect
  }
}


# ----------------- Events: Login -----------------
$BtnLogin.Add_Click({
  try {
    $TxtLoginError.Text = ''
    $u = $TbUser.Text
    $p = $TbPass.Password

    if ([string]::IsNullOrWhiteSpace($u) -or [string]::IsNullOrWhiteSpace($p)) {
      $TxtLoginError.Text = "Benutzer und Passwort eingeben."
      return
    }

    $sec  = ConvertTo-SecureString $p -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($u,$sec)

    if ($null -eq $cred -or [string]::IsNullOrWhiteSpace($cred.UserName)) {
      $TxtLoginError.Text = "Credential konnte nicht erstellt werden."
      return
    }

    $Global:State.Cred = $cred

    $TxtLoginInfo.Text = ("Angemeldet als: {0}" -f $u)
    $LoginGrid.Visibility = 'Collapsed'
    $MainGrid.Visibility  = 'Visible'

    Load-Computers
    Show-Info "angemeldet"
  } catch {
    $TxtLoginError.Text = ("Login-Fehler: {0}" -f $_.Exception.Message)
  }
})

$BtnQuit.Add_Click({ $Window.Close() })

$BtnLogout.Add_Click({
  $Global:State.Cred = $null
  $TxtLoginInfo.Text = "Nicht angemeldet"
  $MainGrid.Visibility  = 'Collapsed'
  $LoginGrid.Visibility = 'Visible'
  Show-Info "abgemeldet"
})

$BtnReload.Add_Click({ Load-Computers })

# ----------------- Events: Computer Tab -----------------
$BtnWsman.Add_Click({
  $row = Get-SelectedRow
  if (-not $row) { return }
  if (Is-MobileTarget $row) { Alert "WinRM testen geht nur auf Windows-PCs."; return }
  if (-not (Ensure-Cred)) { return }

  $target = [string]$row.Host
  if ([string]::IsNullOrWhiteSpace($target)) { $target = [string]$row.Name }

  try {
    Write-Log "WINRM_TEST" $target "START" ""
    Test-WSMan -ComputerName $target -ErrorAction Stop | Out-Null
    Write-Log "WINRM_TEST" $target "OK" ""
    Alert ("WinRM OK auf {0}" -f $target)
  } catch {
    Write-Log "WINRM_TEST" $target "ERR" $_.Exception.Message
    AlertErr ("WinRM Fehler auf {0}:`n{1}" -f $target, $_.Exception.Message)
  }
})

$BtnMsg.Add_Click({
  $row = Get-SelectedRow
  if (-not $row) { return }
  if (Is-MobileTarget $row) { Alert "Nachricht senden (WinRM) geht nur auf Windows-PCs. Für Handy: Tab Chat benutzen."; return }
  if (-not (Ensure-Cred)) { return }

  $target = [string]$row.Host
  if ([string]::IsNullOrWhiteSpace($target)) { $target = [string]$row.Name }

  $msg = $TbMessage.Text
  if ([string]::IsNullOrWhiteSpace($msg)) { $msg = "Hallo von RemoteAdmin" }

  try {
    Write-Log "WIN_MSG" $target "START" $msg
    Invoke-Command -ComputerName $target -Authentication Negotiate -Credential $Global:State.Cred -ScriptBlock {
      param($admin,$m)
      $detail = ($m -replace "`r"," " -replace "`n"," ")
      $logDir='C:\RemoteAdminLite\Logs'
      if(-not (Test-Path $logDir)){ New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
      $ts=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
      $file=Join-Path $logDir ('RemoteActions_{0}.log' -f (Get-Date -Format 'yyyy-MM-dd'))
      Add-Content -Path $file -Value ("{0}`t{1}`t{2}`t{3}" -f $ts,$admin,"WIN_MSG",$detail) -Encoding UTF8
      cmd /c ("msg * " + $m)
    } -ArgumentList (Get-AdminUser), $msg

    Write-Log "WIN_MSG" $target "OK" ""

    Alert "Nachricht gesendet."
  } catch {
    AlertErr ("Senden fehlgeschlagen:`n{0}" -f $_.Exception.Message)
  }
})

$BtnVnc.Add_Click({
  $row = Get-SelectedRow
  if (-not $row) { return }
  Write-Log "VNC_START" ([string]$row.Name) "START" ""
  Start-VncProfile -name ([string]$row.Name)
  Write-Log "VNC_START" ([string]$row.Name) "OK" ""
})

# ----------------- Windows Aktionen (Lock/Shut/Restart via WinRM) -----------------
$BtnLockWin.Add_Click({
  if (-not (Ensure-Cred)) { return }
  $row = Get-SelectedRow
  if (-not $row) { return }
  if (Is-MobileTarget $row) { Alert "Das ist ein Handy/Android. WinRM/Windows-Sperre geht nur auf Windows-PCs."; return }

  $target = [string]$row.Host
  if ([string]::IsNullOrWhiteSpace($target)) { $target = [string]$row.Name }

  try {
    Write-Log "WIN_LOCK" $target "START" ""
    Invoke-Command -ComputerName $target -Authentication Negotiate -Credential $Global:State.Cred -ScriptBlock {
      param($admin)
      $logDir='C:\RemoteAdminLite\Logs'
      if(-not (Test-Path $logDir)){ New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
      $ts=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
      $file=Join-Path $logDir ('RemoteActions_{0}.log' -f (Get-Date -Format 'yyyy-MM-dd'))
      Add-Content -Path $file -Value ("{0}`t{1}`t{2}`t{3}" -f $ts,$admin,"WIN_LOCK","") -Encoding UTF8
      rundll32.exe user32.dll,LockWorkStation
    } -ArgumentList (Get-AdminUser) | Out-Null
    Write-Log "WIN_LOCK" $target "OK" ""
    Alert "PC gesperrt."
  } catch {
    Write-Log "WIN_LOCK" $target "ERR" $_.Exception.Message
    AlertErr ("Sperren fehlgeschlagen:`n{0}" -f $_.Exception.Message)
  }
})

$BtnShutdownWin.Add_Click({
  if (-not (Ensure-Cred)) { return }
  $row = Get-SelectedRow
  if (-not $row) { return }
  if (Is-MobileTarget $row) { Alert "Das ist ein Handy/Android. Ausschalten geht hier nicht über WinRM."; return }

  $target = [string]$row.Host
  if ([string]::IsNullOrWhiteSpace($target)) { $target = [string]$row.Name }

  if (-not (Confirm-Action ("PC '{0}' wirklich ausschalten?" -f $row.Name) "Ausschalten")) { return }

  try {
    Write-Log "WIN_SHUTDOWN" $target "START" ""
    Invoke-Command -ComputerName $target -Authentication Negotiate -Credential $Global:State.Cred -ScriptBlock {
      param($admin)
      $logDir='C:\RemoteAdminLite\Logs'
      if(-not (Test-Path $logDir)){ New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
      $ts=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
      $file=Join-Path $logDir ('RemoteActions_{0}.log' -f (Get-Date -Format 'yyyy-MM-dd'))
      Add-Content -Path $file -Value ("{0}`t{1}`t{2}`t{3}" -f $ts,$admin,"WIN_SHUTDOWN","") -Encoding UTF8
      shutdown.exe /s /t 3 /c "RemoteAdminLite"
    } -ArgumentList (Get-AdminUser) | Out-Null
    Write-Log "WIN_SHUTDOWN" $target "OK" ""
    Alert "Shutdown ausgelöst."
  } catch {
    Write-Log "WIN_SHUTDOWN" $target "ERR" $_.Exception.Message
    AlertErr ("Shutdown fehlgeschlagen:`n{0}" -f $_.Exception.Message)
  }
})

$BtnRestartWin.Add_Click({
  if (-not (Ensure-Cred)) { return }
  $row = Get-SelectedRow
  if (-not $row) { return }
  if (Is-MobileTarget $row) { Alert "Das ist ein Handy/Android. Neustart geht hier nicht über WinRM."; return }

  $target = [string]$row.Host
  if ([string]::IsNullOrWhiteSpace($target)) { $target = [string]$row.Name }

  if (-not (Confirm-Action ("PC '{0}' wirklich neu starten?" -f $row.Name) "Neustart")) { return }

  try {
    Write-Log "WIN_RESTART" $target "START" ""
    Invoke-Command -ComputerName $target -Authentication Negotiate -Credential $Global:State.Cred -ScriptBlock {
      param($admin)
      $logDir='C:\RemoteAdminLite\Logs'
      if(-not (Test-Path $logDir)){ New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
      $ts=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
      $file=Join-Path $logDir ('RemoteActions_{0}.log' -f (Get-Date -Format 'yyyy-MM-dd'))
      Add-Content -Path $file -Value ("{0}`t{1}`t{2}`t{3}" -f $ts,$admin,"WIN_RESTART","") -Encoding UTF8
      shutdown.exe /r /t 3 /c "RemoteAdminLite"
    } -ArgumentList (Get-AdminUser) | Out-Null
    Write-Log "WIN_RESTART" $target "OK" ""
    Alert "Neustart ausgelöst."
  } catch {
    Write-Log "WIN_RESTART" $target "ERR" $_.Exception.Message
    AlertErr ("Neustart fehlgeschlagen:`n{0}" -f $_.Exception.Message)
  }
})




# ----------------- Events: Chat Tab -----------------
$BtnChatConnect.Add_Click({
  $row = Get-SelectedRow
  if (-not $row) { return }
  $target = [string]$row.Host
  if ([string]::IsNullOrWhiteSpace($target)) { $target = [string]$row.Name }

  try {
    $LbChat.Items.Clear()
    Chat-Connect -target $target
  } catch {
    AlertErr ("Chat verbinden fehlgeschlagen:`n{0}" -f $_.Exception.Message)
    Chat-Disconnect
  }
})

$BtnChatDisconnect.Add_Click({
  Write-Log "CHAT_DISCONNECT" ($Global:Chat.Target) "OK" ""
  Chat-Disconnect
})

$BtnChatSend.Add_Click({
  $t = $TbChatInput.Text
  Chat-Send -text $t
  $TbChatInput.Clear()
})

# ----------------- Chat Befehle (Android/Agent) -----------------
$BtnCmdPing.Add_Click({
  Chat-SendCommand "PING"
})

$BtnCmdLock.Add_Click({
  Chat-SendCommand "LOCK"
})

$BtnCmdShutdown.Add_Click({
  if (-not (Confirm-Action "Handy wirklich ausschalten? (Android braucht Root/MDM)" "Handy ausschalten")) { return }
  Chat-SendCommand "SHUTDOWN"
})


# ----------------- Events: Software Tab -----------------
$BtnLoadSoftware.Add_Click({
  if (-not (Ensure-Cred)) { return }
  $row = Get-SelectedRow
  if (-not $row) { return }

  $target = [string]$row.Host
  if ([string]::IsNullOrWhiteSpace($target)) { $target = [string]$row.Name }

  try {
    $data = Invoke-Command -ComputerName $target -Authentication Negotiate -Credential $Global:State.Cred -ScriptBlock {
      Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
        Where-Object { $_.DisplayName } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
        Sort-Object DisplayName
    }
    $DgSoftware.ItemsSource = $data
    Show-Info ("Software-Inventar geladen von {0}" -f $target)
  } catch {
    AlertErr ("Inventar fehlgeschlagen:`n{0}" -f $_.Exception.Message)
  }
})

# Wenn Viewer schliesst -> Chat sauber trennen
$Window.Add_Closing({ Chat-Disconnect })

# ----------------- Start -----------------
try {
  $Window.ShowDialog() | Out-Null
} catch {
  AlertErr ("App ist abgestürzt:`n{0}" -f $_.Exception.Message)
  throw
}
