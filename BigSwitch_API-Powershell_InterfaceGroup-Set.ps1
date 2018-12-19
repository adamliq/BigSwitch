$interfacegrouplist=@( 
("Core-Leaf", "inter-pod", "inter-pod","false","false"), 
("Core-Leaf2", "inter-pod", "inter-pod","false","false")
)




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