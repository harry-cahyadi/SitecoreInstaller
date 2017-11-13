function Create-Package {
	param(
		[string]$settingsFilePath
    )
	
	if(!$settingsFilePath) {
		
		$settingsFilePath = "$PSScriptRoot\sat-settings.config"
	}
	
	if( -not (Test-Path $settingsFilePath)) {
			throw "Configuration file is required"
	}

	Write-Host "- Reading the package settings..."
	
	$settings = Get-Settings $settingsFilePath
	
	$SAT = $settings.SATFolderPath
	$SKU = $settings.SKU
	$Version = $settings.Version
	$Resources = $settings.SATResourcesFolderPath
	$SitecoreVanillaZipFilePath = $settings.SitecoreVanillaInstanceZipFilePath
	$Output = $settings.PackageOutputFolderPath
	
	Write-Host "- Generating package in $output folder"
	
	# Import commandlets
	Import-Module "$SAT\tools\Sitecore.Cloud.Cmdlets.psm1"
	
	# Start the packaging process
	Start-SitecoreAzurePackaging -sitecorePath "$SitecoreVanillaZipFilePath" -destinationFolderPath $Output -cargoPayloadFolderPath "$Resources\cargopayloads" -commonConfigPath "$Resources\configs\common.packaging.config.json" -skuConfigPath "$Resources\configs\$SKU.packaging.config.json" -parameterXmlPath "$Resources\msdeployxmls" -fileVersion 1.0
	
	Write-Host "- Package generation completed successfully"
}

function Get-Settings {
    
    param(
        [Parameter(Mandatory=$true)]
		[string]$settingsFilePath
    )

    [xml]$xml = Get-Content $settingsFilePath
	
	$sat = Get-ConfigParam "SATFolderPath"
	
	if(!$sat -Or !(Test-Path -Path $sat)) {
        throw "Cannot generate package because the Sitecore Azure Toolkit module does not exist"
    }
	
	$sku = Get-ConfigParam "SATSKU"
	
	if(!$sku) {
        throw "Cannot generate package because the SKU information does not exist"
    }
	
	$version = Get-ConfigParam "SitecoreVersion"
	
	if(!$version) {
        throw "Cannot generate package because the Sitecore version does not exist"
    }
	
	$resources = "$sat\resources\$version"
	
	if(!$resources -Or !(Test-Path -Path $resources)) {
        throw "Cannot generate package because the Sitecore Azure Toolkit resources folder does not exist"
    }
	
	$sitecoreVanillaInstanceZipFilePath = Get-ConfigParam "SitecoreVanillaInstanceZipFilePath"
	
	if(!$sitecoreVanillaInstanceZipFilePath -Or !(Test-Path -Path $sitecoreVanillaInstanceZipFilePath)) {
        throw "Cannot generate package because the Sitecore vanilla instance zip file does not exist"
    }
	
	$packageOutputFolderPath = Get-ConfigParam  "PackageOutputFolderPath"

	#Use default value because value is empty in the config file
    if(!$packageOutputFolderPath) {
		$packageOutputFolderPath = "$PSScriptRoot\$(get-date -f MMddyyyyHHmmss)"

        #Make the directory if it does not exist
		if(!(Test-Path -Path $packageOutputFolderPath )){
			New-Item -ItemType directory -Path $packageOutputFolderPath
		}
    }
	
    $settings = @{ 
        SATFolderPath = $sat
		SATResourcesFolderPath = $resources
        SKU = $sku
        SitecoreVersion = $version
        SitecoreVanillaInstanceZipFilePath = $sitecoreVanillaInstanceZipFilePath
        PackageOutputFolderPath = $packageOutputFolderPath
	}

    return $settings
}

function Get-ConfigParam([string] $name) {
    $val = Select-Xml "/configuration/params/param[@name='$name']/text()" $xml
     
    #if([string]::IsNullOrEmpty($val)) {
    #    throw "Parameter $name is missing from config"
    #}
     
    return [string]$val
}

Create-Package