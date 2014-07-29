$ErrorActionPreference = "Stop"

try
{
    $Host.UI.RawUI.WindowTitle = "Winrm config..."
    # $winrmLUrl = "https://raw.github.com/trobert2/windows-openstack-imaging-tools/master/SetupWinRMAccess.ps1"
    # $winrmPath = "$ENV:Temp\SetupWinRMAccess.ps1"
    # (new-object System.Net.WebClient).DownloadFile($winrmLUrl, $winrmPath)
    # powershell -NoLogo -NonInteractive -ExecutionPolicy RemoteSigned -File $winrmPath

    $winrmLUrl = "https://raw.githubusercontent.com/cloudbase/unattended-setup-scripts/master/SetupWinRMAccessSelfSigned.ps1"
    $winrmPath = "$ENV:Temp\SetupWinRMAccessSelfSigned.ps1"
    (new-object System.Net.WebClient).DownloadFile($winrmLUrl, $winrmPath)
    powershell -NoLogo -NonInteractive -ExecutionPolicy RemoteSigned -File $winrmPath

    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name Unattend*
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoLogonCount

    $Host.UI.RawUI.WindowTitle = "Running Sysprep..."        
    $unattendXMLUrl = "https://raw.githubusercontent.com/trobert2/windows-openstack-imaging-tools/master/Unattend.xml"
    $unattendXMLPath = "$ENV:Temp\Unattend.xml"
    (new-object System.Net.WebClient).DownloadFile($unattendXMLUrl, $unattendXMLPath)
    & "$ENV:SystemRoot\System32\Sysprep\Sysprep.exe" `/generalize `/oobe `/shutdown `/unattend:"$unattendXMLPath"
}
catch
{
    $host.ui.WriteErrorLine($_.Exception.ToString())
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    throw
}
