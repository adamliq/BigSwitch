#BigSwitch Credentials
$user = "admin"
$pass= "Password1!"
#BigSwitch IP
$IP="xxx.xxx.xxx.xxx"
$global:token = $null


function Get-BCFSession([string]$user,[string]$pass,[string]$ip)
{
    #LOGON TO BCF
    $api_logon = "https://"+$IP +":8443/api/v1/auth/login"
    $params=@{"user"=$user;"password"=$pass} |convertto-json -compress
    #Collect bigswitch token
    $global:token = Invoke-WebRequest -Uri $api_logon -Method Post -Body $params -ContentType 'application/json' -SessionVariable myWebSession_local
    $global:mywebsession=$mywebsession_local
    $logon_result=$global:token.Content | ConvertFrom-Json
    if($logon_result.success -eq "True")
    {
        Write-Host "**Logon success" -ForegroundColor Green
    }
    else
    {
        Write-Host "**Logon failure" -ForegroundColor Red
    }
}



Write-Host "*Obtaining BCF session token" -ForegroundColor White
Get-BCFSession -user $user -pass $pass -ip $ip