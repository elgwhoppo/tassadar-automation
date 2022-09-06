az group create --location eastus --name tassadar-bootstrap
az network vnet create --resource-group tassadar-bootstrap --name tassadar-vnet --address-prefix 10.10.0.0/16 --subnet-name a --subnet-prefix 10.10.0.0/24

# Create Additional Subnets
az network vnet subnet create --address-prefixes