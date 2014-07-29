$ErrorActionPreference = "Stop"

function SetAdminOnlyACL($path) {
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    # Disable inheritance from parent
    $acl.SetAccessRuleProtection($true,$true)
    
    $fsRights = [System.Security.AccessControl.FileSystemRights]::FullControl 
    $inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $propagationFlags = [System.Security.AccessControl.PropagationFlags]::None
    $aceType =[System.Security.AccessControl.AccessControlType]::Allow

    # BUILTIN\Administrators, NT AUTHORITY\SYSTEM
    # Avoid using account names as they might change based on the locale
    foreach($sid in @("S-1-5-32-544", "S-1-5-18"))
    {    
        $sidObj = New-Object System.Security.Principal.SecurityIdentifier($sid)
        $account = $sidObj.Translate( [System.Security.Principal.NTAccount])
        $ace = New-Object System.Security.AccessControl.FileSystemAccessRule ($account, $fsRights, $inheritanceFlags, $propagationFlags, $aceType) 
        $acl.AddAccessRule($ace)
    }
    
    Set-ACL $path $acl
}

$opensslPath = "$ENV:HOMEDRIVE\OpenSSL-Win32"

function VerifyHash($filename, $expectedHash) {
    $hash = (Get-FileHash -Algorithm SHA1 $filename).Hash
    if ($hash -ne $expectedHash) {
        throw "SHA1 hash not valid for file: $filename"
    }
}

function InstallOpenSSL() {
    if (!(Test-Path $opensslPath)) {
        $filename = "$ENV:Temp\Win32OpenSSL_Light-1_0_1h.exe"
        Invoke-WebRequest -Uri "http://slproweb.com/download/Win32OpenSSL_Light-1_0_1h.exe" -OutFile $filename

        Start-Process -Wait -FilePath $filename -ArgumentList "/silent /verysilent /sp- /suppressmsgboxes"
        del $filename
    }
}

# $opensslUrl = "http://slproweb.com/download/Win32OpenSSL_Light-1_0_1h.exe"
# $openssPath = "$ENV:Temp\$Win32OpenSSL_Light.exe"
# (new-object System.Net.WebClient).DownloadFile($opensslUrl, $openssPath)

# cmd.exe /C call $openssPath /SILENT

InstallOpenSSL

$base_dir="C:\OpenSSL-Win32\"
$ca_dir="$base_dir\CA"

mkdir $ca_dir
SetAdminOnlyACL $ca_dir

pushd .

cd $ca_dir
mkdir private
mkdir certs
mkdir crl

[System.IO.File]::WriteAllText("$ca_dir\index.txt", "")
[System.IO.File]::WriteAllText("$ca_dir\serial", "01`n")

$ca_conf_file="ca.cnf"
$openssl_conf_file="openssl.cnf"
$server_ext_conf_file="server_ext.cnf"

$conf_base_url="https://raw.github.com/cloudbase/unattended-setup-scripts/master/"

Invoke-WebRequest -Uri ($conf_base_url + $ca_conf_file) -OutFile "$ca_dir\$ca_conf_file"
Invoke-WebRequest -Uri ($conf_base_url + $server_ext_conf_file) -OutFile "$ca_dir\$server_ext_conf_file"
Invoke-WebRequest -Uri ($conf_base_url + $openssl_conf_file) -OutFile "$ca_dir\$openssl_conf_file"

$ENV:PATH+=";C:\OpenSSL-Win32\bin"

$ENV:OPENSSL_CONF="$ca_dir\ca.cnf"
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -out certs\ca.pem -outform PEM -keyout private\ca.key
if ($LastExitCode) { throw "openssl failed to create CA certificate" }

$ENV:OPENSSL_CONF="$ca_dir\openssl.cnf"
openssl req -newkey rsa:2048 -nodes -sha1 -keyout private\cert.key -keyform PEM -out certs\cert.req -outform PEM -subj "/C=US/ST=Washington/L=Seattle/emailAddress=nota@realone.com/organizationName=IT/CN=$ENV:COMPUTERNAME"
if ($LastExitCode) { throw "openssl failed to create server certificate request" }

$ENV:OPENSSL_CONF="$ca_dir\ca.cnf"
openssl ca -batch -notext -in certs\cert.req -out certs\cert.pem -extensions v3_req_server -extensions v3_req_server
if ($LastExitCode) { throw "openssl CA failed to sign server certificate request" }

# Import CA certificate
$cacert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("$ca_dir\certs\ca.pem")
$castore = New-Object System.Security.Cryptography.X509Certificates.X509Store([System.Security.Cryptography.X509Certificates.StoreName]::Root, [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
$castore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
$castore.Add($cacert)

# Import server certificate
openssl pkcs12 -export -in certs\cert.pem -inkey private\cert.key -out certs\cert.pfx -password pass:Passw0rd
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("$ca_dir\certs\cert.pfx", "Passw0rd", ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet))
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store([System.Security.Cryptography.X509Certificates.StoreName]::My, [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
$store.Add($cert)
del certs\cert.pfx

popd

# Configure WinRM
& winrm create winrm/config/Listener?Address=*+Transport=HTTPS `@`{Hostname=`"$($ENV:COMPUTERNAME)`"`;CertificateThumbprint=`"$($cert.Thumbprint)`"`}
if ($LastExitCode) { throw "Failed to setup WinRM HTTPS listener" }

& winrm set winrm/config/service `@`{AllowUnencrypted=`"true`"`}
if ($LastExitCode) { throw "Failed to setup WinRM HTTPS listener" }

& winrm set winrm/config/service/auth `@`{Basic=`"true`"`}
if ($LastExitCode) { throw "Failed to setup WinRM basic auth" }

& netsh advfirewall firewall add rule name="WinRM HTTPS" dir=in action=allow protocol=TCP localport=5986
if ($LastExitCode) { throw "Failed to setup WinRM HTTPS firewall rules" }

$SetupWinRMAccessSelfSignedLUrl = "https://raw.github.com/trobert2/windows-openstack-imaging-tools/master/SetupWinRMAccessSelfSigned.ps1"
$SetupWinRMAccessSelfSignedPath = "$ENV:Temp\SetupWinRMAccessSelfSigned.ps1"
(new-object System.Net.WebClient).DownloadFile($SetupWinRMAccessSelfSignedLUrl, $SetupWinRMAccessSelfSignedPath)
powershell -ExecutionPolicy RemoteSigned -File $SetupWinRMAccessSelfSignedPath
powershell -ExecutionPolicy RemoteSigned -File $SetupWinRMAccessSelfSignedPath
