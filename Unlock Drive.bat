@echo off
rem This uses the fix where drive letter is swapped to another letter and back.
rem Uses letter %interimLetter%:\ as interim letter. Uses %endLetter%:\ as expected drive letter.
rem Uses %~dp0BitLBackup.vhdx as file to replace.
rem 
rem Requires user to input password. (The BDEUnlock command does allow unlocking from file,
rem but this makes security pointless.)
rem Requires admin command prompt.
rem
rem Volume numbers are 0-based. Worth noting subst'd stuff like X:\ do not show up.
rem 
rem SET THESE BEFORE RUNNING
set "interimLetter=P"
set "endLetter=Z"
set "vhdPath=%~dp0BitLBackup.vhdx"

echo Opening "%vhdPath%" as %endLetter%:\ (interim letter %interimLetter%:)...
rem Check for admin permissions
net session >nul 2>&1
if not errorLevel 0 (
	echo FATAL ERROR: Not running as admin. DiskPart requires admin permissions.
	pause
	exit
)

pause
rem Check no %interimLetter%\ drive connected, if so, ask to continue and remove the letter
echo select volume %interimLetter%: | diskpart | find "The volume you selected is not valid or does not exist." > nul
rem errorlevel 0 means found it
IF not errorlevel 0 (
	rem TODO: Currently unsafe, as %interimLetter%:\ may not be virtual disk file we expect it to be. Prompt first.
	echo %interimLetter%:\ drive mounted at start.
	choice /C YN /N /M "Press Y to REMOVE %interimLetter%: DRIVE LETTER from whatever it's attached to [Y/N]? "
	if errorlevel 2 (
		pause
		exit
	)
	echo "Removing %interimLetter% drive letter..." 
	(
	echo select volume=%interimLetter%:
	echo remove letter=%interimLetter%
	) | diskpart > nul
	echo Done, waiting for 15 seconds as per docs...
	timeout /T 15 /NOBREAK > nul
)

rem Check virtual disk is not already connected
rem note that a disk that is detached may still show up as status "Added", type "Unknown"
rem When actually attached, status "Attached, not open" and type "Expandable"
(echo list vdisk | diskpart | findstr /C:"%vhdPath%" | findstr "Expandable") > nul
rem errorlevel 0 means found it
IF errorlevel 0 (
	echo Warning: Disk already attached. Performing dismount.
	choice /C YN /N /M "Press Y to continue [Y/N]? "
	if errorlevel 2 (
		pause
		exit
	)
	echo Dismounting...
	(
	echo select vdisk file=VHDPATH
	echo detach vdisk
	) | diskpart > nul
	echo Waiting for 15 seconds as per docs...
	timeout /T 15 /NOBREAK > nul
)

rem Generate unlock/lock scripts for BitLocker.
SETLOCAL EnableDelayedExpansion
rem Check no %endLetter%:\ drive connected
echo select volume %endLetter%: | diskpart | find "The volume you selected is not valid or does not exist."
rem errorlevel 0 means found it
IF not errorlevel 0 (
	echo FATAL ERROR
	echo %endLetter%:\ drive mounted at start. Dismount it, and run script again.
	pause
	exit
)

echo list volume | diskpart > "%~dp0diskout.txt"
rem If there's 10 volumes, they will be numbered 0-9.
rem findstr finds 10 matches, and new volume index is 10, so no reason to increment.
set volumeNum=
(findstr /R /C:"Volume [0-9][0-9 ] " "%~dp0diskout.txt" | find /C " ") > "%~dp0volumenum.txt"
for /F "delims=" %%A in (%~dp0volumenum.txt) do set volumeNum=%%A

rem empty file, then append all lines with NEWVOLINDEX replaced
break> %~dp0DiskPart_PreUnlockDynamic.txt
break> %~dp0DiskPart_PostUnlockDynamic.txt
for /F "delims=" %%A in (%~dp0DiskPart_PreUnlockTemplate.txt) do (
	set "string=%%A"
	set "modified=!string:NEWVOLINDEX=%volumeNum%!"
	set "string=!modified!"
	set "modified=!string:ENDLETTER=%endLetter%!"
	set "string=!modified!"
	set "modified=!string:VHDPATH=%vhdPath%!"
	echo !modified!>> %~dp0DiskPart_PreUnlockDynamic.txt
)
for /F "delims=" %%A in (%~dp0DiskPart_PostUnlockTemplate.txt) do (
	set "string=%%A"
	set "modified=!string:NEWVOLINDEX=%volumeNum%!"
	set "string=!modified!"
	set "modified=!string:INTERIMLETTER=%interimLetter%!"
	set "string=!modified!"
	set "modified=!string:ENDLETTER=%endLetter%!"
	set "string=!modified!"
	set "modified=!string:VHDPATH=%vhdPath%!"
	echo !modified!>> %~dp0DiskPart_PostUnlockDynamic.txt
)

start "Mounting encrypted drive..." "C:\Windows\System32\diskpart.exe" /s "%~dp0DiskPart_PreUnlockDynamic.txt" > nul

echo Completed mount, still drive unlocking to do.
echo Press a key to open password prompt...
pause
rem Any services that use %endLetter%:\ drive you might want to stop here.

endlocal
:userUnlock
echo Running unlock drive, please enter password...
rem The drive is unlocked on letter %interimLetter%:, then rewritten to %endLetter%:
start "Waiting for unlock" /WAIT bdeunlock %interimLetter%: > nul
echo Expected decrypted, waiting for 15 seconds as per docs...

timeout /T 15 /NOBREAK > nul
rem Should be decrypted now. If it is, the filesystem will show up valid, otherwise as Unkno[wn]
(echo list volume | diskpart | findstr /C:"Volume %volumeNum%" | findstr "Unkno") > nul
rem errorlevel 0 means found it, so if not found
IF errorlevel 0 (
	choice /C YN /N /M "Did not decrypt properly. [Y/N]? "
	if errorlevel 2 (
		pause
		exit
	)
	goto userUnlock
)

start "Reassigning encrypted drive letter..." /WAIT "C:\Windows\System32\diskpart.exe" /s "%~dp0DiskPart_PostUnlockDynamic.txt" > nul

rem Any services that use %endLetter%:\ drive you might want to restart here.
echo Completed.
pause
exit