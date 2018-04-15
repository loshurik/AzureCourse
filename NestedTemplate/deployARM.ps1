# This is a generic script to deploy ARM Templates

#region ######## Parameters ################################
param(
    [string]$PathToTemplate = "$PSScriptRoot\BrickTemplates\storageAccount.json",
    [string]$PathToParameters = "$PSScriptRoot\BrickTemplates\storageAccount.parameters.json"
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

Write-Host "$PathToTemplate"
New-AzureRmResourceGroup -Name $resourceGroupName -Location $location
Test-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName `
        -TemplateFile $PathToTemplate `
        -TemplateParameterFile $PathToParameters


New-AzureRmResourceGroupDeployment -Name $deploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $PathToTemplate  `
        -TemplateParameterFile $PathToParameters
        
#endregion