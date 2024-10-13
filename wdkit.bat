@echo off
SETLOCAL EnableDelayedExpansion
CD /d "%~dp0"

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
