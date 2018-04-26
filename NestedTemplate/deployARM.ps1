# This is a generic script to deploy ARM Templates

#region ######## Parameters ################################
param(
    [string]$PathToTemplate = "$PSScriptRoot\keyvault.json",
    [string]$PathToParameters = "$PSScriptRoot\keyvault.parameters.json"
)

#region ######## Variables ################################# 

$subscriptionName = "Free Trial"
$resourceGroupName = "HomeTask41"
$deploymentName = "HomeTask4Deployment"
$location = "South Central US"
$dscContainerName = "dsc"
$keyVaultName = "StaticKV"
$policyName = "DSCpolicy"

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
                        }) | Out-Null
}

# deploy the keyvault
New-AzureRmResourceGroupDeployment -Name $deploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $PathToTemplate `
        -TemplateParameterFile $PathToParameters `
        -keyVaultName $keyVaultName `
        -tenantId $currentTenantId `
        -accessPolicies $accessPolicies

# take care of password
do {
        $password = (Get-Random -Count 15 -InputObject ([char[]]"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-+")) -join ''
}
# make sure the password has at least 1 digit, capital and small letter
until (($password -match "\d") -and ($password -cmatch "[A-Z]") -and ($password -cmatch "[a-z]"-and ($password -cmatch "[+-]"))) 
$securedPassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$passwordExists = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -name "vmPassword" -ErrorAction SilentlyContinue
if (-not $passwordExists){
        [void](Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name "vmPassword" -SecretValue $securedPassword)
}

#endregion
#>

#region ######## Generic deployment ######################## 

New-AzureRmResourceGroupDeployment -Name ($deploymentName) `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile (Join-Path (Get-Item $PSScriptRoot).FullName "genericTemplate.json") `
        -TemplateParameterFile (Join-Path (Get-Item $PSScriptRoot).FullName "genericTemplate.parameters.json")

$storageAccountName = (Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName).StorageAccountName
$accountKeys = Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroupName `
        -Name $storageAccountName  
$storageContext = New-AzureStorageContext -StorageAccountName $storageAccountName `
        -StorageAccountKey $accountKeys[0].Value 

$containerExists = Get-AzureStorageContainer -Context $storageContext -Name $dscContainerName
if (-not $containerExists) {
        $container = New-AzureStorageContainer -Context $storageContext -Name $dscContainerName
}
$policyExists = Get-AzureStorageContainerStoredAccessPolicy -Container $dscContainerName -Context $storageContext
if (-not $policyExists) {
        $policy = New-AzureStorageContainerStoredAccessPolicy -Container $dscContainerName `
        -Policy $policyName `
        -Context $storageContext `
        -StartTime $(Get-Date).ToUniversalTime().AddMinutes(-5) `
        -ExpiryTime $(Get-Date).ToUniversalTime().AddYears(10) `
        -Permission rwld
}
$sas = New-AzureStorageContainerSASToken -name $dscContainerName `
        -Policy $policyName `
        -Context $storageContext

#endregion

#region ######## DSC Extension #############################

Publish-AzureRmVMDscConfiguration  `
-ConfigurationPath (Join-Path (Get-Item $PSScriptRoot).Parent.FullName "DSCExtension\Set-IIS.ps1") `
-ResourceGroupName $resourceGroupName `
-StorageAccountName $storageAccountName `
-ContainerName $dscContainerName `
-Force


#endregion


#endregion