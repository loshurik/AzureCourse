# This is a generic script to deploy ARM Templates

#region ######## Parameters ################################
param(
    [string]$PathToTemplate = "$PSScriptRoot\webappsql.json",
    [string]$PathToParameters = "$PSScriptRoot\webappsql.parameters.json"
)

#region ######## Variables ################################# 

$subscriptionName = "Free Trial"
$resourceGroupName = "HomeTask71"
$deploymentName = "HomeTask7Deployment"
$location = "South Central US"
$keyVaultName = "StaticKV"
$keyVaultResourceGroup = "StaticGroup"

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
        -ResourceGroupName $keyVaultResourceGroup `
        -TemplateFile (Join-Path (Get-Item $PSScriptRoot).Parent.FullName "NestedTemplate\keyvault.json") `
        -TemplateParameterFile (Join-Path (Get-Item $PSScriptRoot).Parent.FullName "NestedTemplate\keyvault.parameters.json") `
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
$passwordExists = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -name "sqlPassword" -ErrorAction SilentlyContinue
if (-not $passwordExists){
        [void](Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name "sqlPassword" -SecretValue $securedPassword)
}

#endregion



#region ######## Web app deployment ######################## 

New-AzureRmResourceGroupDeployment -Name ($deploymentName) `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $PathToTemplate `
        -TemplateParameterFile $PathToParameters

#endregion


#endregion