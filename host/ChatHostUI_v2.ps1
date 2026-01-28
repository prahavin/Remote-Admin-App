# RemoteAdmin Chat Host (Windows) - v2
# Zweck:
#  - Live-Chat (Text)
#  - Optional: Befehle vom Viewer ausführen (LOCK/SHUTDOWN/RESTART/PING)
#  - Logs: C:\RemoteAdminLite\Logs\Host_YYYY-MM-DD.log
#
# Start:
#   powershell.exe -ExecutionPolicy Bypass -File C:\RemoteAdminLite\Host\ChatHostUI.ps1

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

$Port = 5050
$LogDir = 'C:\RemoteAdminLite\Logs'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-HostLog([string]$Admin, [string]$Remote, [string]$Action, [string]$Status, [string]$Detail) {
  try {
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $pc = [string]$env:COMPUTERNAME
    $file = Join-Path $LogDir ("Host_{0}.log" -f (Get-Date -Format 'yyyy-MM-dd'))
    $d = if ($Detail) { ($Detail -replace "`r"," " -replace "`n"," ").Trim() } else { "" }
    $line = "{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}" -f $ts,$pc,$Admin,$Remote,$Action,$Status,$d
    Add-Content -Path $file -Value $line -Encoding UTF8
  } catch {}
}

function UiAdd([string]$line) {
  $Window.Dispatcher.Invoke([action]{
    $Lb.Items.Add($line) | Out-Null
    if ($Lb.Items.Count -gt 0) { $Lb.ScrollIntoView($Lb.Items[$Lb.Items.Count-1]) }
  })
}

function SetStatus([string]$s) {
  $Window.Dispatcher.Invoke([action]{ $TxtStatus.Text = "Status: $s" })
}

function SendLine([string]$line) {
  try {
    if ($Global:Net.Writer) { $Global:Net.Writer.WriteLine($line) }
  } catch {}
}

function Execute-Command([string]$cmd) {
  switch ($cmd.ToUpperInvariant()) {
    'PING'     { return @{ ok=$true; msg='pong' } }
    'LOCK'     {
      try { rundll32.exe user32.dll,LockWorkStation | Out-Null } catch {}
      return @{ ok=$true; msg='locked' }
    }
    'SHUTDOWN' {
      # 3 Sekunden Delay, damit ACK noch raus kann
      try { Start-Process shutdown.exe -WindowStyle Hidden -ArgumentList '/s /t 3 /c "RemoteAdminLite"' } catch {}
      return @{ ok=$true; msg='shutdown scheduled' }
    }
    'RESTART'  {
      try { Start-Process shutdown.exe -WindowStyle Hidden -ArgumentList '/r /t 3 /c "RemoteAdminLite"' } catch {}
      return @{ ok=$true; msg='restart scheduled' }
    }
    default    { return @{ ok=$false; msg="unknown cmd: $cmd" } }
  }
}

$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="RemoteAdmin Chat Host" Height="520" Width="760"
        WindowStartupLocation="CenterScreen"
        Background="#0B0F14"
        Foreground="#E5E7EB">
  <Grid Margin="14">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="14" Padding="12" Grid.Row="0" Margin="0,0,0,12">
      <DockPanel>
        <StackPanel DockPanel.Dock="Left">
          <TextBlock Text="Chat Host (Windows)" FontWeight="Bold" FontSize="16"/>
          <TextBlock x:Name="TxtStatus" Text="Status: startet..." Foreground="#CBD5E1" Margin="0,4,0,0"/>
        </StackPanel>
        <TextBlock DockPanel.Dock="Right" Text="Port 5050" Foreground="#CBD5E1" VerticalAlignment="Center"/>
      </DockPanel>
    </Border>

    <Border Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="14" Padding="12" Grid.Row="1" Margin="0,0,0,12">
      <ListBox x:Name="Lb" Background="#0B0F14" BorderBrush="#1F2937" BorderThickness="1" Padding="6"/>
    </Border>

    <Border Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="14" Padding="12" Grid.Row="2">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <TextBox x:Name="Tb" Height="38" VerticalContentAlignment="Center" Margin="0,0,10,0"/>
        <Button x:Name="BtnSend" Grid.Column="1" Content="Senden" Padding="18,8" Background="#F59E0B" BorderBrush="#F59E0B" Foreground="#0B0F14"/>
      </Grid>
    </Border>
  </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader ([xml]$Xaml))
$Window = [Windows.Markup.XamlReader]::Load($reader)
$Lb = $Window.FindName('Lb')
$Tb = $Window.FindName('Tb')
$BtnSend = $Window.FindName('BtnSend')
$TxtStatus = $Window.FindName('TxtStatus')

$Global:Net = [ordered]@{
  Listener = $null
  Client   = $null
  Reader   = $null
  Writer   = $null
  Stop     = $false
  Remote   = ''
}

$BtnSend.Add_Click({
  $text = $Tb.Text
  if ([string]::IsNullOrWhiteSpace($text)) { return }
  $line = ("[{0}] Host: {1}" -f (Get-Date -Format "HH:mm:ss"), $text.Replace("`r"," ").Replace("`n"," "))
  UiAdd $line
  Write-HostLog "LOCAL" $Global:Net.Remote "CHAT_SEND" "OK" $text
  SendLine $line
  $Tb.Clear()
})

$Window.Add_Closing({
  $Global:Net.Stop = $true
  try { if ($Global:Net.Client) { $Global:Net.Client.Close() } } catch {}
  try { if ($Global:Net.Listener) { $Global:Net.Listener.Stop() } } catch {}
})

# Listener Task
[System.Threading.Tasks.Task]::Run([Action]{
  try {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
    $listener.Start()
    $Global:Net.Listener = $listener
    SetStatus "wartet auf Verbindung (Port $Port)"

    while (-not $Global:Net.Stop) {
      $client = $listener.AcceptTcpClient()
      $Global:Net.Client = $client

      $remote = $client.Client.RemoteEndPoint.ToString()
      $Global:Net.Remote = $remote

      $stream = $client.GetStream()
      $r = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
      $w = New-Object System.IO.StreamWriter($stream, [System.Text.Encoding]::UTF8)
      $w.AutoFlush = $true

      $Global:Net.Reader = $r
      $Global:Net.Writer = $w

      SetStatus "verbunden mit $remote"
      UiAdd ("[{0}] System: verbunden mit {1}" -f (Get-Date -Format "HH:mm:ss"), $remote)
      Write-HostLog "UNKNOWN" $remote "CONNECT" "OK" ""

      while (-not $Global:Net.Stop) {
        $line = $r.ReadLine()
        if ($null -eq $line) { break }

        # CMD: __CMD__|admin|LOCK
        if ($line.StartsWith('__CMD__|')) {
          $parts = $line.Split('|')
          $admin = if ($parts.Length -ge 2) { $parts[1] } else { 'UNKNOWN' }
          $cmd   = if ($parts.Length -ge 3) { $parts[2] } else { '' }

          UiAdd ("[{0}] CMD von {1}: {2}" -f (Get-Date -Format "HH:mm:ss"), $admin, $cmd)
          Write-HostLog $admin $remote ("CMD_"+$cmd) "START" ""

          $res = Execute-Command $cmd
          if ($res.ok) {
            $ack = "__ACK__|$cmd|OK|$($res.msg)"
            SendLine $ack
            UiAdd ("[{0}] ACK: {1}" -f (Get-Date -Format "HH:mm:ss"), $ack)
            Write-HostLog $admin $remote ("CMD_"+$cmd) "OK" $res.msg
          } else {
            $err = "__ERR__|$cmd|$($res.msg)"
            SendLine $err
            UiAdd ("[{0}] ERR: {1}" -f (Get-Date -Format "HH:mm:ss"), $err)
            Write-HostLog $admin $remote ("CMD_"+$cmd) "ERR" $res.msg
          }

          continue
        }

        # normaler Chat
        UiAdd $line
        Write-HostLog "UNKNOWN" $remote "CHAT_RECV" "OK" $line
      }

      try { $client.Close() } catch {}
      $Global:Net.Client = $null
      $Global:Net.Reader = $null
      $Global:Net.Writer = $null
      $Global:Net.Remote = ''

      SetStatus "wartet auf Verbindung (Port $Port)"
      UiAdd ("[{0}] System: getrennt" -f (Get-Date -Format "HH:mm:ss"))
      Write-HostLog "UNKNOWN" $remote "DISCONNECT" "OK" ""
    }

  } catch {
    UiAdd ("[{0}] Fehler: {1}" -f (Get-Date -Format "HH:mm:ss"), $_.Exception.Message)
    Write-HostLog "LOCAL" "" "FATAL" "ERR" $_.Exception.Message
    SetStatus "Fehler (siehe Log)"
  }
}) | Out-Null

# UI Start
$Window.ShowDialog() | Out-Null
