$QOS_State="true"





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




#PROVISION QOS STATE
Write-Host "!Provisioning QOS" -ForegroundColor White
Write-Host "*Provisioning QOS state to _ $QOS_State" -ForegroundColor White
Set-BCFQOS -QOS_State $QOS_State