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