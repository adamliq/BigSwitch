$interfacedescriptionlist=@( 
("ROWA-RACK1-L1","ethernet19","test"),
("ROWA-RACK1-L1","ethernet20","test2")
)


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


#PROVISION INTERFACE DESCRIPTION
foreach($interfacedescription in $interfacedescriptionlist)
{
  $interfacedescription_switch=$interfacedescription[0]
  $interfacedescription_interface=$interfacedescription[1]
  $interfacedescription_description=$interfacedescription[2]
  Write-Host "*Provisioning switch_ $interfacedescription_switch :Interface_ $interfacedescription_interface with description $interfacedescription_description" -ForegroundColor White
  Set-BCFInterfaceDescription -switch_name $interfacedescription_switch -interface $interfacedescription_interface -description $interfacedescription_description
}