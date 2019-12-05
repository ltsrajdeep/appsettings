$hash = @{}
$connectionString = New-Object Collections.Generic.List[string]

Function Flatten_Appsettings
{
    param($appsettings, $key, [int32]$index)
    
    $obj_local = $appsettings | ConvertFrom-Json

    foreach($obj_property in $obj_local.PsObject.Properties)
    {
        if ($obj_property.Name -eq "Values") { #to handle "Values" object 
            $local = $obj_property.Value | ConvertTo-Json
            Flatten_Appsettings $local "" -1 #Call # 2 
        }
        if($obj_property.Value -is [string] -Or $obj_property.Value -is [int32] -Or $obj_property.Value -is [boolean]){
            if($key -eq "ConnectionStrings__")
            {
                #$connectionString[$obj_property.Name] = $obj_property.Value
                $connectionString.Add("$($obj_property.Name)='$($obj_property.Value)'")
            }
            else {
                $hkey = $key + $obj_property.Name
                $hkey = if($index -gt -1) { $hkey.replace("__",":") } else {$hkey} #To handle arrays of object and to write thos in format key1:key2:key3
                $hash[$hkey] = $obj_property.Value
            }
        }
        elseif($obj_property.Value -is [array]){
            if ($obj_property.Value.count -gt 0 -And $obj_property.Value[0] -isnot [int32] -And $obj_property.Value[0] -isnot [string]) {
                for ($idx = 0; $idx -lt $obj_property.Value.Count; $idx++) {
                    $keyd = "$($key)$($obj_property.Name):$($idx):"
                    $obj = $obj_property.Value[$idx]
                    $obj = $obj | ConvertTo-Json
                    Flatten_Appsettings $obj $keyd $idx #Call # 3 : This is only to handle Dictionary 
                }
            }
            else{
                $hkey = $key + $obj_property.Name
                $hash[$hkey] = $obj_property.Value
            }
        }
        elseif ($obj_property.Name -ne "Values"){
            $local = $obj_property.Value | ConvertTo-Json
            $key1 = "$($key)$($obj_property.Name)__"
            Flatten_Appsettings $local $key1 -1 #Call # 4 : To handle anything otherthan "values" 
        }
    }     
}


$path = $args[0]
$output_path = $args[1]
$app_resource_group = $args[2]
$app_name = $args[3]

$local = Get-Content $path
Flatten_Appsettings $local "" -1 #Call # 1 : The script is based on recursion logic. the third parameter "-1" is only useful in dectionary scenario


$appsetings = $hash | ConvertTo-Json
$appsetings | Out-File $output_path

az login --service-principal --username http://DevOpsPrincipal --password 1b323ff5-a85a-4aa8-b1e7-be5f8d3f3353 --tenant 0cbb91b2-6f1b-4899-a000-7520dc611d4e

######------Delete existing appsetting entry
$existing_appsettings = az functionapp config appsettings list --name $app_name --resource-group $app_resource_group

$existing_appsettings_obj = $existing_appsettings  | ConvertFrom-Json

$existing_appsettings_obj_name = $existing_appsettings_obj | ForEach-Object {$_.psobject.properties.name -cnotmatch '^[A-Z_]*$' }

if($existing_appsettings_obj_name.length -gt 0){
    az functionapp config appsettings delete --name $app_name --resource-group $app_resource_group --setting-names $existing_appsettings_obj_name.name
}
######-------------------------------------------------------------------

az functionapp config appsettings set --name $app_name --resource-group $app_resource_group --settings @$output_path


#######------Delete existing connectionString entry
$existing_conStr = az webapp config connection-string list --name $app_name --resource-group $app_resource_group

$existing_conStr_obj = $existing_conStr  | ConvertFrom-Json

$existing_conStr_obj_name = $existing_conStr_obj | Select-Object -Property name

if($existing_conStr_obj_name.length -gt 0){
    az webapp config connection-string delete --name $app_name --resource-group $app_resource_group --setting-names $existing_conStr_obj_name.name
}
######-----------------------------------

az webapp config connection-string set -g $app_resource_group -n $app_name -t SQLServer --settings $connectionString