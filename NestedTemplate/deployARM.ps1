# This is a generic script to deploy ARM Templates

#region ######## Parameters ################################
param(
    [string]$PathToTemplate = "$PSScriptRoot\keyvault.json",
    [string]$PathToParameters = "$PSScriptRoot\keyvault.parameters.json"
)

#region ######## Variables ################################# 

$subscriptionName = "Free Trial"
$resourceGroupName = "HomeTask48"
$deploymentName = "HomeTask4Deployment"
$location = "South Central US"
$dscContainerName = "DSCExtension"
$password = "testKv"

#endregion

#region ######## Enter Azure ###############################

$PresavedContextPath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "context.json"
if (Test-Path $PresavedContextPath) { # for local runs with saved azure context
    Import-AzureRmContext -Path $PresavedContextPath
}
else {
    Login-AzureRmAccount    
}
Select-AzureRmSubscription -SubscriptionName $subscriptionName

#endregion

#region ######## Workflow ##################################

if (-not (Get-AzureRmResourceGroup $resourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $location
}
<#
#region ######## Key Vault deployment ######################

$currentTenantId = (Get-AzureRmContext).Tenant.Id
$accessPolicies = New-Object System.Collections.ArrayList

# add all existing AD users to key vault users (for test purposes it's ok, we have less than 16 users)
foreach ($userToAdd in (Get-AzureRmADUser).id) {
    $accessPolicies.Add(@{"tenantId" = $currentTenantId; 
                            "objectId" = $userToAdd;
                             "permissions" =  @{"keys" = @("all"); "secrets" = @("all")};
                        })
}

# deploy the keyvault
New-AzureRmResourceGroupDeployment -Name $deploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $PathToTemplate `
        -TemplateParameterFile $PathToParameters `
        -tenantId $currentTenantId `
        -accessPolicies $accessPolicies

#endregion
#>
#region ######## Storage Account deployment ################ 

New-AzureRmResourceGroupDeployment -Name ($deploymentName) `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile (Join-Path (Get-Item $PSScriptRoot).FullName "BrickTemplates\storageAccount.json") `
        -TemplateParameterFile (Join-Path (Get-Item $PSScriptRoot).FullName "BrickTemplates\storageAccount.parameters.json")

$storageAccountName = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName `
        -Name ($deploymentName)).Outputs.storageAccountName.value
$accountKeys = Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroupName `
        -Name $storageAccountName  
$storageContext = New-AzureStorageContext -StorageAccountName $storageAccountName `
        -StorageAccountKey $accountKeys[0].Value 
$container = New-AzureStorageContainer -Context $storageContext -Name $dscContainerName
$policy = New-AzureStorageContainerStoredAccessPolicy -Container $dscContainerName `
        -Policy $policyName `
        -Context $storageContext `
        -StartTime $(Get-Date).ToUniversalTime().AddMinutes(-5) `
        -ExpiryTime $(Get-Date).ToUniversalTime().AddYears(10) `
        -Permission rwld
$sas = New-AzureStorageContainerSASToken -name $containerName `
        -Policy $policyName `
        -Context $storageContext

#endregion

#region ######## Virtual Machine deployment ################

#endregion

#region ######## DSC Extension #############################

Publish-AzureRmVMDscConfiguration  `
-ConfigurationPath (Join-Path (Get-Item $PSScriptRoot).Parent.FullName "DSCExtension\Set-IIS.ps1") `
-ResourceGroupName $resourceGroupName `
-StorageAccountName $storageAccountName `
-ContainerName $dscContainerName


#endregion

#endregion