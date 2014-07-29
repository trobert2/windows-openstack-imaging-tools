$ErrorActionPreference = "Stop"

try
{
    $Host.UI.RawUI.WindowTitle = "Downloading Cloudbase-Init..."

    $osArch = (Get-WmiObject  Win32_OperatingSystem).OSArchitecture
    if($osArch -eq "64-bit")
    {
        $CloudbaseInitMsi = "CloudbaseInitSetup_Beta_x64.msi"
        $programFilesDir = ${ENV:ProgramFiles(x86)}
    }
    else
    {
        $CloudbaseInitMsi = "CloudbaseInitSetup_Beta_x86.msi"
        $programFilesDir = $ENV:ProgramFiles
    }

    $CloudbaseInitMsiPath = "$ENV:Temp\$CloudbaseInitMsi"
    $CloudbaseInitMsiUrl = "http://www.cloudbase.it/downloads/$CloudbaseInitMsi"
    $CloudbaseInitMsiLog = "$ENV:Temp\CloudbaseInitSetup_Beta.log"

    (new-object System.Net.WebClient).DownloadFile($CloudbaseInitMsiUrl, $CloudbaseInitMsiPath)

    $Host.UI.RawUI.WindowTitle = "Installing Cloudbase-Init..."

    $serialPortName = @(Get-WmiObject Win32_SerialPort)[0].DeviceId

    $p = Start-Process -Wait -PassThru -FilePath msiexec -ArgumentList "/i $CloudbaseInitMsiPath /qn /l*v $CloudbaseInitMsiLog LOGGINGSERIALPORTNAME=$serialPortName"
    if ($p.ExitCode -ne 0)
    {
        throw "Installing $CloudbaseInitMsiPath failed. Log: $CloudbaseInitMsiLog"
    }
}
catch
{
    $host.ui.WriteErrorLine($_.Exception.ToString())
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    throw
}
