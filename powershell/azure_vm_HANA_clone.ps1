#Clone 1 HANA VM from azure-159.97.56.0-23-prod to azure-159.97.56.0-23-prod in the WR Grace Azure subscription

#New VM Name; same network. Same OS Disk. 
#Assumes Linux virtual machine

#******************************************
# Virtual Machine: Source Variables
#******************************************

#Subscription you are working within
# W.R. Grace Prod Subscription ID 
#$subscriptionID = '2015dfd1-6123-45b5-9adb-f476f4824e5c'
#advizexdev
$subscriptionID = '27b24066-6036-4904-9761-1441c2f0ffaa'

#Resource group of the source VM to be cloned from   
#$resourceGroupName = 'RG-PROD-HANA'
$resourceGroupName = 'sles-tester'

#Names of source VM to clone 
#$sourceVirtualMachineName = 'azrcus0011'
$sourceVirtualMachineName = 'sles-tester'

#Name of snapshot which will be created from the Managed Disk
$snapshotNameOS = $sourceVirtualMachineName + '_OsDisk-snapshot'
$snapshotNameData0 = $sourceVirtualMachineName + '_DataDisk-0-snapshot'
$snapshotNameData1 = $sourceVirtualMachineName + '_DataDisk-1-snapshot'
$snapshotNameData2 = $sourceVirtualMachineName + '_DataDisk-2-snapshot'
$snapshotNameData3 = $sourceVirtualMachineName + '_DataDisk-3-snapshot'

#**********************************************
# Virtual Machine: Destination Variables
#**********************************************

#Pre-existing VNet, VNet Resource Group, Subnet, and Region for the Destination VMs
#$virtualNetworkName = 'North-Central-Production'
$virtualNetworkName = 'bubble-sles-tester-vnet'
#$subnetName = 'azure-159.97.56.0-23-prod'
$subnetName = 'azure-159.97.56.0-23-prod'
#$resourceGroupForDestinationVNet = 'RG-PROD-MGMT'
$resourceGroupForDestinationVNet = 'bubble-sles-tester'
#$location = 'northcentralus'
$location = 'eastus2'

#New Resource Group to be created (if doesn't exist)
$resourceGroupNameCloned = 'bubble-sles-tester'

#Names, IP, and Pre-existing Storage Account for Destination VM
$targetVirtualMachineName = 'cloned-sles-tester'
$targetVirtualMachineIP = '159.97.56.16'
#$cloneToStorageAccountName = 'azrcusdrilldr'
# ^ not needed

#Name of the destination Managed Disks
$diskNameOS = $targetVirtualMachineName + '_OsDisk'  
$diskNameData0 = $targetVirtualMachineName + '_DataDisk0'  
$diskNameData1 = $targetVirtualMachineName + '_DataDisk1'
  
#Size of destination Managed Disk(s) in GB  
#User 0 size for disk if there is no other disk
$diskSize = 30
#Now deterministaclly found
  
#Storage type for the new Managed Disk (Standard_LRS / Premium_LRS / StandardSSD_LRS)  
$storageTypeOS = 'Standard_LRS'
$storageTypeData0 = 'Standard_LRS'
$storageTypeData1 = 'Standard_LRS'
  
#Size of the Virtual Machine (https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes)  
$targetVirtualMachineSize = 'Standard_B2ms'
  
#*********************************
# To Do: Verify Variables Function 
#*********************************

#*********************************
# Begin Actionable Items 
#*********************************

Write-Host "Now creating" $targetVirtualMachineName "..."

#Get the existing VM from which to clone from  
$sourceVirtualMachine = Get-AzVM -ResourceGroupName $resourceGroupName -Name $sourceVirtualMachineName  

#Get the storage account details to clone into 
#$storageaccount = Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $cloneToStorageAccountName}
# ^ not needed?

#Set the subscription for the current session where the commands will execute  
Select-AzureRmSubscription -SubscriptionId $subscriptionID

#Create a new resource group to clone into if it does not exist already 
$newRgAlreadyExists = Get-AzureRmResourceGroup -Name $resourceGroupNameCloned
If (!$newRgAlreadyExists) {New-AzResourceGroup -Name $resourceGroupNameCloned -Location $location} else {Write-Host "Resource group exists already. Skipping creation"}

Write-Host "Taking snapshots of disks..."
  
#Create new OS VM Disk Snapshot in source environment 
$diskSizeOS = $sourceVirtualMachine.StorageProfile.OsDisk.diskSizeGB
$snapshotOSconfig = New-AzSnapshotConfig -SourceUri $sourceVirtualMachine.StorageProfile.OsDisk.ManagedDisk.Id -Location $location -CreateOption copy -DiskSizeGB $diskSize -AccountType Standard_LRS
$snapshotOS = New-AzSnapshot -Snapshot $snapshotOSconfig -SnapshotName $snapshotNameOS -ResourceGroupName $resourceGroupName

#Create new Data Disk 0 Snapshot in source environment 
$diskSizeData0 = $sourceVirtualMachine.StorageProfile.dataDisks.diskSizeGB[0]
$snapshotData0 = New-AzSnapshotConfig -SourceUri $sourceVirtualMachine.StorageProfile.DataDisks.ManagedDisk.Id[0] -Location $location -CreateOption copy -DiskSizeGB $diskSizeData0
$snapshotData0 = New-AzSnapshot -Snapshot $snapshotData0 -SnapshotName $snapshotNameData0 -ResourceGroupName $resourceGroupName

#Create new Data Disk 1 Snapshot in source environment
$diskSizeData1 = $sourceVirtualMachine.StorageProfile.dataDisks.diskSizeGB[1]
$snapshotData1 = New-AzSnapshotConfig -SourceUri $sourceVirtualMachine.StorageProfile.DataDisks.ManagedDisk.Id[1] -Location $location -CreateOption copy -DiskSizeGB $diskSizeData1
$snapshotData1 = New-AzSnapshot -Snapshot $snapshotData1 -SnapshotName $snapshotNameData1 -ResourceGroupName $resourceGroupName

Write-Host "Creating managed disks..."

#Create a new OS Managed Disk from the Snapshot
$diskOS = New-AzureRmDiskConfig -AccountType $storageType -DiskSizeGB $diskSize -Location $location -CreateOption Copy -SourceResourceId $snapshotOS.Id
$diskOS = New-AzureRmDisk -Disk $diskOS -ResourceGroupName $resourceGroupNameCloned -DiskName $diskNameOS

#Initialize virtual machine configuration  
$targetVirtualMachine = New-AzureRmVMConfig -VMName $targetVirtualMachineName -VMSize $targetVirtualMachineSize
  
#Attach Managed Disk to target virtual machine. OS type depends OS present in the disk (Windows/Linux)  
$targetVirtualMachine = Set-AzureRmVMOSDisk -VM $targetVirtualMachine -ManagedDiskId $diskOS.Id -CreateOption Attach -Linux  
  
#Set destination VNet Variable Destination Virtual Network information  
$vnet = Get-AzureRmVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupForDestinationVNet
$subnet = $vnet.Subnets | Where-Object {$_.Name -eq $subnetName}

# Create Network Interface for the VM without Public IP, and with the IP placed in the variables above 
$nic = New-AzureRmNetworkInterface -Name ($targetVirtualMachineName.ToLower() + '_nic') -ResourceGroupName $resourceGroupNameCloned -Location $location -SubnetId $subnet.Id -PrivateIpAddress $targetVirtualMachineIP
$targetVirtualMachine = Add-AzureRmVMNetworkInterface -VM $targetVirtualMachine -Id $nic.Id
  
#Create the virtual machine with Managed Disk attached  
New-AzureRmVM -VM $targetVirtualMachine -ResourceGroupName $resourceGroupNameCloned -Location $location
  
#Remove the OS disk snapshot
Remove-AzureRmSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotNameOS -Force