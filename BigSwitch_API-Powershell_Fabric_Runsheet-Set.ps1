#required function to ignore certificate error
#Sets tls protocol
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12

#######VARIABLES
$ErrorActionPreference = 'SilentlyContinue'
#BigSwitch Credentials
$user = "admin"
$pass= "Password1!"
$segmentlist=@("VLAN_t1","VLAN_t2")
$tenantlist="test"

$lower=1
$upper=32
$ports=($lower..$upper)
$switchlist = @( 
("ROWA-RACK2-S2", "spine", "54:bf:64:ae:7d:c0",""), 
("ROWA-RACK2-L1", "leaf", "54:bf:64:ae:95:c0","ROWA-RACK2") 
)
$interfacegrouplist=@( 
("Core-Leaf", "inter-pod", "inter-pod","false","false"), 
("Core-Leaf2", "inter-pod", "inter-pod","false","false")
)
$segmentinterfacetaggedlist=@( 
("test", "VLAN_t1", "ROWA-RACK1-L1","ethernet19","99"),
("test", "VLAN_t1", "ROWA-RACK1-L1","ethernet20","99")
)
$interfacedescriptionlist=@( 
("ROWA-RACK1-L1","ethernet19","test"),
("ROWA-RACK1-L1","ethernet20","test2")
)
$QOS_State="true"
$QOS_PFC_State="true"
$QOSPFCProfile=@( 
"test", "25", "1","1","1","75","1"
)
#BigSwitch IP
$IP="xxx.xxx.xxx.xxx"
$global:token = $null
#######

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

function Get-BCFSession([string]$user,[string]$pass,[string]$ip)
{
    #LOGON TO BCF
    $api_logon = "https://"+$IP +":8443/api/v1/auth/login"
    $params=@{"user"=$user;"password"=$pass} |convertto-json -compress
    #Collect bigswitch token
    $global:token = Invoke-WebRequest -Uri $api_logon -Method Post -Body $params -ContentType 'application/json' -SessionVariable myWebSession_local
    $global:mywebsession=$mywebsession_local
    $logon_result=$global:token.Content | ConvertFrom-Json
    if($logon_result.success -eq "True")
    {
        Write-Host "**Logon success" -ForegroundColor Green
    }
    else
    {
        Write-Host "**Logon failure" -ForegroundColor Red
    }
}

function Set-BCFSwitch([string]$switch_name,[string]$switch_role,[string]$switch_mac,[string]$leaf_group)
{
    if ($switch_role -eq "spine")
    {
        $switch_properties=@{
          "name"= $switch_name
          "fabric-role"= $switch_role
          "mac-address"= $switch_mac
          "time"= @{
            "override-enabled"= "false"
          }
          "snmp"= @{
            "override-enabled"= "false"
            "trap-enabled"= "false"
          }
          "snmp-trap"= @{
            "override-enabled"= "false"
          }
          "logging"= @{
            "override-enabled"= "false"
            "controller-enabled"= "true"
            "remote-enabled"= "true"
          }
          "tacacs"= @{
            "override-enabled"= "false"
          }
        }|convertto-json -compress
    }
    else
    {
          $switch_properties=@{
          "name"= $switch_name
          "fabric-role"= $switch_role
          "leaf-group"= $leaf_group
          "mac-address"= $switch_mac
          "time"= @{
            "override-enabled"= "false"
          }
          "snmp"= @{
            "override-enabled"= "false"
            "trap-enabled"= "false"
          }
          "snmp-trap"= @{
            "override-enabled"= "false"
          }
          "logging"= @{
            "override-enabled"= "false"
            "controller-enabled"= "true"
            "remote-enabled"= "true"
          }
          "tacacs"= @{
            "override-enabled"= "false"
          }
        }|convertto-json -compress
    }
    #Conduct Action on BCF Using token
    $api_switch="https://"+$IP +":8443/api/v1/data/controller/core/switch-config[name=" + '"' + $switch_name + '"' + "]"
    $result1 = Invoke-WebRequest -Uri $api_switch -Method post -Body $switch_properties -UseBasicParsing -WebSession $myWebSession



    #Check status of http
    if ($result1.StatusCode -eq 204)
    {
        write-host "**PASS, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        Start-Sleep 5
        #Start Array
        $jsonoutput_segmentname=$result1.Content | ConvertFrom-Json
        $jsonoutput_segmentname|ft
        $api_switch_verify="https://"+$IP +":8443/api/v1/data/controller/core/switch"
        $switches=Invoke-WebRequest -Uri $api_switch_verify -Method get -UseBasicParsing -WebSession $myWebSession
        $switch_listing=$switches.content|convertfrom-json
        foreach($switch in $switch_listing)
        {
            if($switch.name -eq $switch_name)
            {
                Write-Host "**Verified: Switch $switch_name" -ForegroundColor Green
            }
            else
            {
            #Nothing
            }
        }
    }
    else
    {
        write-host "**FAIL, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        return
    }
}
function Set-BCFTenant([string]$tenant)
{
    #Conduct Action on BCF Using token
    $api_tenant_name="https://"+$IP +":8443/api/v1/data/controller/applications/bcf/tenant"
    $api_tenant_verify_name="https://"+$IP +":8443/api/v1/data/controller/applications/bcf/tenant[name=" + '"' + $tenant + '"' + "]"
    $params=@{"name"= $Tenant} |convertto-json -compress
    $result1 = Invoke-WebRequest -Uri $api_tenant_name -Method Post -Body $params -UseBasicParsing -WebSession $myWebSession

    #Check status of http
    if ($result1.StatusCode -eq 204)
    {
        write-host "**PASS, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        Start-Sleep 5
        #Start Array
        $tenantname_get = Invoke-WebRequest -Uri $api_tenant_verify_name -Method get -UseBasicParsing -WebSession $myWebSession
        if ($tenantname_get.Content -ne "[ ]")
        {
            $jsonoutput_tenantname=$tenantname_get.Content | ConvertFrom-Json
            Write-Host "**Verified: Tenant $($jsonoutput_tenantname.name)" -ForegroundColor Green 
        }
        else
        {
        "$tenant Not found"
        }
    }
    else
    {
        write-host "**FAIL, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        return
    }
}

function Set-BCFSegment([string]$tenant,[string]$segment)
{
    #Conduct Action on BCF Using token
    $api_tenant_name_segment="https://"+$IP +":8443/api/v1/data/controller/applications/bcf/tenant[name=" + '"' + $tenant + '"' + "]/segment"
    $api_segment_verify_name="https://"+$IP +":8443/api/v1/data/controller/applications/bcf/tenant[name=" + '"' + $tenant + '"' + "]/segment[name=" + '"' + $segment + '"' + "]"
	
    $params=@{"name"= $segment} |convertto-json -compress
    $result1 = Invoke-WebRequest -Uri $api_tenant_name_segment -Method Post -Body $params -UseBasicParsing -WebSession $myWebSession

    #Check status of http
    if ($result1.StatusCode -eq 204)
    {
        write-host "**PASS, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        Start-Sleep 5
        #Start Array
        $segmentname_get = Invoke-WebRequest -Uri $api_segment_verify_name -Method get -UseBasicParsing -WebSession $myWebSession
        if ($segmentname_get.Content -ne "[ ]")
        {
            $jsonoutput_segmentname=$segmentname_get.Content | ConvertFrom-Json
            Write-Host "**Verified: Segment $($jsonoutput_segmentname.name)" -ForegroundColor Green 
        }
        else
        {
        "$segment Not found"
        }
    }
    else
    {
        write-host "**FAIL, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        return
    }
}

Function Set-BCFInterfaceGroup([string]$interfacegroup_name,[string]$interfacegroup_mode,[string]$interfacegroup_backupmode,[string]$interfacegroup_shutdown,[string]$interfacegroup_preempt)
{
    #Conduct Action on BCF Using token
    $api_interfacegroup="https://"+$IP +":8443/api/v1/data/controller/applications/bcf/interface-group"
    $interfacegroup_properties=@{
      "name"= $interfacegroup_name
      "mode"= $interfacegroup_mode
      "backup-mode"= $interfacegroup_backupmode
      "shutdown"= $interfacegroup_shutdown
      "preempt"= $interfacegroup_preempt
    }|convertto-json -compress
    $result1 = Invoke-WebRequest -Uri $api_interfacegroup -Method Post -Body $interfacegroup_properties -UseBasicParsing -WebSession $myWebSession

    #Check status of http
    if ($result1.StatusCode -eq 204)
    {
        write-host "**PASS, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        Start-Sleep 5
        #Start Array
        $interface_group_verify = Invoke-WebRequest -Uri $api_interfacegroup -Method get -UseBasicParsing -WebSession $myWebSession
        $interface_group_verify=$interface_group_verify|ConvertFrom-Json
        foreach($item in $interface_group_verify)
        {
            $findings=($item|where {$_.name -eq $interfacegroup_name})
            if($findings.name -eq $interfacegroup_name)
            {
                write-host "**Verified: Interface Group _ $interfacegroup_name" -ForegroundColor Green
            }
            else
            {
            }

        }
    }
    else
    {
        write-host "**FAIL, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        return
    }
}

Function Set-BCFSegmenttoInterfaceTagged([string]$tenant,[string]$segment,[string]$switch,[string]$interface,[string]$vlan)
{
    #Conduct Action on BCF Using token
    $api_tenant_segment_interface="https://"+$IP +":8443/api/v1/data/controller/applications/bcf/tenant[name=" + '"' + $tenant + '"' + "]/segment[name=" + '"' + $segment + '"' + "]/switch-port-membership-rule[switch=" + "'" + $switch + "'" + "][interface=" + "'" + $interface + "'" + "][vlan=" + $vlan + "]"
	
    $params=@{"vlan"= $vlan;"switch"=$switch; "interface"=$interface} |convertto-json -compress
    $result1 = Invoke-WebRequest -Uri $api_tenant_segment_interface -Method Post -Body $params -UseBasicParsing -WebSession $myWebSession

    #Check status of http
    if ($result1.StatusCode -eq 204)
    {
        write-host "**PASS, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        Start-Sleep 5
        #Start Array
            #Verify
        $api_tenant_segment_interface_verify="https://"+$IP +":8443/api/v1/data/controller/applications/bcf/tenant[name=" + '"' + $tenant + '"' + "]"
        $segment_interface_verify=Invoke-WebRequest -Uri $api_tenant_segment_interface_verify -Method get -UseBasicParsing -WebSession $myWebSession
        $segment_interface_verify=$segment_interface_verify | ConvertFrom-Json
        foreach($item in $segment_interface_verify.segment)
        {
            $findings=($item|where {$_.name -eq $segment})
            if((($findings.'switch-port-membership-rule'|where {$_.interface -eq $interface}).vlan) -eq "99")
            {
                write-host "**Verified: Segment to interface Association $switch _ $segment _ $interface _ $vlan" -ForegroundColor Green
            }
            else
            {
            }

        }
    }
    else
    {
        write-host "**FAIL, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        return
    }
}

Function Set-BCFInterfaceDescription([string]$switch_name,[string]$interface,[string]$description)
{
    #Conduct Action on BCF Using token
    	
    $api_interface="https://"+$IP +":8443/api/v1/data/controller/core/switch-config[name=" + '"' + $switch_name + '"' + "]/interface[name=" + '"' + $interface + '"' + "]"
	
    $params=@{"name"= $interface;"description"=$description} |convertto-json -compress
    $result1 = Invoke-WebRequest -Uri $api_interface -Method Put -Body $params -UseBasicParsing -WebSession $myWebSession

    #Check status of http
    if ($result1.StatusCode -eq 204)
    {
        write-host "**PASS, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        Start-Sleep 5
        #Start Array
        $api_interface_verify="https://"+$IP +":8443/api/v1/data/controller/core/switch-config[name=" + '"' + $switch_name + '"' + "]"
        $interface_verify = Invoke-WebRequest -Uri $api_interface_verify -Method get -UseBasicParsing -WebSession $myWebSession
        $jsonoutput_interface_verify =$interface_verify.Content | ConvertFrom-Json
        foreach($item in $jsonoutput_interface_verify.interface)
        {
            $findings=$item|where{$_.name -eq $interface}
            if($findings.description -eq $description)
            {
                write-host "**Verified: Interface _ $interface description _ $description" -ForegroundColor Green
            }
            else
            {
            }
        }
    }
    else
    {
        write-host "**FAIL, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        return
    }
}

Function Set-BCFQOS([string]$QOS_State)
{
    $params2=@{"enable"=$QOS_State} |convertto-json -compress
    #Conduct Action on BCF Using token
    $api_QOS="https://"+$IP +":8443/api/v1/data/controller/applications/bcf/global-setting/qos"

    $result1 = Invoke-WebRequest -Uri $api_QOS -Method post -body $params2 -UseBasicParsing -WebSession $myWebSession

    #Check status of http
    if ($result1.StatusCode -eq 204)
    {
        write-host "**PASS, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        Start-Sleep 5
        #Start Array
        $jsonoutput_segmentname=$result1.Content | ConvertFrom-Json
        $jsonoutput_segmentname|ft
        #Conduct Action on BCF Using token
        $tenant_segment_interface="https://"+$IP +":8443/api/v1/data/controller/applications/bcf/global-setting/qos"
        $result1 = Invoke-WebRequest -Uri $tenant_segment_interface -Method get -UseBasicParsing -WebSession $myWebSession
        if((($result1.content|convertfrom-json).enable) -eq "True")
        {
            write-host "**Verified: QOS is enabled" -ForegroundColor Green
        }
        else
        {

        }
    }
    else
    {
        write-host "**FAIL, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        return
    }
}

Function Set-BCFQOS_PFC([string]$QOS_PFC_State)
{
    $params2=@{"active"=$QOS_PFC_State} |convertto-json -compress
    #Conduct Action on BCF Using token
    $api_QOS_PFC="https://"+$IP +":8443/api/v1/data/controller/applications/bcf/global-setting/qos/pfc"

    $result1 = Invoke-WebRequest -Uri $api_QOS_PFC -Method post -body $params2 -UseBasicParsing -WebSession $myWebSession

    #Check status of http
    if ($result1.StatusCode -eq 204)
    {
        write-host "**PASS, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        Start-Sleep 5
        #Start Array
        $jsonoutput_segmentname=$result1.Content | ConvertFrom-Json
        $jsonoutput_segmentname|ft
        $tenant_segment_interface="https://"+$IP +":8443/api/v1/data/controller/applications/bcf/global-setting/qos"
        $result1 = Invoke-WebRequest -Uri $tenant_segment_interface -Method get -UseBasicParsing -WebSession $myWebSession
        if((($result1.content|convertfrom-json).pfc.active) -eq "True")
        {
            write-host "**Verified: QOS PFC is enabled" -ForegroundColor Green
        }
        else
        {

        }
        
    }
    else
    {
        write-host "**FAIL, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        return
    }
}

Function Set-BCFQOS_PFC_Profile([string]$QOS_PFC_Profile_name,[string]$QOS_PFC_class0_Percentage,[string]$QOS_PFC_class1_Percentage,[string]$QOS_PFC_class2_Percentage,[string]$QOS_PFC_class3_Percentage,[string]$QOS_PFC_classpfc_Percentage,[string]$QOS_PFC_classspan_Percentage)
{
    $params2=@{
      "name"= $QOS_PFC_Profile_name
      "traffic-class-0"= $QOS_PFC_class0_Percentage
      "traffic-class-1"= $QOS_PFC_class1_Percentage
      "traffic-class-2"= $QOS_PFC_class2_Percentage
      "traffic-class-3"= $QOS_PFC_class3_Percentage
      "traffic-class-pfc"= $QOS_PFC_classpfc_Percentage
      "traffic-class-span-fabric"= $QOS_PFC_classspan_Percentage
    }|convertto-json -compress
    #Conduct Action on BCF Using token
    $api_QOS_PFC_Profile="https://"+$IP +":8443/api/v1/data/controller/applications/bcf/global-setting/qos/queuing-profile[name=" + '"' + $QOS_PFC_Profile + '"' + "]"

    $result1 = Invoke-WebRequest -Uri $api_QOS_PFC_Profile -Method post -body $params2 -UseBasicParsing -WebSession $myWebSession



    #Check status of http
    if ($result1.StatusCode -eq 204)
    {
        write-host "**PASS, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        Start-Sleep 5
        #Start Array
        $jsonoutput_segmentname=$result1.Content | ConvertFrom-Json
        $jsonoutput_segmentname|ft
        $pfc_profile_verify=Invoke-WebRequest -Uri $api_QOS_PFC_Profile -Method get -UseBasicParsing -WebSession $myWebSession
        if(($pfc_profile_verify.Content) -ne "[ ]")
        {
         write-host "**Verified: QOS profile $QOS_PFC_Profile_name is enabled" -ForegroundColor Green
        }
        else
        {
        }
    }
    else
    {
        write-host "**FAIL, statuscode $($result1.StatusCode) returned successfully" -ForegroundColor Yellow
        return
    }
}


Ignore-SSLCertificates
Write-Host "*Obtaining BCF session token" -ForegroundColor White
Get-BCFSession -user $user -pass $pass -ip $ip

#PROVISION SWITCHES
foreach($value in $switchlist)
{
  $switch_name=$value[0]
  $switch_role=$value[1]
  $switch_mac=$value[2]
  $leaf_group=$value[3]
  $fullname=$switch_name
  Write-Host "*Provisioning Switch $switch_name" -ForegroundColor White
  Set-BCFSwitch -switch_name $switch_name -switch_role $switch_role -switch_mac $switch_mac -leaf_group $leaf_group
}

#PROVISION TENANT AND SEGMENTS
foreach($tenant in $tenantlist)
{
Write-Host "*Provisioning Tenant $tenant" -ForegroundColor White
  $fullname=$tenant
    Set-BCFTenant -tenant $tenant
    foreach($segment in $segmentlist)
    {
      $fullname=$segment
        Write-Host "*Provisioning Segment $segment" -ForegroundColor White
        Set-BCFSegment -tenant $tenant -segment $segment
    }
}

#PROVISION INTERFACE GROUP
foreach($interfacegroup in $interfacegrouplist)
{
  $interfacegroup_name=$interfacegroup[0]
  $interfacegroup_mode=$interfacegroup[1]
  $interfacegroup_backupmode=$interfacegroup[2]
  $interfacegroup_shutdown=$interfacegroup[3]
  $interfacegroup_preempt=$interfacegroup[4]
  $fullname= $interfacegroup_name
  Write-Host "*Provisioning Interface Group $interfacegroup_name" -ForegroundColor White
  Set-BCFInterfaceGroup -interfacegroup_name $interfacegroup_name -interfacegroup_mode $interfacegroup_mode -interfacegroup_backupmode $interfacegroup_backupmode -interfacegroup_shutdown $interfacegroup_shutdown -interfacegroup_preempt $interfacegroup_preempt
}

#PROVISION SEGMENT TO INTERFACE TAGGED
foreach($segmentinterface in $segmentinterfacetaggedlist)
{
  $segmentinterface_tenant=$segmentinterface[0]
  $segmentinterface_segment=$segmentinterface[1]
  $segmentinterface_switch=$segmentinterface[2]
  $segmentinterface_interface=$segmentinterface[3]
  $segmentinterface_vlan=$segmentinterface[4]
    $fullname="segment $segmentinterface_segment to interface $segmentinterface_interface with vlan $segmentinterface_vlan"
  Write-Host "*Provisioning segment $segmentinterface_segment to interface $segmentinterface_interface with vlan $segmentinterface_vlan" -ForegroundColor White
  Set-BCFSegmenttoInterfaceTagged -tenant $segmentinterface_tenant -segment $segmentinterface_segment -switch $segmentinterface_switch -interface $segmentinterface_interface -vlan $segmentinterface_vlan
}

#PROVISION INTERFACE DESCRIPTION
foreach($interfacedescription in $interfacedescriptionlist)
{
  $interfacedescription_switch=$interfacedescription[0]
  $interfacedescription_interface=$interfacedescription[1]
  $interfacedescription_description=$interfacedescription[2]
  Write-Host "*Provisioning switch_ $interfacedescription_switch :Interface_ $interfacedescription_interface with description $interfacedescription_description" -ForegroundColor White
  Set-BCFInterfaceDescription -switch_name $interfacedescription_switch -interface $interfacedescription_interface -description $interfacedescription_description
}

#PROVISION QOS STATE
Write-Host "!Provisioning QOS" -ForegroundColor White
Write-Host "*Provisioning QOS state to _ $QOS_State" -ForegroundColor White
Set-BCFQOS -QOS_State $QOS_State

#PROVISION QOS_PFC STATE
Write-Host "*Provisioning QOS_PFC state to _ $QOS_PFC_State" -ForegroundColor White
Set-BCFQOS_PFC -QOS_PFC_State $QOS_PFC_State

#PROVISION QOS_PFC Profile
$QOS_PFC_Profile_name=$QOSPFCProfile[0]
$QOS_PFC_class0_Percentage=$QOSPFCProfile[1]
$QOS_PFC_class1_Percentage=$QOSPFCProfile[2]
$QOS_PFC_class2_Percentage=$QOSPFCProfile[3]
$QOS_PFC_class3_Percentage=$QOSPFCProfile[4]
$QOS_PFC_classpfc_Percentage=$QOSPFCProfile[5]
$QOS_PFC_classspan_Percentage=$QOSPFCProfile[6]
$fullname=$QOS_PFC_Profile_name
Write-Host "*Provisioning QOS_PFC profile _ $QOS_PFC_Profile_name" -ForegroundColor White
Set-BCFQOS_PFC_Profile -QOS_PFC_Profile_name $QOS_PFC_Profile_name -QOS_PFC_class0_Percentage $QOS_PFC_class0_Percentage -QOS_PFC_class1_Percentage $QOS_PFC_class1_Percentage -QOS_PFC_class2_Percentage $QOS_PFC_class2_Percentage -QOS_PFC_class3_Percentage $QOS_PFC_class3_Percentage -QOS_PFC_classpfc_Percentage $QOS_PFC_classpfc_Percentage -QOS_PFC_classspan_Percentage $QOS_PFC_classspan_Percentage
