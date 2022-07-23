# Start Veeam Ordered Services 

$ServiceName = 'MSSQL$VEEAMSQL2016'
$arrService = Get-Service -Name $ServiceName

while ($arrService.Status -ne 'Running')
{
    Start-Service $ServiceName
    write-host $arrService.status
    write-host 'Service starting'
    Start-Sleep -seconds 15
    $arrService.Refresh()
    if ($arrService.Status -eq 'Running')
    {
        Write-Host 'Service is now Running'
    }
}

$ServiceName = 'SQLTELEMETRY$VEEAMSQL2016'
$arrService = Get-Service -Name $ServiceName

while ($arrService.Status -ne 'Running')
{
    Start-Service $ServiceName
    write-host $arrService.status
    write-host 'Service starting'
    Start-Sleep -seconds 15
    $arrService.Refresh()
    if ($arrService.Status -eq 'Running')
    {
        Write-Host 'Service is now Running'
    }
}

$ServiceName = 'SQLBrowser'
$arrService = Get-Service -Name $ServiceName

while ($arrService.Status -ne 'Running')
{
    Start-Service $ServiceName
    write-host $arrService.status
    write-host 'Service starting'
    Start-Sleep -seconds 15
    $arrService.Refresh()
    if ($arrService.Status -eq 'Running')
    {
        Write-Host 'Service is now Running'
    }
}


$ServiceName = 'VeeamBackupSvc'
$arrService = Get-Service -Name $ServiceName

while ($arrService.Status -ne 'Running')
{
    Start-Service $ServiceName
    write-host $arrService.status
    write-host 'Service starting'
    Start-Sleep -seconds 15
    $arrService.Refresh()
    if ($arrService.Status -eq 'Running')
    {
        Write-Host 'Service is now Running'
    }
}


#Start all other non-running veeam Services 
Get-Service -Name Veeam* | Where-Object {$_.Status -ne 'Running'} | Start-Service