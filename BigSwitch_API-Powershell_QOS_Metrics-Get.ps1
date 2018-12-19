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
        #Prepare switch mac address before encode
        $MAChash="interface-queue-counter[switch-dpid="+'"'+"$switchmac_string"+'"'+"]"
        #Encode Switch mac address
        $Encode = [System.Web.HttpUtility]::UrlEncode($MAChash) 
        #Prepare url
        $env="https://"+$IP +":8443/api/v1/data/controller/applications/bcf/info/statistic/"+$encode+"?select=interface/queue"
        #Invoke url
        $api_result = Invoke-WebRequest -Uri $env -Method Get -UseBasicParsing -WebSession $myWebSession
        #Collect system information properties
        $api_result_convert=($api_result.Content | ConvertFrom-Json)
        #Iterate through api results (Queue)
        foreach($interface in $api_result_convert)
        {
            #Iterate through each interface within queue
            foreach($interface_Queue in $($interface.Interface))
            {
                #Commit queue
                $interface_Queue_name=$interface_queue.name
                #Filter to qos queue 4 only
                $interface_Queue_counter=$interface_Queue.queue|where {($_."queue-id" -like "4")}
                #Collect counter metrics for qos 4
                $Interface_Queue_counter_metrics=$interface_Queue_counter.counter
                #Collect sub properties of switch and commit to array
                $results+=new-object -TypeName psobject -Property @{"Switch Name"=$switch_name
                    "Interface_Name"=$interface_Queue_name
                    "tx-multicast-bytes"=$Interface_Queue_counter_metrics.'tx-multicast-bytes'
                    "tx-multicast-drop-packets"=$Interface_Queue_counter_metrics.'tx-multicast-drop-packets'
                    "tx-multicast-packets"=$Interface_Queue_counter_metrics.'tx-multicast-packets'
                    "tx-unicast-bytes"=$Interface_Queue_counter_metrics.'tx-unicast-bytes'
                    "tx-unicast-drop-packets"=$Interface_Queue_counter_metrics.'tx-unicast-drop-packets'
                    "tx-unicast-packets"=$Interface_Queue_counter_metrics.'tx-unicast-packets'}
            }        
        }
    }
}
else
{
    [String]::Format("- FAIL, statuscode {0} returned",$result1.StatusCode)
    return
}
$results|select "Switch Name","Interface_Name","tx-multicast-bytes","tx-multicast-drop-packets","tx-multicast-packets","tx-unicast-bytes","tx-unicast-drop-packets","tx-unicast-packets"|ft