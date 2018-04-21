# This is a generic script to deploy ARM Templates

#region ######## Parameters ################################
param(
    [string]$PathToTemplate = "$PSScriptRoot\keyvault.json",
    [string]$PathToParameters = "$PSScriptRoot\keyvault.parameters.json"
)

#region ######## Variables ################################# 

$subscriptionName = "Free Trial"
$resourceGroupName = "HomeTask47"
$deploymentName = "HomeTask4Deployment"
$location = "South Central US"
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

#region ######## KeyVault deployment #######################

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

#endregion