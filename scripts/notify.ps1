param(
  [string]$title,
  [string]$message
)
Add-Type -AssemblyName System.Windows.Forms
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.Visible = $true
$notify.ShowBalloonTip(10000, $title, $message,
  [System.Windows.Forms.ToolTipIcon]::Info)
Start-Sleep -Seconds 3
$notify.Dispose()
