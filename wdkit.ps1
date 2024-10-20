Set-Location -Path $PSScriptRoot # Set initial location

$architecture = (Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture
$defaultConfig = ".\default.conf"
$global:PHPArchiveVersion = [System.Collections.ArrayList]::new()
$global:PHPReleaseVersion = [System.Collections.ArrayList]::new()
$global:MariaDbNetVersion = [System.Collections.ArrayList]::new()
$headers = @{ 
	'Accept-Language'='en-US,en;q=0.9,id;q=0.8'
	'DNT'='1'
	'Sec-Fetch-Dest'='document'
	'Sec-Fetch-Mode'='navigate'
	'Sec-Fetch-Site'='none'
	'Sec-Fetch-User'='?1'
	'Upgrade-Insecure-Requests'='1'
	'sec-ch-ua'='`\"Microsoft Edge`\";v=`\"129`\", `\"Not=A?Brand`\";v=`\"8`\", `\"Chromium`\";v=`\"129`\"'
	'sec-ch-ua-mobile'='?0'
	'sec-ch-ua-platform'='Windows' 
};

function WDKitPrepare {
	if(-not (Test-Path -Path $defaultConfig)) { New-Item -Path $defaultConfig | Out-Null }
	if(-not (Test-Path -Path "tmp")) { New-Item -ItemType Directory -Path "tmp" | Out-Null }
	if(-not (Test-Path -Path "php")) { New-Item -ItemType Directory -Path "php" | Out-Null }
	if(-not (Test-Path -Path "apache")) { New-Item -ItemType Directory -Path "apache" | Out-Null }
	if(-not (Test-Path -Path "mariadb")) { New-Item -ItemType Directory -Path "mariadb" | Out-Null }
	if(-not (Test-Path -Path "htdocs")) { 
		New-Item -ItemType Directory -Path "htdocs" | Out-Null
		"<html><head><title>WDKit</title></head><body><h1>It works</h1></body></html>" | Set-Content "htdocs/index.html"
		"<?php phpinfo(); ?>" | Set-Content "htdocs/info.php"
	}
}

function PauseProcess {
	Write-Host "Press any key to continue." -NoNewLine
	$_ = $host.ui.rawui.readkey("NoEcho,IncludeKeyDown").virtualkeycode
}

function PathResolve {
	Param(
		[string] $Path
	)
	$unresolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
	return $unresolved
}

function Asking {
	Param(
		[string] $Question = "Continue?",
		[string] $CancelledMessage = "Cancelled"
	)
	$continue = $false
	$continueQuestion = Read-Host "$Question (y/n)"
	if($continueQuestion.Length -gt 0) {
		if($continueQuestion.Substring(0,1).ToLower() -eq "y") { $continue = $true }
	}
	if($continue -ne $true) {
		Write-Host $CancelledMessage
	}
	return $continue
}

function DownloadFile {
	Param(
		[string] $Url,
		[string] $OutPath,
		[bool] $Ask = $false,
		[bool] $PrintDownloadStart = $false,
		[bool] $OutString = $false,
		[bool] $Force = $false
	)
	
	$OutPath = Join-Path -Path (Get-Location).Path -ChildPath $OutPath
	$dirpath = Split-Path -Path $OutPath
	$filename = Split-Path -Path $OutPath -Leaf
	if((Test-Path -Path $OutPath)) {
		if($Force) {
				Remove-Item -Recurse -Force -Path $OutPath
		} else {
			Write-Host "File already downloaded"
			return
		}
	}
	
	$parts = 1
	$part_size = 0
	$request = [System.Net.WebRequest]::Create($Url)
	$request.Method = "HEAD"
	$request.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0';
	$request.Accept = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7';
	foreach($h in $headers.GetEnumerator()) { 
		$request.Headers.Add($h.Name, $h.Value)
	}
	$response = $request.GetResponse()
	$response.Close()
	$fileSize = $response.Headers.Get("Content-Length")
	$acceptBytesRange = $response.Headers.Get('Accept-Ranges') -eq 'bytes'
	if($Ask) {
		$continue = Asking -Question "You need download $([math]::Round($fileSize/1000000, 2)) MiB. Continue?" -CancelledMessage "Download cancelled"
		if(-not $continue) { return }
	}
	
	if($acceptBytesRange) {
		$parts = [math]::Ceiling($fileSize / 1000000)
		if($parts -lt 1) { $parts = 1 }
	}
	if($PrintDownloadStart) { Write-Host "Downloading..." }
	
	if($parts -eq 1) {
		$request = [System.Net.WebRequest]::Create($Url)
		$request.Method = "GET"
		$request.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0';
		$request.Accept = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7';
		foreach($h in $headers.GetEnumerator()) { 
			$request.Headers.Add($h.Name, $h.Value)
		}
		$response = $request.GetResponse()
		$stream = $response.GetResponseStream()
		$fileStream = [System.IO.File]::Create($OutPath)
		$buffer = New-Object byte[] 8192
		while(($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
			$fileStream.Write($buffer, 0, $bytesRead)
		}
		$stream.Close()
		$fileStream.Close()
		$resultPath = PathResolve -Path $OutPath
		if($OutString) {
			$content = Get-Content -Path $resultPath | Out-String
			Remove-Item -Path $resultPath
			return $content
		} else {
			return $resultPath
		}
	}

	$partsDir = Join-Path -Path $dirpath -ChildPath ".$filename-part"
	if((Test-Path -Path $partsDir)) { Remove-Item -Recurse -Force -Path $partsDir }
	New-Item -ItemType Directory -Path $partsDir -Force | Set-ItemProperty -Name Attributes -Value ([System.IO.FileAttributes]::Hidden)
	$jobs = @()
	for($i = 0; $i -lt $parts; $i++) {
		$start = $i * 1000000
		$end = (($i + 1) * 1000000) - 1
		$partFile = Join-Path -Path $partsDir -ChildPath "part_$i"
		
		$jobs += Start-Job -ScriptBlock {
			Param(
				[string] $url,
				[string] $partFile,
				[int] $start,
				[int] $end
			)
			
			$request = [System.Net.WebRequest]::Create($Url)
			$request.Method = "GET"
			$request.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0';
			$request.Accept = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7';
			$request.AddRange('bytes', $start, $end)
			foreach($h in $headers.GetEnumerator()) { 
				$request.Headers.Add($h.Name, $h.Value)
			}
			$response = $request.GetResponse()
			$fileStream = [System.IO.File]::Create($partFile)
			$stream = $response.GetResponseStream()
			$buffer = New-Object byte[] 8192
			while(($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
				$fileStream.Write($buffer, 0, $bytesRead)
			}
			$stream.Close()
			$fileStream.Close()
		} -ArgumentList $url, $partFile, $start, $end
	}
	
	$jobs | ForEach-Object { $_ | Wait-Job | Out-Null }; # wait until jobs completed
	$output = [System.IO.File]::Create($OutPath)
	for($i = 0; $i -lt $parts; $i++) {
		$partFile = Join-Path -Path $partsDir -ChildPath "part_$i"
		$fileStream = [System.IO.File]::OpenRead($partFile)
		$buffer = New-Object byte[] 8192
		while(($bytesRead = $fileStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
			$output.Write($buffer, 0, $bytesRead)
		}
		$fileStream.Close()
	}
	$output.Close()
	Remove-Item -Recurse -Force -Path $partsDir
	$resultPath = PathResolve -Path $OutPath
	if($OutString) {
		$content = Get-Content -Path $resultPath | Out-String
		Remove-Item -Path $resultPath
		return $content
	} else {
		return $resultPath
	}
}

function Unzip {
	Param (
		[string] $zipFile,
		[string] $destDir,
		[bool] $removeAfterUnzip=$true
	)
	$absZip = Join-Path -Path (Get-Location).Path -ChildPath $zipFile
	$absDest = Join-Path -Path (Get-Location).Path -ChildPath $destDir
	if(-not (Test-Path -Path $absDest)) { New-Item -ItemType Directory -Path $absDest -Force | Out-Null }
	
	$absZip = PathResolve -Path $absZip
	$absDest = PathResolve -Path $absDest
	
	try {
		$shell = New-Object -ComObject shell.application;
		$zip = $shell.NameSpace($absZip);
		if ($zip -ne $null) { 
			foreach ($item in $zip.items()) {
				$shell.Namespace($absDest).CopyHere($item);
			}
			if($removeAfterUnzip) {
				Remove-Item -Force -Path $absZip
			}
		} else {
			Write-Host 'Error: Could not find zip file.'
		}
	} catch {
		if(Test-Path -Path $absDest) { Remove-Item -Force -Path $absDest }
	}
}

function defaultConfigGet {
	$defaultConfigPath = Join-Path -Path (Get-Location).Path -ChildPath $defaultConfig
	if(-not (Test-Path -Path $defaultConfigPath)) { New-Item -Force -Path $defaultConfigPath }
	$defaultConfigPath = PathResolve -Path $defaultConfigPath
	return (Get-Content $defaultConfigPath | Out-String)
}

function CreateMenu {
	Param (
		[string[]] $Menu,
		[string] $Title = "Menu",
		[string] $SubTitle = "",
		[string] $Question = "Choose an option",
		[int] $Index = 0,
		[bool] $Reprint = $true
	)
	
	if($Reprint) {
		Clear-Host
		if($Title.Length -gt 0) {
			$border = ""
			for($i = 0; $i -lt [Console]::WindowWidth; $i++) { $border += "=" }

			$space = ""
			$spaceLength = ([Console]::WindowWidth / 2) - $Title.Length
			if($spaceLength -lt 0) { $spaceLength = 0 }
			for($i = 0; $i -lt $spaceLength; $i++) { $space += " " }
			
			Write-Host $border
			Write-Host "$space$Title"
			Write-Host $border
		}
		if($SubTitle.Length -gt 0) { Write-Host $SubTitle }
		for($i = 0; $i -lt $Menu.Length; $i++) {
			$m = $Menu[$i]
			if($i -eq $Index) {
				Write-Host "[*] $m"
			} else {
				Write-Host "[ ] $m"
			}
		}
		Write-Host "$Question`: $($Menu[$Index])" -NoNewLine
	}
	
	$KeyInput = $host.ui.rawui.readkey("NoEcho,IncludeKeyDown").virtualkeycode
	$nextMenu = $Index
	
	if($KeyInput -eq 38) { # Up
		if($Index -gt 0) { $nextMenu = $Index - 1 }
		if($Index -eq 0) { $nextMenu = $Menu.Length - 1 }
	}
	if($KeyInput -eq 40) { # Down
		if($Index -lt $($Menu.Length - 1)) { $nextMenu = $Index + 1 }
		if($Index -eq $($Menu.Length - 1)) { $nextMenu = 0 }
	}
	if($KeyInput -eq 13) { # Enter
		Write-Host ""
		return $nextMenu + 1
	}
	if($Index -ne $nextMenu) { CreateMenu -Menu $Menu -Title $Title -SubTitle $SubTitle -Index $nextMenu -Question $Question } 
	else { CreateMenu -Menu $Menu -Title $Title -SubTitle $SubTitle -Index $nextMenu -Question $Question -Reprint $false }
}

function MainMenu {
	$option = CreateMenu -Menu ("PHP", "Apache", "MariaDB", "Exit") -Title "Main Menu"
	switch($option) {
		1 { PHPMenu }
		2 { ApacheMenu }
		3 { MariadbMenu }
		4 { 
			Clear-Host
			Exit 
		}
		Default { 
			Clear-Host
			Exit 
		}
	}
	MainMenu
}

function PHPMenu {
	$option = CreateMenu -Menu ("Download & Install", "List Version", "Set Default Version", "Uninstall", "Back to Main Menu") -Title "PHP Menu"
	switch($option) {
		1 { PHPDownloadAndInstall }
		2 { PHPGetVersion }
		3 { PHPSetDefaultVersion }
		4 { PHPUninstall }
		5 { return }
		Default { return }
	}
	PauseProcess
	PHPMenu
}

function PHPDownloadAndInstall {
	PHPGetVersion
	$allVersion = ($PHPArchiveVersion + $PHPReleaseVersion) | Sort-Object -Unique
	$localVersion = PHPGetLocalVersion
	$version = Read-Host "Choose PHP version to install"
	if($version.Length -lt 1) {
		Write-Host "Version can't be empty"
		return
	}
	Write-Host "Validating version..."
	$valid = $false
	foreach($ver in $allVersion) {
		if($ver -eq $version) { $valid = $true }
	}
	foreach($ver in $localVersion) {
		if($ver -eq $version) {
			Write-Host "PHP-$version already installed"
			return
		}
	}
	if(-not $valid) {
		Write-Host "Version is invalid"
		return
	}
	
	$isArchived = $true
	foreach($ver in $PHPReleaseVersion) {
		if($ver -eq $version) { $isArchived = $false }
	}
	$xArch = "x86"
	$urlDownload=
	if($architecture -eq "64-bit") { $xArch = "x64" }
	if($isArchived) {
		$phpVer = DownloadFile -Url "https://windows.php.net/downloads/releases/archives/" -OutPath ".\tmp\php_ver.html" -OutString $true
		$match = [regex]::matches($phpVer, "/downloads/releases/archives/php-$version-Win32-(vc|vs|VC|VS)\d+-$xArch.zip")
		if($xArch -eq "x64" -and $match.Groups.Length -eq 0) {
			$match = [regex]::matches($phpVer, "/downloads/releases/archives/php-$version-Win32-(vc|vs|VC|VS)\d+-x86.zip")
		}
		if($match.Groups.Length -eq 0) {
			Write-Host "Can't get PHP for $xArch"
			return
		}
		$urlDownload = $match.Value
	} else {
		$phpVer = DownloadFile -Url "https://windows.php.net/downloads/releases/" -OutPath ".\tmp\php_ver.html" -OutString $true
		$match = [regex]::matches($phpVer, "/downloads/releases/php-$version-Win32-(vc|vs|VC|VS)\d+-$xArch.zip")
		if($xArch -eq "x64" -and $match.Groups.Length -eq 0) {
			$match = [regex]::matches($phpVer, "/downloads/releases/php-$version-Win32-(vc|vs|VC|VS)\d+-x86.zip")
		}
		if($match.Groups.Length -eq 0) {
			Write-Host "Can't get PHP for $xArch"
			return
		}
		$urlDownload = $match.Value
	}
	$dpath = ".\tmp\php-$version.zip"
	if(-not (Test-Path -Path $dpath)) {
		$dpath = DownloadFile -Url "https://windows.php.net$urlDownload" -OutPath $dpath -Ask $true -PrintDownloadStart $true
	}
	if($dpath -eq $null) {
		Write-Host "Failed to download"
		return
	}
	if(-not (Test-Path -Path $dpath)) {
		Write-Host "Failed to download"
		return
	}
	
	Write-Host "Unziping..."
	Unzip -zipFile $dpath -destDir ".\php\php-$version"
	if(-not (Test-Path -Path ".\php\php-$version")) {
		Write-Host "Failed to install PHP $version"
		return
	}
	
	$iniDev = ".\php\php-$version\php.ini-development"
	if(-not (Test-Path -Path $iniDev)) {
		$iniDev = ".\php\php-$version\php.ini-recommended"
		if(-not (Test-Path -Path $iniDev)) {
			$iniDev = ""
		}
	}
	
	if($iniDev.Length -gt 0) {
		$phpPath = PathResolve -Path ".\php\php-$version"
		$iniContent = (Get-Content -Path $iniDev | Out-String)
		$iniContent = $iniContent -replace ";extension=", "extension=" 
		$iniContent = $iniContent -replace ';?extension_dir = "./"', "extension_dir = `"$phpPath\ext`""
		$iniContent = $iniContent -replace ";?extension=(php_)?exif(.*)", ';extension=$1exif$2' 
		$iniContent = $iniContent -replace ";?extension=(php_)?ifx(.*)", ';extension=$1ifx$2' 
		$iniContent = $iniContent -replace ";?extension=(php_)?sybase(.*)", ';extension=$1sybase$2' 
		$iniContent = $iniContent -replace ";?extension=(php_)?oci(.*)", ';extension=$1oci$2' 
		$iniContent = $iniContent -replace ";?extension=(php_)?pdo_firebird(.*)", ';extension=$1pdo_firebird$2' 
		$iniContent = $iniContent -replace ";?extension=(php_)?pdo_oci(.*)", ';extension=$1pdo_oci$2' 
		$iniContent = $iniContent -replace ";?extension=(php_)?snmp(.*)", ';extension=$1snmp$2' 
		
		$iniContent | Set-Content "$phpPath\php.ini"
	}
	
	Write-Host "Update default PHP version..."
	PHPSetDefaultVersion -Ask $false
	Write-Host "PHP $version installed"
}

function PHPIniSetup {
	Param(
		[string] $phpPath,
		[string] $iniContent
	)
	$match = [Regex]::Match($iniContent, '(;)?extension_dir = ".*"')
	if ($match.Success) {
		$iniContent = $iniContent.Substring(0, $match.Index) + "extension_dir = `"$phpPath\ext`"" + $iniContent.Substring($match.Index + $match.Length)
	}
	$iniContent = $iniContent -replace ";extension=", "extension=" 
	$iniContent = $iniContent -replace ";?extension=(php_)?exif(.*)", ';extension=$1exif$2' 
	$iniContent = $iniContent -replace ";?extension=(php_)?ifx(.*)", ';extension=$1ifx$2' 
	$iniContent = $iniContent -replace ";?extension=(php_)?sybase(.*)", ';extension=$1sybase$2' 
	$iniContent = $iniContent -replace ";?extension=(php_)?oci(.*)", ';extension=$1oci$2' 
	$iniContent = $iniContent -replace ";?extension=(php_)?pdo_firebird(.*)", ';extension=$1pdo_firebird$2' 
	$iniContent = $iniContent -replace ";?extension=(php_)?pdo_oci(.*)", ';extension=$1pdo_oci$2' 
	$iniContent = $iniContent -replace ";?extension=(php_)?snmp(.*)", ';extension=$1snmp$2' 
	return $iniContent
}

function PHPGetNetVersion {
	if($PHPArchiveVersion.Count -lt 1) {
		$archivesHtml = DownloadFile -Url "https://windows.php.net/downloads/releases/archives/" -OutPath ".\tmp\php_ver.html" -OutString $true -Force $true
		$matchArchiveDownload = [regex]::matches($archivesHtml, "/downloads/releases/archives/php-([0-9\.]+)-Win32-(vc|vs|VC|VS)\d+-x(86|64).zip")
		foreach($m in $matchArchiveDownload) { $global:PHPArchiveVersion.Add($m.Groups[1].Value) | Out-Null }
	}
	if($PHPReleaseVersion.Count -lt 1) {
		$releasesHtml = DownloadFile -Url "https://windows.php.net/downloads/releases/" -OutPath ".\tmp\php_ver.html" -OutString $true -Force $true
		$matchReleaseDownload = [regex]::matches($releasesHtml, "/downloads/releases/php-([0-9\.]+)-Win32-(vc|vs|VC|VS)\d+-x(86|64).zip")
		foreach($m in $matchReleaseDownload) { $global:PHPReleaseVersion.Add($m.Groups[1].Value) | Out-Null }
	}
}

function PHPGetLocalVersion {
	$content = Get-ChildItem -Path '.\php' -Directory | Out-String
	$matches = [regex]::matches($content, 'php-([0-9\.]+)')
	$versions = [System.Collections.ArrayList]::new()
	foreach($match in $matches) {$versions.Add($match.Groups[1].Value) | Out-Null}
	return $versions
}

function PHPGetVersion {
	Write-Host "Fetching PHP version..."
	PHPGetNetVersion
	$localVersion = PHPGetLocalVersion
	$allVersion = ($PHPArchiveVersion + $PHPReleaseVersion) | Sort-Object -Unique
	foreach($ver in $allVersion) {
		$installed = $false
		foreach($lver in $localVersion) {
			if($lver -eq $ver) { $installed = $true }
		}
		if(-not $installed) { Write-Host $ver }
	}
	foreach($ver in $localVersion) {
		Write-Host "$ver [INSTALLED]"
	}
}

function PHPGetDefaultVersion {
	$defaultConfigContent = defaultConfigGet
	$match = [regex]::matches($defaultConfigContent, "php=([0-9\.]+)?")
	if($match.Groups.Length -lt 2) { return "" }
	$version = $match.Groups[1].Value
	if($version -eq "") { return "0" }
	else { return $version }
}

function PHPSetDefaultVersion {
	Param(
		[bool] $Ask = $true
	)

	$localVersion = [System.Collections.ArrayList]::new()
	$_localVersion = PHPGetLocalVersion
	foreach($v in $_localVersion) { $localVersion.Add($v) | Out-Null }
	$defaultVersion = PHPGetDefaultVersion
	$defaultConfigPath = Join-Path -Path (Get-Location).Path -ChildPath $defaultConfig
	if($defaultVersion -eq  "") {
		"$(Get-Content -Path $defaultConfigPath | Out-String)`nphp=" | Set-Content $defaultConfigPath
		$defaultVersion = PHPGetDefaultVersion
	}
	$version = $defaultVersion
	
	if($localVersion.Count -lt 1) {
		Write-Host "PHP is not installed"
		PHPGenerateBin
		ApacheHttpdConfSetup
		return
	}
	
	if($Ask) {
		foreach($ver in $localVersion) {
			if($ver -eq $defaultVersion) {
				Write-Host "$ver [DEFAULT]"
			} else {
				Write-Host "$ver"
			}
		}
		$version = (Read-Host "Set PHP version for default") -replace " ", "" -replace "/",""
		if($version.Length -lt 1) {
			Write-Host "Version can't be empty"
			return
		}
	}
	
	if($version -eq "0") {
		$version = $localVersion[$localVersion.Count -1]
	}
	if(-not (Test-Path -Path ".\php\php-$version")) {
		Write-Host "PHP $version is not installed"
		return
	}
	$updatedConfig = (Get-Content -Path $defaultConfigPath | Out-String) -replace "php=([0-9\.]+)?","php=$version"
	$updatedConfig.trim() | Set-Content $defaultConfigPath
	Write-Host "PHP default version updated to $version"
	
	$phpPath = PathResolve -Path ".\php\php-$version"
	$iniContent = (Get-Content -Path "$phpPath\php.ini" | Out-String)
	$iniContent = PHPIniSetup -phpPath $phpPath -iniContent $iniContent
	$iniContent | Set-Content "$phpPath\php.ini"
	ApacheHttpdConfSetup
	PHPGenerateBin
}

function PHPGenerateBin {
	$version = PHPGetDefaultVersion
	$binPath = Join-Path -Path (Get-Location).Path -ChildPath ".\php\bin"

	if(Test-Path -Path $binPath) { Remove-Item -Recurse -Force -Path $binPath }
	if($version -eq "0") {
		Write-Host "PHP bin removed"
		return
	}
	
	Write-Host "Generating bin directory for PHP..."
	New-Item -ItemType Directory -Path $binPath | Out-Null
	
	$phpPath = Join-Path -Path (Get-Location).Path -ChildPath ".\php\php-$version"
	$executable = Get-ChildItem -Path $phpPath | Where-Object { $_.Name -match '^.+\.(exe|bat)$' }
	$apps = @();
	foreach($c in $executable) { $apps += $executable.Name }
	foreach($c in $apps) {
		$match = [regex]::matches($c, "^(.*)\.(exe|bat)")
		$name = $match.Groups[1].Value
		$bin = Join-Path -Path (Get-Location).Path -ChildPath ".\php\bin\$name`.bat"
		$src = PathResolve -Path (Join-Path -Path (Get-Location).Path -ChildPath ".\php\php-$version\$c")
		"@echo off`n$src %*" | Set-Content $bin
	}
	Write-Host "Done"
}

function PHPUninstall {
	$localVersion = PHPGetLocalVersion
	if($localVersion.Length -lt 1) {
		Write-Host "PHP is not installed"
		return
	}
	
	foreach($ver in $localVersion) { Write-Host "$ver" }
	$version = (Read-Host "Set PHP version to uninstall") -replace " ", "" -replace "/",""
	if($version.Length -lt 1) {
		Write-Host "Version can't be empty"
		return
	}
	if(-not (Test-Path -Path ".\php\php-$version")) {
		Write-Host "PHP $version is not installed"
		return
	}
	$uninstall = Asking -Question "Are you sure want uninstall PHP $version`?" -CancelledMessage "Uninstall cancelled"
	if(-not $uninstall) { return }
	
	Remove-Item -Recurse -Force -Path ".\php\php-$version"
	$defaultConfigPath = Join-Path -Path (Get-Location).Path -ChildPath $defaultConfig
	$updatedConfig = (Get-Content -Path $defaultConfigPath | Out-String) -replace "php=$version","php="
	$updatedConfig.trim() | Set-Content $defaultConfigPath
	PHPSetDefaultVersion -Ask $false
}

function ApacheMenu {
	$option = CreateMenu -Menu ("Download & Install", "Start", "Restart", "Stop", "Uninstall", "Back to Main Menu") -Title "Apache Menu" -SubTitle "Status: $(ApacheStatus)"
	switch($option) {
		1 { ApacheDownloadAndInstall }
		2 { ApacheStart }
		3 { ApacheRestart }
		4 { ApacheStop }
		5 { ApacheUninstall }
		6 { return }
		Default { return }
	}
	PauseProcess
	ApacheMenu
}

function ApacheStatus {
	$currentProcess = (tasklist | findstr /i httpd | Select-Object -First 1)
	if($currentProcess.Length -lt 1) { return "Stopped" }
	else { return "Started" }
}

function ApacheHttpdConfSetup {
	$htdocsPath = Join-Path -Path (Get-Location).Path -ChildPath ".\htdocs"
	$apachePath = Join-Path -Path (Get-Location).Path -ChildPath ".\apache"
	$httpdConfPath = Join-Path -Path (Get-Location).Path -ChildPath ".\apache\conf\httpd.conf"
	if(-not (Test-Path -Path $httpdConfPath)) { return }
	$content = Get-Content -Path $httpdConfPath | Out-String
	if($content.indexOf("AddHandler application/x-httpd-php .php .phar") -lt 0) {
		$content = $content -replace "<IfModule mime_module>", "<IfModule mime_module>`n    AddHandler application/x-httpd-php .php .phar"
	}
	if($content.indexOf("PHPIniDir") -lt 0) {
		$content = $content -replace "LoadModule actions_module modules/mod_actions.so", "#LoadModule php_module `"`"`n#PHPIniDir `"`"`nLoadModule actions_module modules/mod_actions.so"
	}
	$content = $content -replace 'Define SRVROOT ".*"', "Define SRVROOT `"$(PathResolve -Path $apachePath)`""
	$content = $content -replace '#?ServerName www.example.com:80', 'ServerName localhost:80'
	$content = $content -replace "`".*htdocs`"", "`"$(PathResolve -Path $htdocsPath)`""
	$content = $content -replace "DirectoryIndex index.html", "DirectoryIndex index.php index.html index.htm"
	
	$PHPVersion = PHPGetDefaultVersion
	if(($PHPVersion.Length -lt 1) -or ($PHPVersion -eq "0")) {
		$content = $content -replace "#?LoadModule php\d?_module `".*`"", "#LoadModule php_module `"`""
		$content = $content -replace "#?PHPIniDir `".*`"", "#PHPIniDir `"`""
	} else {
		$PHPPath = PathResolve -Path (Join-Path -Path (Get-Location).Path -ChildPath ".\php\php-$PHPVersion")
		$dll = (Get-ChildItem -Path $PHPPath -Filter "*apache*.dll" | Select-Object -First 1).Name
		$mod = ""
		if($PHPVersion.Substring(0, 1) -lt 8) { $mod = $PHPVersion.Substring(0, 1) }
		$content = $content -replace "#?LoadModule php\d?_module `".*`"", "LoadModule php$mod`_module `"$phpPath\$dll`""
		$content = $content -replace "#?PHPIniDir `".*`"", "PHPIniDir `"$phpPath`""
	}
	$content | Set-Content $httpdConfPath
}

function ApacheDownloadAndInstall {
	$httpdPath = Join-Path -Path (Get-Location).Path -ChildPath ".\apache\bin\httpd.exe"
	if(Test-Path -Path $httpdPath) {
		Write-Host "Apache already installed"
		return
	}
	
	$downloadPage = DownloadFile -Url "https://www.apachelounge.com/download/" -OutPath ".\tmp\apache.html" -OutString $true -Force $true
	$match = [regex]::matches($downloadPage, "Apache ([0-9\.]+) .+ Windows Binaries and Modules")
	$apacheVersion = "Apache"
	if($match.Groups.Count -gt 1) {
		$ver = $match.Groups[1].Value -replace "\.",""
		$apacheVersion += $ver
	}
	
	$downloads = [System.Collections.ArrayList]::new()
	$matchDownloads = [regex]::matches($downloadPage, '"(/download/.+/binaries/httpd-.+-win(32|64)-.+\.zip)"')
	foreach($d in $matchDownloads) { $downloads.Add("https://www.apachelounge.com$($d.Groups[1].Value)") | Out-Null }
	$xArch = "32"
	$urlDownload=
	if($architecture -eq "64-bit") { $xArch = "64" }

	$urls = [System.Collections.ArrayList]::new()
	
	foreach($d in $downloads) {
		$match = [regex]::matches($d, ".+-win$xArch-.+.zip")
		if($match.Count -gt 0) { $urls.Add($d) | Out-Null }
	}

	if($urls.Count -lt 1) {
		Write-Host "Can't get Apache for Win$xArch"
		return
	} else {
		$urlDownload = $urls[0]
	}
	
	$dpath = ".\tmp\apache.zip"
	if(-not (Test-Path -Path $dpath)) {
		$dpath = DownloadFile -Url $urlDownload -OutPath $dpath -Ask $true -PrintDownloadStart $true
	}
	if($dpath -eq $null) {
		Write-Host "Failed to download"
		return
	}
	if(-not (Test-Path -Path $dpath)) {
		Write-Host "Failed to download"
		return
	}
	
	Write-Host "Unziping..."
	Unzip -zipFile "$dpath\$apacheVersion" -destDir ".\apache" -removeAfterUnzip $false
	if(-not (Test-Path -Path ".\apache\bin\httpd.exe")) {
		Write-Host "Failed to install Apache"
		return
	}
	if(Test-Path -Path $dpath) { Remove-Item -Force $dpath }
	ApacheHttpdConfSetup
	Write-Host "Apache installed";
}

function ApacheStart {
	$httpdPath = Join-Path -Path (Get-Location).Path -ChildPath ".\apache\bin\httpd.exe"
	if(-not (Test-Path -Path $httpdPath)) {
		Write-Host "Apache not installed"
		return
	}
	$httpdPath = PathResolve -Path $httpdPath
	
	$currentProcess = (tasklist | findstr /i httpd | Select-Object -First 1)
	if($currentProcess.Length -gt 0) {
		Write-Host "Apache already started"
		return
	}
	Start-Process -FilePath $httpdPath -WindowStyle Hidden | Out-Null
	Write-Host "Apache started"
}

function ApacheRestart {
	$httpdPath = Join-Path -Path (Get-Location).Path -ChildPath ".\apache\bin\httpd.exe"
	$httpdPidPath = Join-Path -Path (Get-Location).Path -ChildPath ".\apache\logs\httpd.pid"
	if(-not (Test-Path -Path $httpdPath)) {
		Write-Host "Apache not installed"
		return
	}
	if(-not (Test-Path -Path $httpdPidPath)) { $httpdPidPath = "" }
	else { $httpdPidPath = PathResolve -Path $httpdPidPath }
	$httpdPath = PathResolve -Path $httpdPath
	
	$currentProcess = (tasklist | findstr /i httpd | Select-Object -First 1)
	if($currentProcess.Length -gt 0) {
		Stop-Process -Id (Get-Process -Name httpd).Id -Force | Out-Null
		if($httpdPidPath.Length -gt 0) {
			Remove-Item -Force -Path $httpdPidPath
		}
	}
	Start-Process -FilePath $httpdPath -WindowStyle Hidden | Out-Null
	Write-Host "Apache re-started"
}

function ApacheStop {
	$httpdPath = Join-Path -Path (Get-Location).Path -ChildPath ".\apache\bin\httpd.exe"
	$httpdPidPath = Join-Path -Path (Get-Location).Path -ChildPath ".\apache\logs\httpd.pid"
	if(-not (Test-Path -Path $httpdPath)) {
		Write-Host "Apache not installed"
		return
	}
	if(-not (Test-Path -Path $httpdPidPath)) { $httpdPidPath = "" }
	else { $httpdPidPath = PathResolve -Path $httpdPidPath }
	
	$currentProcess = (tasklist | findstr /i httpd | Select-Object -First 1)
	if($currentProcess.Length -lt 1) {
		Write-Host "Apache not started"
		return
	}
	Stop-Process -Id (Get-Process -Name httpd).Id -Force | Out-Null
	if($httpdPidPath.Length -gt 0) { Remove-Item -Force -Path $httpdPidPath }
	Write-Host "Apache stopped"
}

function ApacheUninstall {
	$uninstall = Asking -Question "Are you sure want uninstall Apache?" -CancelledMessage "Uninstall cancelled"
	if(-not $uninstall) { return }
	$apachePath = Join-Path -Path (Get-Location).Path -ChildPath ".\apache"
	$httpdPath = Join-Path -Path (Get-Location).Path -ChildPath ".\apache\bin\httpd.exe"
	if(-not (Test-Path -Path $httpdPath)) {
		Write-Host "Apache not installed"
		return
	}
	
	$currentProcess = (tasklist | findstr /i httpd | Select-Object -First 1)
	if($currentProcess.Length -gt 0) {
		Stop-Process -Id (Get-Process -Name httpd).Id -Force | Out-Null
	}
	
	if(Test-Path -Path $apachePath) { Remove-Item -Recurse -Force -Path $apachePath }
	New-Item -ItemType Directory -Force -Path $apachePath | Out-Null
	Write-Host "Apache uninstalled"
}

function MariadbMenu {
	$option = CreateMenu -Menu ("Download & Install", "List Version", "Set Default Version", "Start", "Restart", "Stop", "Uninstall", "Back to Main Menu") -Title "MariaDB Menu" -SubTitle "Status: $(MariadbStatus)"
	switch($option) {
		1 { MariadbDownloadAndInstall }
		2 { MariadbGetVersion }
		3 { MariadbSetDefaultVersion }
		4 { MariadbStart }
		5 { MariadbRestart }
		6 { MariadbStop }
		7 { MariadbUninstall }
		8 { return }
		Default { return }
	}
	PauseProcess
	MariadbMenu
}

function MariadbStatus {
	$currentProcess = (tasklist | findstr /i mysqld | Select-Object -First 1)
	if($currentProcess.Length -lt 1) { return "Stopped" }
	else { return "Started" }
}

function MariadbDownloadAndInstall {
	MariadbGetVersion
	$version = Read-Host "Choose MariaDB version to install"
	if($version.Length -lt 1) {
		Write-Host "Version can't be empty"
		return
	}
	Write-Host "Validating version..."
	$valid = $false
	foreach($ver in $MariaDbNetVersion) {
		if($ver -eq $version) { $valid = $true }
	}
	foreach($ver in $localVersion) {
		if($ver -eq $version) {
			Write-Host "MariaDB $version already installed"
			return
		}
	}
	if(-not $valid) {
		Write-Host "Version is invalid"
		return
	}
	
	$mirrorJsonPath = DownloadFile -Url "https://downloads.mariadb.org/rest-api/mariadb/$version/downloads-form/" -OutPath ".\tmp\mirror.json" -Force $true
	if($mirrorJsonPath -eq $null) {
		Write-Host "Failed get version info"
		return
	}
	$mirrorJson = Get-Content -Path $mirrorJsonPath -Raw
	Remove-Item -Path $mirrorJsonPath -Force
	$jsonData = ConvertFrom-Json -InputObject $mirrorJson
	$files = $jsonData.release_data.files
	if($files.Count -lt 1) {
		Write-Host "Can't get files from remote repository"
		return
	}
	$fileMirrors = $files[0].mirrors
	$closestMirrors = $jsonData.release_data.closest_mirrors
	$availableMirrors = [System.Collections.ArrayList]::new()
	$matchedMirrors = [System.Collections.ArrayList]::new()
	foreach($fm in $fileMirrors) {
		foreach($prop in $fm.PSObject.Properties) {
			foreach($child in $prop.Value.children) {
				$availableMirrors.Add($child.mirror_url) | Out-Null
			}
		}
	}
	foreach($cm in $closestMirrors) {
		$match = $availableMirrors | Where-Object { $_ -eq $cm.mirror_url }
		if ($match) { $matchedMirrors.Add($cm.mirror_url) | Out-Null }
	}
	if($matchedMirrors.Count -lt 1) {
		Write-Host "Failed getting mirror"
		return
	}
	$mirror = $matchedMirrors[0]
	$xArch = "x86"
	$filePath=
	if($architecture -eq "64-bit") { $xArch = "x86_64" }
	foreach($file in $files) {
		if($file.os_code -eq 'windows' -and $file.package_type_code -eq 'zip' -and $file.cpu -eq $xArch) {
			$matches = [regex]::matches($file.file_name, 'win(.+)\.zip')
			$m = $matches.Groups[1]
			if(($m -replace '-','') -eq $m) {
				$filePath = $file.full_path
			}
		}
	}
	
	$dname = ""
	$matches = [regex]::matches($filePath, "(mariadb-$version-.+)\.zip$")
	if($matches.Groups.Count -gt 0) { $dname = $matches.Groups[1].Value }
	
	$dpath = ".\tmp\mariadb-$version.zip"
	if(-not (Test-Path -Path $dpath)) {
		$dpath = DownloadFile -Url "$mirror$filePath" -OutPath $dpath -Ask $true -PrintDownloadStart $true
	}
	if($dpath -eq $null) {
		Write-Host "Failed to download"
		return
	}
	if(-not (Test-Path -Path $dpath)) {
		Write-Host "Failed to download"
		return
	}
	
	Write-Host "Unziping..."
	Unzip -zipFile "$dpath\$dname" -destDir ".\mariadb\mariadb-$version" -removeAfterUnzip $false
	if(-not (Test-Path -Path ".\mariadb\mariadb-$version")) {
		Write-Host "Failed to install MariaDB $version"
		return
	}
	if(Test-Path -Path $dpath) { Remove-Item -Force $dpath }
	
	Write-Host "Update default MariaDB version..."
	MariadbSetDefaultVersion -Ask $false
	if(-not (Test-Path -Path ".\mariadb\mariadb-$version\data")) {
		$installDBPath = Join-Path -Path (Get-Location).Path -ChildPath ".\mariadb\mariadb-$version\bin\mysql_install_db.exe"
		$installDBPath = PathResolve -Path $installDBPath
		if(Test-Path -Path $installDBPath) {
			Start-Process -File $installDBPath -WindowStyle Minimize | Out-Null
		}
	}
	if((-not (Test-Path -Path ".\mariadb\mariadb-$version\backup")) -and (Test-Path -Path ".\mariadb\mariadb-$version\data")) {
		Copy-Item -Path ".\mariadb\mariadb-$version\data" -Destination ".\mariadb\mariadb-$version\backup" -Recurse -Force | Out-Null
	}
	Write-Host "MariaDB $version  installed"
}

function MariadbGetNetVersion {
	if($MariaDbNetVersion.Count -lt 1) {
		$versionJson = DownloadFile -Url "https://downloads.mariadb.org/rest-api/mariadb/all-releases/?olderReleases=true" -OutPath ".\tmp\mariadb.json" -OutString $true -Force $true
		$matches = [regex]::matches($versionJson, "`"release_number`": `"([0-9\.]+)`"")
		$versions = [System.Collections.ArrayList]::new()
		foreach($m in $matches) { $versions.Add($m.Groups[1].Value) | Out-Null }
		$global:MariaDbNetVersion = $versions | Sort-Object -Property {[version]$_.Trim()} -Unique
	}
}

function MariadbGetLocalVersion {
	$content = Get-ChildItem -Path '.\mariadb' -Directory | Out-String
	$matches = [regex]::matches($content, 'mariadb-([0-9\.]+)')
	$versions = [System.Collections.ArrayList]::new()
	foreach($match in $matches) {$versions.Add($match.Groups[1].Value) | Out-Null}
	return $versions
}

function MariadbGetVersion {
	Write-Host "Fetching MariaDB version..."
	MariadbGetNetVersion
	$localVersion = MariadbGetLocalVersion
	foreach($ver in $MariaDbNetVersion) {
		$installed = $false
		foreach($lver in $localVersion) {
			if($lver -eq $ver) { $installed = $true }
		}
		if(-not $installed) { Write-Host $ver }
	}
	foreach($ver in $localVersion) {
		Write-Host "$ver [INSTALLED]"
	}
}

function MariadbGetDefaultVersion {
	$defaultConfigContent = defaultConfigGet
	$match = [regex]::matches($defaultConfigContent, "mariadb=([0-9\.]+)?")
	if($match.Groups.Length -lt 2) { return "" }
	$version = $match.Groups[1].Value
	if($version -eq "") { return "0" }
	else { return $version }
}

function MariadbSetDefaultVersion {
	Param(
		[bool] $Ask = $true
	)

	$localVersion = [System.Collections.ArrayList]::new()
	$_localVersion = MariadbGetLocalVersion
	foreach($v in $_localVersion) { $localVersion.Add($v) | Out-Null }
	$defaultVersion = MariadbGetDefaultVersion
	$defaultConfigPath = Join-Path -Path (Get-Location).Path -ChildPath $defaultConfig
	if($defaultVersion -eq  "") {
		"$(Get-Content -Path $defaultConfigPath | Out-String)`nmariadb=" | Set-Content $defaultConfigPath
		$defaultVersion = MariadbGetDefaultVersion
	}
	$version = $defaultVersion
	
	if($localVersion.Count -lt 1) {
		MariadbGenerateBin
		Write-Host "MariaDB is not installed"
		return
	}
	
	if($Ask) {
		foreach($ver in $localVersion) {
			if($ver -eq $defaultVersion) {
				Write-Host "$ver [DEFAULT]"
			} else {
				Write-Host "$ver"
			}
		}
		$version = (Read-Host "Set MariaDB version for default") -replace " ", "" -replace "/",""
		if($version.Length -lt 1) {
			Write-Host "Version can't be empty"
			return
		}
	}
	
	if($version -eq "0") {
		$version = $localVersion[$localVersion.Count -1]
	}
	if(-not (Test-Path -Path ".\mariadb\mariadb-$version")) {
		Write-Host "MariaDB $version is not installed"
		return
	}
	$updatedConfig = (Get-Content -Path $defaultConfigPath | Out-String) -replace "mariadb=([0-9\.]+)?","mariadb=$version"
	$updatedConfig.trim() | Set-Content $defaultConfigPath
	Write-Host "MariaDB default version updated to $version"
	MariadbGenerateBin
}

function MariadbGenerateBin {
	$version = MariadbGetDefaultVersion
	$binPath = Join-Path -Path (Get-Location).Path -ChildPath ".\mariadb\bin"

	if(Test-Path -Path $binPath) { Remove-Item -Recurse -Force -Path $binPath }
	if($version -eq "0") {
		Write-Host "MariaDB bin removed"
		return
	}
	
	Write-Host "Generating bin directory for MariaDB..."
	New-Item -ItemType Directory -Path $binPath | Out-Null
	
	$mariadbPath = Join-Path -Path (Get-Location).Path -ChildPath ".\mariadb\mariadb-$version\bin"
	$executable = Get-ChildItem -Path $mariadbPath | Where-Object { $_.Name -match '^.+\.(exe|bat)$' }
	$apps = @();
	foreach($c in $executable) { $apps += $executable.Name }
	foreach($c in $apps) {
		$match = [regex]::matches($c, "^(.*)\.(exe|bat)")
		$name = $match.Groups[1].Value
		$bin = Join-Path -Path (Get-Location).Path -ChildPath ".\mariadb\bin\$name`.bat"
		$src = PathResolve -Path (Join-Path -Path (Get-Location).Path -ChildPath ".\mariadb\mariadb-$version\bin\$c")
		"@echo off`n$src %*" | Set-Content $bin
	}
	Write-Host "Done"
}

function MariadbStart {
	$localVersion = MariadbGetLocalVersion
	if($localVersion.Count -lt 1) {
		Write-Host "MariaDB not installed"
		return
	}
	
	$defaultVersion = MariadbGetDefaultVersion
	if(($defaultVersion -eq "0") -or ($defaultVersion.Length -lt 1)) {
		Write-Host "MariaDB default version not setted"
		return
	}
	
	$mysqld = PathResolve (Join-Path -Path (Get-Location).Path -ChildPath ".\mariadb\bin\mysqld")
	if(Test-Path -Path $mysqld) {
		Write-Host "mysqld not found"
		return
	}
	
	$currentProcess = (tasklist | findstr /i mysqld | Select-Object -First 1)
	if($currentProcess.Length -gt 0) {
		Write-Host "MariaDB already started"
		return
	}
	Start-Process -FilePath $mysqld -WindowStyle Hidden | Out-Null
	Write-Host "MariaDB started"
}

function MariadbRestart {
	$localVersion = MariadbGetLocalVersion
	if($localVersion.Count -lt 1) {
		Write-Host "MariaDB not installed"
		return
	}
	
	$defaultVersion = MariadbGetDefaultVersion
	if(($defaultVersion -eq "0") -or ($defaultVersion.Length -lt 1)) {
		Write-Host "MariaDB default version not setted"
		return
	}
	
	$mysqld = PathResolve (Join-Path -Path (Get-Location).Path -ChildPath ".\mariadb\bin\mysqld")
	if(Test-Path -Path $mysqld) {
		Write-Host "mysqld not found"
		return
	}
	
	$currentProcess = (tasklist | findstr /i mysqld | Select-Object -First 1)
	if($currentProcess.Length -gt 0) {
		Stop-Process -Id (Get-Process -Name mysqld).Id -Force | Out-Null
	}
	Start-Process -FilePath $mysqld -WindowStyle Hidden | Out-Null
	Write-Host "MariaDB re-started"
}

function MariadbStop {
	$localVersion = MariadbGetLocalVersion
	if($localVersion.Count -lt 1) {
		Write-Host "MariaDB not installed"
		return
	}
	
	$defaultVersion = MariadbGetDefaultVersion
	if(($defaultVersion -eq "0") -or ($defaultVersion.Length -lt 1)) {
		Write-Host "MariaDB default version not setted"
		return
	}
	
	$mysqld = PathResolve (Join-Path -Path (Get-Location).Path -ChildPath ".\mariadb\bin\mysqld")
	if(Test-Path -Path $mysqld) {
		Write-Host "mysqld not found"
		return
	}
	
	$currentProcess = (tasklist | findstr /i mysqld | Select-Object -First 1)
	if($currentProcess.Length -lt 1) {
		Write-Host "MariaDB not started"
		return
	}
	
	Stop-Process -Id (Get-Process -Name mysqld).Id -Force | Out-Null
	Write-Host "MariaDB stopped"
}

function MariadbUninstall {
	$localVersion = MariadbGetLocalVersion
	if($localVersion.Length -lt 1) {
		Write-Host "MariaDB is not installed"
		return
	}
	
	foreach($ver in $localVersion) { Write-Host "$ver" }
	$version = (Read-Host "Set MariaDB version to uninstall") -replace " ", "" -replace "/",""
	if($version.Length -lt 1) {
		Write-Host "Version can't be empty"
		return
	}
	if(-not (Test-Path -Path ".\mariadb\mariadb-$version")) {
		Write-Host "MariaDB $version is not installed"
		return
	}
	$uninstall = Asking -Question "Are you sure want uninstall MariaDB $version`?" -CancelledMessage "Uninstall cancelled"
	if(-not $uninstall) { return }
	
	$currentProcess = (tasklist | findstr /i mysqld | Select-Object -First 1)
	if($currentProcess.Length -gt 0) {
		Stop-Process -Id (Get-Process -Name mysqld).Id -Force | Out-Null
	}
	
	Remove-Item -Recurse -Force -Path ".\mariadb\mariadb-$version"
	$defaultConfigPath = Join-Path -Path (Get-Location).Path -ChildPath $defaultConfig
	$updatedConfig = (Get-Content -Path $defaultConfigPath | Out-String) -replace "mariadb=$version","php="
	$updatedConfig.trim() | Set-Content $defaultConfigPath
	MariadbSetDefaultVersion -Ask $false
}

WDKitPrepare
MainMenu