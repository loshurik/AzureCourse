# This is a generic script to deploy ARM Templates

#region ######## Parameters ################################
param(
    [string]$PathToTemplate = "$PSScriptRoot\genericTemplate.json",
    [string]$PathToParameters = "$PSScriptRoot\genericTemplate.parameters.json"
)

#region ######## Variables ################################# 

$subscriptionName = "Free Trial"
$resourceGroupName = "HomeTask3"
$deploymentName = "HomeTask3Deployment"
$location = "South Central US"

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

New-AzureRmResourceGroupDeployment -Name $deploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $PathToTemplate `
        -TemplateParameterFile $PathToParameters

#endregion