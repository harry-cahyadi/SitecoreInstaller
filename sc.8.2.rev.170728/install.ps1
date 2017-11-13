function Install {
    param(
		[string]$settingsFilePath
    )
	
	if(!$settingsFilePath) {
		
		$settingsFilePath = "$PSScriptRoot\settings.config"
	}
	
	if( -not (Test-Path $settingsFilePath)) {
			throw "Configuration file is required"
	}
    	
    $DbSAPassword = Read-Host -Prompt 'Please enter the db administrator password' -AsSecureString
	
	$settings = Get-Settings $settingsFilePath $DbSAPassword
	
    FindOrCreateWebsiteDirectory $settings.WebsitePath

	Begin-Installation $settings
	
	if ($settings.RunPackageInstallation) {
    
        Write-Host "Adding package upload tool to Sitecore..."
        Copy-Item $settings.PackageInstallerPath $settings.WebsitePath -force
	    
	    Add-Packages $settings
	}
}

function Get-Settings {
    
    param(
        [Parameter(Mandatory=$true)]
		[string]$settingsFilePath,

        [Parameter(Mandatory=$true)]
		[securestring]$DbSAPassword
    )

    [xml]$xml = Get-Content $settingsFilePath

    $installationManifestFilePath = Get-ConfigParam "InstallationManifestFilePath"
    
    if(!$installationManifestFilePath -Or !(Test-Path -Path $installationManifestFilePath)) {
        throw "Cannot run package installation because the installer manifest file does not exist"
    }

    $installationPackageFilePath = Get-ConfigParam "InstallationPackageFilePath"
    
    if(!$installationPackageFilePath -Or !(Test-Path -Path $installationPackageFilePath)) {
        throw "Cannot run package installation because the installer package file does not exist"
    }

    $sitecoreLicenseFilePath = Get-ConfigParam "SitecoreLicenseFilePath"
    
    if(!$sitecoreLicenseFilePath -Or !(Test-Path -Path $sitecoreLicenseFilePath)) {
        throw "Cannot run package installation because the Sitecore license file does not exist"
    }

    $websiteName = Get-ConfigParam "WebsiteName"
    
    #Use default value because value is empth in the config file
    if(!$websiteName) {
        $websiteName = "Sitecore"
    }

	$websitePath = Get-ConfigParam "WebsitePath"
    
    #Use default value because value is empty in the config file
    if(!$websitePath) {
        $PSScriptRootParentDirPath = Split-Path "$PSScriptRoot" -Parent
		$websitePath = "$PSScriptRootParentDirPath\Website"

        #Make the Website directory if it does not exist
		if(!(Test-Path -Path $websitePath )){
			New-Item -ItemType directory -Path $websitePath

		}
    }

    $DbServer = Get-ConfigParam "DbServer"

    #Use default value because value is empty in the config file
    if(!$DbServer) {
        $DbServer = "."
    }

	$DbSAUsername = Get-ConfigParam "DbSAUsername"

    #Use default value because value is empty in the config file
    if(!$DbSAUsername) {
        $DbSAUsername = "sa"
    }

	$sitecoreSiteName = "$websiteName.sc"

    $strRunPackageInstallation = Get-ConfigParam "RunPackageInstallation"

    #Use default value because value is empty in the config file
    if(!$strRunPackageInstallation) {
        $strRunPackageInstallation = "false"
    }

	$runPackageInstallation = [System.Convert]::ToBoolean($strRunPackageInstallation)
    
    $packageInstallerPath = ""
    $packages = $null

    if ($runPackageInstallation) {

        $packageInstallerPath = Get-ConfigParam "PackageUploadTool"

        #Use default value because value is empty in the config file
        if(!$packageInstallerPath) {
            $packageInstallerPath = "$PSScriptRoot\addons\sc.packages.installer\InstallModules.aspx"

            #Package installer is missing
		    if(!(Test-Path -Path $packageInstallerPath )){
			    throw "Cannot run package installation because the package installer does not exist"
		    }
        }

        $packages = Get-ConfigPackages

        if (!$packages) {
            throw "No packages specified in the settings file"
        }
    }

    $settings = @{ 
        InstallationManifestFilePath = $installationManifestFilePath
        InstallationPackageFilePath = $installationPackageFilePath
        SitecoreLicenseFilePath = $sitecoreLicenseFilePath
		WebsiteName = $websiteName
        WebsitePath = $websitePath
        SitecoreWebsiteName = $sitecoreSiteName
        DbServer = $DbServer
        DbSAUsername = $DbSAUsername
        DbSAPassword = $DbSAPassword
        RunPackageInstallation = $runPackageInstallation
        PackageInstallerPath = $packageInstallerPath
        Packages = $packages
	}

    return $settings
}

function Import-SitecoreInstallFramework {

	#Registers Sitecore powershell repository
	Register-PSRepository -Name SitecoreGallery -SourceLocation https://sitecore.myget.org/F/sc-powershell/api/v2
	
	#Installs  SitecoreInstallationFramework powershell module
	Install-Module SitecoreInstallFramework -force
	
	#Ensures the module is the latest version
	Update-Module SitecoreInstallFramework
	
	#Shows the list of available SitecoreInstallationFramework modules
	Get-Module SitecoreInstallFramework –ListAvailable
}

function FindOrCreateWebsiteDirectory {
	param(
		[Parameter(Mandatory=$true)]
		[string]$websitePath
	)
    
    if( -not (Test-Path $websitePath) ) {
		
		#Make the Website directory if it does not exist
		if(!(Test-Path -Path $websitePath )){
			New-Item -ItemType directory -Path $websitePath
		}
		
		#For some reason the directory cannot be created, so go with the default
		if( -not (Test-Path $websitePath) ) {
			$PSScriptRootParentDirPath = Split-Path "$PSScriptRoot" -Parent
			$websitePath = "$PSScriptRootParentDirPath\Website"
		
			Write-Host "An error occurred when creating the desired website directory. The default directory ($websitePath) will be used"
		
			#Make the Website directory if it does not exist
			if(!(Test-Path -Path $websitePath )){
				New-Item -ItemType directory -Path $websitePath

			}
		}
	}
}

function Begin-Installation {	

	param(
		[Parameter(Mandatory=$true)]
		[object]$settings
	)

    Import-SitecoreInstallFramework

	#Coverts the password to plain text
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($settings.DbSAPassword)
    $DbSAPasswordAsPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

	#install sitecore instance
	$sitecoreParams = @{ 
		SitePhysicalPath = $settings.WebsitePath
		Path = "$PSScriptRoot\" + $settings.InstallationManifestFilePath 
		Package = "$PSScriptRoot\" + $settings.InstallationPackageFilePath
		LicenseFile = "$PSScriptRoot\" + $settings.SitecoreLicenseFilePath 
		SqlDbPrefix = $settings.WebsiteName 
		SqlServer = $settings.DbServer 
		SqlAdminUser = $settings.DbSAUsername 
		SqlAdminPassword = $DbSAPasswordAsPlainText
		Sitename = $settings.SitecoreWebsiteName
        SolrCorePrefix = $settings.WebsiteName
	} 

	Install-SitecoreConfiguration @sitecoreParams
}

function Add-Packages() {
	param(
		[Parameter(Mandatory=$true)]
		[object]$settings
	)
	
    $tempPackagesFolder = $settings.WebsitePath + "\temp\packages"  
	
	if(!(Test-Path -Path $tempPackagesFolder )){
		New-Item -ItemType directory -Path $tempPackagesFolder
	}
	
	$packageInstallerFileName = Split-Path -Path $settings.PackageInstallerPath -Leaf
	
    foreach($package in $settings.Packages) {
        # make querystring
        $query = (Split-Path -Path $package -Leaf)
         
        # Copy the package
        Write-Host "Copying package $query to Sitecore package folder..."
        Copy-Item $package $tempPackagesFolder -force
         
        Write-Host "Installing $query..."
     
        # call tool
        $websiteName = $settings.WebsiteName
        $sitecoreWebsiteName = $settings.SitecoreWebsiteName
        $url = "http://$sitecoreWebsiteName/" + $packageInstallerFileName + "?modules=$query"
        $result = Invoke-WebRequest -Uri $url -TimeoutSec 600 -OutFile ".\$websiteName-PackageResponse-$query.log" -PassThru
         
        if($result.StatusCode -ne 200) {
            Write-Host "StatusCode: $($result.StatusCode)"
            throw "Package install failed for $($query)"
        }
         
        # Removing installed package file
        $file = Join-Path $tempPackagesFolder $query
        Remove-Item $file -Force
    }
 
    write-host "Package installation done..."
}

function Get-ConfigParam([string] $name) {
    $val = Select-Xml "/configuration/params/param[@name='$name']/text()" $xml
     
    #if([string]::IsNullOrEmpty($val)) {
    #    throw "Parameter $name is missing from config"
    #}
     
    return [string]$val
}
 
function Get-ConfigPackages() {
    return Select-Xml "/configuration/packages/package/text()" $xml
}

Install