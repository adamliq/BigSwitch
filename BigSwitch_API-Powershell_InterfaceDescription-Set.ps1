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