$segmentlist=@("VLAN_t1","VLAN_t2")


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

foreach($segment in $segmentlist)
    {
      $fullname=$segment
        Write-Host "*Provisioning Segment $segment" -ForegroundColor White
        Set-BCFSegment -tenant $tenant -segment $segment
    }