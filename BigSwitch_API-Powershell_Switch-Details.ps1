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
$user = "<USERNAME>"
$pass= "<PASSWORD>"
#BigSwitch IP
$IP="<BCF IP>"
$params=@{"user"=$user;"password"=$pass} |convertto-json -compress
$results=@()
#######

$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
#Create pscredential from idrac credentials
$credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)

#LOGON TO BCF
$logon = "https://"+$IP +":8443/api/v1/auth/login"
#Collect bigswitch token
$result2 = Invoke-WebRequest -Uri $logon -Method Post -Body $params -ContentType 'application/json' -SessionVariable myWebSession
 
#Conduct Action on BCF Using token
$Switch_name="https://"+$IP +":8443/api/v1/data/controller/core/switch?select=name"
$switchname_result = Invoke-WebRequest -Uri $Switch_name -Method Get -UseBasicParsing -WebSession $myWebSession
$switches_list="https://"+$IP +":8443/api/v1/data/controller/applications/bcf/info/fabric/switch"
$switchlist_result = Invoke-WebRequest -Uri $Switches_list -Method Get -UseBasicParsing -WebSession $myWebSession
$jsonoutput_Switchlist=$switchlist_result.Content | ConvertFrom-Json
#Check status of http
if ($switchname_result.StatusCode -eq 200)
{
    [String]::Format("`n- PASS, statuscode {0} returned successfully",$result1.StatusCode)
    Start-Sleep 5
    #Start Array
    $results=@()
    $jsonoutput_Switchname=$switchname_result.Content | ConvertFrom-Json
    foreach($switchmac in $jsonoutput_Switchname)
    {
        #Commit switch mac to string variable
        $switch_name=$switchmac.name
        $switchmac_string=$switchmac.dpid.tostring()
        $switchmac_string=$switchmac_string.Substring(6)
        #Prepare switch mac address before encode
        $MAChash="device[mac-address="+'"'+"$switchmac_string"+'"'+"]"
        #Encode Switch mac address
        $Encode = [System.Web.HttpUtility]::UrlEncode($MAChash) 
        #Prepare url
        $env="https://"+$IP +":8443/api/v1/data/controller/core/zerotouch/"+$encode+"/action/status/environment"

        #Invoke url
        $api_result = Invoke-WebRequest -Uri $env -Method Get -UseBasicParsing -WebSession $myWebSession
        #Collect system information properties
        $api_result_convert=($api_result.Content | ConvertFrom-Json)
        $api_result_convert
        #Iterate through api results (Queue)
        foreach($switch in $api_result_convert)
        {
            $switch_extendeddetails=$jsonoutput_switchlist|foreach{$_|where{$_.'mac-address' -eq $switch."system-information".'mac'}}
                #Commit queue
                $switch_name_environment=$switch."system-information"
                #Collect sub properties of switch and commit to array
                $results+=new-object -TypeName psobject -Property @{"MAC Address"=$switch_name_environment.'mac'
                    "Product-Name"=$switch_name_environment.'product-name'
                    "Serial-Number"=$switch_name_environment.'serial-number'
                    "Service-tag"=$switch_name_environment.'service-tag'
                    "Switch-Name"=$switch_extendeddetails.'name'
                    "Leaf-Group"=$switch_extendeddetails.'leaf-group'
                    "fabric-role"=$switch_extendeddetails.'fabric-role'}
        }
    }
}
else
{
    [String]::Format("- FAIL, statuscode {0} returned",$result1.StatusCode)
    return
}
$results|ft
