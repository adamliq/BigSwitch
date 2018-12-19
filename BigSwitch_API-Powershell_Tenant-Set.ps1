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