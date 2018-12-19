$segmentinterfacetaggedlist=@( 
("test", "VLAN_t1", "ROWA-RACK1-L1","ethernet19","99"),
("test", "VLAN_t1", "ROWA-RACK1-L1","ethernet20","99")
)


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