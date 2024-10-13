@echo off
SETLOCAL EnableDelayedExpansion
SET userAgent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.3
SET php_local_versions_count=0
SET php_net_versions_count=0
SET php_net_archive_versions_count=0
SET php_net_release_versions_count=0
SET php_local_versions=
SET php_net_versions=
SET php_net_release_versions=
SET php_net_archive_versions=
CD /d "%~dp0"

GOTO :prepare_directory

:main_menu
CLS
ECHO ========================================================
ECHO					  MAIN MENU
ECHO ========================================================
ECHO 1. PHP
ECHO 2. Apache
ECHO 3. MySQL/MariaDB
ECHO 4. Exit
CHOICE /C 1234 /M "Pilih menu"
IF ERRORLEVEL 4 GOTO exit
IF ERRORLEVEL 3 GOTO mysql_menu
IF ERRORLEVEL 2 GOTO apache_menu
IF ERRORLEVEL 1 GOTO php_menu

:prepare_directory
IF NOT EXIST ".\\default.conf" (COPY NUL ".\\default.conf")
IF NOT EXIST ".\\tmp\\" (MKDIR ".\\tmp\\")
IF NOT EXIST ".\\php\\" (
	MKDIR ".\\php\\"
) ELSE (
	CALL :get_local_php_versions
	IF %php_local_versions_count% GTR 0 AND NOT EXIST ".\\php\\bin" (
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
IF %ERRORLEVEL% NEQ 0 (
	RMDIR "%~f2"
	ECHO Failed to unzip
) ELSE (
	DEL %~f1
)
EXIT /b

:php_menu
CLS
ECHO ========================================================
ECHO					  PHP MENU
ECHO ========================================================
ECHO 1. Download and Install
ECHO 2. List Version
ECHO 3. Set Default Version
ECHO 4. Uninstall
ECHO 5. Back
CHOICE /C 12345 /M "Pilih menu"
IF ERRORLEVEL 5 GOTO main_menu
IF ERRORLEVEL 4 GOTO uninstall_php
IF ERRORLEVEL 3 GOTO set_default_php_version
IF ERRORLEVEL 2 GOTO php_version
IF ERRORLEVEL 1 GOTO dowload_and_install_php
PAUSE
GOTO main_menu

:get_net_php_versions
IF NOT DEFINED php_net_versions[1] (
	POWERSHELL -Command "Invoke-WebRequest -UserAgent '%userAgent%' -Uri https://windows.php.net/downloads/releases/archives/ -OutFile .\\tmp\\php_archives_version.html"
	POWERSHELL -Command ^
		"$content=Get-Content -Path .\\tmp\\php_archives_version.html | Out-String;" ^
		"$matches=[regex]::matches($content, '/downloads/releases/archives/php-([0-9\.]+)-Win32-(vc|vs|VC|VS)\d+-x(86|64).zip');" ^
		"$versions=@();" ^
		"foreach($match in $matches) { $versions+=$match.Groups[1].Value };" ^
		"$versions = $versions | Sort-Object -Unique; Write-Output $versions" > .\\tmp\temp.txt
	DEL .\\tmp\\php_archives_version.html
	POWERSHELL -Command "Invoke-WebRequest -UserAgent '%userAgent%' -Uri https://windows.php.net/downloads/releases/ -OutFile .\\tmp\\php_releases_version.html"
	FOR /f "delims=" %%a IN (.\\tmp\\temp.txt) DO (
		SET /a php_net_archive_versions_count+=1
		SET "php_net_archive_versions[!php_net_archive_versions_count!]=%%a"
		SET /a php_net_versions_count+=1
		SET "php_net_versions[!php_net_versions_count!]=%%a"
	)
	DEL .\\tmp\\temp.txt
	
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

:get_local_php_versions
POWERSHELL -Command "$content = Get-ChildItem -Path '.\\php' -Directory; $matches = [regex]::matches($content, 'php-([0-9\.]+)'); $versions = @(); foreach($match in $matches) {$versions += $match.Groups[1].Value}; Write-Output $versions" > .\\tmp\\temp.txt
SET php_local_versions=
SET php_local_versions_count=0
for /f "delims=" %%a in (.\\tmp\\temp.txt) do (
	SET /a php_local_versions_count += 1
	SET "php_local_versions[!php_local_versions_count!]=%%a"
)
DEL .\\tmp\\temp.txt
EXIT /b

:print_php_versions
ECHO Fetching PHP Versions...
CALL :get_net_php_versions
CALL :get_local_php_versions
FOR /L %%i IN (1,1,%php_net_versions_count%) DO (
	SET installed=false
	FOR /L %%j IN (1,1,%php_local_versions_count%) DO (
		IF "!php_net_versions[%%i]!" == "!php_local_versions[%%j]!" (
			SET installed=true
		)
	)

	IF "!installed!"=="false" (
		ECHO PHP version: !php_net_versions[%%i]!
	)
)
FOR /L %%i IN (1,1,%php_local_versions_count%) DO (
	ECHO PHP version: !php_local_versions[%%i]! [INSTALLED]
)
EXIT /b

:php_version
CALL :print_php_versions
PAUSE
GOTO php_menu

:apache_menu
CLS
ECHO ========================================================
ECHO					  APACHE MENU
ECHO ========================================================
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

:mysql_menu
CLS
ECHO ========================================================
ECHO					  MYSQL MENU
ECHO ========================================================
ECHO 1. Download and Install
ECHO 2. List Version
ECHO 3. Set Default Version
ECHO 4. Uninstall
ECHO 5. Back
CHOICE /C 12345 /M "Pilih menu"
IF ERRORLEVEL 5 GOTO main_menu
PAUSE
GOTO main_menu

:exit
exit /b 0
