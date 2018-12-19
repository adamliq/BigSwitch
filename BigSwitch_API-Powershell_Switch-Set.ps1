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