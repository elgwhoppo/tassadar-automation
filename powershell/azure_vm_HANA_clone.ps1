#This script will clone a VM from a source RG and VNet to a destination RG and VNet. 

#New VM Name; same network. Same OS Disk. 

#Note!! The 

#Todo: Check if snapshots exist with the same name 

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
$snapshotNameOS = $sourceVirtualMachineName + '_OsDisk-snapshot-cloning-powershell'
$snapshotNameData0 = $sourceVirtualMachineName + '_DataDisk-0-snapshot-cloning-powershell'
$snapshotNameData1 = $sourceVirtualMachineName + '_DataDisk-1-snapshot-cloning-powershell'

#**********************************************
# Virtual Machine: Destination Variables
#**********************************************

#Pre-existing VNet, VNet Resource Group, Subnet, and Region for the Destination VMs
#$virtualNetworkName = 'North-Central-Production'
$virtualNetworkName = 'bubble-sles-tester-vnet'
#$subnetName = 'azure-159.97.56.0-23-prod'
$subnetName = 'bubble-azure-159.97.56.0-23-prod'
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

#Operating System Type (-Windows/-Linux)  
$targetOStype = "-Linux"
  
#Storage type for the desired cloned Managed Disk (Available values are Standard_LRS, Premium_LRS, StandardSSD_LRS, and UltraSSD_LRS)
#https://learn.microsoft.com/en-us/powershell/module/azurerm.compute/new-azurermdiskconfig?view=azurermps-6.13.0#-skuname
$storageTypeOS = 'Standard_LRS'
$storageTypeData0 = 'Premium_LRS'
$storageTypeData1 = 'Premium_LRS'
  
#Size of the Virtual Machine (https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes)  
# to get powershell friendly names of the sizes for each region:   az vm list-sizes --location "eastus" --output table
# to get powershell friendly names of the regions:                 Get-AzLocation | select displayname,location
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

#Set the subscription for the current session where the commands will execute
Select-AzureRmSubscription -SubscriptionId $subscriptionID

#Create a new resource group to clone into if it does not exist already 
$newRgAlreadyExists = Get-AzureRmResourceGroup -Name $resourceGroupNameCloned
If (!$newRgAlreadyExists) {New-AzResourceGroup -Name $resourceGroupNameCloned -Location $location} else {Write-Host "Resource group exists already. Skipping creation"}

Write-Host "Taking snapshots of disks..."
#look for any pre-existing snapshots with the exact name. Delete them. 
$osSnapShotExists = az snapshot show --resource-group $resourceGroupNameCloned --name $snapshotNameOS
If ($osSnapShotExists) {Remove-AzureRmSnapshot -ResourceGroupName $resourceGroupNameCloned -SnapshotName $snapshotNameOS -Force} else {Write-Host "No snapshots found with the name $snapshotNameOS, continuing with creating fresh snapshots."}
#Create new OS VM Disk Snapshot from source VM
#Lesson learned, if you use $sourceVirtualMachine.StorageProfile.OsDisk.diskSizeGB it only works if the VM is powered on. This way it works both. 
$diskNameOS = $sourceVirtualMachine.StorageProfile.OsDisk.Name
$diskSizeOS = az disk show --name $diskNameOS --resource-group $resourceGroupName --query diskSizeGb
$snapshotOSconfig = New-AzSnapshotConfig -SourceUri $sourceVirtualMachine.StorageProfile.OsDisk.ManagedDisk.Id -Location $location -CreateOption copy -DiskSizeGB $diskSizeOS
$snapshotOS = New-AzSnapshot -Snapshot $snapshotOSconfig -SnapshotName $snapshotNameOS -ResourceGroupName $resourceGroupNameCloned


#Create new Data Disk 0 Snapshot from source VM
#look for any pre-existing snapshots with the exact name. Delete them. 
$data0SnapShotExists = az snapshot show --resource-group $resourceGroupNameCloned --name $snapshotNameData0
If ($data0SnapShotExists) {Remove-AzureRmSnapshot -ResourceGroupName $resourceGroupNameCloned -SnapshotName $snapshotNameData0 -Force} else {Write-Host "No snapshots found with the name $snapshotNameData0, continuing with creating fresh snapshots."}
$diskNameData0 = $sourceVirtualMachine.StorageProfile.dataDisks.Name[0]
$diskSizeData0 = az disk show --name $diskNameData0 --resource-group $resourceGroupName --query diskSizeGb
$snapshotData0config = New-AzSnapshotConfig -SourceUri $sourceVirtualMachine.StorageProfile.DataDisks.ManagedDisk.Id[0] -Location $location -CreateOption copy -DiskSizeGB $diskSizeData0
$snapshotData0 = New-AzSnapshot -Snapshot $snapshotData0config -SnapshotName $snapshotNameData0 -ResourceGroupName $resourceGroupNameCloned

#Create new Data Disk 1 Snapshot from source VM 
#look for any pre-existing snapshots with the exact name. Delete them. 
$data1SnapShotExists = az snapshot show --resource-group $resourceGroupNameCloned --name $snapshotNameData1
If ($data1SnapShotExists) {Remove-AzureRmSnapshot -ResourceGroupName $resourceGroupNameCloned -SnapshotName $snapshotNameData1 -Force} else {Write-Host "No snapshots found with the name $snapshotNameData1, continuing with creating fresh snapshots."}
$diskNameData1 = $sourceVirtualMachine.StorageProfile.dataDisks.Name[1]
$diskSizeData1 = az disk show --name $diskNameData1 --resource-group $resourceGroupName --query diskSizeGb
$snapshotData1config = New-AzSnapshotConfig -SourceUri $sourceVirtualMachine.StorageProfile.DataDisks.ManagedDisk.Id[1] -Location $location -CreateOption copy -DiskSizeGB $diskSizeData1
$snapshotData1 = New-AzSnapshot -Snapshot $snapshotData1config -SnapshotName $snapshotNameData1 -ResourceGroupName $resourceGroupNameCloned

Write-Host "Creating managed disks..."
#Create a new OS Managed Disk from the Snapshot
$diskOS = New-AzureRmDiskConfig -AccountType $storageTypeOS -DiskSizeGB $diskSizeOS -Location $location -CreateOption Copy -SourceResourceId $snapshotOS.Id
$diskOS = New-AzureRmDisk -Disk $diskOS -ResourceGroupName $resourceGroupNameCloned -DiskName $diskNameOS

#Create a new Data Disk 0 from the Snapshot
$diskData0 = New-AzureRmDiskConfig -AccountType $storageTypeData0 -DiskSizeGB $diskSizeData0 -Location $location -CreateOption Copy -SourceResourceId $snapshotData0.Id
$diskData0 = New-AzureRmDisk -Disk $diskData0 -ResourceGroupName $resourceGroupNameCloned -DiskName $diskNameData0

#Create a new Data Disk 1 from the Snapshot
$diskData1 = New-AzureRmDiskConfig -AccountType $storageTypeData1 -DiskSizeGB $diskSizeData1 -Location $location -CreateOption Copy -SourceResourceId $snapshotData1.Id
$diskData1 = New-AzureRmDisk -Disk $diskData1 -ResourceGroupName $resourceGroupNameCloned -DiskName $diskNameData1

Write-Host "Create VM Configuration..."
#Initialize virtual machine configuration  
$targetVirtualMachine = New-AzureRmVMConfig -VMName $targetVirtualMachineName -VMSize $targetVirtualMachineSize
  
#Attach Managed Disks to target virtual machine. OS type depends variable set in destination variable section (Windows/Linux)  
$targetVirtualMachine = Set-AzureRmVMOSDisk -VM $targetVirtualMachine -ManagedDiskId $diskOS.Id -CreateOption Attach -Linux
$targetVirtualMachine = Add-AzVMDataDisk -VM $targetVirtualMachine -Name $diskNameData0 -CreateOption Attach -ManagedDiskId $diskData0.Id -Lun 0
$targetVirtualMachine = Add-AzVMDataDisk -VM $targetVirtualMachine -Name $diskNameData1 -CreateOption Attach -ManagedDiskId $diskData1.Id -Lun 1
  
#Set destination VNet Variable Destination Virtual Network information  
$vnet = Get-AzureRmVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupForDestinationVNet
$subnet = $vnet.Subnets | Where-Object {$_.Name -eq $subnetName}

# Create Network Interface for the VM without Public IP, and with the IP placed in the variables above 
$nic = New-AzureRmNetworkInterface -Name ($targetVirtualMachineName.ToLower() + '_nic') -ResourceGroupName $resourceGroupNameCloned -Location $location -SubnetId $subnet.Id -PrivateIpAddress $targetVirtualMachineIP -Force
$targetVirtualMachine = Add-AzureRmVMNetworkInterface -VM $targetVirtualMachine -Id $nic.Id

Write-Host "Create VM..."
#Create the virtual machine with Managed Disk attached  
New-AzureRmVM -VM $targetVirtualMachine -ResourceGroupName $resourceGroupNameCloned -Location $location
 
Write-Host "Clean up snapshots..."
#Remove the OS disk snapshots
Remove-AzureRmSnapshot -ResourceGroupName $resourceGroupNameCloned -SnapshotName $snapshotNameOS -Force
Remove-AzureRmSnapshot -ResourceGroupName $resourceGroupNameCloned -SnapshotName $snapshotNameData0 -Force
Remove-AzureRmSnapshot -ResourceGroupName $resourceGroupNameCloned -SnapshotName $snapshotNameData1 -Force

#Check to see if the VM was created
$vmcreated = az vm show --name $targetVirtualMachineName --resource-group $resourceGroupNameCloned --output table
If ($vmcreated) {Write-Host "The following VM was created: "; $vmcreated} else {Write-Host "VM with name $targetVirtualMachineName was not found after script was run; something went wrong."}