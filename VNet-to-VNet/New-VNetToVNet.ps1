# A sample script creating 2 connected Azure networks in 1 subscription
# Mostly from
# https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-vnet-vnet-rm-ps#samesub
# Not idempotent

#region ######## Variables #################################

$Sub1 = "Free Trial"


$RG1           = "TestRG1"
$Location1     = "East US"
$VNetName1     = "TestVNet1"
$FESubName1    = "FrontEnd"
$BESubName1    = "Backend"
$GWSubName1    = "GatewaySubnet"
$VNetPrefix11  = "10.11.0.0/16"
$VNetPrefix12  = "10.12.0.0/16"
$FESubPrefix1  = "10.11.0.0/24"
$BESubPrefix1  = "10.12.0.0/24"
$GWSubPrefix1  = "10.12.255.0/27"
$GWName1       = "VNet1GW"
$GWIPName1     = "VNet1GWIP"
$GWIPconfName1 = "gwipconf1"
$Connection14  = "VNet1toVNet4"

$RG4           = "TestRG4"
$Location4     = "West US"
$VnetName4     = "TestVNet4"
$FESubName4    = "FrontEnd"
$BESubName4    = "Backend"
$GWSubName4    = "GatewaySubnet"
$VnetPrefix41  = "10.41.0.0/16"
$VnetPrefix42  = "10.42.0.0/16"
$FESubPrefix4  = "10.41.0.0/24"
$BESubPrefix4  = "10.42.0.0/24"
$GWSubPrefix4  = "10.42.255.0/27"
$GWName4       = "VNet4GW"
$GWIPName4     = "VNet4GWIP"
$GWIPconfName4 = "gwipconf4"
$Connection41  = "VNet4toVNet1"

#endregion

#region ######## Enter Azure ###############################

$PresavedContextPath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "context.json"
if (Test-Path $PresavedContextPath) { # for local runs with saved azure context
    Import-AzureRmContext -Path $PresavedContextPath
}
else {
    Login-AzureRmAccount    
}
Select-AzureRmSubscription -SubscriptionName $Sub1

#endregion

#region ######## Network 1 + Gateway #######################

New-AzureRmResourceGroup -Name $RG1 -Location $Location1
$fesub1 = New-AzureRmVirtualNetworkSubnetConfig -Name $FESubName1 -AddressPrefix $FESubPrefix1
$besub1 = New-AzureRmVirtualNetworkSubnetConfig -Name $BESubName1 -AddressPrefix $BESubPrefix1
$gwsub1 = New-AzureRmVirtualNetworkSubnetConfig -Name $GWSubName1 -AddressPrefix $GWSubPrefix1
New-AzureRmVirtualNetwork -Name $VNetName1 `
        -ResourceGroupName $RG1 `
        -Location $Location1 `
        -AddressPrefix $VNetPrefix11,$VNetPrefix12 `
        -Subnet $fesub1,$besub1,$gwsub1

$gwpip1 = New-AzureRmPublicIpAddress -Name $GWIPName1 `
        -ResourceGroupName $RG1 `
        -Location $Location1 `
        -AllocationMethod Dynamic

$vnet1     = Get-AzureRmVirtualNetwork -Name $VNetName1 -ResourceGroupName $RG1
$subnet1   = Get-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet1
$gwipconf1 = New-AzureRmVirtualNetworkGatewayIpConfig -Name $GWIPconfName1 `
        -Subnet $subnet1 -PublicIpAddress $gwpip1

New-AzureRmVirtualNetworkGateway -Name $GWName1 `
        -ResourceGroupName $RG1 -Location $Location1 `
        -IpConfigurations $gwipconf1 `
        -GatewayType Vpn `
        -VpnType RouteBased `
        -GatewaySku Standard

#endregion

#region ######## Network 4 + Gateway #######################

New-AzureRmResourceGroup -Name $RG4 -Location $Location4
$fesub4 = New-AzureRmVirtualNetworkSubnetConfig -Name $FESubName4 -AddressPrefix $FESubPrefix4
$besub4 = New-AzureRmVirtualNetworkSubnetConfig -Name $BESubName4 -AddressPrefix $BESubPrefix4
$gwsub4 = New-AzureRmVirtualNetworkSubnetConfig -Name $GWSubName4 -AddressPrefix $GWSubPrefix4

New-AzureRmVirtualNetwork -Name $VnetName4 `
        -ResourceGroupName $RG4 `
        -Location $Location4 `
        -AddressPrefix $VnetPrefix41,$VnetPrefix42 `
        -Subnet $fesub4,$besub4,$gwsub4

$gwpip4 = New-AzureRmPublicIpAddress -Name $GWIPName4 `
        -ResourceGroupName $RG4 `
        -Location $Location4 `
        -AllocationMethod Dynamic

$vnet4     = Get-AzureRmVirtualNetwork -Name $VnetName4 -ResourceGroupName $RG4
$subnet4   = Get-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet4
$gwipconf4 = New-AzureRmVirtualNetworkGatewayIpConfig -Name $GWIPconfName4 `
        -Subnet $subnet4 -PublicIpAddress $gwpip4

New-AzureRmVirtualNetworkGateway -Name $GWName4 `
        -ResourceGroupName $RG4 `
        -Location $Location4 `
        -IpConfigurations $gwipconf4 `
        -GatewayType Vpn `
        -VpnType RouteBased `
        -GatewaySku Standard

#endregion

#region ######## Connecting Gateways #######################

$vnet1gw = Get-AzureRmVirtualNetworkGateway -Name $GWName1 -ResourceGroupName $RG1
$vnet4gw = Get-AzureRmVirtualNetworkGateway -Name $GWName4 -ResourceGroupName $RG4
New-AzureRmVirtualNetworkGatewayConnection -Name $Connection14 `
        -ResourceGroupName $RG1 `
        -VirtualNetworkGateway1 $vnet1gw `
        -VirtualNetworkGateway2 $vnet4gw `
        -Location $Location1 `
        -ConnectionType Vnet2Vnet `
        -SharedKey 'AzureA1b2C3'

New-AzureRmVirtualNetworkGatewayConnection -Name $Connection41 `
        -ResourceGroupName $RG4 `
        -VirtualNetworkGateway1 $vnet4gw `
        -VirtualNetworkGateway2 $vnet1gw `
        -Location $Location4 `
        -ConnectionType Vnet2Vnet `
        -SharedKey 'AzureA1b2C3'

Write-Host "###################################################"

Write-Host "Testing conntection $Connection14"
Get-AzureRmVirtualNetworkGatewayConnection -Name $Connection14 -ResourceGroupName $RG1

Write-Host "Testing conntection $Connection41"
Get-AzureRmVirtualNetworkGatewayConnection -Name $Connection41 -ResourceGroupName $RG4

#endregion