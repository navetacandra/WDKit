@echo off
SETLOCAL EnableDelayedExpansion
SET userAgent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.3
SET php_net_archive_versions_count=0
SET php_net_release_versions_count=0
SET php_local_versions_count=0
SET php_net_versions_count=0
SET php_net_release_versions=
SET php_net_archive_versions=
SET php_local_versions=
SET php_net_versions=
SET mariadb_local_versions_count=0
SET mariadb_net_versions_count=0
SET mariadb_local_versions=
SET mariadb_net_versions=
CD /d "%~dp0"

GOTO prepare_directory

:print_menu_header
SET title=%1
FOR /f "tokens=2" %%a IN ('mode con ^| findstr /c:"Columns:"') DO SET "width=%%a"
SET "length=0"
FOR /l %%a IN (1,1,100) DO (
    IF "!title:~%%a,1!"=="" (
        SET /a "length=%%a-2"
        GOTO break
    )
)
:break
SET /a "center=(width / 2) - ((length-2) / 2)"
SET border=
FOR /L %%i IN (1,1,!width!) DO (
	SET border=!border!=
)
SET space=
FOR /L %%i IN (1,1,!center!) DO (
	SET space=!space! 
)

ECHO !border!
ECHO !space!!title:~1,%length%!
ECHO !border!
EXIT /b

:main_menu
CLS
CALL :print_menu_header "MAIN MENU"
ECHO 1. PHP
ECHO 2. Apache
ECHO 3. MySQL/MariaDB
ECHO 4. Exit
CHOICE /C 1234 /M "Pilih menu"
IF ERRORLEVEL 4 GOTO exit
IF ERRORLEVEL 3 GOTO mariadb_menu
IF ERRORLEVEL 2 GOTO apache_menu
IF ERRORLEVEL 1 GOTO php_menu

:prepare_directory
IF NOT EXIST ".\\default.conf" (COPY NUL ".\\default.conf")
IF NOT EXIST ".\\tmp\\" (MKDIR ".\\tmp\\")
IF NOT EXIST ".\\php\\" (
	MKDIR ".\\php\\"
) ELSE (
	CALL :php_get_local_versions
	IF !php_local_versions_count! GTR 0 AND NOT EXIST ".\\php\\bin" (
		MKDIR ".\\php\\bin"
	)
)
IF NOT EXIST ".\\apache\\" (
	MKDIR ".\\apache\\"
)
IF NOT EXIST ".\\htdocs\\" (
	MKDIR ".\\htdocs\\"
	POWERSHELL -Command "Write-Output '<html><body><h1>It works!</h1></body></html>' | Set-Content .\\htdocs\\index.html"
)
IF NOT EXIST ".\\mariadb\\" (MKDIR ".\\mariadb\\")
IF NOT EXIST ".\\postgres\\" (MKDIR ".\\postgres\\")
GOTO main_menu

:download_file
setlocal
set "url=%1"
set "filepath=%~f2"
powershell -Command ^
    "$url = '!url!'; $filepath='!filepath!';" ^
    "$dname=(Split-Path -Path $filepath);" ^
    "$fname=(Split-Path -Path $filepath -Leaf);" ^
    "$tempdir = \"$dname\$fname-parts\";" ^
    "$headers = @{ 'Accept-Language'='en-US,en;q=0.9,id;q=0.8'; 'DNT'='1'; 'Sec-Fetch-Dest'='document'; 'Sec-Fetch-Mode'='navigate'; 'Sec-Fetch-Site'='none'; 'Sec-Fetch-User'='?1'; 'Upgrade-Insecure-Requests'='1'; 'sec-ch-ua'='`\"Microsoft Edge`\";v=`\"129`\", `\"Not=A?Brand`\";v=`\"8`\", `\"Chromium`\";v=`\"129`\"'; 'sec-ch-ua-mobile'='?0'; 'sec-ch-ua-platform'='Windows' };" ^
    "if (-not (Test-Path -Path $tempdir)) { New-Item -ItemType Directory -Path $tempdir | Out-Null };" ^
    "$num_parts = 8;" ^
    "$request = [System.Net.WebRequest]::Create($url);" ^
    "$request.Method = 'HEAD';" ^
    "$request.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0';" ^
    "$request.Accept = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7';" ^
    "foreach($h in $headers.GetEnumerator()) { $request.Headers.Add($h.Name, $h.Value) };" ^
    "$response = $request.GetResponse();" ^
    "$headers = $response.Headers;" ^
    "$response.Close();" ^
    "if($headers.Get('Accept-Ranges') -ne 'bytes') { $num_parts = 1 };" ^
    "$filesize = $headers.Get('Content-Length');" ^
    "$filesize = [int]$filesize;" ^
    "$part_size = [math]::Ceiling($filesize / $num_parts);" ^
    "$jobs = @();" ^
    "for ($i = 0; $i -lt $num_parts; $i++) {" ^
    "    $start = $i * $part_size;" ^
    "    $end = (($i + 1) * $part_size) - 1;" ^
    "    if ($i -eq ($num_parts - 1)) { $end = $filesize - 1 };" ^
    "    $jobs += Start-Job -ScriptBlock { Param ($url, $start, $end, $tempdir, $part);" ^
    "        $request = [System.Net.WebRequest]::Create($url);" ^
    "        $request.Method = 'GET';" ^
    "        $request.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0';" ^
    "        $request.Accept = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7';" ^
    "        foreach($h in $headers.GetEnumerator()) { $request.Headers.Add($h.Name, $h.Value) };" ^
    "        $request.AddRange('bytes', $start, $end);" ^
    "        $response = $request.GetResponse();" ^
    "        $stream = $response.GetResponseStream();" ^
    "        $fileStream = [System.IO.File]::Create((Join-Path $tempdir $part));" ^
    "        $buffer = New-Object byte[] 8192;" ^
    "        while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) { $fileStream.Write($buffer, 0, $bytesRead) };" ^
    "        $stream.Close();" ^
    "        $fileStream.Close();" ^
    "    } -ArgumentList $url, $start, $end, $tempdir, \"$fname.part$i\";" ^
    "};" ^
    "$jobs | ForEach-Object { $_ | Wait-Job | Out-Null };" ^
    "$output = [System.IO.File]::Create($filepath);" ^
    "foreach ($i in 0..($num_parts-1)) {" ^
    "    $part = Join-Path $tempdir \"$fname.part$i\";" ^
    "    $buffer = New-Object byte[] 8192;" ^
    "    $fileStream = [System.IO.File]::OpenRead($part);" ^
    "    while (($bytesRead = $fileStream.Read($buffer, 0, $buffer.Length)) -gt 0) { $output.Write($buffer, 0, $bytesRead) };" ^
    "    $fileStream.Close();" ^
    "};" ^
    "$output.Close();" ^
    "Remove-Item -Recurse -Force $tempdir;"
endlocal
EXIT /b

:unzipper
IF NOT EXIST "%~f2" (MKDIR "%~f2")
POWERSHELL -Command ^
	"$shell = New-Object -ComObject shell.application;" ^
	"$zip = $shell.NameSpace('%~f1');" ^
	"if ($zip -ne $null) { " ^
	"	foreach ($item in $zip.items()) {" ^
	"		$shell.Namespace('%~f2').CopyHere($item);" ^
	"	} " ^
	"} else {" ^
	" Write-Host 'Error: Could not find zip file.'}"
IF !ERRORLEVEL! NEQ 0 (
	RMDIR "%~f2"
	ECHO Failed to unzip
) ELSE (
	DEL %~f1
)
EXIT /b

:php_menu
CLS
CALL :print_menu_header "PHP MENU"
ECHO 1. Download and Install
ECHO 2. List Version
ECHO 3. Set Default Version
ECHO 4. Uninstall
ECHO 5. Back
CHOICE /C 12345 /M "Pilih menu"
IF ERRORLEVEL 5 GOTO main_menu
IF ERRORLEVEL 4 GOTO php_uninstall
IF ERRORLEVEL 3 GOTO php_set_default_version
IF ERRORLEVEL 2 GOTO php_version
IF ERRORLEVEL 1 GOTO php_install
PAUSE
GOTO main_menu

:php_get_net_versions
IF NOT DEFINED php_net_versions[1] (
	CALL :download_file "https://windows.php.net/downloads/releases/archives/" ".\\tmp\\php_archives_version.html"
	POWERSHELL -Command ^
		"$content=Get-Content -Path .\\tmp\\php_archives_version.html | Out-String;" ^
		"$matches=[regex]::matches($content, '/downloads/releases/archives/php-([0-9\.]+)-Win32-(vc|vs|VC|VS)\d+-x(86|64).zip');" ^
		"$versions=@();" ^
		"foreach($match in $matches) { $versions+=$match.Groups[1].Value };" ^
		"$versions = $versions | Sort-Object -Unique; Write-Output $versions" > .\\tmp\temp.txt
	DEL .\\tmp\\php_archives_version.html
	FOR /f "delims=" %%a IN (.\\tmp\\temp.txt) DO (
		SET /a php_net_archive_versions_count+=1
		SET "php_net_archive_versions[!php_net_archive_versions_count!]=%%a"
		SET /a php_net_versions_count+=1
		SET "php_net_versions[!php_net_versions_count!]=%%a"
	)
	DEL .\\tmp\\temp.txt
	
	CALL :download_file "https://windows.php.net/downloads/releases/" ".\\tmp\\php_releases_version.html"
	POWERSHELL -Command ^
		"$content=Get-Content -Path .\\tmp\\php_releases_version.html | Out-String;" ^
		"$matches=[regex]::matches($content, '/downloads/releases/php-([0-9\.]+)-Win32-(vc|vs|VC|VS)\d+-x(86|64).zip');" ^
		"$versions=@();" ^
		"foreach($match in $matches) { $versions+=$match.Groups[1].Value };" ^
		"$versions = $versions | Sort-Object -Unique; Write-Output $versions" >> .\\tmp\temp.txt
	DEL .\\tmp\\php_releases_version.html
	POWERSHELL -Command "Get-Content -Path .\\tmp\\temp.txt | Sort-Object -Property {[version]$_.Trim()} | Set-Content -Path .\\tmp\\temp.txt"
	FOR /f "delims=" %%a IN (.\\tmp\\temp.txt) DO (
		SET /a php_net_release_versions_count+=1
		SET "php_net_release_versions[!php_net_release_versions_count!]=%%a"
		SET /a php_net_versions_count+=1
		SET "php_net_versions[!php_net_versions_count!]=%%a"
	)
	DEL .\\tmp\\temp.txt
)
EXIT /b

:php_get_local_versions
POWERSHELL -Command "$content = Get-ChildItem -Path '.\\php' -Directory | Out-String; $matches = [regex]::matches($content, 'php-([0-9\.]+)'); $versions = @(); foreach($match in $matches) {$versions += $match.Groups[1].Value}; Write-Output $versions" > .\\tmp\\temp.txt
SET php_local_versions=
SET php_local_versions_count=0
for /f "delims=" %%a in (.\\tmp\\temp.txt) do (
	SET /a php_local_versions_count += 1
	SET "php_local_versions[!php_local_versions_count!]=%%a"
)
DEL .\\tmp\\temp.txt
EXIT /b

:php_print_versions
ECHO Fetching PHP Versions...
CALL :php_get_net_versions
CALL :php_get_local_versions
FOR /L %%i IN (1,1,!php_net_versions_count!) DO (
	SET installed=false
	FOR /L %%j IN (1,1,!php_local_versions_count!) DO (
		IF "!php_net_versions[%%i]!" == "!php_local_versions[%%j]!" (
			SET installed=true
		)
	)

	IF "!installed!"=="false" (
		ECHO PHP-!php_net_versions[%%i]!
	)
)
FOR /L %%i IN (1,1,!php_local_versions_count!) DO (
	ECHO PHP-!php_local_versions[%%i]! [INSTALLED]
)
EXIT /b

:php_create_default_bin
CALL :php_get_local_versions
POWERSHELL -Command "$content=Get-Content -Path .\\default.conf | Out-String; $matches=[regex]::matches($content, 'php=php-([0-9\.]+)'); if($matches.Count -gt 0) {$ver=$matches.Groups[1].Value; Write-Output \"php-$ver\"} else {Write-Output php-0.0.0}" > .\\tmp\\temp.txt
SET /p php_ver=<.\\tmp\\temp.txt
DEL .\\tmp\\temp.txt

IF EXIST .\\php\\bin (
	RMDIR /S /Q .\\php\\bin
)
MKDIR .\\php\\bin

IF "!php_ver!"=="php-0.0.0" (
	IF !php_local_versions_count! GTR 0 (
		SET php_ver=php-!php_local_versions[%php_local_versions_count%]!
		POWERSHELL -Command "FINDSTR /i 'php=' default.conf" > .\\tmp\temp.txt
		SET /p  php_line_conf=<.\\tmp\temp.txt
		IF "!php_line_conf!" == "" (
			ECHO php=php-!php_local_versions[%php_local_versions_count%]! >> default.conf
		) ELSE (
			POWERSHELL -Command "(Get-Content .\\default.conf) -replace 'php=(php-([0-9.]*))?', 'php=php-!php_local_versions[%php_local_versions_count%]!' | Set-Content .\\default.conf"
		)
	) ELSE (
		POWERSHELL -Command "FINDSTR /i 'php=' default.conf" > .\\tmp\temp.txt
		SET /p  php_line_conf=<.\\tmp\temp.txt
		IF "!php_line_conf!" == "" (
			ECHO php= >> default.conf
		) ELSE (
			POWERSHELL -Command "(Get-Content .\\default.conf) -replace 'php=(php-([0-9.]*))?', 'php=' | Set-Content .\\default.conf"
		)
		CALL :apache_set_php_module
		ECHO PHP not installed.
		PAUSE
		GOTO php_menu
	)
)

SET php_path=0
FOR /L %%i IN (1,1,!php_local_versions_count!) DO (
	IF "php-!php_local_versions[%%i]!"=="!php_ver!" (
		IF EXIST .\\php\\php-!php_local_versions[%%i]! (
			SET php_path=%CD%\\php\\php-!php_local_versions[%%i]!
		)
	)
)
IF !php_path! NEQ 0 (
	POWERSHELL -Command "$content=Get-ChildItem -Path !php_path! | Where-Object {$_.Name -match '^.+\.(exe|bat)$'}; $apps=@(); foreach($c in $content) {$apps+=$c.Name}; Write-Output $apps" > .\\tmp\\temp.txt
	FOR /F "delims=" %%a IN (.\\tmp\\temp.txt) DO (
		POWERSHELL -Command "$matches=[regex]::matches('%%a', '^(.*)\.(exe|bat)'); $fname=$matches.Groups[1].Value; Write-Output \"@echo off`n!php_path!\%%a !%%*\" | Out-File -FilePath \".\php\bin\$fname.bat\" -Encoding ASCII"
	)
	ECHO !php_ver! set as default.
	CALL :apache_set_php_module
) ELSE (
	POWERSHELL -Command "(Get-Content .\\default.conf) -replace 'php=(php-([0-9.]*))?', 'php=php-!php_local_versions[%php_local_versions_count%]!' | Set-Content .\\default.conf"
	GOTO php_create_default_bin
)
EXIT /b

:php_install
CALL :php_print_versions
SET choosen_php_version=
SET /p choosen_php_version=Download PHP Version: 
FOR /f "tokens=* delims=" %%a IN ("!choosen_php_version!") DO SET choosen_php_version=%%~a
IF "!choosen_php_version!" == "" (
  ECHO Version can't be empty
  PAUSE
  GOTO php_menu
)
SET archived=true

ECHO Validating version..

SET valid_version=false
FOR /L %%i IN (1,1,!php_net_versions_count!) DO (
	IF "!php_net_versions[%%i]!" == "!choosen_php_version!" (
		SET installed=
		FOR /L %%j IN (1,1,!php_local_versions_count!) DO (
			IF "!php_net_versions[%%i]!" == "!php_local_versions[%%j]!" (SET installed=true)
		)

		IF "!installed!"=="true" (
			ECHO PHP-!choosen_php_version! already installed.
			PAUSE
			GOTO php_menu
		) ELSE (
			SET valid_version=true
		)
	)
)

IF NOT "!valid_version!" == "true" (
	ECHO PHP version is invalid or not found at repository.
	PAUSE
	GOTO php_menu
)

FOR /L %%i IN (1,1,!php_net_release_versions_count!) DO (
	IF "!php_net_release_versions[%%i]!" == "!choosen_php_version!" (
		SET archived=false
	)
)

IF "!archived!" == "true" (
	CALL :download_file "https://windows.php.net/downloads/releases/archives/" ".\\tmp\\php_repos.html"
	POWERSHELL -Command "$content=Get-Content -Path .\\tmp\\php_repos.html | Out-String; $matches=[regex]::matches($content, '/downloads/releases/archives/php-!choosen_php_version!-Win32-(vc|vs|VC|VS)\d+-x(86|64).zip'); $versions=@(); foreach($match in $matches) { $versions+=$match.Value }; Write-Output $versions" > .\\tmp\temp.txt
) ELSE (
	CALL :download_file "https://windows.php.net/downloads/releases/" ".\\tmp\\php_repos.html"
	POWERSHELL -Command "$content=Get-Content -Path .\\tmp\\php_repos.html | Out-String; $matches=[regex]::matches($content, '/downloads/releases/php-!choosen_php_version!-Win32-(vc|vs|VC|VS)\d+-x(86|64).zip'); $versions=@(); foreach($match in $matches) { $versions+=$match.Value }; Write-Output $versions" > .\\tmp\temp.txt
)
IF EXIST .\\tmp\\php_repos.html (
	DEL .\\tmp\\php_repos.html
)

SET count=0
FOR /f "delims=" %%a IN (.\\tmp\\temp.txt) DO (
	IF NOT "%%a" == "" (
		SET /a count+=1
	)
)

IF !count! LSS 1 (
	ECHO Failed get download URL
	PAUSE
	GOTO php_menu
)

IF NOT EXIST .\\tmp\\php-!choosen_php_version!.zip (
	SET arch=x64
	IF "%PROCESSOR_ARCHITECTURE%"=="x86" (
		SET arch=x86
	)
			
	SET /p download_path=<.\\tmp\temp.txt
	IF !count! GTR 1 (
		POWERSHELL -Command "$content=Get-Content -Path .\\tmp\\temp.txt | Out-String; $matches=[regex]::matches($content, '.+-!arch!.zip'); Write-Output $matches[0].Value" > .\\tmp\\temp.txt
		SET /p download_path=<.\\tmp\temp.txt
	)		
	DEL .\\tmp\\temp.txt
	
	POWERSHELL -Command ^
		"try {" ^
		"    $request = [System.Net.WebRequest]::Create('https://windows.php.net!download_path!');" ^
		"    $request.Method = 'HEAD';" ^
		"    $request.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0';" ^
		"    $request.Headers.Add('Accept-Language', 'en-US,en;q=0.9,id;q=0.8');" ^
		"    $request.Headers.Add('DNT', '1');" ^
		"    $request.Headers.Add('Sec-Fetch-Dest', 'document');" ^
		"    $request.Headers.Add('Sec-Fetch-Mode', 'navigate');" ^
		"    $request.Headers.Add('Sec-Fetch-Site', 'none');" ^
		"    $request.Headers.Add('Sec-Fetch-User', '?1');" ^
		"    $request.Headers.Add('Upgrade-Insecure-Requests', '1');" ^
		"    $request.Headers.Add('sec-ch-ua', '\"Microsoft Edge\";v=\"129\", \"Not=A?Brand\";v=\"8\", \"Chromium\";v=\"129\"');" ^
		"    $request.Headers.Add('sec-ch-ua-mobile', '?0');" ^
		"    $request.Headers.Add('sec-ch-ua-platform', 'Windows');" ^
		"    $response = $request.GetResponse();" ^
		"    $headers = $response.Headers;" ^
		"    $response.Close();" ^
		"    Write-Output ([Math]::Round($headers.Get('Content-Length')/1000000, 2)) | Set-Content .\\tmp\\temp.txt;" ^
		"} catch {" ^
		"    Write-Output '?' | Set-Content .\\tmp\\temp.txt;" ^
		"    Write-Host \"Can't get file size\";" ^
		"}"
	SET /p filesize=<.\\tmp\\temp.txt
	DEL .\\tmp\\temp.txt
	SET y=false
	SET /p continue=You need download !filesize!MiB file. Continue? [Y/N] 
	IF "!continue!" == "y" (
		SET y=true
	) ELSE IF "!continue!" == "Y" (
		SET y=true
	)

	IF "!y!" == "true" (
		ECHO Downloading PHP-!choosen_php_version!...
		CALL :download_file "https://windows.php.net!download_path!" ".\\tmp\\php-!choosen_php_version!.zip"
	) ELSE (
		ECHO Cancelled.
		PAUSE
		GOTO php_menu
	)
)

ECHO Unzipping...
CALL :unzipper ".\\tmp\\php-!choosen_php_version!.zip" ".\\php\\php-!choosen_php_version!\\"
IF EXIST .\\php\\php-!choosen_php_version!\\php.exe (
	IF EXIST .\\php\\php-!choosen_php_version!\\php.ini-development (
		POWERSHELL -Command ^
			"$content = Get-Content .\\php\\php-!choosen_php_version!\\php.ini-development | Out-String;" ^
			"$content = [regex]::Replace($content, ';extension=', 'extension=');" ^
			"$content = [regex]::Replace($content, ';?extension_dir = \"./\"', 'extension_dir = \"%CD%\\php\\php-!choosen_php_version!\\ext\"');" ^
			"Write-Output $content | Set-Content .\\php\\php-!choosen_php_version!\\php.ini"
	)
	IF EXIST .\\php\\php-!choosen_php_version!\\php.ini-recommended (
		POWERSHELL -Command ^
			"$content = Get-Content .\\php\\php-!choosen_php_version!\\php.ini-recommended | Out-String;" ^
			"$content = [regex]::Replace($content, ';extension=', 'extension=');" ^
			"$content = [regex]::Replace($content, ';?extension_dir = \"./\"', 'extension_dir = \"%CD%\\php\\php-!choosen_php_version!\\ext\"');" ^
			"Write-Output $content | Set-Content .\\php\\php-!choosen_php_version!\\php.ini"
	)
	ECHO PHP !choosen_php_version! installed.
	ECHO Update default php version...
	CALL :php_create_default_bin
) ELSE (
	IF EXIST .\\php\\php-!choosen_php_version! (
		RMDIR /S /Q .\\php\\php-!choosen_php_version!
	)
	ECHO PHP !choosen_php_version! failed to install.
)
PAUSE
GOTO php_menu

:php_version
CALL :php_print_versions
PAUSE
GOTO php_menu

:php_set_default_version
ECHO Getting installed PHP versions...
CALL :php_get_local_versions
IF !php_local_versions_count! LEQ 0 (
	ECHO PHP not installed.
	PAUSE
	GOTO php_menu
)

POWERSHELL -Command "$content=Get-Content -Path .\\default.conf | Out-String; $matches=[regex]::matches($content, 'php=php-([0-9\.]+)'); if($matches.Count -gt 0) {$ver=$matches.Groups[1].Value; Write-Output \"php-$ver\"} else {Write-Output php-0.0.0}" > .\\tmp\\temp.txt
SET /p php_ver=<.\\tmp\\temp.txt
DEL .\\tmp\\temp.txt
FOR /L %%j IN (1,1,!php_local_versions_count!) DO (
	IF "php-!php_local_versions[%%j]!" == "!php_ver!" (
		ECHO PHP-!php_local_versions[%%j]! [DEFAULT]
	) ELSE (
		ECHO PHP-!php_local_versions[%%j]!
	)
)
SET choosen_php_version=
SET /p choosen_php_version=Set PHP Version as default: 
FOR /f "tokens=* delims=" %%a IN ("!choosen_php_version!") DO SET choosen_php_version=%%~a
IF "!choosen_php_version!" == "" (
  ECHO Version can't be empty
  PAUSE
  GOTO php_menu
)

SET installed=false
FOR /L %%j IN (1,1,!php_local_versions_count!) DO (
	IF !php_local_versions[%%j]! == !choosen_php_version! (
		SET installed=true
	)
)

IF "!installed!" == "true" (
	ECHO Update default php version...
	POWERSHELL -Command "(Get-Content .\\default.conf) -replace 'php=(php-([0-9.]*))?', 'php=php-!choosen_php_version!' | Set-Content .\\default.conf"
	CALL :php_create_default_bin
) ELSE (
	ECHO PHP-!choosen_php_version! is not installed.
)
PAUSE
GOTO php_menu

:php_uninstall
CALL :php_get_local_versions
IF !php_local_versions_count! LEQ 0 (
	ECHO PHP not installed.
	PAUSE
	GOTO php_menu
)

FOR /L %%j IN (1,1,!php_local_versions_count!) DO (
	ECHO PHP-!php_local_versions[%%j]!
)

SET choosen_php_version=
SET /p choosen_php_version=Uninstall PHP Version: 
FOR /f "tokens=* delims=" %%a IN ("!choosen_php_version!") DO SET choosen_php_version=%%~a
IF "!choosen_php_version!" == "" (
  ECHO Version can't be empty
  PAUSE
  GOTO php_menu
)

SET installed=false
FOR /L %%j IN (1,1,!php_local_versions_count!) DO (
	IF !php_local_versions[%%j]! == !choosen_php_version! (
		SET installed=true
	)
)

IF "!installed!" == "true" (
	SET y=false
	SET /p continue=Do you want continue uninstall PHP-!choosen_php_version! [Y/N]?
	IF "!continue!" == "y" (
		SET y=true
	) ELSE IF "!continue!" == "Y" (
		SET y=true
	)
	
	IF "!y!" == "true" (
		RMDIR /S /Q .\\php\\php-!choosen_php_version!\\
		ECHO Uninstall PHP-!choosen_php_version! successful.
		ECHO Update default php version...
		CALL :php_create_default_bin
	) ELSE (
		ECHO Uninstallation cancelled.
	)
) ELSE (
	ECHO PHP-!choosen_php_version! is not installed.
)

PAUSE
GOTO php_menu

:apache_menu
CLS
CALL :print_menu_header "APACHE MENU"
CALL :apache_status
ECHO 1. Download and Install
ECHO 2. Start
ECHO 3. Restart
ECHO 4. Stop
ECHO 5. Uninstall
ECHO 6. Back
CHOICE /C 123456 /M "Pilih menu"
IF ERRORLEVEL 6 GOTO main_menu
IF ERRORLEVEL 5 GOTO apache_uninstall
IF ERRORLEVEL 4 GOTO apache_stop
IF ERRORLEVEL 3 GOTO apache_restart
IF ERRORLEVEL 2 GOTO apache_start
IF ERRORLEVEL 1 GOTO apache_install
PAUSE
GOTO main_menu

:apache_set_php_module
SET php_version=
SET php_mod=
IF "!php_version!" == "" (
	POWERSHELL -Command ^
		"$content=Get-Content -Path .\\default.conf | Out-String;" ^
		"$matches=[regex]::matches($content, 'php=php-([0-9\.]+)');" ^
		"if($matches.Count -gt 0) {$ver=$matches.Groups[1].Value; Write-Output \"php-$ver\"}" ^
		"else {Write-Output php-0.0.0}" > .\\tmp\\temp.txt
	SET /p php_version=<.\\tmp\\temp.txt
	POWERSHELL -Command ^
		"$content=Get-Content -Path .\\default.conf | Out-String;" ^
		"$matches=[regex]::matches($content, 'php=php-([0-9]+)');" ^
		"if($matches.Count -gt 0) {$ver=$matches.Groups[1].Value; Write-Host \"$ver\"}" ^
		"else { Write-Host '0'}" > .\\tmp\\temp.txt
	SET /p phpmod=<.\\tmp\\temp.txt
	IF !phpmod! GTR 7 (
		SET phpmod=
	)
	DEL .\\tmp\\temp.txt
)
IF EXIST .\\apache\\conf\\httpd.conf (
	IF "!php_version!" == "php-0.0.0" (
		POWERSHELL -Command ^
			"$content=(Get-Content .\\apache\\conf\\httpd.conf | Out-String);" ^
			"$content=[regex]::Replace($content, \"#?LoadModule php\d?_module '.*'\", \"#LoadModule php_module ''\");" ^
			"$content=[regex]::Replace($content, \"#?PHPIniDir '.*'\", \"#PHPIniDir ''\");" ^
			"Write-Output $content | Set-Content .\\apache\\conf\\httpd.conf"
	) ELSE (
		POWERSHELL -Command ^
			"$dll=(Get-ChildItem -Path .\\php\\!php_version! -Filter *apache*.dll | Select-Object -First 1).Name;" ^
			"$content=(Get-Content .\\apache\\conf\\httpd.conf | Out-String);" ^
			"$content=[regex]::Replace($content, \"#?LoadModule php\d?_module '.*'\", \"LoadModule php!phpmod!_module '%CD%\\php\\!php_version!\\$dll'\");" ^
			"$content=[regex]::Replace($content, \"#?PHPIniDir '.*'\", \"PHPIniDir '%CD%\\php\\!php_version!'\");" ^
			"Write-Output $content | Set-Content .\\apache\\conf\\httpd.conf"
	)
)
EXIT /b

:apache_status
POWERSHELL -Command "tasklist | findstr /i httpd | Select-Object -First 1" > .\\tmp\temp.txt
SET count=0
FOR /f %%a IN (.\\tmp\\temp.txt) DO (
	SET /a count+=1
)
DEL .\\tmp\temp.txt
IF !count! GTR 0 (
	ECHO Apache: Started
) ELSE (
	ECHO Apache: Stopped
)
EXIT /b

:apache_install
CALL :download_file "https://www.apachelounge.com/download/" ".\\tmp\\apachelounge.html"
POWERSHELL -Command " $content=Get-Content -Path .\\tmp\\apachelounge.html | Out-String; $matches=[regex]::matches($content, 'Apache ([0-9\.]+) .+ Windows Binaries and Modules'); $ver=$matches.Groups[1].Value -replace '\.', ''; Write-Output \"Apache$ver\"" > .\\tmp\\temp.txt
SET /p apache_version=<.\\tmp\\temp.txt
DEL .\\tmp\\temp.txt

IF NOT EXIST .\\tmp\\apache.zip (
	SET download_regex="(/download/.+/binaries/httpd-.+-win(32|64)-.+\.zip)"
	POWERSHELL -Command "$content=Get-Content -Path .\\tmp\\apachelounge.html | Out-String; $matches=[regex]::matches($content, $Env:download_regex); foreach($match in $matches) {Write-Output $match.Groups[1].Value}" > .\\tmp\\temp.txt
	DEL .\\tmp\\apachelounge.html
	SET arch=32
	IF "%PROCESSOR_ARCHITECTURE%" == "AMD64" (
		SET arch=64
	)
	SET count=0
	FOR /f "delims=" %%a IN (.\\tmp\\temp.txt) DO (
		IF NOT "%%a" == "" (
			SET /a count+=1
		)
	)

	IF !count! == 0 (
		ECHO Failed get download URL.
		PAUSE
		GOTO apache_menu
	)

	SET /p download_path=<.\\tmp\\temp.txt
	IF !count! GTR 1 (
		POWERSHELL -Command "$content=Get-Content -Path .\\tmp\\temp.txt | Out-String; $matches=[regex]::matches($content, '.+-win!arch!-.+.zip'); Write-Output $matches[0].Value" > .\\tmp\\temp.txt
		SET /p download_path=<.\\tmp\temp.txt
	)
	DEL .\\tmp\\temp.txt
	POWERSHELL -Command ^
		"try {" ^
		"    $request = [System.Net.WebRequest]::Create('https://www.apachelounge.com!download_path!');" ^
		"    $request.Method = 'HEAD';" ^
		"    $request.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0';" ^
		"    $request.Headers.Add('Accept-Language', 'en-US,en;q=0.9,id;q=0.8');" ^
		"    $request.Headers.Add('DNT', '1');" ^
		"    $request.Headers.Add('Sec-Fetch-Dest', 'document');" ^
		"    $request.Headers.Add('Sec-Fetch-Mode', 'navigate');" ^
		"    $request.Headers.Add('Sec-Fetch-Site', 'none');" ^
		"    $request.Headers.Add('Sec-Fetch-User', '?1');" ^
		"    $request.Headers.Add('Upgrade-Insecure-Requests', '1');" ^
		"    $request.Headers.Add('sec-ch-ua', '\"Microsoft Edge\";v=\"129\", \"Not=A?Brand\";v=\"8\", \"Chromium\";v=\"129\"');" ^
		"    $request.Headers.Add('sec-ch-ua-mobile', '?0');" ^
		"    $request.Headers.Add('sec-ch-ua-platform', 'Windows');" ^
		"    $response = $request.GetResponse();" ^
		"    $headers = $response.Headers;" ^
		"    $response.Close();" ^
		"    Write-Output ([Math]::Round($headers.Get('Content-Length')/1000000, 2)) | Set-Content .\\tmp\\temp.txt;" ^
		"} catch {" ^
		"    Write-Output '?' | Set-Content .\\tmp\\temp.txt;" ^
		"    Write-Host \"Can't get file size\";" ^
		"}"
	SET /p filesize=<.\\tmp\\temp.txt
	SET y=false
	SET /p continue=You need download !filesize!MiB file. Continue? [Y/N] 
	IF "!continue!" == "y" (
		SET y=true
	) ELSE IF "!continue!" == "Y" (
		SET y=true
	)

	IF "!y!" == "true" (
		ECHO Downloading apache...
		CALL :download_file "https://www.apachelounge.com%download_path%" ".\\tmp\\apache.zip"
	) ELSE (
		ECHO Cancelled.
		PAUSE
		GOTO apache_menu
	)
)

ECHO Unzipping...
CALL :unzipper ".\\tmp\\apache.zip\\!apache_version!" ".\\apache"
IF EXIST .\\apache\\bin\\httpd.exe (
	POWERSHELL -Command ^
		"$content=Get-Content .\\apache\\conf\\httpd.conf | Out-String;" ^
		"$content=[regex]::Replace($content, 'Define SRVROOT \".+\"', 'Define SRVROOT \"%CD%\\apache\"');" ^
		"$content=$content -replace \"LoadModule actions_module modules/mod_actions.so\", \"#LoadModule php_module ''`n#PHPIniDir ''`nLoadModule actions_module modules/mod_actions.so\";" ^
		"$content=[regex]::Replace($content, '#ServerName www.example.com:80', 'ServerName localhost:80');" ^
		"$content=[regex]::Replace($content, '\${SRVROOT}/htdocs', '%CD%\\htdocs');" ^
		"$content=[regex]::Replace($content, 'DirectoryIndex index.html', 'DirectoryIndex index.php index.html index.htm');" ^
		"$content=[regex]::Replace($content, \"^<IfModule mime_module^>\", \"^<IfModule mime_module^>`n	AddHandler application/x-httpd-php .php .phar\");" ^
		"Write-Output $content | Set-Content -Path .\\apache\\conf\\httpd.conf"
	CALL :apache_set_php_module
	ECHO Apache installed.
) ELSE (
	ECHO Apache failed to install.
)

IF EXIST .\\tmp\\apache.zip (
	DEL .\\tmp\\apache.zip
)
PAUSE
GOTO apache_menu

:apache_start
IF NOT EXIST .\\apache\\bin\\httpd.exe (
	ECHO Apache is not installed
	PAUSE
	GOTO apache_menu
)

POWERSHELL -Command "tasklist | findstr /i httpd | Select-Object -First 1" > .\\tmp\temp.txt
SET count=0
FOR /f %%a IN (.\\tmp\temp.txt) DO (
	SET /a count+=1
)
DEL .\\tmp\temp.txt
IF !count!==0 (
	START /min /b .\\apache\\bin\\httpd.exe
) ELSE (
	ECHO Apache already started
)
CALL :apache_status
PAUSE
GOTO apache_menu

:apache_stop
IF NOT EXIST .\\apache\\bin\\httpd.exe (
	ECHO Apache is not installed
	PAUSE
	GOTO apache_menu
)

POWERSHELL -Command "tasklist | findstr /i httpd | Select-Object -First 1" > .\\tmp\temp.txt
SET count=0
FOR /f %%a IN (.\\tmp\temp.txt) DO (
	SET /a count+=1
)
DEL .\\tmp\temp.txt
IF !count! GTR 0 (
	POWERSHELL -Command "Stop-Process -Id (Get-Process -Name httpd).Id -Force"
	DEL .\\apache\\logs\\httpd.pid
)
CALL :apache_status
PAUSE
GOTO apache_menu

:apache_restart
IF NOT EXIST .\\apache\\bin\\httpd.exe (
	ECHO Apache is not installed
	PAUSE
	GOTO apache_menu
)

POWERSHELL -Command "tasklist | findstr /i httpd | Select-Object -First 1" > .\\tmp\temp.txt
SET count=0
FOR /f %%a IN (.\\tmp\temp.txt) DO (
	SET /a count+=1
)
DEL .\\tmp\temp.txt
IF !count! GTR 0 (
	POWERSHELL -Command "Stop-Process -Id (Get-Process -Name httpd).Id -Force"
	DEL .\\apache\\logs\\httpd.pid
)
IF EXIST .\\apache\\bin\\httpd.exe (START /min /b .\\apache\\bin\\httpd.exe)
CALL :apache_status
PAUSE
GOTO apache_menu

:apache_uninstall
SET y=false
SET /p continue=Do you want continue uninstall Apache [Y/N]?
IF "!continue!" == "y" (
	SET y=true
) ELSE IF "!continue!" == "Y" (
	SET y=true
)
	
IF "!y!" == "true" (
	POWERSHELL -Command "tasklist | findstr /i httpd | Select-Object -First 1" > .\\tmp\temp.txt
	SET count=0
	FOR /f %%a IN (.\\tmp\temp.txt) DO (
		SET /a count+=1
	)
	DEL .\\tmp\temp.txt
	IF !count! GTR 0 (
		POWERSHELL -Command "Stop-Process -Id (Get-Process -Name httpd).Id -Force"
		DEL .\\apache\\logs\\httpd.pid
	)
	IF EXIST .\\apache (
		RMDIR /S /Q .\\apache
		MKDIR .\\apache
	)
	ECHO Apache uninstalled.
) ELSE (
	ECHO Uninstallation cancelled.
)
PAUSE
GOTO apache_menu

:mariadb_menu
CLS
CALL :print_menu_header "MARIADB MENU"
CALL :mariadb_status
ECHO 1. Download and Install
ECHO 2. List Version
ECHO 3. Set Default Version
ECHO 4. Start
ECHO 5. Restart
ECHO 6. Stop
ECHO 7. Uninstall
ECHO 8. Back
CHOICE /C 12345678 /M "Pilih menu"
IF ERRORLEVEL 8 GOTO main_menu
IF ERRORLEVEL 7 GOTO mariadb_uninstall
IF ERRORLEVEL 6 GOTO mariadb_stop
IF ERRORLEVEL 5 GOTO mariadb_restart
IF ERRORLEVEL 4 GOTO mariadb_start
IF ERRORLEVEL 3 GOTO mariadb_set_default_version
IF ERRORLEVEL 2 GOTO mariadb_version
IF ERRORLEVEL 1 GOTO mariadb_install
PAUSE
GOTO main_menu

:mariadb_get_local_versions
POWERSHELL -Command "$content = Get-ChildItem -Path '.\\mariadb' -Directory | Out-String; $matches = [regex]::matches($content, 'mariadb-([0-9\.]+)'); $versions = @(); foreach($match in $matches) {$versions += $match.Groups[1].Value}; Write-Output $versions" > .\\tmp\\temp.txt
SET mariadb_local_versions=
SET mariadb_local_versions_count=0
FOR /f "delims=" %%a IN (.\\tmp\\temp.txt) DO (
	SET /a mariadb_local_versions_count += 1
	SET "mariadb_local_versions[!mariadb_local_versions_count!]=%%a"
)
DEL .\\tmp\\temp.txt
EXIT /b

:mariadb_get_net_versions
IF NOT !mariadb_net_versions_count! GTR 0 (
	SET release_number_regex="release_number": "([0-9\.]+)"
	CALL :download_file "https://downloads.mariadb.org/rest-api/mariadb/all-releases/?olderReleases=true" ".\\tmp\\mariadb-ver.json"
	POWERSHELL -Command ^
	  "$content=Get-Content -Path .\\tmp\\mariadb-ver.json | Out-String;" ^
	  "$matches=[regex]::matches($content, $Env:release_number_regex);" ^
	  "$versions=@();" ^
	  "foreach($match in $matches) { $versions+=$match.Groups[1].Value };" ^
	  "Write-Output $versions | Sort-Object -Property {[version]$_.Trim()} | Set-Content -Path .\\tmp\\temp.txt"

	FOR /f %%a IN (.\\tmp\\temp.txt) DO (
	  SET /a mariadb_net_versions_count+=1
	  SET "mariadb_net_versions[!mariadb_net_versions_count!]=%%a"
	)
	
	DEL .\\tmp\\mariadb-ver.json
	DEL.\\tmp\\temp.txt
)
EXIT /b

:mariadb_print_versions
ECHO Fetching MariaDB Versions...
CALL :mariadb_get_local_versions
CALL :mariadb_get_net_versions
FOR /L %%i IN (1,1,!mariadb_net_versions_count!) DO (
	SET installed=false
	FOR /L %%j IN (1,1,!mariadb_local_versions_count!) DO (
		IF "!mariadb_net_versions[%%i]!" == "!mariadb_local_versions[%%j]!" (
			SET installed=true
		)
	)
	SET ver=!mariadb_net_versions[%%i]!
	IF "!installed!"=="false" (
		IF "%PROCESSOR_ARCHITECTURE%" == "x86" ( :: Only print has x86
			IF "!ver:~0,5!" LEQ "10.1." (
				ECHO MariaDB-!ver!
			)
			IF "!ver:~0,5!" == "10.2." (
				IF "!ver:~5,7!" LEQ "41" (
					ECHO MariaDB-!ver!
				)
			)
		) ELSE (
			ECHO MariaDB-!ver!
		)
	)
)
FOR /L %%i IN (1,1,!mariadb_local_versions_count!) DO (
	ECHO MariaDB-!mariadb_local_versions[%%i]! [INSTALLED]
)
EXIT /b

:mariadb_create_default_bin
CALL :mariadb_get_local_versions
POWERSHELL -Command "$content=Get-Content -Path .\\default.conf | Out-String; $matches=[regex]::matches($content, 'mariadb=mariadb-([0-9\.]+)'); if($matches.Count -gt 0) {$ver=$matches.Groups[1].Value; Write-Output \"mariadb-$ver\"} else {Write-Output mariadb-0.0.0}" > .\\tmp\\temp.txt
SET /p mariadb_ver=<.\\tmp\\temp.txt
DEL .\\tmp\\temp.txt

IF EXIST .\\mariadb\\bin (
	RMDIR /S /Q .\\mariadb\\bin
)
MKDIR .\\mariadb\\bin

IF "!mariadb_ver!"=="mariadb-0.0.0" (
	IF !mariadb_local_versions_count! GTR 0 (
		SET mariadb_ver=mariadb-!mariadb_local_versions[%mariadb_local_versions_count%]!
		POWERSHELL -Command "FINDSTR /i 'mariadb=' default.conf" > .\\tmp\temp.txt
		SET /p  mariadb_line_conf=<.\\tmp\temp.txt
		IF "!mariadb_line_conf!" == "" (
			ECHO mariadb=mariadb-!mariadb_local_versions[%mariadb_local_versions_count%]! >> default.conf
		) ELSE (
			POWERSHELL -Command "(Get-Content .\\default.conf) -replace 'mariadb=(mariadb-([0-9.]*))?', 'mariadb=mariadb-!mariadb_local_versions[%mariadb_local_versions_count%]!' | Set-Content .\\default.conf"
		)
	) ELSE (
		ECHO MariaDB not installed.
		IF "!mariadb_line_conf!" == "" (
			ECHO mariadb= >> default.conf
		) ELSE (
			POWERSHELL -Command "(Get-Content .\\default.conf) -replace 'mariadb=(mariadb-([0-9.]*))?', 'mariadb=' | Set-Content .\\default.conf"
		)
		PAUSE
		GOTO mariadb_menu
	)
)

SET mariadb_path=0
FOR /L %%i IN (1,1,!mariadb_local_versions_count!) DO (
	IF "mariadb-!mariadb_local_versions[%%i]!"=="!mariadb_ver!" (
		IF EXIST .\\mariadb\\mariadb-!mariadb_local_versions[%%i]! (
			SET mariadb_path=%CD%\\mariadb\\mariadb-!mariadb_local_versions[%%i]!
		)
	)
)
IF !mariadb_path! NEQ 0 (
	POWERSHELL -Command "$content=Get-ChildItem -Path !mariadb_path!\\bin | Where-Object {$_.Name -match '^.+\.(exe|bat)$'}; $apps=@(); foreach($c in $content) {$apps+=$c.Name}; Write-Output $apps" > .\\tmp\\temp.txt
	FOR /F "delims=" %%a IN (.\\tmp\\temp.txt) DO (
		POWERSHELL -Command "$matches=[regex]::matches('%%a', '^(.*)\.(exe|bat)'); $fname=$matches.Groups[1].Value; Write-Output \"@echo off`n!mariadb_path!\\bin\\%%a !%%*\" | Out-File -FilePath \".\mariadb\bin\$fname.bat\" -Encoding ASCII"
	)
	ECHO !mariadb_ver! set as default.
) ELSE (
	POWERSHELL -Command "(Get-Content .\\default.conf) -replace 'mariadb=(mariadb-([0-9.]*))?', 'mariadb=mariadb-!mariadb_local_versions[%mariadb_local_versions_count%]!' | Set-Content .\\default.conf"
	GOTO mariadb_create_default_bin
)
EXIT /b

:mariadb_status
POWERSHELL -Command "tasklist | findstr /i mysqld | Select-Object -First 1" > .\\tmp\temp.txt
SET count=0
FOR /f %%a IN (.\\tmp\\temp.txt) DO (
	SET /a count+=1
)
DEL .\\tmp\temp.txt
IF !count! GTR 0 (
	ECHO MariaDB: Started
) ELSE (
	ECHO MariaDB: Stopped
)
EXIT /b

:mariadb_install
CALL :mariadb_print_versions
SET /p choosen_mariadb_version=Download MariaDB Version: 
SET valid_version=false
SET installed=false

ECHO Validating version...

FOR /L %%i IN (1,1,!mariadb_local_versions_count!) DO (
	IF "!mariadb_local_versions[%%i]!" == "!choosen_mariadb_version!" (
		SET installed=true
	)
)
IF "!installed!" == "true" (
	ECHO MariaDB-!choosen_mariadb_version! already installed
	PAUSE
	GOTO mariadb_menu
)
FOR /L %%i IN (1,1,!mariadb_net_versions_count!) DO (
	IF !mariadb_net_versions[%%i]! == !choosen_mariadb_version! (
		SET valid_version=true
	)
)
IF NOT "!valid_version!" == "true" (
	ECHO MariaDB-!choosen_mariadb_version! not found in repository
	PAUSE
	GOTO mariadb_menu
)

ECHO Getting mirror...
CALL :download_file "https://downloads.mariadb.org/rest-api/mariadb/!choosen_mariadb_version!/downloads-form/" ".\\tmp\\mirror.json"
POWERSHELL -Command ^
	"$content=Get-Content -Path .\\tmp\\mirror.json -Raw;" ^
	"$data=ConvertFrom-Json -InputObject $content;" ^
	"$file_mirrors=$data.release_data.files[0].mirrors;" ^
	"$closest_mirrors=$data.release_data.closest_mirrors;" ^
	"$avail_mirrors=@();" ^
	"foreach($fm in $file_mirrors) {" ^
	"	foreach($prop in $fm.PSObject.Properties) {" ^
	"		foreach($child in $prop.Value.children) {" ^
	"			$mirror=@{};" ^
	"			$mirror.country=$child.country;" ^
	"			$mirror.url=$child.mirror_url;" ^
	"			$avail_mirrors+=$mirror;" ^
	"		}" ^
	"	}" ^
	"}" ^
	"$matched_mirrors = @();" ^
	"foreach ($cm in $closest_mirrors) {" ^
	"	$match = $avail_mirrors | Where-Object { $_.url -eq $cm.mirror_url };" ^
	"	if ($match) { $matched_mirrors += $match }" ^
	"}" ^
	"Write-Output $matched_mirrors[0].url | Set-Content -Path .\\tmp\\temp.txt"
SET /p mirror_url=<.\\tmp\\temp.txt
POWERSHELL -Command ^
	"$arch_code='x86';" ^
	"$arch='%PROCESSOR_ARCHITECTURE%';" ^
	"if($arch -eq 'AMD64') {$arch_code='x86_64'}" ^
	"$content=Get-Content -Path .\\tmp\\mirror.json -Raw;" ^
	"$data=ConvertFrom-Json -InputObject $content;" ^
	"$files=$data.release_data.files;" ^
	"$file_path='';" ^
	"foreach($file in $files) {" ^
	"	if($file.os_code -eq 'windows' -and $file.package_type_code -eq 'zip' -and $file.cpu -eq $arch_code) {" ^
	"		$matches=[regex]::matches($file.file_name, 'win(.+)\.zip');" ^
	"		$m=$matches.Groups[1];" ^
	"		if(($m -replace '-','') -eq $m) {" ^
	"			$file_path=$file.full_path;" ^
	"		}" ^
	"	}" ^
	"}" ^
	"Write-Output $file_path | Set-Content .\\tmp\\temp.txt;"
SET /p file_path=<.\\tmp\\temp.txt
IF "!file_path!" == "" (
	SET arch=%PROCESSOR_ARCHITECTURE%
	IF "%PROCESSOR_ARCHITECTURE%" == "AMD64" (
		SET arch=x86_64
	) ELSE IF "%PROCESSOR_ARCHITECTURE%" == "x86" (
		SET arch=x86
	)
	ECHO Cannot get file for Windows-!arch!
	PAUSE
	GOTO mariadb_menu
)
POWERSHELL -Command "$matches=[regex]::matches('!file_path!', '(mariadb-!choosen_mariadb_version!-.+)\.zip$'); $dname=''; if($matches.Groups.Length -gt 0) { $dname=$matches.Groups[1].Value }; Write-Output $dname | Set-Content .\\tmp\\temp.txt"
SET /p dname=<.\\tmp\\temp.txt

DEL .\\tmp\\temp.txt
DEL .\\tmp\\mirror.json

IF NOT EXIST .\\tmp\\mariadb-!choosen_mariadb_version!.zip (
	POWERSHELL -Command ^
		"try {" ^
		"    $request = [System.Net.WebRequest]::Create('!mirror_url!!file_path!');" ^
		"    $request.Method = 'HEAD';" ^
		"    $request.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0';" ^
		"    $request.Headers.Add('Accept-Language', 'en-US,en;q=0.9,id;q=0.8');" ^
		"    $request.Headers.Add('DNT', '1');" ^
		"    $request.Headers.Add('Sec-Fetch-Dest', 'document');" ^
		"    $request.Headers.Add('Sec-Fetch-Mode', 'navigate');" ^
		"    $request.Headers.Add('Sec-Fetch-Site', 'none');" ^
		"    $request.Headers.Add('Sec-Fetch-User', '?1');" ^
		"    $request.Headers.Add('Upgrade-Insecure-Requests', '1');" ^
		"    $request.Headers.Add('sec-ch-ua', '\"Microsoft Edge\";v=\"129\", \"Not=A?Brand\";v=\"8\", \"Chromium\";v=\"129\"');" ^
		"    $request.Headers.Add('sec-ch-ua-mobile', '?0');" ^
		"    $request.Headers.Add('sec-ch-ua-platform', 'Windows');" ^
		"    $response = $request.GetResponse();" ^
		"    $headers = $response.Headers;" ^
		"    $response.Close();" ^
		"    Write-Output ([Math]::Round($headers.Get('Content-Length')/1000000, 2)) | Set-Content .\\tmp\\temp.txt;" ^
		"} catch {" ^
		"    Write-Output '?' | Set-Content .\\tmp\\temp.txt;" ^
		"    Write-Host \"Can't get file size\";" ^
		"}"
	SET /p filesize=<.\\tmp\\temp.txt
	DEL .\\tmp\\temp.txt
	SET y=false
	SET /p continue=You need download !filesize!MiB file. Continue? [Y/N] 
	IF "!continue!" == "y" (
		SET y=true
	) ELSE IF "!continue!" == "Y" (
		SET y=true
	)
	IF "!y!" == "true" (		
		ECHO Downloading MariaDB-!choosen_mariadb_version!...
		CALL :download_file "!mirror_url!!file_path!" ".\\tmp\\mariadb-!choosen_mariadb_version!.zip"
	) ELSE (
		ECHO Cancelled.
		PAUSE
		GOTO mariadb_menu
	)
)

ECHO Unzipping...
CALL :unzipper ".\\tmp\\mariadb-!choosen_mariadb_version!.zip\\!dname!" ".\\mariadb\\mariadb-!choosen_mariadb_version!"

IF EXIST .\\mariadb\\mariadb-!choosen_mariadb_version!\\bin\\mysqld.exe (
	IF NOT EXIST .\\mariadb\\mariadb-!choosen_mariadb_version!\\data (POWERSHELL -Command ".\\mariadb\\mariadb-!choosen_mariadb_version!\\bin\\mysql_install_db.exe -s -d .\\mariadb\\mariadb-!choosen_mariadb_version!\\data")
	IF EXIST .\\mariadb\\mariadb-!choosen_mariadb_version!\\data (
		XCOPY /s /i /q .\\mariadb\\mariadb-!choosen_mariadb_version!\\data .\\mariadb\\mariadb-!choosen_mariadb_version!\\backup > .\\tmp\\temp.txt
		DEL .\\tmp\\temp.txt
	)
	CALL :mariadb_create_default_bin
	ECHO MariaDB-!choosen_mariadb_version! installed.
) ELSE (
	IF EXIST .\\mariadb\\mariadb-!choosen_mariadb_version! (
		RMDIR .\\mariadb\\mariadb-!choosen_mariadb_version!
	)
	ECHO MariaDB-!choosen_mariadb_version! failed to install.
)

IF EXIST .\\tmp\\mariadb-!choosen_mariadb_version!.zip (
	DEL .\\tmp\\mariadb-!choosen_mariadb_version!.zip
)
PAUSE
GOTO mariadb_menu

:mariadb_version
CALL :mariadb_print_versions
PAUSE
GOTO mariadb_menu

:mariadb_set_default_version
ECHO Getting installed MariaDB versions...
CALL :mariadb_get_local_versions
IF !mariadb_local_versions_count! LEQ 0 (
	ECHO MariaDB not installed.
	PAUSE
	GOTO mariadb_menu
)

POWERSHELL -Command "$content=Get-Content -Path .\\default.conf | Out-String; $matches=[regex]::matches($content, 'mariadb=mariadb-([0-9\.]+)'); if($matches.Count -gt 0) {$ver=$matches.Groups[1].Value; Write-Output \"mariadb-$ver\"} else {Write-Output mariadb-0.0.0}" > .\\tmp\\temp.txt
SET /p mariadb_ver=<.\\tmp\\temp.txt
DEL .\\tmp\\temp.txt

FOR /L %%i IN (1,1,!mariadb_local_versions_count!) DO (
	IF "mariadb-!mariadb_local_versions[%%i]!" == "!mariadb_ver!" (
		ECHO MariaDB-!mariadb_local_versions[%%i]! [DEFAULT]
	) ELSE (
		ECHO MariaDB-!mariadb_local_versions[%%i]!
	)
)
SET choosen_mariadb_version=
SET /p choosen_mariadb_version=Set MariaDB version as default: 
FOR /f "tokens=* delims=" %%a IN ("!choosen_mariadb_version!") DO SET choosen_mariadb_version=%%~a
IF "!choosen_mariadb_version!"=="" (
  ECHO Version can't be empty
  PAUSE
  GOTO mariadb_menu
)

SET installed=false
FOR /L %%i IN (1,1,!mariadb_local_versions_count!) DO (
	IF !mariadb_local_versions[%%i]! == !choosen_mariadb_version! (
		SET installed=true
	)
)
IF "!installed!" == "false" (
	ECHO MariaDB-!choosen_mariadb_version! is not installed.
	PAUSE
	GOTO mariadb_menu
)
ECHO Update default MariaDB version...
POWERSHELL -Command "(Get-Content .\\default.conf) -replace 'mariadb=(mariadb-([0-9.]*))?', 'mariadb=mariadb-!choosen_mariadb_version!' | Set-Content .\\default.conf"
CALL :mariadb_create_default_bin
PAUSE
GOTO mariadb_menu

:mariadb_start
IF NOT EXIST .\\mariadb\\bin\\mysqld.bat (
	ECHO MariaDB is not installed
	PAUSE
	GOTO mariadb_menu
)

POWERSHELL -Command "tasklist | findstr /i mysqld | Select-Object -First 1" > .\\tmp\temp.txt
SET count=0
FOR /f %%a IN (.\\tmp\temp.txt) DO (
	SET /a count+=1
)
DEL .\\tmp\temp.txt
IF !count!==0 (
	POWERSHELL -Command "$content=Get-Content -Path .\\default.conf | Out-String; $matches=[regex]::matches($content, 'mariadb=mariadb-([0-9\.]+)'); if($matches.Count -gt 0) {$ver=$matches.Groups[1].Value; Write-Output \"mariadb-$ver\"} else {Write-Output mariadb-0.0.0}" > .\\tmp\\temp.txt
	SET /p mariadb_ver=<.\\tmp\\temp.txt
	DEL .\\tmp\\temp.txt
	START /min /b .\\mariadb\\!mariadb_ver!\\bin\\mysqld.exe
) ELSE (
	ECHO MariaDB already started
)
CALL :mariadb_status
PAUSE
GOTO mariadb_menu

:mariadb_stop
IF NOT EXIST .\\mariadb\\bin\\mysqld.bat (
	ECHO MariaDB is not installed
	PAUSE
	GOTO mariadb_menu
)

POWERSHELL -Command "tasklist | findstr /i mysqld | Select-Object -First 1" > .\\tmp\temp.txt
SET count=0
FOR /f %%a IN (.\\tmp\temp.txt) DO (
	SET /a count+=1
)
DEL .\\tmp\temp.txt
IF !count! GTR 0 (
	POWERSHELL -Command "Stop-Process -Id (Get-Process -Name mysqld).Id -Force"
)
CALL :mariadb_status
PAUSE
GOTO mariadb_menu

:mariadb_restart
IF NOT EXIST .\\mariadb\\bin\\mysqld.bat (
	ECHO MariaDB is not installed
	PAUSE
	GOTO mariadb_menu
)

POWERSHELL -Command "tasklist | findstr /i mysqld | Select-Object -First 1" > .\\tmp\temp.txt
SET count=0
FOR /f %%a IN (.\\tmp\temp.txt) DO (
	SET /a count+=1
)
DEL .\\tmp\temp.txt
IF !count! GTR 0 (
	POWERSHELL -Command "Stop-Process -Id (Get-Process -Name mysqld).Id -Force"
)
IF EXIST .\\mariadb\\bin\\mysqld.bat (
	POWERSHELL -Command "$content=Get-Content -Path .\\default.conf | Out-String; $matches=[regex]::matches($content, 'mariadb=mariadb-([0-9\.]+)'); if($matches.Count -gt 0) {$ver=$matches.Groups[1].Value; Write-Output \"mariadb-$ver\"} else {Write-Output mariadb-0.0.0}" > .\\tmp\\temp.txt
	SET /p mariadb_ver=<.\\tmp\\temp.txt
	DEL .\\tmp\\temp.txt
	START /min /b .\\mariadb\\!mariadb_ver!\\bin\\mysqld.exe
)
CALL :mariadb_status
PAUSE
GOTO mariadb_menu

:mariadb_uninstall
CALL :mariadb_get_local_versions
IF !mariadb_local_versions_count! LEQ 0 (
	ECHO MariaDB not installed.
	PAUSE
	GOTO mariadb_menu
)
FOR /L %%j IN (1,1,!mariadb_local_versions_count!) DO (
	ECHO MariaDB-!mariadb_local_versions[%%j]!
)

SET choosen_mariadb_version=
SET /p choosen_mariadb_version=Uninstall MariaDB Version: 
FOR /f "tokens=* delims=" %%a IN ("!choosen_mariadb_version!") DO SET choosen_mariadb_version=%%~a
IF "!choosen_mariadb_version!"=="" (
  ECHO Version can't be empty
  PAUSE
  GOTO mariadb_menu
)
SET installed=false
FOR /L %%j IN (1,1,!mariadb_local_versions_count!) DO (
	IF !mariadb_local_versions[%%j]! == !choosen_mariadb_version! (
		SET installed=true
	)
)

IF "!installed!" == "false" (
	ECHO MariaDB-!choosen_mariadb_version! is not installed.
	PAUSE
	GOTO mariadb_menu
)

SET y=false
SET /p continue=Do you want continue uninstall MariaDB-!choosen_mariadb_version! [Y/N]?
IF "!continue!" == "y" (
	SET y=true
) ELSE IF "!continue!" == "Y" (
	SET y=true
)
	
IF "!y!" == "true" (
	POWERSHELL -Command "tasklist | findstr /i mysqld | Select-Object -First 1" > .\\tmp\temp.txt
	SET count=0
	FOR /f %%a IN (.\\tmp\temp.txt) DO (
		SET /a count+=1
	)
	DEL .\\tmp\temp.txt
	IF !count! GTR 0 (
		POWERSHELL -Command "Stop-Process -Id (Get-Process -Name mysqld).Id -Force"
	)
	IF EXIST .\\mariadb\\mariadb-!choosen_mariadb_version! (
		RMDIR /S /Q .\\mariadb\\mariadb-!choosen_mariadb_version!
	)
	ECHO Update MariaDB default version...
	CALL :mariadb_create_default_bin
	ECHO MariaDB-!choosen_mariadb_version! uninstalled.
) ELSE (
	ECHO Uninstallation cancelled.
)
PAUSE
GOTO mariadb_menu

:exit
exit /b 0

ENDLOCAL