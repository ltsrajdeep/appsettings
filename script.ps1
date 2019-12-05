$local = Get-Content 'local.settings.json'

$obj_local = $local | ConvertFrom-Json

$j = $obj_local.Values | ConvertTo-Json

$j | Out-File 'appsettings.json'

az functionapp config appsettings set --name FunctionApp220191024012218 --resource-group Fun --settings @appsettings.json