# Step 1: Import module
Import-Module Az.Accounts

# Step 2: get existing context
$currentAzContext = Get-AzContext

# Destination image resource group
$imageResourceGroup="RG-AVDImageBuilder"

# Location (see possible locations in the main docs)
$location="westeurope"

# Your subscription. This command gets your current subscription
$subscriptionID=$currentAzContext.Subscription.Id

# Image template name
$imageTemplateName="AVD-WIN10ImageTemplate"

# Distribution properties object name (runOutput). Gives you the properties of the managed image on completion
$runOutputName="sigOutput"

# Create resource group
New-AzResourceGroup -Name $imageResourceGroup -Location $location

# setup role def names, these need to be unique
$imageRoleDefName="Azure Image Builder Image Def"
$identityName="AVD-AIB-Identity"

## Add Azure PowerShell modules to support AzUserAssignedIdentity and Azure VM Image Builder
'Az.ImageBuilder', 'Az.ManagedServiceIdentity' | ForEach-Object {Install-Module -Name $_ }

# Create the identity
New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName -Location $location

$identityNameResourceId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).Id
$identityNamePrincipalId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).PrincipalId

$aibRoleImageCreationUrl="https://raw.githubusercontent.com/RamonImpara/AVD/main/aibRoleImageCreation.json"
$aibRoleImageCreationPath = "aibRoleImageCreation.json"

# Download the config
Invoke-WebRequest -Uri $aibRoleImageCreationUrl -OutFile $aibRoleImageCreationPath -UseBasicParsing

((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<rgName>', $imageResourceGroup) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace 'Azure Image Builder Service Image Creation Role', $imageRoleDefName) | Set-Content -Path $aibRoleImageCreationPath

# Create a role definition
New-AzRoleDefinition -InputFile  ./aibRoleImageCreation.json

# Grant the role definition to the VM Image Builder service principal
New-AzRoleAssignment -ObjectId $identityNamePrincipalId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"


$sigGalleryName= "AVD_AIB_Gallery"
$imageDefName ="win10avd"

# Create the gallery
New-AzGallery -GalleryName $sigGalleryName -ResourceGroupName $imageResourceGroup  -Location $location

# Create the gallery definition
New-AzGalleryImageDefinition -GalleryName $sigGalleryName -ResourceGroupName $imageResourceGroup -Location $location -Name $imageDefName -OsState generalized -OsType Windows -Publisher 'myCo' -Offer 'Windows' -Sku '10avd'