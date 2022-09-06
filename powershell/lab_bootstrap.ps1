#Create VNet
az group create --location eastus --name tassadar-bootstrap
az network vnet create --resource-group tassadar-bootstrap --name tassadar-vnet --address-prefix 10.10.0.0/16 --subnet-name prod-subnet-10-10-0-0 --subnet-prefix 10.10.0.0/24

#Create Additional Subnets
az network vnet subnet create --resource-group tassadar-bootstrap --vnet-name tassadar-vnet --name GatewaySubnet --address-prefix 10.10.1.0/24
az network vnet subnet create --resource-group tassadar-bootstrap --vnet-name tassadar-vnet --name prod-subnet-10-10-2-0 --address-prefix 10.10.2.0/24
az network vnet subnet create --resource-group tassadar-bootstrap --vnet-name tassadar-vnet --name prod-subnet-10-10-3-0 --address-prefix 10.10.3.0/24
az network vnet subnet create --resource-group tassadar-bootstrap --vnet-name tassadar-vnet --name prod-subnet-10-10-4-0 --address-prefix 10.10.4.0/24
az network vnet subnet create --resource-group tassadar-bootstrap --vnet-name tassadar-vnet --name prod-subnet-10-10-5-0 --address-prefix 10.10.5.0/24


#Create VPN Gateway
#az network vpn-gateway connection create --resource-group tassadar-bootstrap --name MyConnection --gateway-name MyGateway --remote-vpn-site /subscriptions/MySub/resourceGroups/MyRG/providers/Microsoft.Network/vpnSites/MyVPNSite --associated-route-table /subscriptions/MySub/resourceGroups/MyRG/providers/Microsoft.Network/virtualHubs/MyHub/hubRouteTables/MyRouteTable1 --propagated-route-tables /subscriptions/MySub/resourceGroups/MyRG/providers/Microsoft.Network/virtualHubs/MyHub/hubRouteTables/MyRouteTable1 /subscriptions/MySub/resourceGroups/MyRG/providers/Microsoft.Network/virtualHubs/MyHub/hubRouteTables/MyRouteTable2 --labels label1 label2
az network public-ip create --resource-group tassadar-bootstrap --name tassadar-vpn-pip
az network vnet-gateway create --resource-group tassadar-bootstrap --name TassadarGateway --public-ip-address tassadar-vpn-pip --vnet tassadar-vnet --gateway-type Vpn --sku Basic --vpn-type RouteBased --no-wait