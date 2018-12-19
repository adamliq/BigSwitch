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