#required function to ignore certificate error
function Ignore-SSLCertificates
{
    $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler = $Provider.CreateCompiler()
    $Params = New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable = $false
    $Params.GenerateInMemory = $true
    $Params.IncludeDebugInformation = $false
    $Params.ReferencedAssemblies.Add("System.DLL") > $null
    $TASource=@'
        namespace Local.ToolkitExtensions.Net.CertificatePolicy
        {
            public class TrustAll : System.Net.ICertificatePolicy
            {
                public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                {
                    return true;
                }
            }
        }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly
    $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
}

Ignore-SSLCertificates

#Sets tls protocol
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12

#######VARIABLES
#BigSwitch Credentials
$user = "admin"
$pass= "Password1!"
$tenant= "<tenant>"
$segment= "<segment>"
$switch= "ROWA-RACK2-L1"
$PFC_Profile= "Test-PFC"
#BigSwitch IP
$params=@{"user"=$user;"password"=$pass} |convertto-json -compress
$params2=@{
  "forwarding-mode"= "high-bandwidth"
}|convertto-json -compress
$IP="<Clusterip>"
#######

$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
#Create pscredential from idrac credentials
$credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)

#LOGON TO BCF
$logon = "https://"+$IP +":8443/api/v1/auth/login"
#Collect bigswitch token
$result2 = Invoke-WebRequest -Uri $logon -Method Post -Body $params -ContentType 'application/json' -SessionVariable myWebSession

#Conduct Action on BCF Using token
$tenant_segment_interface="https://"+$IP +":8443/api/v1/data/controller/applications/bcf/global-setting"

$result1 = Invoke-WebRequest -Uri $tenant_segment_interface -Method post -body $params2 -UseBasicParsing -WebSession $myWebSession



#Check status of http
if ($result1.StatusCode -eq 204)
{
    [String]::Format("`n- PASS, statuscode {0} returned successfully",$result1.StatusCode)
    Start-Sleep 5
    #Start Array
    $jsonoutput_segmentname=$result1.Content | ConvertFrom-Json
    $jsonoutput_segmentname|ft
}
else
{
    [String]::Format("- FAIL, statuscode {0} returned",$result1.StatusCode)
    return
}