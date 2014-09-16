#####################################
#  Function ToolboxUpgrade
#  Parametres : fileNamePrefix, scriptType, topologyName, upgradeName, inputFileName, pathScript, pathInput, pathStatus, pathLog, pathConf, toLaunch, cryptoKey, separator, standAlone
#  $type : UnScriptChapeau
#  $description : v1.4.201409151700
#
##################################### 

#Parameters
Param(
	[string]$fileNamePrefix = 'applicativeUpgrade', #correspond a 'accountName'
	[string]$datacenterCode,
	[string]$topologyName,
	[string]$upgradeName,
	[string]$scriptType = 'relay',
	[string]$inputFileName = "$fileNamePrefix.csv", #equivaut a $fileNamePrefix+".csv"
	[string]$confMatrixFileName = "matrixUpgrade.csv",
	[string]$confDatacenterFileName = "vCenterConfigData.csv",
	[string]$confVmToolsVersionFileName = "vmToolsVersion.csv",
	[string]$sshConfDataFileName = "sshConfigData.csv",
	[string]$pathSshFile = "c:\Config\",
	[string]$pathScript = ".\scripts\",
	[string]$pathInput = ".\input\",
	[string]$pathStatus = ".\statuts\",
	[string]$pathLog = ".\log\",
	[string]$pathConf = ".\conf\",
	[string]$pathTemp = ".\temp\", #pour gerer l'avancement des installations
	[string]$teraTermMacroPath = "C:\Progra~2/TeraTermPortable/App/TeraTerm/",#"C:/Users/Administrateur/Desktop/TeraTermPortable/App/TeraTerm/",
	[string]$fileLog,
	[string]$repriseFile = "$($fileNamePrefix)_$($scriptType)_$($datacenterCode)_$($topologyName)_$($upgradeName)_repriseFile.sav",
	[string]$toLaunch = 'no',
	[int]$nbRetry = 10,
	[int]$timeOut = 10, #10*15min => 2h30m
	[int]$timer = 900, #10 minute, c'est le decalage entre l'installation firmware/locale sur le cucm pub et le reste
	[string]$ttlScriptName = "scriptTemp.ttl",
	[string]$separator = ";",
	[System.Byte[]]$cryptoKey = (3,210,1,3,52,18,227,122,79,1,2,23,42,54,38,233,34,7,43,2,15,5,35,1), # la cle de cryptage utilise pour crypter et decrypter le fichier vCenterConfigData.csv
	[System.Byte[]]$sshCryptoKey = (9,26,134,57,18,7,137,122,64,11,9,45,38,190,83,244,33,7,108,248,14,1,235,2), # la cle de cryptage utilise pour crypter et decrypter le fichier sshConfigData.csv
	[int]$repriseLvl,
	[int]$standAlone = 0, # si a 1 => on ne passe pas par VHM
	[int]$uisCryped = 0, # si a 1 => utilisation du sshCryptoKey sur les passwords des VMs
	[int]$logTeraterm = 1, # si a 1 => on redirige la sortie standart de teraterm vers un fichier qui sera créé dans la racine du projet (sur la toolbox)
	[string]$prompt = "admin:"
)

$fileStatusPending = "$($fileNamePrefix)_$($scriptType)_PENDING.status"
$fileStatusOk = "$($fileNamePrefix)_$($scriptType)_OK.status"
$fileStatusKo = "$($fileNamePrefix)_$($scriptType)_KO.status"
$currentDate = Get-Date -f "yyMMddHHmmss"
if([string]::IsNullOrEmpty($fileLog)){
	$fileLog = $fileNamePrefix+"_"+$currentDate+".log"
}
$fileStatus = ""
$fileStatusInt = ""
$pathTempTtlScript = "tempScriptsTTL/"
if($separator -eq "defaut"){
	$separator = ";"
}
if($standAlone){
	Start-Sleep 2 # tempo de 2 secondes pour laisser le temps au script parent de finir correctement
	$oldpathTemp = $pathTemp
	$pathTemp = "$($pathTemp)/toolbox/"
}

#Se placer au niveau parent du dossier des scripts
$myOldPath = Get-Location
$myCurrentPath = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent
Set-Location $myCurrentPath
Set-Location ".."
$myCurrentPath = Get-Location

#Fonctions logger
Function Log-Start{
	<#
	.SYNOPSIS
		Creer le fichier de log
	.DESCRIPTION
		Creer le fichier de log, si il n'existe pas deja. De plus si le chemin du fichier n'existe pas, le creer egalement.
	.INPUTS
		Aucun
	.OUTPUTS
		Le fichier de log cree
	.EXAMPLE
		Log-Start
	#>
	Process{
		$sFullPath = $pathLog + "\" + $fileLog
		#creation du dossier si non existence
		if(-not (Test-Path -path $pathLog)){
			New-Item -Name $pathLog -ItemType directory
		}
		#Creation du fichier si non existence
		If(-not (Test-Path -path $sFullPath)){
			New-Item -Path $pathLog -Name $fileLog -ItemType File
		}
	}
}
 
Function Log-Write{
	<#
	.SYNOPSIS
		Ecrire dans le fichier de log
	.DESCRIPTION
		Ajouter une nouvelle ligne a la fin du fichier de log
	.PARAMETER LineValue
		Obligatoire. La chaine de caractere que l'on veux rejouter au fichier de log
	.INPUTS
		Voir le champ "PARAMETER" au dessus
	.OUTPUTS
		Aucun
	.EXAMPLE
		Log-Write -LineValue "Ceci est une nouvelle ligne qui sera ajoute a la fin du fichier de log."
	#>
	Param ([Parameter(Mandatory=$true)][string]$LineValue)
	Process{
		$currentTime = Get-Date -f "yyMMddHHmmss"
        Add-Content -Path "$($pathLog)\$fileLog" -Value "$($currentTime) - `t$LineValue"
		#Write to screen for debug mode
		Write-Debug $LineValue
	}
}

#Fonctions Install-Vm
Function Install-Vm{
	<#
	.SYNOPSIS
		Lancer l'installation de l'iso monte sur la VM
	.DESCRIPTION
		Se connecte en ssh sur la VM (via TeraTerm) et execute l'installation de l'iso monte
	.PARAMETER vmName
		Obligatoire. Le nom de la machine virtuel sur laquelle on lancera l'installation.
	.PARAMETER vmIp
		Obligatoire. L'adresse IP de la machine virtuel sur laquelle on lancera l'installation.
	.INPUTS
		Voir les champs "PARAMETER" au dessus
	.OUTPUTS
		Aucun
	.EXAMPLE
		Install-Vm -vmName "myVirtualServer" -vmIp "1.2.3.4"
	#>
	Param (	[Parameter(Mandatory=$true)][string]$vmName,
			[Parameter(Mandatory=$true)][string]$vmIp,
			[Parameter(Mandatory=$true)][string]$isoName,
			[Parameter(Mandatory=$false)][string]$optionNumber = 1,
			[Parameter(Mandatory=$false)][string]$optionName = "",
			[Parameter(Mandatory=$false)][string]$stopServices = "0"
	)
	Process{
		Log-Write "`tInstall-VM - $($vmName) ($($vmIp)) - $($isoName)"
		
		#Recuperer le login et le mot de passe pour se connecter en ssh sur la machine virtuelle
		$authentification = $sshConfDataFileMap["$vmName"]
		if([string]::IsNullOrEmpty($authentification)){
			throw "ERROR - Le fichier de conf ssh ne contient pas les donnees de la machine : $($sVmVcenterName)"
		}
		$tAuthentification = $authentification.split("$($separator)")
		$vmLogin = $tAuthentification[0]
		$vmPassword = $tAuthentification[1]
		if($uisCryped -gt 0){
			Try{
				$mdpCryptedSecureString = ConvertTo-SecureString ($vmPassword) -key $sshCryptoKey
				$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($mdpCryptedSecureString)
				$vmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 
			}Catch{
				$ErrorMessage = $_.Exception.Message
				throw "Impossible de decrypter le mot de passe du server virtuel: $($vmName) ($($vmIp)) avec la cle - $ErrorMessage"
			}
		}
		
		#retrait du '(1)' s'il y en a dans le nom de l'iso
		$isoNameSplitted = $isoName.split("(")
		$isoName = $isoNameSplitted[0]
		
		#recuperation de la version
		$isoVersion = "NoVersionInIsoName"
		$isoVersionSplitted = $isoName.split("_")
		$sizeTab = [int]$isoVersionSplitted.length - 1
		if($sizeTab -gt 0){
			$isoVersionTemp = $isoVersionSplitted[$sizeTab]
			$isoVersionSplitted = $isoVersionTemp.split('.')
			$sizeTab = [int]$isoVersionSplitted.length
			if($sizeTab -gt 3){
				$isoVersion = $isoVersionSplitted[0] + '.' + $isoVersionSplitted[1] + '.' + $isoVersionSplitted[2] + '.' + $isoVersionSplitted[3]
			}
		}
		
		#Le nom du fichier d'avancement
		$fileName = "Install_$($isoName)_On_$vmName"
		$theTimeLog = Get-Date -f "yyMMddHHmmss"
		$fileLogName = $fileName + '_'
		
		[string]$sRestartVM=""
		if(-not([string]::IsNullOrEmpty($optionName))){
			#si une option, alors il faut redemarrer les vms apres l'install de l'option (langue)
			$isoName = $optionName
			$fileName = "Install_$($isoName)_On_$vmName"
			
			$sRestartVM=@"
:RESTART
pause 5
wait '$($prompt)'
if result > 0 then
	goto GO_TO_RESTART
else
	pause 5
	wait '$($prompt)'
	if result > 0 then
		goto GO_TO_RESTART
	else
		pause 5
		wait '$($prompt)'
		if result > 0 then
			goto GO_TO_RESTART
		else
			pause 5
			wait '$($prompt)'
			if result > 0 then
				goto GO_TO_RESTART
			else
				pause 5
				wait '$($prompt)'
				if result > 0 then
					goto GO_TO_RESTART
				else
					pause 5
					wait '$($prompt)'
					if result > 0 then
						goto GO_TO_RESTART
					else
						goto KO_WAIT_TIMEOUT
					endif
				endif
			endif
		endif
	endif
endif

:GO_TO_RESTART
sendln 'utils system restart'
wait 'Do you really want to restart ?' 'Enter (yes/no)'
if result = 1 then
	pause 4
	goto PUSH_YES
elseif result = 2 then
	pause 2
	goto PUSH_YES
else
	pause 2
	goto ERROR1
endif

:PUSH_YES
pause 1
sendln '' ;ligne pour debug
pause 1
sendln 'yes'
wait 'Warning: Restart could take up to 5 minutes.' 'Shutting down Service Manager. Please wait' 'Enter (yes/no)?'
if result = 1 then
	pause 2
	goto SUCCESS
elseif result = 2 then
	pause 2
	goto SUCCESS
elseif result = 3 then
	pause 1
	goto PUSH_YES
else
	pause 2
	goto ERROR2
endif

:SUCCESS
pause 2
filecreate fhandleOK '$($fileName).ok'
filewrite fhandleOK 'Restart (pour le locale) lance'
fileclose fhandleOK
goto EXIT

:ERROR1
pause 2
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'TimeOut - L_appel de la commande restart (pour le locale) n_a pas eu l_effet escompte'
fileclose fhandleKO
goto EXIT

:ERROR2
pause 2
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'TimeOut - La confirmation n_a pas eu l_effet escompte (pour le locale)'
fileclose fhandleKO
goto EXIT

:KO_WAIT_TIMEOUT
filecreate fhandleTIMEOUT '$($fileName).ko'
filewrite fhandleTIMEOUT 'TimeOut - Pas de reponses du prompt apres 15min d_attente (pas possible de relancer la VM...)'
fileclose fhandleTIMEOUT
goto EXIT
"@
		}
		
		#par defaut, un simple show version active pour voir si l'iso est installe
		[string]$sStopServicesandShowVersionActive = @"
sendln 'show version active'
wait '$($isoName)' 'Version: $($isoVersion)' '$($prompt)'; contient exactement une ligne avec le nom de l'iso monte ou pas
if result = 1 then
	pause 2
	goto EXIST
elseif result = 2 then
	pause 2
	goto EXIST
else
	pause 2
	goto UPGRADE
endif
"@

		#Si c'est l'installation locale pour un unity 
		#=> utilisation de show cuc locales
		#=> il faut arréter les services "Connection Conversation Manager" et "Connexion Mixer" (c'est le redémarrage des VMs qui les relanceront)
		if($stopServices -eq "1"){
			$sStopServicesandShowVersionActive=@"
sendln 'utils service stop Service Manager'
pause 300; attente de 5 minutes le temps de la prise en compte de l_arret des services
sendln 'show cuc locales'
wait '$($isoName)' 'Version: $($isoVersion)' '$($prompt)'; contient exactement une ligne avec le nom de l'iso monte ou pas
if result = 1 then
	pause 2
	goto EXIST
elseif result = 2 then
	pause 2
	goto EXIST
else
	pause 2
	goto UPGRADE
endif
"@
		}
		
		$cmdTTL =@"
;Variables
timeout = 150 ; variable utilisee par le wait, si le wait ne donne rien apres ce temps la (en seconde), le wait sort en erreur
str2int intLogTeraterm '$($logTeraterm)'
if result = 0 goto KO_LOGTERATERMNOINT

;Set-Location
setdir '$($myCurrentPath)'
setdir '$($pathTemp)'

:CONNECT
connect '$($vmIp):22 /ssh /auth=password /user=$($vmLogin) /passwd=$($vmPassword) /timeout=30 /nosecuritywarning'
if result<2 goto ERROR_CONNECT
pause 5
wait '$($prompt)'
if result = 0 goto KO_TIMEOUT

if intLogTeraterm = 1 then
	goto START_LOG
else
	goto CHECK_EXIST
endif

:START_LOG
setsync 1
inputFileName = '$($myCurrentPath)\log_$($fileName).log'
logopen inputFileName 0 1
logwrite #13#10'@@@@@@@@@@@@@@@@ Start_of_Install_Debug_Log_at_$($theTimeLog) @@@@@@@@@@@@@@'#13#10

:CHECK_EXIST
$sStopServicesandShowVersionActive

:UPGRADE
sendln 'utils system upgrade initiate'
wait 'Source:' 'Assume control'; <=> 'Another user session is currently configuring an upgrade' ('An upgrade is already in progress')
if result = 0 then
	goto CANCELING_CURRENT_UPGRADE
elseif result = 2 then
	pause 2
	sendln 'yes'
endif
;On prend le dernier choix qui est en principe le DVD/CD
wait 'Please select an option (1 - 1' 'Please select an option (1 - 2' 'Please select an option (1 - 3' 'Please select an option (1 - 4' 'Please select an option (1 - 5' 'Please select an option (1 - 6'
if result = 0 then
	goto CANCELING_CURRENT_UPGRADE
elseif result = 1 then
	pause 2
	sendln '1'
elseif result = 2 then
	pause 2
	sendln '2'
elseif result = 3 then
	pause 2
	sendln '3'
elseif result = 4 then
	pause 2
	sendln '4'
elseif result = 5 then
	pause 2
	sendln '5'
elseif result = 6 then
	pause 2
	sendln '6'
endif

:LOOP_LOOP
wait 'Please select an option' 'Unable to mount the local file system.' 'The given directory was located and searched but no valid options or upgrades were available.' 'Assume control' 'Directory ()' 'Directory (' 'Directory [' 'Please enter SMTP Host Server'
if result = 0 then
	pause 2
	goto ERROR ;erreur inconnue
elseif result = 2 then
	pause 2
	goto ERROR_DISCONECT ;iso corrompue ou lecteur deconnecte
elseif result = 3 then
	pause 4
	sendln 'q'
	goto ERROR_UNCOMPATIBLE ;pas un upgrade compatible
elseif result = 4 then
	pause 2
	sendln 'yes'
	goto LOOP_LOOP ;on re-attends pour la suite
elseif result = 5 then
	pause 2
	sendln '/'
	goto LOOP_LOOP ;on re-attends pour la suite
elseif result = 6 then
	pause 2
	sendln ''
	goto LOOP_LOOP ;on re-attends pour la suite
elseif result = 7 then
	pause 2
	sendln '/'
	goto LOOP_LOOP ;on re-attends pour la suite
elseif result = 8 then
	pause 2
	sendln ''
	goto LOOP_LOOP ;on re-attends pour la suite
endif
pause 2
sendln '$($optionNumber)'

postUpgradeToDo=0

:START_INSTALL
wait 'Start Refresh Upgrade (yes/no)' 'Start installation (yes/no)' 'Downloaded' 'Post Upgrade Information' 'Initiate the switch version process after upgrade is complete' 'Switch to new version if the upgrade is successful' 'Automatically switch versions if the upgrade is successful'
if result = 0 then
	goto ERROR_CONFIRM
elseif result = 3 then
	pause 60
	goto START_INSTALL
elseif result = 4 then
	pause 2
	postUpgradeToDo=1
	goto START_INSTALL
elseif result = 5 then
	pause 2
	postUpgradeToDo=1
	goto START_INSTALL
elseif result > 5 then
	pause 2
	sendln 'yes';
	wait 'Start Refresh Upgrade (yes/no)' 'Start installation (yes/no)'
	if result = 0 goto ERROR_CONFIRM2
endif
pause 2
sendln 'yes'

:WAIT
pause 15
wait 'Installation of $($isoName).iso failed' 'Installation of $($isoName) failed' 'Successfully installed $($isoName).iso' 'Successfully installed $($isoName)' 'Successfully installed ' 'The system upgrade was successful.';The system upgrade was successful.  A switch version request has been submitted.  This can take a long time depending on the platform and database size.  Please continue to monitor the switchover process from the Cisco Unified Communications OS Platform CLI.  Please verify the system restarts and the correct version is active.
if result = 0 then
	goto WAIT ; boucle infini possible (d'ou la possibilite de sortir en timeout)
elseif result = 1 then ; l'installation a echoue (failed)
	goto FAILED
elseif result = 2 then ; l'installation a echoue (failed)
	goto FAILED
endif

:SWITCH
;switch version
if postUpgradeToDo = 1 then
	wait '$($prompt)'
	if result = 0 then
		pause 300
		wait '$($prompt)'
		if result = 0 then
			pause 300
			wait '$($prompt)'
			if result = 0 then
				pause 300
				wait '$($prompt)'
				if result = 0 then
					pause 300
					wait '$($prompt)'
					if result = 0 then
						pause 300
						wait '$($prompt)'
						if result = 0 then
							pause 300
							wait '$($prompt)'
							if result = 0 then
								goto KO_WAIT_FOR_SWITCH
							endif
						endif
					endif
				endif
			endif
		endif
	endif
	
	sendln 'utils system switch-version'
	wait 'Enter (yes/no)' 'Do you really want to switch between versions'
	if result = 0 then
		goto ERROR_CONFIRM_SWITCH
	elseif result > 0 then
		pause 1
		:LOOP_FORCE_YES
		sendln ''
		sendln 'yes'
		wait 'Waiting for Switch Version to complete' 'Enter (yes/no)'
		if result > 1 then
			goto LOOP_FORCE_YES
		endif
		pause 5
		goto OK_WITHOUT_CLOSE
	endif
endif

$sRestartVM

:OK
pause 2
filecreate fhandleOK '$($fileName).ok'
filewrite fhandleOK 'L_iso a ete correctement installee sur cette machine'
fileclose fhandleOK
goto EXIT

:OK_WITHOUT_CLOSE
pause 2
filecreate fhandleOK '$($fileName).ok'
filewrite fhandleOK 'L_iso a ete correctement installee/switchee sur cette machine'
fileclose fhandleOK
goto EXIT_WITHOUT_CLOSE

:EXIST
pause 2
filecreate fhandleExist '$($fileName).exist'
filewrite fhandleExist 'L_iso monte est deja installee sur cette machine'
fileclose fhandleExist
goto EXIT

:EXIT
if intLogTeraterm = 1 then
	pause 2
	logwrite #13#10'@@@@@@@@@@@@@@@@@@@@@@ End_of_Install_Debug_Log @@@@@@@@@@@@@@@@@'#13#10
	logclose
	setsync 0
endif
pause 2
disconnect 0 ;deconnection de teraterm sans confirmation
closett ;fermeture de teraterm
END

:EXIT_WITHOUT_CLOSE
if intLogTeraterm = 1 then
	pause 2
	logwrite #13#10'@@@@@@@@@@@@@@@@@@@@@@ End_of_Install_Debug_Log @@@@@@@@@@@@@@@@@'#13#10
	logclose
	setsync 0
endif
pause 900
END

:CANCELING_CURRENT_UPGRADE
sendln 'q'
wait '$($prompt)'
sendln 'utils system upgrade cancel'
wait '$($prompt)'
if result = 0 goto ERROR_CANCEL
goto UPGRADE

:FAILED
filecreate fhandleFAILED '$($fileName).ko'
filewrite fhandleFAILED 'Une erreur est apparue lors de l_installation de l_iso sur cette machine'
fileclose fhandleFAILED
goto EXIT

:ERROR
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'Une erreur est apparue dans la procedure d_installation de l_iso sur cette machine'
fileclose fhandleKO
goto EXIT

:ERROR_DISCONECT
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'Une erreur est apparue car l_iso est corrompue ou le lecteur est deconnecte'
fileclose fhandleKO
goto EXIT

:ERROR_UNCOMPATIBLE
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'Une erreur est apparue car l_iso n_est pas un upgrade compatible (ou il est deja installe)'
fileclose fhandleKO
goto EXIT

:ERROR_CONFIRM
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'Une erreur est apparue, la demande de confirmation n_a pas eu lieu'
fileclose fhandleKO
goto EXIT

:ERROR_CONFIRM2
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'Une erreur est apparue apres la confirmation du switch automatique (la demande de confirmation n_a pas eu lieu)'
fileclose fhandleKO
goto EXIT

:ERROR_CANCEL
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'Une erreur est apparue lors de la tentative d_anulation de l_upgrade en cours'
fileclose fhandleKO
goto EXIT

:ERROR_CONNECT
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'TimeOut - Impossible de se connecter en SSH a la machine ($($vmIp)) via teraterm'
fileclose fhandleKO
goto EXIT

:KO_TIMEOUT
filecreate fhandleTIMEOUT '$($fileName).ko'
filewrite fhandleTIMEOUT 'Impossible de se connecter au serveur virtuel, pas de reponses'
fileclose fhandleTIMEOUT
goto EXIT

:KO_LOGTERATERMNOINT
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'Impossible de convertir en un entier le parametre pour le debug mod (teraterm log)'
fileclose fhandleKO
goto EXIT

:KO_WAIT_FOR_SWITCH
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'TimeOut - Impossible de switcher la version via teraterm (apres plus d_une demie heure d_attente)'
fileclose fhandleKO
goto EXIT

:ERROR_CONFIRM_SWITCH
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'Une erreur est apparue, la demande de confirmation du switch version n_a pas eu lieu'
fileclose fhandleKO
goto EXIT
"@

		if(-not (Test-Path "$($teraTermMacroPath)/$($pathTempTtlScript)/")){
			New-Item -Path "$($teraTermMacroPath)/" -Name "$pathTempTtlScript" -ItemType directory
		}
		echo $null > "$($teraTermMacroPath)/$($pathTempTtlScript)/$($vmIp)$ttlScriptName"
		add-content "$($teraTermMacroPath)/$($pathTempTtlScript)/$($vmIp)$ttlScriptName" $cmdTTL

		#$commandOld = "$teraTermPath/TeraTermPortable.exe $($tConfDatacenter[0]):22 /ssh /auth=password /user=$($tConfDatacenter[1]) /passwd=$($tConfDatacenter[2])"
		$command = "$($teraTermMacroPath)/ttpmacro.exe $($teraTermMacroPath)/$($pathTempTtlScript)/$($vmIp)$ttlScriptName"
		invoke-expression -Command $command
	}
}

#Fonctions Upgrade-Group
Function Upgrade-Group{
	<#
	.SYNOPSIS
		Gestion de l'upgrade sur un 'groupe'
	.DESCRIPTION
		Gere le retry, les logs, les exceptions et timeouts, et lance les installations des l'iso montes sur chacune des VMs du 'group'
	.PARAMETER applicationType
	Obligatoire. Le type d'application du group pour l'upgrade (CUCM, UCCX, CUPS, UCNX, OTHER).
	.PARAMETER role
	Obligatoire. Le role du groupe sur lequel on lancera l'installation (P => publisher; S => subscriber; other => autre).
	.PARAMETER upgradeType
	Obligatoire. Le type de l'upgrade du groupe sur lequel on lancera l'installation (Major, Firmware, Locale).
	.INPUTS
		Voir les champs "PARAMETER" au dessus
	.OUTPUTS
		Aucun
	.EXAMPLE
		Upgrade-Group -applicationType "CUCM" -role "P" -upgradeType "Major"
	#>
	Param (	[Parameter(Mandatory=$true)][string]$applicationType,
			[Parameter(Mandatory=$true)][string]$role,
			[Parameter(Mandatory=$true)][string]$upgradeType
	)
	Process{
		Log-Write "Upgrade-Group - $($upgradeType) : $($applicationType);$($role)"
		$vmNames = $vmTypeRoleToVmNameMap["$($applicationType);$($role)"]
		if(-not ([string]::IsNullOrEmpty($vmNames))){
			$vmNamesSplitted = $vmNames.split("$($separator)")
			$isOk = "0"
			for($i=0; ($i -le $nbRetry) -and ($isOk -eq "0"); $i++){
				$retryTitle = ""
				if($i -gt 0){
					Log-Write "Retry - groupe : $($applicationType);$($role) - $i"
					$retryTitle = "Retry$($i)_"
				}
				$numberInstalls = 0
				Foreach ( $vmName in $vmNamesSplitted ) {
					if(-not ([string]::IsNullOrEmpty($vmName))){
						#Recuperer le nom de l'iso monte qui sera installe s'il ne l'est pas deja sur la machine virtuelle
						$isoNameWithExt = $confVmNameToIsoNameMap["$($vmName)"]
						if(-not ([string]::IsNullOrEmpty($isoNameWithExt))){
							$isoName = $isoNameWithExt.substring(0,[int]$isoNameWithExt.Length -4) #retrait de l'extension .iso
							
							$numberInstalls++
							$vmIp = $vmNameToVmIpMap[$vmName]
							$fileStatusIntOld = $fileStatusInt
							$fileStatusInt = Update-FileStatusInt -status "PENDING" -description "$($retryTitle)Upgrade$($upgradeType)-$($applicationType)-$($role)-$($numberInstalls)"
							
							Install-Vm -vmName $vmName -vmIp $vmIp -isoName $isoName
						}
					}
				}
				
				$countTimeOut = 0
				do {
					if($logTeraterm -eq 1){ #debugMod
						Log-Write "DEBUG - Wait $($timer) secondes"
					}
					Start-Sleep $timer #wait 15 minutes
					$countTimeOut++
					$numberFiles = Get-ChildItem -Path "$pathTemp" | Measure-Object
					$numberComplete = $numberFiles.Count -eq $numberInstalls
					if($logTeraterm -eq 1){ #debugMod
						Log-Write "DEBUG - Wait number $($countTimeOut) - number of files found : $($numberFiles.Count)"
					}
				} while (!$numberComplete -and ($countTimeOut -le $timeOut))
				
				$listFiles = get-childitem "$pathTemp" | Sort-Object LastWriteTime
				if(!$numberComplete){#timeout
					Log-Write "TimeOut - groupe : $($applicationType);$($role) - $($numberFiles.Count)/$($numberInstalls)"
					foreach($installFile in $listFiles){
						$fileName = $installFile.Name
						Log-Write "`t$fileName"
					}
				}else{ #le nombre de fichiers est ok
					$ListKo = $listFiles | where {$_.extension -eq ".ko"}
					$listKoSize = $ListKo | Measure-Object
					if($listKoSize.Count -gt 0){#si au moins une installation de KO
						$fileOk = [int]$numberInstalls - $listKoSize.Count
						Log-Write "Install KO - groupe : $applicationType;$role - $fileOk/$numberInstalls"
						foreach($installFile in $listFiles){
							$fileName = $installFile.Name
							$moreInformation = ""
							$installFileContent = Get-Content ("$pathTemp\$fileName")
							$moreInformation = $installFileContent
							Log-Write "`t$($fileName) - $($moreInformation)"
						}
					}else{
						$ListExist = $listFiles | where {$_.extension -eq ".exist"}
						$listExistSize = $ListExist | Measure-Object
						if($listExistSize.Count -eq $numberInstalls){
							$isOk = "2" #que des exist
						}else{
							$isOk = "1" #pas de ko
							if($logTeraterm -eq 1){ #debugMod
								Log-Write "DEBUG - Wait $($timer) minutes - attendre que la(les) VM(s) ait(aient) redemarree(s) (apres un swithc)"
							}
							Start-Sleep ($timer) #attendre que la(les) VM(s) ait(aient) redemarree(s) (apres un switch)
						}
					}
				}
				Remove-Item "$($pathTemp)\*"
			}
			if($isOk -eq "1"){#Install OK
				Log-Write "Install OK - groupe : $applicationType;$role - $($numberFiles.Count)/$numberInstalls"
			}elseif($isOk -eq "2"){#Install OK (que des exist)
				Log-Write "Upgrade OK (deja a jour) - groupe : $applicationType;$role - $($numberFiles.Count)/$numberInstalls"
			}elseif(!$numberComplete){#TimeOut
				throw "ERROR - TIMEOUT - L'upgrade $upgradeType du groupe : '$applicationType;$role' a echoue -> voir les logs"
			}else{#Install KO
				throw "ERROR - KO - L'upgrade $upgradeType du groupe : '$applicationType;$role' a echoue -> voir les logs"
			}
		}
	}
}

#Fonctions Upgrade-Locale-Group
Function Upgrade-Locale-Group{
	<#
	.SYNOPSIS
		Gestion de l'upgrade locale (langue) sur un 'groupe', Install la totalite des options presentes sur l'iso
	.DESCRIPTION
		Gere le retry, les logs, les exceptions et timeouts, et lance les installations des ISOs LOCALE montes sur chacune des VMs du 'group'
	.PARAMETER applicationType
	Obligatoire. Le type d'application du group pour l'upgrade locale (CUCM, UCCX, CUPS, UCNX, UNITY, OTHER).
	.PARAMETER role
	Obligatoire. Le role du groupe sur lequel on lancera l'installation locale (P => publisher; S => subscriber; other => autre).
	.PARAMETER upgradeType
	Non obligatoire. Le type de l'upgrade du groupe sur lequel on lancera l'installation (Major, Firmware, Locale).
	.INPUTS
		Voir les champs "PARAMETER" au dessus
	.OUTPUTS
		Aucun
	.EXAMPLE
		Upgrade-Group -applicationType "CUCM" -role "P"
	#>
	Param (	[Parameter(Mandatory=$true)][string]$applicationType,
			[Parameter(Mandatory=$true)][string]$role,
			[Parameter(Mandatory=$false)][string]$upgradeType = "Locale"
	)
	Process{
		Log-Write "Upgrade-Locale-Group - $($upgradeType) : $($applicationType);$($role)"
		$vmNames = $vmTypeRoleToVmNameMap["$($applicationType);$($role)"]
		if(-not ([string]::IsNullOrEmpty($vmNames))){
			$vmNamesSplitted = $vmNames.split("$($separator)")
			
			#lister les options de l'iso a installer
			$nbToInstallMax = 1
			$isoLocaleListOptionsFileMap = @{}
			Foreach ( $vmName in $vmNamesSplitted ) {
				if(-not ([string]::IsNullOrEmpty($vmName))){
					$vmIp = $vmNameToVmIpMap[$vmName]
					#Recuperer le nom de l'iso monte
					$isoNameWithExt = $confVmNameToIsoNameMap["$($vmName)"]
					if(-not ([string]::IsNullOrEmpty($isoNameWithExt))){
						$isoName = $isoNameWithExt.substring(0,[int]$isoNameWithExt.Length -4) #retrait de l'extension .iso
						if([string]::IsNullOrEmpty($isoLocaleListOptionsFileMap["$($isoName);0"])){
							$isOk = "0"
							for($i=0; ($i -le $nbRetry) -and ($isOk -eq "0"); $i++){
								if($i -gt 0){
									Log-Write "Retry - Get-Install-Options for $($vmName) - $i"
								}
							
								$isoLocaleListOptionsFileMap["$($isoName);0"] = "ok"
								$nbToInstall = 0
								Get-Install-Options -vmName $vmName -vmIp $vmIp -isoName $isoName
								
								if($logTeraterm -eq 1){ #debugMod
									Log-Write "DEBUG - Wait 5 minutes"
								}
								Start-Sleep 300 #wait 5 minutes
								do {
									$countTimeOut++
									if((Test-Path -path "$($pathTemp)\$($vmName).ok") -or (Test-Path -path "$($pathTemp)\$($vmName).ko")){
										$numberComplete = $true
									}elseif($countTimeOut -le $timeOut){
										if($logTeraterm -eq 1){ #debugMod
											Log-Write "DEBUG - Wait number $($countTimeOut) - pas de fichier $($vmName).ok ou $($vmName).ko trouve"
										}
										Start-Sleep $timer #wait 15 minutes
									}
								} while (!$numberComplete -and ($countTimeOut -le $timeOut))
								
								if(!$numberComplete){#timeout
									Log-Write "TimeOut - le fichier attendu n'a pas ete trouve : $($applicationType);$($role) - 0/1"
								}else{ #le nombre de fichiers est ok
									if(Test-Path -path "$($pathTemp)\$($vmName).ok"){
										$isOk = "1"
										Log-Write "Get-Install-Options on $($vmName) - OK"
									}else{
										$moreInformation = ""
										$getFileContent = Get-Content ("$pathTemp\$($vmName).ko")
										$moreInformation = $getFileContent
										Log-Write "Get-Install-Options on $($vmName) - KO - $($vmName).ko - $($moreInformation)"
									}
								}
							}
							
							#Lire la list des options et les recuperer par iso
							if(Test-Path -path "$($pathTemp)\$($vmName).txt"){
								$listFileLines = Get-Content ("$($pathTemp)\$($vmName).txt")
								$startCount = 0
								Log-Write "`tlisting des options de l'iso $($isoName):"
								Foreach ( $line in $listFileLines ) {
									if(-not([string]::IsNullOrEmpty($line))){
										$nbToInstall++
										$isoLocaleListOptionsFileMap["$($isoName);$($nbToInstall)"]=$line
										Log-Write "`t`t$($line)"
									}
								}
								Log-Write "L'iso contient $($nbToInstall) options (langue/cop) a installer"
								Remove-Item "$($pathTemp)\*"
								if($nbToInstall>$nbToInstallMax){
									$nbToInstallMax = $nbToInstall
								}
							}else{
								Log-Write "`tWARNING - la VM $($vmName) n'a pas permis d'avoir la liste des options de l'iso $($isoName)"
							}
						}
					}
				}
			}
			
			#Installer successivement toutes les options
			for($j=1; ($j -le $nbToInstallMax); $j++){
				$isOk = "0"
				for($i=0; ($i -le $nbRetry) -and ($isOk -eq "0"); $i++){
					$retryTitle = ""
					if($i -gt 0){
						Log-Write "Retry - locale groupe : $($applicationType);$($role) - $i"
						$retryTitle = "Retry$($i)_"
					}
					Log-Write "$($retryTitle)Installation de l'option $($j) des ISOs (si existance)"
					$numberInstalls = 0
					Foreach ( $vmName in $vmNamesSplitted ) {
						if(-not ([string]::IsNullOrEmpty($vmName))){
							$stopServices="0"
							if(($applicationType -eq "UNITY") -and ($role -eq "other") -and ($upgradeType = "Locale")){
								$stopServices="1" 
							}
							#Recuperer le nom de l'iso monte qui sera installe s'il ne l'est pas deja sur la machine virtuelle
							$isoNameWithExt = $confVmNameToIsoNameMap["$($vmName)"]
							if(-not ([string]::IsNullOrEmpty($isoNameWithExt))){
								$isoName = $isoNameWithExt.substring(0,[int]$isoNameWithExt.Length -4) #retrait de l'extension .iso
								
								$numberInstalls++
								$optionName = $isoLocaleListOptionsFileMap["$($isoName);$($j)"]
								if(-not ([string]::IsNullOrEmpty($optionName))){
									$vmIp = $vmNameToVmIpMap[$vmName]
									$fileStatusIntOld = $fileStatusInt
									$fileStatusInt = Update-FileStatusInt -status "PENDING" -description "$($retryTitle)Upgrade$($upgradeType)-$($applicationType)-$($role)-$($numberInstalls)"
									
									Install-Vm -vmName $vmName -vmIp $vmIp -isoName $isoName -optionNumber $j -optionName $optionName -stopServices $stopServices
								}else{
									Log-Write "L'ISO $($isoName) de la VM $($vmName) ne possede pas d'option num $($j)"
								}
							}
						}
					}
					
					$countTimeOut = 0
					do {
						if($logTeraterm -eq 1){ #debugMod
							Log-Write "DEBUG - Wait $($timer) secondes"
						}
						Start-Sleep $timer #wait 15 minutes
						$countTimeOut++
						$numberFiles = Get-ChildItem -Path "$pathTemp" | Measure-Object
						$numberComplete = $numberFiles.Count -eq $numberInstalls
						if($logTeraterm -eq 1){ #debugMod
							Log-Write "DEBUG - Wait number $($countTimeOut) - number of files found : $($numberFiles.Count)"
						}
					} while (!$numberComplete -and ($countTimeOut -le $timeOut))
					
					$listFiles = get-childitem "$pathTemp" | Sort-Object LastWriteTime
					if(!$numberComplete){#timeout
						Log-Write "TimeOut - locale groupe : $($applicationType);$($role) - $($numberFiles.Count)/$($numberInstalls)"
						foreach($installFile in $listFiles){
							$fileName = $installFile.Name
							Log-Write "`t$fileName"
						}
					}else{ #le nombre de fichiers est ok
						$ListKo = $listFiles | where {$_.extension -eq ".ko"}
						$listKoSize = $ListKo | Measure-Object
						if($listKoSize.Count -gt 0){#si au moins une installation de KO
							$fileOk = [int]$numberInstalls - $listKoSize.Count
							Log-Write "Install KO - locale groupe : $applicationType;$role - $fileOk/$numberInstalls"
							foreach($installFile in $listFiles){
								$fileName = $installFile.Name
								$moreInformation = ""
								$installFileContent = Get-Content ("$pathTemp\$fileName")
								$moreInformation = $installFileContent
								Log-Write "`t$($fileName) - $($moreInformation)"
							}
						}else{
							$ListExist = $listFiles | where {$_.extension -eq ".exist"}
							$listExistSize = $ListExist | Measure-Object
							if($listExistSize.Count -eq $numberInstalls){
								$isOk = "2" #que des exist
							}else{
								$isOk = "1" #pas de ko
								if($logTeraterm -eq 1){ #debugMod
									Log-Write "DEBUG - Wait $($timer) minutes - attendre que la(les) VM(s) ait(aient) redemarree(s) (apres un redemarrage locale)"
								}
								Start-Sleep ($timer) #besoin d'attendre, car les vm ne redémarrent pas avec un locale, mais il est fait dans le script
							}
						}
					}
					Remove-Item "$($pathTemp)\*"
				}
				if($isOk -eq "1"){#Install OK
					Log-Write "Install OK - locale groupe : $applicationType;$role - $($numberFiles.Count)/$numberInstalls"
				}elseif($isOk -eq "2"){#Install OK (que des exist)
					Log-Write "Upgrade OK (deja a jour) - locale groupe : $applicationType;$role - $($numberFiles.Count)/$numberInstalls"
				}elseif(!$numberComplete){#TimeOut
					throw "ERROR - TIMEOUT - L'upgrade $upgradeType : '$applicationType;$role' a echoue -> voir les logs"
				}else{#Install KO
					throw "ERROR - KO - L'upgrade $upgradeType : '$applicationType;$role' a echoue -> voir les logs"
				}
			}
		}
	}
}

Function Get-Install-Options{
	<#
	.SYNOPSIS
		Pre-Lancer l'installation de l'iso monte sur la VM pour y recuperer la list des options proposees par l'iso
	.DESCRIPTION
		Se connecte en ssh sur la VM (via TeraTerm) et lance le debut de l'installation de l'iso monte, fait un fichier et quite
	.PARAMETER vmName
		Obligatoire. Le nom de la machine virtuel sur laquelle on lancera l'installation (qui donnera le nom du fichier cree).
	.PARAMETER vmIp
		Obligatoire. L'adresse IP de la machine virtuel sur laquelle on lancera la pre-installation.
	.PARAMETER isoName
		Obligatoire. Le nom de l'iso que l'on veut parcourir pour en connaitre ses options.
	.INPUTS
		Voir les champs "PARAMETER" au dessus
	.OUTPUTS
		Le fichier listant les options de l'iso
	.EXAMPLE
		Get-Install-Options -vmName "myVirtualServer" -vmIp "1.2.3.4" -isoName "cucm_locale_fr-es"
	#>
	Param (	[Parameter(Mandatory=$true)][string]$vmName,
			[Parameter(Mandatory=$true)][string]$vmIp,
			[Parameter(Mandatory=$true)][string]$isoName
	)
	Process{
		Log-Write "`tGet-Install-Options - $($vmName) ($($vmIp)) - $($isoName)"
		
		#Recuperer le login et le mot de passe pour se connecter en ssh sur la machine virtuelle
		$authentification = $sshConfDataFileMap["$vmName"]
		if([string]::IsNullOrEmpty($authentification)){
			throw "ERROR - Le fichier de conf ssh ne contient pas les donnees de la machine : $($sVmVcenterName)"
		}
		$tAuthentification = $authentification.split("$($separator)")
		$vmLogin = $tAuthentification[0]
		$vmPassword = $tAuthentification[1]
		if($uisCryped -gt 0){
			Try{
				$mdpCryptedSecureString = ConvertTo-SecureString ($vmPassword) -key $sshCryptoKey
				$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($mdpCryptedSecureString)
				$vmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 
			}Catch{
				$ErrorMessage = $_.Exception.Message
				throw "Impossible de decrypter le mot de passe du server virtuel: $($vmName) ($($vmIp)) avec la cle - $ErrorMessage"
			}
		}
		
		#Le nom du fichier d'avancement
		$fileName = "$vmName"
		$theTimeLog = Get-Date -f "yyMMddHHmmss"
		
		$cmdTTL =@"
;Variables
timeout = 150 ; variable utilisee par le wait, si le wait ne donne rien apres ce temps la (en seconde), le wait sort en erreur
str2int intLogTeraterm '$($logTeraterm)'
if result = 0 goto KO_LOGTERATERMNOINT

;Set-Location
setdir '$($myCurrentPath)'
setdir '$($pathTemp)'

:CONNECT
connect '$($vmIp):22 /ssh /auth=password /user=$($vmLogin) /passwd=$($vmPassword) /timeout=30 /nosecuritywarning'
if result<2 goto ERROR_CONNECT
pause 5
wait '$($prompt)'
if result = 0 goto KO_TIMEOUT

setsync 1
if intLogTeraterm = 1 then
	goto START_LOG
else
	goto UPGRADE
endif

:START_LOG
inputFileName = '$($myCurrentPath)\log_$($fileName).log'
logopen inputFileName 0 1
logwrite #13#10'@@@@@@@@@@@@@@@@ Start_of_Install_Debug_Log_at_$($theTimeLog) @@@@@@@@@@@@@@'#13#10

:UPGRADE
sendln 'utils system upgrade initiate'
wait 'Source:' 'Assume control'; <=> 'Another user session is currently configuring an upgrade' ('An upgrade is already in progress')
if result = 0 then
	goto CANCELING_CURRENT_UPGRADE
elseif result = 2 then
	pause 2
	sendln 'yes'
endif
;On prend le dernier choix qui est en principe le DVD/CD
wait 'Please select an option (1 - 1' 'Please select an option (1 - 2' 'Please select an option (1 - 3' 'Please select an option (1 - 4' 'Please select an option (1 - 5' 'Please select an option (1 - 6'

; preparation du listage des options de l'iso
continueLoop=1
fileopen listFile '$($fileName).txt' 1

if result = 0 then
	goto CANCELING_CURRENT_UPGRADE
elseif result = 1 then
	pause 2
	sendln '1'
elseif result = 2 then
	pause 2
	sendln '2'
elseif result = 3 then
	pause 2
	sendln '3'
elseif result = 4 then
	pause 2
	sendln '4'
elseif result = 5 then
	pause 2
	sendln '5'
elseif result = 6 then
	pause 2
	sendln '6'
endif

:LOOP_LOOP
wait 'Available options and upgrades in' 'Unable to mount the local file system.' 'The given directory was located and searched but no valid options or upgrades were available.' 'Assume control' 'Directory ()' 'Directory (' 'Directory [' 'Please enter SMTP Host Server'
if result = 0 then
	pause 2
	goto ERROR ;erreur inconnue
elseif result = 2 then
	pause 2
	goto ERROR_DISCONECT ;iso corompue ou lecteur deconecte
elseif result = 3 then
	pause 4
	sendln 'q'
	goto ERROR_UNCOMPATIBLE ;pas un upgrade compatible
elseif result = 4 then
	pause 2
	sendln 'yes'
	goto LOOP_LOOP ;on re-attends pour la suite
elseif result = 5 then
	pause 2
	sendln '/'
	goto LOOP_LOOP ;on re-attends pour la suite
elseif result = 6 then
	pause 2
	sendln ''
	goto LOOP_LOOP ;on re-attends pour la suite
elseif result = 7 then
	pause 2
	sendln '/'
	goto LOOP_LOOP ;on re-attends pour la suite
elseif result = 8 then
	pause 2
	sendln ''
	goto LOOP_LOOP ;on re-attends pour la suite
endif

;enregistrement des lignes
counter = 0
while continueLoop=1
	recvln
	theLine=inputstr
	notSave=1
	strscan theLine ')'
	if result>0 then
		notSave=0
	endif
	strscan theLine 'options and upgrades in'
	if result>0 then
		notSave=1
	endif
	; lire 1 ligne
	if notSave = 0 then
		; lire 1 ligne
		counter = counter + 1
		strscan theLine 'q) quit'
		if result>0 then
			continueLoop=0
		else
			; ecrire la ligne (le nom de l'option) dans le fichier
			numberToWithdraw = 6
			if counter<10 then
				numberToWithdraw = 5
			endif
			strlen theLine
			lengthOfOption = result - numberToWithdraw + 1
			strcopy theLine numberToWithdraw lengthOfOption substr; recuperation du nom de l'option 
			filewriteln listFile substr
		endif
	endif
endwhile
pause 2
;femer le fichier 'listOptions'
fileclose listFile

pause 2
sendln 'q'
	
:OK
pause 2
filecreate fhandleOK '$($fileName).ok'
filewrite fhandleOK 'Les option de l_iso ont ete correctement lue'
fileclose fhandleOK
goto EXIT

:EXIT
if intLogTeraterm = 1 then
	pause 2
	logwrite #13#10'@@@@@@@@@@@@@@@@@@@@@@ End_of_Install_Debug_Log @@@@@@@@@@@@@@@@@'#13#10
	logclose
endif
setsync 0
pause 2
disconnect 0 ;deconnection de teraterm sans confirmation
closett ;fermeture de teraterm
END

:CANCELING_CURRENT_UPGRADE
sendln 'q'
wait '$($prompt)'
sendln 'utils system upgrade cancel'
wait '$($prompt)'
if result = 0 goto ERROR_CANCEL
goto UPGRADE

:ERROR
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'Une erreur est apparue dans la procedure d_installation de l_iso sur cette machine'
fileclose fhandleKO
goto EXIT

:ERROR_DISCONECT
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'Une erreur est apparue car l_iso est corompue ou le lecteur est deconecte'
fileclose fhandleKO
goto EXIT

:ERROR_UNCOMPATIBLE
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'Une erreur est apparue car l_iso n_est pas un upgrade compatible (ou il est deja installe)'
fileclose fhandleKO
goto EXIT

:ERROR_CANCEL
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'Une erreur est apparue lors de la tentative d_anulation de l_upgrade en cours'
fileclose fhandleKO
goto EXIT

:ERROR_CONNECT
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'TimeOut - Impossible de se connecter en SSH a la machine ($($vmIp)) via teraterm'
fileclose fhandleKO
goto EXIT

:KO_TIMEOUT
filecreate fhandleTIMEOUT '$($fileName).ko'
filewrite fhandleTIMEOUT 'Impossible de se connecter au serveur virtuel, pas de reponses'
fileclose fhandleTIMEOUT
goto EXIT

:KO_LOGTERATERMNOINT
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'Impossible de convertir en un entier le parametre pour le debug mod (teraterm log)'
fileclose fhandleKO
goto EXIT
"@

		if(-not (Test-Path "$($teraTermMacroPath)/$($pathTempTtlScript)/")){
			New-Item -Path "$($teraTermMacroPath)/" -Name "$pathTempTtlScript" -ItemType directory
		}
		echo $null > "$($teraTermMacroPath)/$($pathTempTtlScript)/$($vmIp)$ttlScriptName"
		add-content "$($teraTermMacroPath)/$($pathTempTtlScript)/$($vmIp)$ttlScriptName" $cmdTTL

		#$commandOld = "$teraTermPath/TeraTermPortable.exe $($tConfDatacenter[0]):22 /ssh /auth=password /user=$($tConfDatacenter[1]) /passwd=$($tConfDatacenter[2])"
		$command = "$($teraTermMacroPath)/ttpmacro.exe $($teraTermMacroPath)/$($pathTempTtlScript)/$($vmIp)$ttlScriptName"
		invoke-expression -Command $command
	}
}

#Fonctions Check-DB
Function Check-DB{
	<#
	.SYNOPSIS
		Verifie la base de donnee du cluster (via le PUB)
	.DESCRIPTION
		Se connecte en ssh sur la VM pub (via TeraTerm) et execute la verification de la DB
	.PARAMETER vmName
		Obligatoire. Le nom de la machine virtuel PUB sur laquelle on lancera la verif.
	.PARAMETER vmIp
		Obligatoire. L'adresse IP de la machine virtuel PUB sur laquelle on lancera la verif.
	.INPUTS
		Voir les champs "PARAMETER" au dessus
	.OUTPUTS
		Aucun
	.EXAMPLE
		Check-DB -vmName "myVirtualServerPub" -vmIp "1.2.3.4"
	#>
	Param (	[Parameter(Mandatory=$true)][string]$vmName,
			[Parameter(Mandatory=$true)][string]$vmIp
	)
	Process{
		Log-Write "`tCheck-DB - $($vmName) ($($vmIp))"
		
		#Recuperer le login et le mot de passe pour se connecter en ssh sur la machine virtuelle
		$authentification = $sshConfDataFileMap["$vmName"]
		if([string]::IsNullOrEmpty($authentification)){
			throw "ERROR - Le fichier de conf ssh ne contient pas les donnees de la machine : $($sVmVcenterName)"
		}
		$tAuthentification = $authentification.split("$($separator)")
		$vmLogin = $tAuthentification[0]
		$vmPassword = $tAuthentification[1]
		if($uisCryped -gt 0){
			Try{
				$mdpCryptedSecureString = ConvertTo-SecureString ($vmPassword) -key $sshCryptoKey
				$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($mdpCryptedSecureString)
				$vmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 
			}Catch{
				$ErrorMessage = $_.Exception.Message
				throw "Impossible de decrypter le mot de passe du server virtuel: $($vmName) ($($vmIp)) avec la cle - $ErrorMessage"
			}
		}
		
		#Le nom du fichier d'avancement
		$fileName = "$vmName"
		
		$cmdTTL =@"
;Variables
timeout = 120 ; variable utilisee par le wait, si le wait ne donne rien apres ce temps la (en seconde), le wait sort en erreur

;Set-Location
setdir '$($myCurrentPath)'
setdir '$($pathTemp)'

:CONNECT
connect '$($vmIp):22 /ssh /auth=password /user=$($vmLogin) /passwd=$($vmPassword) /timeout=30 /nosecuritywarning'
if result<2 goto ERROR_CONNECT
pause 5
wait '$($prompt)'
if result = 0 goto KO_TIMEOUT

:CHECK_DB
sendln 'utils dbreplication runtimestate'
wait 'Runtime state cannot be performed on a cluster with a single active node' '(0) PUB Setup Completed' '(1) PUB Setup Completed' '(3) PUB Setup Completed' '(4) PUB Setup Completed' '(0) Setup Completed' '(1) Setup Completed' '(3) Setup Completed' '(4) Setup Completed'
if result > 1 then
	pause 2
	goto ERROR
elseif result = 1 then
	pause 1
	goto WARNING
else
	pause 1
	goto OK
endif
	
:OK
pause 2
filecreate fhandleOK '$($fileName).ok'
filewrite fhandleOK 'Tous les RTMT sont a 2 => OK'
fileclose fhandleOK
goto EXIT

:WARNING
pause 2
filecreate fhandleExist '$($fileName).warn'
filewrite fhandleExist 'Impossible de verifier la base de donnees car le cluster n_a qu_un seul noeud actif'
fileclose fhandleExist
goto EXIT

:EXIT
pause 2
disconnect 0 ;deconnection de teraterm sans confirmation
closett ;fermeture de teraterm
END

:ERROR
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'Une erreur est apparue dans la base de donnees (un des RTMT est a 0, 1, 3 ou 4)'
fileclose fhandleKO
goto EXIT

:ERROR_CONNECT
filecreate fhandleKO '$($fileName).ko'
filewrite fhandleKO 'TimeOut - Impossible de se connecter en SSH a la machine ($($vmIp)) via teraterm'
fileclose fhandleKO
goto EXIT

:KO_TIMEOUT
filecreate fhandleTIMEOUT '$($fileName).ko'
filewrite fhandleTIMEOUT 'Impossible de se connecter au serveur virtuel, pas de reponses'
fileclose fhandleTIMEOUT
goto EXIT
"@

		if(-not (Test-Path "$($teraTermMacroPath)/$($pathTempTtlScript)/")){
			New-Item -Path "$($teraTermMacroPath)/" -Name "$pathTempTtlScript" -ItemType directory
		}
		echo $null > "$($teraTermMacroPath)/$($pathTempTtlScript)/$($vmIp)$ttlScriptName"
		add-content "$($teraTermMacroPath)/$($pathTempTtlScript)/$($vmIp)$ttlScriptName" $cmdTTL

		#$commandOld = "$teraTermPath/TeraTermPortable.exe $($tConfDatacenter[0]):22 /ssh /auth=password /user=$($tConfDatacenter[1]) /passwd=$($tConfDatacenter[2])"
		$command = "$($teraTermMacroPath)/ttpmacro.exe $($teraTermMacroPath)/$($pathTempTtlScript)/$($vmIp)$ttlScriptName"
		invoke-expression -Command $command
	}
}

#Fonctions CheckDB-And-Restart
Function CheckDB-And-Restart{
	<#
	.SYNOPSIS
		Verifier la base de donnee et redemarrer l'ensemble de machine dans l'ordre 'startOrder'
	.DESCRIPTION
		Verifier la base de donnee et redemarrer l'ensemble de machine dans l'ordre 'startOrder' d'input.
	.EXAMPLE
		CheckDB-And-Restart -upgradeType "Major"
	#>
	Param (	[Parameter(Mandatory=$true)][string]$upgradeType
	)
	Process{
		Log-Write "Verification de la base de donnee"
		$vmNames = $vmTypeRoleToVmNameMap["CUCM;P"]
		if(-not ([string]::IsNullOrEmpty($vmNames))){
			$vmNamesSplitted = $vmNames.split("$($separator)")
			$isOk = "0"
			$nbCheckPub = 0
			Foreach ( $vmName in $vmNamesSplitted ) {
				if(-not ([string]::IsNullOrEmpty($vmName))){
					#Verifier la base de donnee du cluster via le pub				
					$nbCheckPub++
					$vmIp = $vmNameToVmIpMap[$vmName]
					$fileStatusIntOld = $fileStatusInt
					$fileStatusInt = Update-FileStatusInt -status "PENDING" -description "CheckDB_$($upgradeType)$($nbCheckPub)"
					
					Check-DB -vmName $vmName -vmIp $vmIp
				}
			}
			
			$countTimeOut = 0
			do {
				if($logTeraterm -eq 1){ #debugMod
					Log-Write "DEBUG - Wait $($timer) secondes"
				}
				Start-Sleep $timer #wait 15 minutes
				$countTimeOut++
				$numberFiles = Get-ChildItem -Path "$pathTemp" | Measure-Object
				$numberComplete = $numberFiles.Count -eq $nbCheckPub
				if($logTeraterm -eq 1){ #debugMod
					Log-Write "DEBUG - Wait number $($countTimeOut) - number of files found : $($numberFiles.Count)"
				}
			} while (!$numberComplete -and ($countTimeOut -le $timeOut))
			
			$listFiles = get-childitem "$pathTemp" | Sort-Object LastWriteTime
			if(!$numberComplete){#timeout
				Log-Write "TimeOut - CheckDB - $($numberFiles.Count)/$($nbCheckPub)"
				foreach($checkedFile in $listFiles){
					$fileName = $checkedFile.Name
					Log-Write "`t$fileName"
				}
			}else{ #le nombre de fichiers est ok
				$ListKo = $listFiles | where {$_.extension -eq ".ko"}
				$listKoSize = $ListKo | Measure-Object
				$ListWarn = $listFiles | where {$_.extension -eq ".warn"}
				$listWarnSize = $ListWarn | Measure-Object
				if($listKoSize.Count -gt 0){#si au moins une installation de KO
					$fileOk = [int]$nbCheckPub - $listKoSize.Count
					Log-Write "CheckDB KO - $fileOk/$nbCheckPub"
					foreach($checkedFile in $listFiles){
						$fileName = $checkedFile.Name
						$moreInformation = ""
						$installFileContent = Get-Content ("$pathTemp\$fileName")
						$moreInformation = $installFileContent
						Log-Write "`t$($fileName) - $($moreInformation)"
					}
				}elseif($listWarnSize.Count -gt 0){#si au moins une installation de Warning
					$fileOk = [int]$nbCheckPub - $listKoSize.Count
					Log-Write "CheckDB Warning - Les serveurs virtuels 'publisher' en warning sont ceux appartenant a un cluster avec un seul noeud actif => impossible de verifier la DB"
					foreach($warnFile in $ListWarn){
						$fileName = $warnFile.Name
						Log-Write "`t$fileName"
					}
					$isOk = "1"
				}else{
					$isOk = "1"
				}
			}
			Remove-Item "$($pathTemp)\*"
			
			if($isOk -eq "1"){#CheckDB OK
				Log-Write "CheckDB OK - $($numberFiles.Count)/$nbCheckPub"
			}elseif(!$numberComplete){#TimeOut
				throw "ERROR - TIMEOUT - La verification de la Base de Donnees en mode $upgradeType a echoue -> voir les logs"
			}else{#Install KO
				throw "ERROR - KO - La verification de la Base de Donnees en mode $upgradeType a echoue -> voir les logs"
			}
		}else{
			Log-Write "CheckDB - non faite (car pas de cucm pub)"
		}
		
		Log-Write "Redemarrer les machines virtuelles dans le bon ordre (avec attente interne pour que la(les) VM(s) soi(en)t switchee(s))"
		$oldStartOrder = 0
		$numberRestart = 0
		$cancel = 0
		foreach ($vm in $vms){
			$sDataIpAddress = $vm.DataIpAddress
			$sVmVcenterName = $vm.vmVCenterName
			$sStartOrder = $vm.startOrder
			$iVmStartOrder = [int]$vm.startOrder
			if(($cancel -eq 0) -and (!([string]::IsNullOrEmpty($sVmVcenterName))) -and ($iVmStartOrder -ge 0)){
				
				#si cette VM a un start order different de la precedente => on attends la duree du timer pour que les VMs finissent le restart, puis on verifie s'il y a eu des erreurs
				if($sStartOrder -ne $oldStartOrder){
					if($oldStartOrder -ne 0){ #si pas premier passage
						
						#Attendre le redemarage des VMs
						Start-Sleep ($timer)

						#verifier si il y a des erreurs ou non
						$numberFiles = Get-ChildItem -Path "$pathTemp" | Measure-Object
						$isTimeOut = 0
						if($numberFiles.Count -lt $numberRestart){#TimeOut
							$cancel = 1
						}else{
							$listFiles = get-childitem "$pathTemp" | Sort-Object LastWriteTime
							foreach($restartedFile in $listFiles){
								$extensionFile = $restartedFile.Extension
								
								if($extensionFile -eq ".ko"){
									$cancel = 1 #anuler la boucle d'install sur les VMs
								}
							}
						}
					}
					#On enregistre l'ordre de redemarrage actuel de la VM pour la comparer avec la suivante
					$oldStartOrder = $sStartOrder
				}
				
				#Executer la commande (restart) si pas de cancel
				if($cancel -ne 1){
					Log-Write "`t$($sVmVcenterName)"
					
					#Recuperer le login et le mot de passe pour se connecter en ssh sur la machine virtuelle
					$authentification = $sshConfDataFileMap["$($sVmVcenterName)"]
					if([string]::IsNullOrEmpty($authentification)){
						throw "ERROR - Le fichier de conf ssh ne contient pas les donnees de la machine : $($sVmVcenterName)"
					}
					$tAuthentification = $authentification.split("$($separator)")
					$vmLogin = $tAuthentification[0]
					$vmPassword = $tAuthentification[1]
					if($uisCryped -gt 0){
						Try{
							$mdpCryptedSecureString = ConvertTo-SecureString ($vmPassword) -key $sshCryptoKey
							$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($mdpCryptedSecureString)
							$vmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 
						}Catch{
							$ErrorMessage = $_.Exception.Message
							throw "Impossible de decrypter le mot de passe du server virtuel: $($sVmVcenterName) ($($sDataIpAddress)) avec la cle - $ErrorMessage"
						}
					}
					
					$theTimeLog = Get-Date -f "yyMMddHHmmss"
					
					$cmdTTL =@"
;Variables
timeout = 60 ; variable utilisee par le wait, si le wait ne donne rien apres ce temps la (en seconde), le wait sort en erreur
str2int intLogTeraterm '$($logTeraterm)'
if result = 0 goto KO_LOGTERATERMNOINT

;Set-Location
setdir '$myCurrentPath'
setdir '$pathTemp'

:CONNECT
connect '$($sDataIpAddress):22 /ssh /auth=password /user=$vmLogin /passwd=$vmPassword /timeout=30 /nosecuritywarning'
if result<2 then
	goto RESTART1
else
	goto CONTINUE
endif

:RESTART1
pause 900
connect '$($sDataIpAddress):22 /ssh /auth=password /user=$vmLogin /passwd=$vmPassword /timeout=30 /nosecuritywarning'
if result<2 then
	goto RESTART2
else
	goto CONTINUE
endif

:RESTART2
pause 900
connect '$($sDataIpAddress):22 /ssh /auth=password /user=$vmLogin /passwd=$vmPassword /timeout=30 /nosecuritywarning'
if result<2 then
	goto RESTART3
else
	goto CONTINUE
endif

:RESTART3
pause 900
connect '$($sDataIpAddress):22 /ssh /auth=password /user=$vmLogin /passwd=$vmPassword /timeout=30 /nosecuritywarning'
if result<2 then
	goto RESTART4
else
	goto CONTINUE
endif

:RESTART4
pause 900
connect '$($sDataIpAddress):22 /ssh /auth=password /user=$vmLogin /passwd=$vmPassword /timeout=30 /nosecuritywarning'
if result<2 then
	goto ERROR_CONNECT
else
	goto CONTINUE
endif

:CONTINUE
pause 5
wait '$($prompt)'
if result = 0 goto KO_TIMEOUT

setsync 1
if intLogTeraterm = 1 then
	goto START_LOG
else
	goto RESTART
endif

:START_LOG
inputFileName = '$($myCurrentPath)\log_RestartVM$($sVmVcenterName).log'
logopen inputFileName 0 1
logwrite #13#10'@@@@@@@@@@@@@@@@ Start_of_Install_Debug_Log_at_$($theTimeLog) @@@@@@@@@@@@@@'#13#10

:RESTART
sendln 'utils system restart'
wait 'Do you really want to restart ?' 'Enter (yes/no)'
if result = 1 then
	pause 4
	goto PUSH_YES
elseif result = 2 then
	pause 2
	goto PUSH_YES
else
	pause 2
	goto ERROR1
endif

:PUSH_YES
pause 1
sendln '' ;ligne pour debug
pause 1
sendln 'yes'
wait 'Warning: Restart could take up to 5 minutes.' 'Shutting down Service Manager. Please wait' 'Enter (yes/no)?'
if result = 1 then
	pause 2
	goto SUCCESS
elseif result = 2 then
	pause 2
	goto SUCCESS
elseif result = 3 then
	pause 1
	goto PUSH_YES
else
	pause 2
	goto ERROR2
endif

:SUCCESS
pause 2
filecreate fhandleOK '$($sVmVcenterName).ok'
filewrite fhandleOK 'Restart lance'
fileclose fhandleOK
goto EXIT

:ERROR1
pause 2
filecreate fhandleKO '$($sVmVcenterName).ko'
filewrite fhandleKO 'TimeOut - L_appel de la commande restart n_a pas eu l_effet escompte'
fileclose fhandleKO
goto EXIT

:ERROR2
pause 2
filecreate fhandleKO '$($sVmVcenterName).ko'
filewrite fhandleKO 'TimeOut - La confirmation n_a pas eu l_effet escompte'
fileclose fhandleKO
goto EXIT

:ERROR_CONNECT
pause 2
filecreate fhandleKO '$($sVmVcenterName).ko'
filewrite fhandleKO 'TimeOut - Impossible de se connecter en SSH a la machine ($($sDataIpAddress)) via teraterm (apres 5 essaies sur 1 heure)'
fileclose fhandleKO
goto EXIT

:KO_TIMEOUT
filecreate fhandleTIMEOUT '$($sVmVcenterName).ko'
filewrite fhandleTIMEOUT 'Impossible de se connecter au serveur virtuel, pas de reponses'
fileclose fhandleTIMEOUT
goto EXIT

:KO_LOGTERATERMNOINT
filecreate fhandleKO '$($sVmVcenterName).ko'
filewrite fhandleKO 'Impossible de convertir en un entier le parametre pour le debug mod (teraterm log)'
fileclose fhandleKO
goto EXIT

:EXIT
if intLogTeraterm = 1 then
	pause 2
	logwrite #13#10'@@@@@@@@@@@@@@@@@@@@@@ End_of_Install_Debug_Log @@@@@@@@@@@@@@@@@'#13#10
	logclose
endif
setsync 0
pause 2
disconnect 0 ;deconnection de teraterm sans confirmation
closett ;fermeture de teraterm
END
"@

					# echo $cmdTTL > "$teraTermMacroPath/$($pathTempTtlScript)/$ttlScriptName"
					if(-not (Test-Path "$($teraTermMacroPath)/$($pathTempTtlScript)/")){
						New-Item -Path "$($teraTermMacroPath)/" -Name "$pathTempTtlScript" -ItemType directory
					}
					echo $null > "$($teraTermMacroPath)/$($pathTempTtlScript)/$($sDataIpAddress)$ttlScriptName"
					add-content "$($teraTermMacroPath)/$($pathTempTtlScript)/$($sDataIpAddress)$ttlScriptName" $cmdTTL
					
					$command = "$($teraTermMacroPath)/ttpmacro.exe $($teraTermMacroPath)/$($pathTempTtlScript)/$($sDataIpAddress)$ttlScriptName"
					invoke-expression -Command $command
					
					$numberRestart++
					
					$fileStatusIntOld = $fileStatusInt
					$fileStatusInt = Update-FileStatusInt -status "PENDING" -description "RestartVm$($numberRestart)"
				}
			}
		}
		
		$nbFileIsOk = "0"
		for($i=0; ($i -le $nbRetry) -and ($nbFileIsOk -eq "0"); $i++){
			$retryTitle = ""
			if($i -gt 0){
				Log-Write "Retry $i - Wait all VMs restarted"
				$retryTitle = "Retry$($i)_"
			}
			$fileStatusIntOld = $fileStatusInt
			$fileStatusInt = Update-FileStatusInt -status "PENDING" -description "$($retryTitle)WaitVMsRestarted$($numberRestart)"
			
			#Attendre le redemarage des dernieres VMs
			if($logTeraterm -eq 1){ #debugMod
				Log-Write "DEBUG - Wait Restart of last VM(s) - $($timer) secondes"
			}
			Start-Sleep ($timer)

			#verifier si il y a eu des erreurs ou non
			$listFiles = get-childitem "$pathTemp" | Sort-Object LastWriteTime
			$numberFiles = 0
			$errorRestart = ""
			$sepError = ""
			foreach($restartedFile in $listFiles){
				$fileName = $restartedFile.Name
				if(!([string]::IsNullOrEmpty($fileName))){
					$extensionFile = $restartedFile.Extension
					$moreInformation = ""
					if($extensionFile -eq ".ko"){
						$installFileContent = Get-Content ("$($pathTemp)\$($fileName)") -totalcount 1
						$moreInformation = $installFileContent
						$extensionSize = $extensionFile.length
						$vmNameSize = [int]($fileName.length - $extensionSize)
						$vmName = $fileName.Substring(0,[int]$vmNameSize)
						$errorRestart = $errorRestart + $sepError + $vmName
						if($sepError -eq ""){
							$sepError = ";"
						}
					}
					Log-Write "`t$($fileName)  $($moreInformation)"
					
					$numberFiles++
				}
			}
			
			if($numberFiles -eq $numberRestart){
				$nbFileIsOk = "1"
			}
		}
		#tempo de 5 secondes pour que le fichier status reste plus vieux que le tolaunch
		Start-Sleep 5
		
		#Suppression des fichiers temporaire
		Remove-Item "$($pathTemp)\*"
		
		#Gestion des cas d'erreures
		$isTimeOut = 0
		if($numberFiles -ne $numberRestart){
			$isTimeOut = 1
		}
		if(!([string]::IsNullOrEmpty($errorRestart))){
			throw "ERROR - Impossible de redemarrer la(les) machine(s): $errorRestart"
		}elseif($isTimeOut -eq 1){ #timeout
			Log-Write "TimeOut - RestartVM : $($numberFiles)/$($numberRestart)"
			throw "ERROR - TIMEOUT - L'installation/La mise a jour des VmWareTools des VMs a echoue -> voir les logs"
		}
	}
}

#Fonctions Check-VmTools
Function Check-VmTools{
	<#
	.SYNOPSIS
		Verifie l'etat des vmTools de chacune des VMs
	.DESCRIPTION
		Verifie si oui ou non les VMs ont besoin d'avoir un upgrade des vmtools. Retourne la liste des VMs avec un ";OK" ou ";toUpdate"
	#>
	Process{
		$numberVm = 0
		foreach ($vm in $vms){
			$sDataIpAddress = $vm.DataIpAddress
			$sVmVcenterName = $vm.vmVCenterName
			$iVmStartOrder = [int]$vm.startOrder
			
			if(!([string]::IsNullOrEmpty($sVmVcenterName)) -and ($iVmStartOrder -ge 0)){
				$numberVm++
				Log-Write "Check-VmTools for $sVmVcenterName"
				$fileStatusIntOld = $fileStatusInt
				$fileStatusInt = Update-FileStatusInt -status "PENDING" -description "CheckVmTools$($numberVm)"
				#Recuperer le login et le mot de passe pour se connecter en ssh sur la machine virtuelle
				$authentification = $sshConfDataFileMap["$($sVmVcenterName)"]
				$tAuthentification = $authentification.split("$($separator)")
				$vmLogin = $tAuthentification[0]
				$vmPassword = $tAuthentification[1]
				if($uisCryped -gt 0){
					Try{
						$mdpCryptedSecureString = ConvertTo-SecureString ($vmPassword) -key $sshCryptoKey
						$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($mdpCryptedSecureString)
						$vmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 
					}Catch{
						$ErrorMessage = $_.Exception.Message
						throw "Impossible de decrypter le mot de passe du server virtuel: $($sVmVcenterName) ($($sDataIpAddress)) avec la cle - $ErrorMessage"
					}
				}
				
				#Recuperer la version necessaire des vmTools sur cette machine
				$vmToolsVersion = $confVmNameToVmToolsVersionMap[$sVmVcenterName]
				
				$cmdTTL =@"
;Variables
timeout = 30 ; variable utilisee par le wait, si le wait ne donne rien apres ce temps la (en seconde), le wait sort en erreur

;Set-Location
setdir '$myCurrentPath'

:CONNECT
connect '$($sDataIpAddress):22 /ssh /auth=password /user=$($vmLogin) /passwd=$($vmPassword) /timeout=30 /nosecuritywarning'
if result<2 goto ERROR_CONNECT
pause 5
wait '$($prompt)'
if result = 0 goto KO_TIMEOUT

:CHECK_VERSION
sendln 'utils vmtools status'
wait '$vmToolsVersion' ; contient la version souhaitee
if result = 1 then
	pause 2
	goto UPDATED
else
	pause 2
	goto TO_UPDATE
endif

:UPDATED
pause 2
filecreate fhandleOK '$($pathTemp)/$($sVmVcenterName).OK'
filewrite fhandleOK 'La VM est a jour au niveau des vmTools'
fileclose fhandleOK
goto EXIT

:TO_UPDATE
pause 2
filecreate fhandleToUpdate '$($pathTemp)/$($sVmVcenterName).toUpdate'
filewrite fhandleToUpdate 'La VM n_est pas a jour au niveau de ses vmTools'
fileclose fhandleToUpdate
goto EXIT

:ERROR_CONNECT
pause 2
filecreate fhandleKO '$($pathTemp)/$($sVmVcenterName).ko'
filewrite fhandleKO 'TimeOut - Impossible de se connecter en SSH a la machine ($($sDataIpAddress)) via teraterm'
fileclose fhandleKO
goto EXIT

:KO_TIMEOUT
filecreate fhandleTIMEOUT '$($pathTemp)/$($sVmVcenterName).ko'
filewrite fhandleTIMEOUT 'Impossible de se connecter au serveur virtuel, pas de reponse'
fileclose fhandleTIMEOUT
goto EXIT

:EXIT
pause 2
disconnect 0 ;deconnection de teraterm sans confirmation
closett ;fermeture de teraterm
END
"@

				if(-not (Test-Path "$($teraTermMacroPath)/$($pathTempTtlScript)/")){
					New-Item -Path "$($teraTermMacroPath)/" -Name "$pathTempTtlScript" -ItemType directory
				}
				echo $null > "$($teraTermMacroPath)/$($pathTempTtlScript)/$($sDataIpAddress)$ttlScriptName"
				add-content "$($teraTermMacroPath)/$($pathTempTtlScript)/$($sDataIpAddress)$ttlScriptName" $cmdTTL

				$command = "$($teraTermMacroPath)/ttpmacro.exe $($teraTermMacroPath)/$($pathTempTtlScript)/$($sDataIpAddress)$ttlScriptName"
				invoke-expression -Command $command
			}
		}
		
		$countTimeOut = 0
		do {
			Start-Sleep 60 #wait 60 secondes
			$countTimeOut++
			$numberFiles = Get-ChildItem -Path "$pathTemp" | Measure-Object
			$numberComplete = $numberFiles.Count -eq $numberVm
		} while (!$numberComplete -and ($countTimeOut -le $timeOut))
		
		$errorInstall = ""
		$sepError = ""
		$listFiles = get-childitem "$pathTemp" | Sort-Object LastWriteTime
		foreach($installFile in $listFiles){
			$fileName = $installFile.Name
			$typeFile = $installFile.Extension
			$moreInformation = ""
			$extensionSize = $typeFile.length
			$statusVmTools = $typeFile.Substring(1) #on retire le point de l'extension
			$vmNameSize = [int]($fileName.length - $extensionSize)
			$vmName = $fileName.Substring(0,[int]$vmNameSize)
			if($typeFile -eq ".ko"){
				$installFileContent = Get-Content ("$pathTemp\$fileName")
				$moreInformation = $installFileContent
				$errorInstall = $errorInstall + $sepError + $vmName
				if($sepError -eq ""){
					$sepError = ";"
				}
			}
			Log-Write "`t$($fileName)  $($moreInformation)"
			
			#ajout du status VmTools de la VM dans le fichier status du script
			If(-not (Test-Path -path "$($pathStatus)/$fileStatusPending")){
				New-Item -Path $pathStatus -Name $fileStatusPending -ItemType File
			}
			Add-Content -Path "$($pathStatus)/$fileStatusPending" -Value "$($vmName)$($separator)$statusVmTools"
		}
		
		Remove-Item "$($pathTemp)\*"
		if($errorInstall -ne ""){
			throw "ERROR - Impossible de se connecter en SSH au(x) machine(s) via teraterm: $error"
		}elseif(!$numberComplete){#timeout
			Log-Write "TimeOut - CheckVmTools : $($numberFiles.Count)/$($numberVm)"
			throw "ERROR - TIMEOUT - La verification de la version des VmTools des VMs a echoue -> voir les logs"
		}
	}
}

#Fonctions Install-VmTools
Function Install-VmTools{
	<#
	.SYNOPSIS
		Install si necessaire les vmTools sur chacune des VMs
	.DESCRIPTION
		Effectue l'operation en fonction de l'ordre de redemarrage des VMs defini dans le fichier d'input.
	#>
	Process{
		Log-Write "Installation des VmWareTools"
		$oldStartOrder = 0
		$numberInstall = 0
		$numberNewsInstall = 0
		$cancel = 0
		$errorInstall = ""
		$sepError = ""
		foreach ($vm in $vms){
			$sDataIpAddress = $vm.DataIpAddress
			$sVmVcenterName = $vm.vmVCenterName
			$sStartOrder = $vm.startOrder
			$iVmStartOrder = [int]$vm.startOrder
			if(($cancel -eq 0) -and (!([string]::IsNullOrEmpty($sVmVcenterName))) -and ($iVmStartOrder -ge 0)){
				
				#si cette VM a un start order different de la precedente => on attends la duree du timer pour que les VMs finissent le restart, puis on verifie s'il y a eu des erreurs
				if($iVmStartOrder -ne $oldStartOrder){
					if($oldStartOrder -ne 0){ #si pas premier passage
						
						#Verifier si les VMs n'etaient pas deja toutes a jour
						Start-Sleep 60 #on attend une minute le temps que les fichiers .ok soient crees
						$numberFiles = Get-ChildItem -Path "$pathTemp" | Measure-Object
						$noNeedWait = 0
						if($numberFiles.Count -eq $numberInstall){
							$listFiles = get-childitem "$pathTemp" | Sort-Object LastWriteTime
							$noNeedWait = 1
							$lastCheckCompter = 0
							foreach($installFile in $listFiles){
								if($lastCheckCompter -lt $numberNewsInstall){
									$extensionFile = $installFile.Extension
									if($extensionFile -eq ".up"){
										$noNeedWait = 0
									}
									$lastCheckCompter++
								}
							}
						}
						
						#Attendre le redemarrage des VMs
						if($noNeedWait -eq 0){
							Start-Sleep ($timer)
						}

						#verifier si il y a des erreurs ou non
						$numberFiles = Get-ChildItem -Path "$pathTemp" | Measure-Object
						if($numberFiles.Count -lt $numberInstall){#TimeOut
							#$cancel = 1
						}else{
							$listFiles = get-childitem "$pathTemp" | Sort-Object LastWriteTime
							foreach($installFile in $listFiles){
								$extensionFile = $installFile.Extension
								
								if($extensionFile -eq ".ko"){
									#$cancel = 1 #annuler la boucle d'install sur les VMs
								}
							}
						}
						
						#mise a zero du nombre de VMs dans la vague
						$numberNewsInstall = 0
					}
					#On enregistre l'ordre de redemarrage actuel de la VM pour la comparer avec la suivante
					$oldStartOrder = $iVmStartOrder
				}
				
				#Executer la commande si pas de cancel
				if($cancel -ne 1){
					Log-Write "`t$($sVmVcenterName) ($($sDataIpAddress)) - StartOrder : $($iVmStartOrder)"
					if($logTeraterm -eq 1){ #debugMod
						Log-Write "`t`tDebug - startOrder = $($iVmStartOrder) secondes"
					}
					
					#Recuperer le login et le mot de passe pour se connecter en ssh sur la machine virtuelle
					$authentification = $sshConfDataFileMap["$($sVmVcenterName)"]
					$tAuthentification = $authentification.split("$($separator)")
					$vmLogin = $tAuthentification[0]
					$vmPassword = $tAuthentification[1]
					if($uisCryped -gt 0){
						Try{
							$mdpCryptedSecureString = ConvertTo-SecureString ($vmPassword) -key $sshCryptoKey
							$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($mdpCryptedSecureString)
							$vmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 
						}Catch{
							$ErrorMessage = $_.Exception.Message
							throw "Impossible de decrypter le mot de passe du server virtuel: $($sVmVcenterName) ($($sDataIpAddress)) avec la cle - $ErrorMessage"
						}
					}
					$theTimeLog = Get-Date -f "yyMMddHHmmss"
					
					$cmdTTL =@"
;Variables
timeout = 300 ; variable utilisee par le wait, si le wait ne donne rien apres ce temps la (en seconde), le wait sort en erreur
str2int intLogTeraterm '$($logTeraterm)'
if result = 0 goto KO_LOGTERATERMNOINT

;Set-Location
setdir '$myCurrentPath'
setdir '$pathTemp'

:CONNECT
connect '$($sDataIpAddress):22 /ssh /auth=password /user=$vmLogin /passwd=$vmPassword /timeout=30 /nosecuritywarning'
if result<2 goto ERROR_CONNECT
pause 5
wait '$($prompt)'
if result = 0 goto KO_TIMEOUT

setsync 1
if intLogTeraterm = 1 then
	goto START_LOG
else
	goto UPDATE_VERSION
endif

:START_LOG
inputFileName = '$($myCurrentPath)\log_InstallVmToolsOnVm_$($sVmVcenterName).log'
logopen inputFileName 0 1
logwrite #13#10'@@@@@@@@@@@@@@@@ Start_of_Install_Debug_Log_at_$($theTimeLog) @@@@@@@@@@@@@@'#13#10

:UPDATE_VERSION
sendln 'utils vmtools upgrade'

wait 'Continue (y/n)?' 'Continue?' 'VMware Tools are OK.' 'No further action is needed';'Running this command will update your current version of VMware Tools'
if result = 1 then
	pause 2
	goto PUSH_YES
elseif result = 2 then
	pause 2
	goto PUSH_YES
elseif result = 3 then
	pause 2
	goto UP_TO_DATE
elseif result = 4 then
	pause 2
	goto UP_TO_DATE
else
	pause 2
	goto ERROR
endif

:PUSH_YES
;pause 1
sendln 'y'
wait 'VMware Tools are OK.' 'VMware Tools installed is up-to-date' 'No further action is needed' 'The system will now be restarted.' 'The system is going down for reboot NOW!' 'Restart has succeeded' 'Continue?' 'WARNING...errors truncated !!!' 'Executed command unsuccessfully'
if result = 1 then
	pause 2
	goto UP_TO_DATE
elseif result = 2 then
	pause 2
	goto UP_TO_DATE
elseif result = 3 then
	pause 2
	goto UP_TO_DATE
elseif result = 4 then
	pause 2
	goto UPDATED
elseif result = 5 then
	pause 2
	goto UPDATED
elseif result = 6 then
	pause 2
	goto UPDATED
elseif result = 7 then
	goto PUSH_YES
else
	pause 2
	goto RETRY
endif

:UP_TO_DATE
pause 2
filecreate fhandleUpToDate '$($sVmVcenterName).ok'
filewrite fhandleUpToDate 'Les VmWareTools sont deja a jour sur la machine ($($sDataIpAddress))'
fileclose fhandleUpToDate
goto EXIT

:RETRY ;la mise a jour n'est pas immediate
pause 10 ;attendre 10 secondes
wait '$($prompt)'
if result = 0 goto RETRY ; boucle infini possible (d'ou la possibilite de sortir en timeout)
goto UPDATED

:UPDATED
pause 2
filecreate fhandleUpdated '$($sVmVcenterName).up'
filewrite fhandleUpdated 'Les VmWareTools ont ete mis a jour sur la machine ($($sDataIpAddress))'
fileclose fhandleUpdated
goto EXIT

:ERROR
pause 2
filecreate fhandleKO '$($sVmVcenterName).ko'
filewrite fhandleKO 'Error - Une erreur est survenue sur la machine ($($sDataIpAddress))'
fileclose fhandleKO
goto EXIT

:ERROR_CONNECT
pause 2
filecreate fhandleKO '$($sVmVcenterName).ko'
filewrite fhandleKO 'TimeOut - Impossible de se connecter en SSH a la machine ($($sDataIpAddress)) via teraterm'
fileclose fhandleKO
goto EXIT

:KO_TIMEOUT
filecreate fhandleTIMEOUT '$($sVmVcenterName).ko'
filewrite fhandleTIMEOUT 'Impossible de se connecter au serveur virtuel, pas de reponses'
fileclose fhandleTIMEOUT
goto EXIT

:KO_LOGTERATERMNOINT
filecreate fhandleKO '$($sVmVcenterName).ko'
filewrite fhandleKO 'Impossible de convertir en un entier le parametre pour le debug mod (teraterm log)'
fileclose fhandleKO
goto EXIT

:RESTART
pause 2
sendln 'utils system restart'
wait 'Do you really want to restart ?'
if result = 0 goto ERROR
pause 2
sendln 'yes'
wait 'Shutting down Service Manager. Please wait...'
if result = 0 goto ERROR
goto EXIT

:EXIT
if intLogTeraterm = 1 then
	pause 2
	logwrite #13#10'@@@@@@@@@@@@@@@@@@@@@@ End_of_Install_Debug_Log @@@@@@@@@@@@@@@@@'#13#10
	logclose
endif
pause 2
disconnect 0 ;deconnection de teraterm sans confirmation
closett ;fermeture de teraterm
END
"@

					# echo $cmdTTL > "$teraTermMacroPath/$($pathTempTtlScript)/$ttlScriptName"
					if(-not (Test-Path "$($teraTermMacroPath)/$($pathTempTtlScript)/")){
						New-Item -Path "$($teraTermMacroPath)/" -Name "$pathTempTtlScript" -ItemType directory
					}
					echo $null > "$($teraTermMacroPath)/$($pathTempTtlScript)/$($sDataIpAddress)$ttlScriptName"
					add-content "$($teraTermMacroPath)/$($pathTempTtlScript)/$($sDataIpAddress)$ttlScriptName" $cmdTTL
					
					$command = "$($teraTermMacroPath)/ttpmacro.exe $($teraTermMacroPath)/$($pathTempTtlScript)/$($sDataIpAddress)$ttlScriptName"
					invoke-expression -Command $command
					
					$numberInstall++
					$numberNewsInstall++
					
					$fileStatusIntOld = $fileStatusInt
					$fileStatusInt = Update-FileStatusInt -status "PENDING" -description "UpdateVmTools$($numberInstall)"
				}
			}
		}
		#Verifier si les derniere VMs n'etaient pas deja toutes a jour
		if($cancel -ne 1){
			Start-Sleep 60 #on attend une minute le temps que les fichiers .ok soient crees
			$numberFiles = Get-ChildItem -Path "$pathTemp" | Measure-Object
			$noNeedWait = 0
			if($numberFiles.Count -eq $numberInstall){
				$listFiles = get-childitem "$pathTemp" | Sort-Object LastWriteTime
				$noNeedWait = 1
				$lastCheckCompter = 0
				foreach($installFile in $listFiles){
					if($lastCheckCompter -lt $numberNewsInstall){
						$extensionFile = $installFile.Extension
						if($extensionFile -eq ".up"){
							$noNeedWait = 0
						}
						$lastCheckCompter++
					}
				}
			}
			
			#Attendre le redemarage des dernieres VMs
			if($noNeedWait -eq 0){
				write "wait time = $($timer)"
				Start-Sleep ($timer)
				write "wait timer ok"
			}
		}

		#verifier si il y a eu des erreurs ou non
		# et
		#ecrire dans le fichier status l'etat des vmtools par vm
		$listFiles = get-childitem "$pathTemp" | Sort-Object LastWriteTime
		$numberFiles = 0
		foreach($installFile in $listFiles){
			$fileName = $installFile.Name
			if(!([string]::IsNullOrEmpty($fileName))){
				$extensionFile = $installFile.Extension
				$moreInformation = ""
				$extensionSize = $extensionFile.length
				$vmNameSize = [int]($fileName.length - $extensionSize)
				$vmName = $fileName.Substring(0,[int]$vmNameSize)
				if($extensionFile -eq ".ko"){
					$installFileContent = Get-Content ("$pathTemp\$fileName")
					$moreInformation = $installFileContent
					$errorInstall = $errorInstall + $sepError + $vmName
					if($sepError -eq ""){
						$sepError = ";"
					}
				}
				Log-Write "`t$($fileName)  $($moreInformation)"
				
				#ajout du status VmTools de la VM dans le fichier status du script (les KO et timeout n'y sont pas présents)
				if(-not (Test-Path -path "$($pathStatus)/$fileStatusPending")){
					New-Item -Path $pathStatus -Name $fileStatusPending -ItemType File
				}
				if(($extensionFile -eq ".ok") -or ($extensionFile -eq ".up")){
					Add-Content -Path "$($pathStatus)/$fileStatusPending" -Value "$($vmName)$($separator)OK"
				}
				$numberFiles++
			}
		}
		#tempo de 5 secondes pour que le fichier status reste plus vieux que le tolaunch
		Start-Sleep 5
		
		#Suppression des fichiers temporaire
		Remove-Item "$($pathTemp)\*"
		
		#Gestion des cas d'erreures
		$isTimeOut = 0
		if($numberFiles -ne $numberInstall){
			$isTimeOut = 1
		}
		if(!([string]::IsNullOrEmpty($errorInstall))){
			Log-Write "ERROR - Impossible de mettre a jour les vmTools au(x) machine(s): $errorInstall"
			#throw "ERROR - Impossible de mettre a jour les vmTools au(x) machine(s): $errorInstall"
		}elseif($isTimeOut -eq 1){ #timeout
			Log-Write "TimeOut - InstallVmTools : $($numberFiles)/$($numberInstall)"
			#throw "ERROR - TIMEOUT - L'installation/La mise a jour des VmWareTools des VMs a echoue -> voir les logs"
		}
	}
}

#Fonctions UpdateFileStatusInt
Function Update-FileStatusInt{
	<#
	.SYNOPSIS
		Met a jour la description et le status du fichier de status intermediaire
	.PARAMETER description
	Obligatoire. La description permettant de definir le businessStatus de VHM.
	.PARAMETER status
	Obligatoire. Le status du fichiet de status intermediaire (OK, KO, PENDING, TOLAUNCH).
	.EXAMPLE
		Update-FileStatusInt -status "PENDING" -description "UpdateVmTools15"
	#>
	Param (	[Parameter(Mandatory=$true)][string]$status,
			[Parameter(Mandatory=$true)][string]$description
	)
	Process{
		Log-Write "Status Int : $($status) - $($description)"
		if($status -eq "TOLAUNCH"){
			$scriptType = "VCO" #le tolaunch etant la derniere chose effectue par le script, on peut se permetre de changer cette variable
		}
		if(([string]::IsNullOrEmpty($fileStatusInt)) -or ([string]::IsNullOrEmpty($fileStatusIntOld))){
			$fileStatusInt = "$($fileNamePrefix)_$($scriptType)_$($description)_$($status).statusInt"
			If(-not (Test-Path -path "$pathStatus\$fileStatusInt")){
				echo $null > "$($pathStatus)\$fileStatusInt"
			}
			$fileStatusIntOld = $fileStatusInt
		}else{
			If(-not (Test-Path -path "$pathStatus\$fileStatusInt")){
				echo $null > "$($pathStatus)\$fileStatusInt"
			}
			$fileStatusIntOld = $fileStatusInt
			$fileStatusInt = "$($fileNamePrefix)_$($scriptType)_$($description)_$($status).statusInt"
			if(($fileStatusIntOld -eq $fileStatusInt)){
				if(Test-Path -path "$($pathStatus)\$fileStatusInt"){
					Remove-Item "$($pathStatus)\$fileStatusInt"
				}
				Rename-Item -Path "$($pathStatus)\$($fileStatusIntOld)" -NewName $fileStatusInt
			}else{
				if(Test-Path -path "$($pathStatus)\$fileStatusInt"){
					Remove-Item "$($pathStatus)\$fileStatusInt"
				}
				echo $null > "$($pathStatus)\$fileStatusInt"
			}
		}
		return $fileStatusInt
	}
}

Try{
	#Suppression de certain fichiers de status (pour eviter un toLaunch ou la prise en compte d'un KO non souhaite)
	if(Test-Path $pathStatus){
		Remove-Item "$($pathStatus)\$($fileNamePrefix)*KO.status"
		Remove-Item "$($pathStatus)\$($fileNamePrefix)_*TOLAUNCH.statusInt"
	}
	#Suppression de ce qui se trouve dans le dossier Temps (possible s'il y a eu une erreur timeout)
	if(Test-Path -path "$pathTemp\*"){
		Remove-Item "$($pathTemp)\*"
	}

	#Creation/reprise du fichier de log
	Log-Start #creation du dossier et du fichier si non existence
	
	# if([string]::IsNullOrEmpty($scriptType)){
		# throw "ERROR - Le parametre 'scriptType' ne doit pas etre vide"
	# }
	if([string]::IsNullOrEmpty($topologyName)){
		throw "ERROR - Le parametre 'topologyName' ne doit pas etre vide"
	}
	if([string]::IsNullOrEmpty($upgradeName)){
		throw "ERROR - Le parametre 'upgradeName' ne doit pas etre vide"
	}
	if([string]::IsNullOrEmpty($fileLog)){
		throw "ERROR - Le parametre 'fileLog' ne doit pas etre vide"
	}
	if([string]::IsNullOrEmpty($repriseLvl)){
		throw "ERROR - Le parametre 'repriseLvl' ne doit pas etre vide"
	}
	
	$repriseMap = @{ 1 = "1 - Major Upgrade"; 2 = "2 - Check and Install vmTools"; 3 = "3 - Firmware Upgrade"; 4 = "4 - Locale Upgrade" ; 5 = "5 - End"}
	$sRepriseLvl = $repriseMap[$repriseLvl]
	Log-Write " "
	Log-Write -l "----------------------------------------------------------------"
	Log-Write "$currentDate - Execution du script : ToolboxUpgrade.ps1 - $sRepriseLvl"
	Log-Write "----------------------------------------------------------------`r`n"

	#Creer le fichier status "PENDING"
	if(-not (Test-Path $pathStatus)){
		Log-Write "Creation du dossier status"
		New-Item -Name $pathStatus -ItemType directory
	}
	Log-Write "Creation du fichier de status PENDING"
	$fileStatus = $fileStatusPending
	echo $null > "$($pathStatus)\$fileStatusPending"
	
	#Recuperer les infos du fichier d'input
	$vmNameToVmIpMap = @{}
	$vmTypeRoleToVmNameMap = @{}
	$vms = Import-CSV "$($pathInput)\$inputFileName" -Delimiter $separator | Sort-Object {[int] $_.startOrder}, role
	$separator1 = ""
	$separator2 = ""
	$separator3 = ""
	$separator4 = ""
	foreach ($vm in $vms){
		$sDataIpAddress = $vm.DataIpAddress
		$sApplicationType=$vm.applicationType
		$sRole = $vm.role
		$sVmVcenterName = $vm.vmVCenterName
		$iVmStartOrder = [int]$vm.startOrder
		if(!([string]::IsNullOrEmpty($sVmVcenterName)) -and ($iVmStartOrder -ge 0)){
			$vmNameToVmIpMap[$sVmVcenterName] = $sDataIpAddress
			switch -regex ("$sRepriseLvl"){
				'^1' {
					if(("CUCM" -eq $sApplicationType) -and ("P" -eq $sRole)){
						$vmTypeRoleToVmNameMap["$($sApplicationType);$sRole"] = $vmTypeRoleToVmNameMap["$($sApplicationType);$sRole"] + $separator1 + $sVmVcenterName
						$separator1 = ";"
					}elseif(("CUCM" -eq $sApplicationType) -and ("S" -eq $sRole)){
						$vmTypeRoleToVmNameMap["$($sApplicationType);$sRole"] = $vmTypeRoleToVmNameMap["$($sApplicationType);$sRole"] + $separator2 + $sVmVcenterName
						$separator2 = ";"
					}elseif(("UCCX" -eq $sApplicationType) -and ("P" -eq $sRole)){
						$vmTypeRoleToVmNameMap["$($sApplicationType);$sRole"] = $vmTypeRoleToVmNameMap["$($sApplicationType);$sRole"] + $separator3 + $sVmVcenterName
						$separator3 = ";"
					}else{
						$vmTypeRoleToVmNameMap["OTHER;other"] = $vmTypeRoleToVmNameMap["OTHER;other"] + $separator4 + $sVmVcenterName
						$separator4 = ";"
					}
				}
				'^2' {}
				'^[3]' {
					if(("CUCM" -eq $sApplicationType) -and ("P" -eq $sRole)){
						$vmTypeRoleToVmNameMap["$($sApplicationType);$sRole"] = $vmTypeRoleToVmNameMap["$($sApplicationType);$sRole"] + $separator1 + $sVmVcenterName
						$separator1 = ";"
					}else{
						$vmTypeRoleToVmNameMap["OTHER;other"] = $vmTypeRoleToVmNameMap["OTHER;other"] + $separator4 + $sVmVcenterName
						$separator4 = ";"
					}
				}
				'^[4]' {
					if(("CUCM" -eq $sApplicationType) -and ("P" -eq $sRole)){
						$vmTypeRoleToVmNameMap["$($sApplicationType);$sRole"] = $vmTypeRoleToVmNameMap["$($sApplicationType);$sRole"] + $separator1 + $sVmVcenterName
						$separator1 = ";"
					}elseif(("Unity" -eq $sApplicationType) -or ("UCNX" -eq $sApplicationType)){
						$vmTypeRoleToVmNameMap["UNITY;other"] = $vmTypeRoleToVmNameMap["UNITY;other"] + $separator4 + $sVmVcenterName
						$separator4 = ";"
					}else{
						$vmTypeRoleToVmNameMap["OTHER;other"] = $vmTypeRoleToVmNameMap["OTHER;other"] + $separator4 + $sVmVcenterName
						$separator4 = ";"
					}
				}
				Default {
					throw "Error - Niveau d'upgrade inconnue : $sRepriseLvl"
				}
			}
		}
	}
	
	#Recuperation des infos du fichier des login/password des VMs
	$sshConfDataFileMap = @{}
	Log-Write "Recuperation du fichier de configuration - les infos de connection ssh des VMs : "
	$sshConfDataFileLines = Get-Content ("$($pathSshFile)\$sshConfDataFileName")
	$counter = 0 #un compteur
	Foreach ( $line in $sshConfDataFileLines ) {
		if($counter -gt 0){ #on zap l'entete du fichier csv
			$line_splitted = $line.split("$($separator)") #vmName ; login ; password
			if(($line_splitted.length -gt 1) -and !([string]::IsNullOrEmpty($line_splitted[0]))){
				$key = $line_splitted[0] #on recupere pour la cle: le nom de la machine virtuelle
				$null, $tValue = $line_splitted #on retire le premier element (qui a ete recupere pour la cle)
				$value = $tValue -join "$($separator)" #on transforme le array en string avec ';' comme separateur
				$sshConfDataFileMap[$key]=$value
				$login = $tValue[0]
				Log-Write "`t$counter - $key -> $login;****" #on n'affiche pas les password dans les logs
			}
		}
		$counter++
	}
	#Recuperation de la map vmName/vmToolsVersion
	if(($repriseLvl -eq 2) -and ("checkVmToolsOnly" -eq $upgradeName)){ #si phase check vmTools => recuperer la map des versions cible des vmTools
		Log-Write "Recuperation de la map vmName/vmToolsVersion"
		$confVmNameToVmToolsVersionMap = @{}
		$counter = 0 #un compteur
		$confVmToolsVersionFileLines = Get-Content ("$($pathStatus)\$($fileNamePrefix)_PENDING.status")
		Foreach ( $line in $confVmToolsVersionFileLines ) {
			$line_splitted = $line.split("$($separator)") #vmName ; vmToolsVersion
			if(($line_splitted.length -gt 1) -and !([string]::IsNullOrEmpty($line_splitted[0]))){
				$key = $line_splitted[0] #on recupere pour la cle: la vmName
				$value = $line_splitted[1] #on recupere le seconds element (vmToolsVersion)
				$confVmNameToVmToolsVersionMap[$key]=$value
				Log-Write "`t$counter - $key -> $value"
				$counter++
			}
		}
	}
	#Recuperation de la map vmName/isoName
	if($repriseLvl -ne 2){ 
		Log-Write "Recuperation de la map vmName/isoName"
		$confVmNameToIsoNameMap = @{}
		$counter = 0 #un compteur
		$confIsoNameFileLines = Get-Content ("$($pathStatus)\$($fileNamePrefix)_PENDING.status")
		Foreach ( $line in $confIsoNameFileLines ) {
			$line_splitted = $line.split("$($separator)") #vmName ; isoName
			if(($line_splitted.length -gt 1) -and !([string]::IsNullOrEmpty($line_splitted[0]))){
				$key = $line_splitted[0] #on recupere pour la cle: la vmName
				$value = $line_splitted[1] #on recupere le seconds element (isoName)
				$confVmNameToIsoNameMap[$key]=$value
				Log-Write "`t$counter - $key -> $value"
				$counter++
			}
		}
	}
	
	#Creation du dossier d'avancement
	if(-not (Test-Path -path $pathTemp)){
		New-Item -Name $pathTemp -ItemType directory
	}
	#Upgrade en fonction du niveau
	switch -regex ("$sRepriseLvl"){ 
		'^1' {#Upgrade majeur
			Upgrade-Group -applicationType "CUCM" -role "P" -upgradeType "Major"
			
			Upgrade-Group -applicationType "CUCM" -role "S" -upgradeType "Major"
			
			Upgrade-Group -applicationType "UCCX" -role "P" -upgradeType "Major"
			
			Upgrade-Group -applicationType "OTHER" -role "other" -upgradeType "Major"
		
			CheckDB-And-Restart -upgradeType "Major"
			Start-Sleep $timer #on attend une duree '$timer' pour attendre le redemarrage des machines
		}
		'^2' {#Check and install vmTools
			if("checkVmToolsOnly" -eq $upgradeName){
				#Check vmTools
				Check-VmTools
			}else{
				#CheckAndInstallVmTools (prend en compte l'ordre de redemarrage)
				Install-VmTools
			}
		}
		'^[3]' {#Upgrade Firmware
			$typeOfUpgrade = "Firmware"
			Upgrade-Group -applicationType "CUCM" -role "P" -upgradeType "$typeOfUpgrade"
			
			#wait timer
			Start-Sleep $timer
			
			Upgrade-Group -applicationType "OTHER" -role "other" -upgradeType "$typeOfUpgrade"
			
			CheckDB-And-Restart -upgradeType "$typeOfUpgrade"
			Start-Sleep $timer #on attend une duree '$timer' pour attendre le redemarrage des machines
		}
		'^[4]' {#Upgrade Locale
			$typeOfUpgrade = "Locale"
			Upgrade-Locale-Group -applicationType "CUCM" -role "P"
			
			#wait timer
			Start-Sleep $timer
			
			Upgrade-Locale-Group -applicationType "UNITY" -role "other"
			Upgrade-Locale-Group -applicationType "OTHER" -role "other"
			
			CheckDB-And-Restart -upgradeType "$typeOfUpgrade"
			Start-Sleep $timer #on attend une duree '$timer' pour attendre le redemarrage des machines
		}
		Default {
			throw "Error - Niveau d'upgrade inconnue : $sRepriseLvl"
		}
	}
	
	#ToLaunch
	$sCryptoKey = ''+$cryptoKey #convertir la clé VCO en string
	$tCryptoKey = $sCryptoKey.split(' ')
	$sCryptoKey = $tCryptoKey -join ","
	$sCryptoKey = '('+$sCryptoKey+')'
	$sSshCryptoKey = ''+$sshCryptoKey #convertir la clé UIS en string
	$tSshCryptoKey = $sSshCryptoKey.split(' ')
	$sSshCryptoKey = $tSshCryptoKey -join ","
	$sSshCryptoKey = '('+$sSshCryptoKey+')'
	$nextReprise = [int]$repriseLvl + 1
	$fileStatusIntOld = $fileStatusInt
	$fileStatusInt = Update-FileStatusInt -status "TOLAUNCH" -description "MasterUpgrade$($nextReprise)"
	if($separator -eq ";"){
		$separator = "defaut"
	}
	if($standAlone){
		$pathTemp = $oldpathTemp
	}
	$cmdToLaunch =@"
MasterUpgrade.ps1
fileNamePrefix;'$fileNamePrefix'
datacenterCode;'$datacenterCode'
scriptType;'VCO'
topologyName;'$topologyName'
upgradeName;'$upgradeName'
inputFileName;'$inputFileName'
confMatrixFileName;'$confMatrixFileName'
confDatacenterFileName;'$confDatacenterFileName'
confVmToolsVersionFileName;'$confVmToolsVersionFileName'
sshConfDataFileName;'$sshConfDataFileName'
pathSshFile;'$pathSshFile'
pathScript;'$pathScript'
pathInput;'$pathInput'
pathStatus;'$pathStatus'
pathLog;'$pathLog'
pathConf;'$pathConf'
pathTemp;'$pathTemp'
teraTermMacroPath;'$teraTermMacroPath'
fileLog;'$fileLog'
repriseFile;'$repriseFile'
toLaunch;'$toLaunch'
nbRetry;$nbRetry
timeOut;$timeOut
timer;$timer
ttlScriptName;'$ttlScriptName'
cryptoKey;$sCryptoKey
sshCryptoKey;$sSshCryptoKey
separator;'$separator'
standAlone;$standAlone
uisCryped;$uisCryped
"@
	set-content "$($pathStatus)\$($fileStatusInt)" $cmdToLaunch
	Log-Write "ToLaunch - $($fileNamePrefix)_VCO_MasterUpgrade$($nextReprise)_TOLAUNCH.statusInt"
	
	if($standAlone){#si en mode standAlone, on execute le script suivant via le fichier toLaunch (pour tester la conformite du fichier et eviter les oublies lors des evols)
		Start-Sleep 5 #on attend 5 seconde pour etre sure que le fichier toLaunch est present
		$toLaunchLines = Get-Content ("$($pathStatus)\$fileStatusInt")
		$counter = 0
		$powershellCommand = ""
		Foreach ( $line in $toLaunchLines ) {
			if(!([string]::IsNullOrEmpty($line))){
				if($counter -eq 0){ #la premiere ligne est le nom du script a lancer
					$powershellCommand += $line
				}else{ #le reste sont les parametres
					$line_splitted = $line.split(";") #param ; value
					if(($line_splitted.length -gt 1) -and !([string]::IsNullOrEmpty($line_splitted[0]))){
						$param = $line_splitted[0] #on recupere le nom du parametre
						$value = $line_splitted[1] #on recupere la valeur du parametre
						$argToAdd = " -$($param) $($value)"
						$powershellCommand += $argToAdd
					}
				}
				$counter++
			}
		}
		Log-Write "STAND ALONE - $($powershellCommand)"
		$command = ". $($pathScript)/$powershellCommand"
		invoke-expression -Command $command
	}
	
	#Nettoyage fichiers temp + fichiers status
	if($repriseLvl -eq 4){
		if((Test-Path $pathStatus) -and !$standAlone){ #suppression des fichiers de status (sauf le toLaunch) et temps
			Remove-Item "$($pathStatus)\$($fileNamePrefix)_*KO.*"
			Remove-Item "$($pathStatus)\$($fileNamePrefix)_*PENDING.statusInt" #le status pending doit rester sinon vhm coince
			Remove-Item "$($pathStatus)\$($fileNamePrefix)_*OK.*"
		}
		if(Test-Path -path "$pathTemp\*"){
			Remove-Item "$pathTemp\*"
		}
	}

}Catch{
	$ErrorMessage = $_.Exception.Message
	$ErrorItem = $_.Exception.ItemName
	Log-Start #creation du dossier et du fichier de log si non existence
	Log-Write "Exception $ErrorItem - $ErrorMessage"
	
	#ToLaunch
	$sCryptoKey = ''+$cryptoKey #convertir la clé VCO en string
	$tCryptoKey = $sCryptoKey.split(' ')
	$sCryptoKey = $tCryptoKey -join ","
	$sCryptoKey = '('+$sCryptoKey+')'
	$sSshCryptoKey = ''+$sshCryptoKey #convertir la clé UIS en string
	$tSshCryptoKey = $sSshCryptoKey.split(' ')
	$sSshCryptoKey = $tSshCryptoKey -join ","
	$sSshCryptoKey = '('+$sSshCryptoKey+')'
	$nextReprise = [int]$repriseLvl + 1
	$fileStatusIntOld = $fileStatusInt
	$fileStatusInt = Update-FileStatusInt -status "TOLAUNCH" -description "MasterUpgrade$($nextReprise)"
	if($separator -eq ";"){
		$separator = "defaut"
	}
	if($standAlone){
		$pathTemp = $oldpathTemp
	}
	$cmdToLaunch =@"
MasterUpgrade.ps1
toLaunch;'KO'
fileNamePrefix;'$fileNamePrefix'
datacenterCode;'$datacenterCode'
scriptType;'VCO'
topologyName;'$topologyName'
upgradeName;'$upgradeName'
inputFileName;'$inputFileName'
confMatrixFileName;'$confMatrixFileName'
confDatacenterFileName;'$confDatacenterFileName'
confVmToolsVersionFileName;'$confVmToolsVersionFileName'
sshConfDataFileName;'$sshConfDataFileName'
pathSshFile;'$pathSshFile'
pathScript;'$pathScript'
pathInput;'$pathInput'
pathStatus;'$pathStatus'
pathLog;'$pathLog'
pathConf;'$pathConf'
pathTemp;'$pathTemp'
teraTermMacroPath;'$teraTermMacroPath'
fileLog;'$fileLog'
repriseFile;'$repriseFile'
nbRetry;$nbRetry
timeOut;$timeOut
timer;$timer
ttlScriptName;'$ttlScriptName'
cryptoKey;$sCryptoKey
sshCryptoKey;$sSshCryptoKey
separator;'$separator'
standAlone;$standAlone
uisCryped;$uisCryped
"@
	set-content "$($pathStatus)\$($fileStatusInt)" $cmdToLaunch
	Log-Write "ToLaunch KO - $($fileNamePrefix)_VCO_MasterUpgrade$($nextReprise)_TOLAUNCH.statusInt"
		
	if($standAlone){#si en mode standAlone, on execute le script suivant via le fichier toLaunch (pour tester la conformite du fichier et eviter les oublies lors des evols)
		Start-Sleep 5 #on attend 5 seconde pour etre sure que le fichier toLaunch est present
		$toLaunchLines = Get-Content ("$($pathStatus)\$fileStatusInt")
		$counter = 0
		$powershellCommand = ""
		Foreach ( $line in $toLaunchLines ) {
			if(!([string]::IsNullOrEmpty($line))){
				if($counter -eq 0){ #la premiere ligne est le nom du script a lancer
					$powershellCommand += $line
				}else{ #le reste sont les parametres
					$line_splitted = $line.split(";") #param ; value
					if(($line_splitted.length -gt 1) -and !([string]::IsNullOrEmpty($line_splitted[0]))){
						$param = $line_splitted[0] #on recupere le nom du parametre
						$value = $line_splitted[1] #on recupere la valeur du parametre
						$argToAdd = " -$($param) $($value)"
						$powershellCommand += $argToAdd
					}
				}
				$counter++
			}
		}
		Log-Write "STAND ALONE - $($powershellCommand)"
		$command = ". $($pathScript)/$powershellCommand"
		invoke-expression -Command $command
	}
	
}Finally{
	#Se replacer ou l'on etait avant l'execution du script
	Set-Location $myOldPath
	
	exit
}