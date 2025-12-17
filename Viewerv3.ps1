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

    <!-- Farben (Zest/Achilles Gefühl): Rot/Blau/Gelb + Weiss/Schwarz/Hellgrau -->
    <SolidColorBrush x:Key="Bg" Color="#0B0F14"/>
    <SolidColorBrush x:Key="Panel" Color="#111827"/>
    <SolidColorBrush x:Key="Panel2" Color="#0F172A"/>
    <SolidColorBrush x:Key="Border" Color="#1F2937"/>
    <SolidColorBrush x:Key="TextDim" Color="#CBD5E1"/>

    <SolidColorBrush x:Key="Blue" Color="#3B82F6"/>
    <SolidColorBrush x:Key="Red" Color="#EF4444"/>
    <SolidColorBrush x:Key="Yellow" Color="#F59E0B"/>

    <CornerRadius x:Key="Radius">14</CornerRadius>

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
  throw "XAML kaputt: $($_.Exception.Message)"
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
$TbMessage     = $Window.FindName('TbMessage')

$BtnLoadSoftware = $Window.FindName('BtnLoadSoftware')
$DgSoftware      = $Window.FindName('DgSoftware')

$TbUser        = $Window.FindName('TbUser')
$TbPass        = $Window.FindName('TbPass')
$BtnLogin      = $Window.FindName('BtnLogin')
$BtnQuit       = $Window.FindName('BtnQuit')
$TxtLoginError = $Window.FindName('TxtLoginError')

# Safety: wenn irgendwas null ist -> sofort Fehler, statt still kaputt.
$must = @('MainGrid','LoginGrid','TxtLoginInfo','TxtStatus','TxtCounts','BtnReload','BtnLogout','DgComputers','BtnWsman','BtnMsg','BtnVnc','TbMessage','BtnLoadSoftware','DgSoftware','TbUser','TbPass','BtnLogin','BtnQuit','TxtLoginError')
foreach ($n in $must) {
  if ($null -eq (Get-Variable -Name $n -ValueOnly -ErrorAction SilentlyContinue)) {
    throw "WPF Control fehlt (FindName): $n"
  }
}

# ----------------- UI Helper -----------------
function Show-Info([string]$msg) { $TxtStatus.Text = "Status: $msg" }

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

    # kleines "Sanity": Credential Objekt muss existieren
    if ($null -eq $cred -or [string]::IsNullOrWhiteSpace($cred.UserName)) {
      $TxtLoginError.Text = "Credential konnte nicht erstellt werden."
      return
    }

    $Global:State.Cred = $cred

    $TxtLoginInfo.Text = "Angemeldet als: $u"
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
  if (-not (Ensure-Cred)) { return }
  $row = Get-SelectedRow
  if (-not $row) { return }

  $target = [string]$row.Host
  if ([string]::IsNullOrWhiteSpace($target)) { $target = [string]$row.Name }

  try {
    Test-WSMan -ComputerName $target -ErrorAction Stop | Out-Null
    Alert ("WinRM OK auf {0}" -f $target)
  } catch {
    AlertErr ("WinRM Fehler auf {0}:`n{1}" -f $target, $_.Exception.Message)
  }
})

$BtnMsg.Add_Click({
  if (-not (Ensure-Cred)) { return }
  $row = Get-SelectedRow
  if (-not $row) { return }

  $target = [string]$row.Host
  if ([string]::IsNullOrWhiteSpace($target)) { $target = [string]$row.Name }

  $msg = $TbMessage.Text
  if ([string]::IsNullOrWhiteSpace($msg)) { $msg = "Hallo von RemoteAdmin" }

  try {
    Invoke-Command -ComputerName $target -Authentication Negotiate -Credential $Global:State.Cred -ScriptBlock {
      param($m) cmd /c ("msg * " + $m)
    } -ArgumentList $msg

    Alert "Nachricht gesendet."
  } catch {
    AlertErr ("Senden fehlgeschlagen:`n{0}" -f $_.Exception.Message)
  }
})

$BtnVnc.Add_Click({
  $row = Get-SelectedRow
  if (-not $row) { return }
  Start-VncProfile -name ([string]$row.Name)
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

# ----------------- Start -----------------
try {
  $Window.ShowDialog() | Out-Null
} catch {
  AlertErr ("App ist abgestürzt:`n{0}" -f $_.Exception.Message)
  throw
}
