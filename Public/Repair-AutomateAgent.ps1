function Repair-AutomateAgent {
<#
.Synopsis
   Takes changed detected in Compare-AutomateControlStatus and performs a specified repair on them
.DESCRIPTION
   Takes changed detected in Compare-AutomateControlStatus and performs a specified repair on them
.PARAMETER Action
   Takes either Update, Restart, Reinstall or Check
.PARAMETER BatchSize
   When multiple jobs are run, they run in Parallel. Batch size determines how many jobs can run at once. Default is 10
.PARAMETER LTPoShURI 
   If you do not wish to use the LT Posh module on GitHub you can use your own link to the LTPosh Module with this parameter
.PARAMETER AutomateControlStatusObject
   Object taken from the Pipeline from Compare-AutomateControlStatus
.EXAMPLE
   Get-AutomateComputer -Online $False | Compare-AutomateControlStatus | Repair-AutomateAgent -Action Check
.EXAMPLE
   Get-AutomateComputer -Online $False | Compare-AutomateControlStatus | Repair-AutomateAgent -Action Restart
.INPUTS
   Compare-AutomateControlStatus Object
.OUTPUTS
   Object containing result of job(s)
#>
   [CmdletBinding(
   SupportsShouldProcess = $True,
   ConfirmImpact = 'High')]
   param (
   [ValidateSet('Update','Restart','ReInstall','Check')]
   [String]$Action = 'Check',

   [Parameter(Mandatory = $False)]
   [ValidateRange(1,50)]
   [int]
   $BatchSize = 10,

   [Parameter(Mandatory = $False)]
   [String]$LTPoShURI = $Script:LTPoShURI,

   [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
   $AutomateControlStatusObject
   )

   Begin {
      $RepairProperty='RepairResult'
      $ObjectCapture = {}.Invoke()
   }

   Process {
      Foreach ($igu in $AutomateControlStatusObject) {
         If ($igu.ComputerID -and $igu.SessionID -and $igu.SessionID -match '^[a-z0-9]{8}(?:-[a-z0-9]{4}){3}-[a-z0-9]{12}' -and !($Action -eq 'Reinstall' -and !($igu.Location.ID -gt 0))) {
            $Null = $ObjectCapture.Add($igu)
         } Else {
            Write-Host -BackgroundColor Yellow -ForegroundColor Red "An object was passed that is missing a required property (ComputerID, SessionID)"
         }
      }
   }

   End {
      If ($ObjectCapture) {
         Write-Host -ForegroundColor Green "Starting fixes"
         If ($Action -eq 'Check') {
            $ServiceResults = $(
               $ObjectCapture | Where-Object {$_.OperatingSystemName -like '*Windows*'} | ForEach-Object {
                  If ($PSCmdlet.ShouldProcess("Automate Services on $($_.ComputerID) - $($_.ComputerName)",$Action)) {
                     Write-Host -BackgroundColor DarkGray -ForegroundColor Yellow "$($_.ComputerID) - $($_.ComputerName) - Attempting to $Action Automate Services - job will be submitted to online systems"
                     $_
                  }
               } | Invoke-ControlCommand -Powershell -Command @"
Try { 
  (new-object Net.WebClient).DownloadString('$($LTPoShURI)') | iex
  Get-LTServiceInfo
} Catch {
  'Error getting service settings. Checking LTErrors.txt'
  Get-Content "`${env:windir}\ltsvc\lterrors.txt" | Select-Object -Last 100
}
"@ -TimeOut 60000 -MaxLength 102400 -BatchSize $BatchSize -OfflineAction Skip -ResultPropertyName $RepairProperty -PassthroughObjects
               $ObjectCapture | Where-Object {$_.OperatingSystemName -like '*OS X*'}  | ForEach-Object {
                  If ($PSCmdlet.ShouldProcess("Automate Services on $($_.ComputerID) - $($_.ComputerName)",$Action)) {
                     Write-Host -BackgroundColor DarkGray -ForegroundColor Yellow "$($_.ComputerID) - $($_.ComputerName) - Attempting to $Action Automate Services - job will be submitted to online systems"
                     $_
                  }
               } | Invoke-ControlCommand -Command @'
[ -f /usr/local/ltechagent/state ]&&(echo '{'
echo '"state": '; cat /usr/local/ltechagent/state 2>/dev/null
[ -f /usr/local/ltechagent/agent_config ]&&(cat /usr/local/ltechagent/agent_config | awk 'BEGIN { print ",\"agent_config\": \{"}; { row[NR]= "\"" $1 "\": \"" $2 "\"" }; END { for (i = 1; i < NR; i++) { print row[i] ","}; print row[NR] "\n\}" }')
[ -f /usr/local/ltechagent/agent.log ]&&(tail -n 100 /usr/local/ltechagent/agent.log | awk 'BEGIN { print ",\"lterrors\": \["}; { gsub ("[\\\\]","\\\\"); gsub ("[\\\"]","\\\""); gsub ("[\\\/]","\\\/"); gsub ("[\\b]","\\b"); gsub ("[\\f]","\\f"); gsub ("[\\t]","\\t"); row[NR]=$0 }; END { for (i = 1; i < NR; i++) { print "\"" row[i] "\","}; print "\"" row[NR] "\"\n\]" }')
echo '}'
)
'@.Replace("`r",'') -TimeOut 60000 -MaxLength 102400 -BatchSize $BatchSize -OfflineAction Skip -ResultPropertyName $RepairProperty -PassthroughObjects
               $ObjectCapture | Where-Object {$_.OperatingSystemName -like '*Linux*'}  | ForEach-Object {
                  If ($PSCmdlet.ShouldProcess("Automate Services on $($_.ComputerID) - $($_.ComputerName)",$Action)) {
                     Write-Host -BackgroundColor DarkGray -ForegroundColor Yellow "$($_.ComputerID) - $($_.ComputerName) - Attempting to $Action Automate Services - job will be submitted to online systems"
                     $_
                  }
               } | Invoke-ControlCommand -Command @'
[ -f /usr/local/ltechagent/state ]&&(echo '{'
echo '"state": '; cat /usr/local/ltechagent/state 2>/dev/null
[ -f /usr/local/ltechagent/agent_config ]&&(cat /usr/local/ltechagent/agent_config | awk 'BEGIN { print ",\"agent_config\": \{"}; { row[NR]= "\"" $1 "\": \"" $2 "\"" }; END { for (i = 1; i < NR; i++) { print row[i] ","}; print row[NR] "\n\}" }')
[ -f /usr/local/ltechagent/agent.log ]&&(tail -n 100 /usr/local/ltechagent/agent.log | awk 'BEGIN { print ",\"lterrors\": \["}; { gsub ("[\\\\]","\\\\"); gsub ("[\\\"]","\\\""); gsub ("[\\\/]","\\\/"); gsub ("[\\b]","\\b"); gsub ("[\\f]","\\f"); gsub ("[\\t]","\\t"); row[NR]=$0 }; END { for (i = 1; i < NR; i++) { print "\"" row[i] "\","}; print "\"" row[NR] "\"\n\]" }')
echo '}'
)
'@.Replace("`r",'') -TimeOut 60000 -MaxLength 102400 -BatchSize $BatchSize -OfflineAction Skip -ResultPropertyName $RepairProperty -PassthroughObjects
            )
            $ObjectCapture | Where-Object {!($_.OperatingSystemName -like '*Windows*' -or $_.OperatingSystemName -like '*OS X*' -or $_.OperatingSystemName -like '*Linux*')}  | ForEach-Object {
               Write-Host -BackgroundColor Yellow -ForegroundColor Red "$($_.ComputerID) - $($_.ComputerName) - $Action action for Operating System ($($_.OperatingSystemName)) is not supported at present in this module"
            }
         } ElseIf ($Action -eq 'Update') {
            $ServiceResults = $(
               $ObjectCapture | Where-Object {$_.OperatingSystemName -like '*Windows*'} | ForEach-Object {
                  If ($PSCmdlet.ShouldProcess("Automate Services on $($_.ComputerID) - $($_.ComputerName)",$Action)) {
                     Write-Host -BackgroundColor DarkGray -ForegroundColor Yellow "$($_.ComputerID) - $($_.ComputerName) - Attempting to $Action Automate Services - job will be submitted to online systems"
                     $_
                  }
               } | Invoke-ControlCommand -Powershell -Command @"
(new-object Net.WebClient).DownloadString('$($LTPoShURI)') | iex
Update-LTService
"@ -TimeOut 120000 -MaxLength 20480 -BatchSize $BatchSize -OfflineAction Skip -ResultPropertyName $RepairProperty -PassthroughObjects
               $ObjectCapture | Where-Object {$_.OperatingSystemName -like '*OS X*'}  | ForEach-Object {
                  If ($PSCmdlet.ShouldProcess("Automate Services on $($_.ComputerID) - $($_.ComputerName)",$Action)) {
                     Write-Host -BackgroundColor DarkGray -ForegroundColor Yellow "$($_.ComputerID) - $($_.ComputerName) - Attempting to $Action Automate Services - job will be submitted to online systems"
                     $_
                  }
               } | Invoke-ControlCommand -Command  @'
[ -f /usr/local/ltechagent/ltupdate ]&&(
/usr/local/ltechagent/ltupdate&&echo "Agent Update Completed Successfully"||echo "Agent Update failed or was not needed"
)||echo "Error - Missing file /usr/local/ltechagent/ltupdate"
'@.Replace("`r",'') -TimeOut 120000 -MaxLength 10240 -BatchSize $BatchSize -OfflineAction Skip -ResultPropertyName $RepairProperty -PassthroughObjects
               $ObjectCapture | Where-Object {$_.OperatingSystemName -like '*Linux*'}  | ForEach-Object {
                  If ($PSCmdlet.ShouldProcess("Automate Services on $($_.ComputerID) - $($_.ComputerName)",$Action)) {
                     Write-Host -BackgroundColor DarkGray -ForegroundColor Yellow "$($_.ComputerID) - $($_.ComputerName) - Attempting to $Action Automate Services - job will be submitted to online systems"
                     $_
                  }
               } | Invoke-ControlCommand -Command @'
[ -f /usr/local/ltechagent/ltupdate ]&&(
/usr/local/ltechagent/ltupdate&&echo "Agent Update Completed Successfully"||echo "Agent Update failed or was not needed"
)||echo "Error - Missing file /usr/local/ltechagent/ltupdate"
'@.Replace("`r",'') -TimeOut 120000 -MaxLength 10240 -BatchSize $BatchSize -OfflineAction Skip -ResultPropertyName $RepairProperty -PassthroughObjects
            )
            $ObjectCapture | Where-Object {!($_.OperatingSystemName -like '*Windows*' -or $_.OperatingSystemName -like '*OS X*' -or $_.OperatingSystemName -like '*Linux*')}  | ForEach-Object {
               Write-Host -BackgroundColor Yellow -ForegroundColor Red "$($_.ComputerID) - $($_.ComputerName) - $Action action for Operating System ($($_.OperatingSystemName)) is not supported at present in this module"
            }
         } ElseIf ($Action -eq 'Restart') {
            $ServiceResults = $(
               $ObjectCapture | Where-Object {$_.OperatingSystemName -like '*Windows*'} | ForEach-Object {
                  If ($PSCmdlet.ShouldProcess("Automate Services on $($_.ComputerID) - $($_.ComputerName)",$Action)) {
                     Write-Host -BackgroundColor DarkGray -ForegroundColor Yellow "$($_.ComputerID) - $($_.ComputerName) - Attempting to $Action Automate Services - job will be submitted to online systems"
                     $_
                  }
               } | Invoke-ControlCommand -Powershell -Command @"
(new-object Net.WebClient).DownloadString('$($LTPoShURI)') | iex
Try { Restart-LTService }
Catch {
  net stop ltsvcmon
  net stop labvnc
  net stop ltservice
  TASKKILL /im ltsvcmon.exe /f
  TASKKILL /im ltsvc.exe /f
  TASKKILL /im lttray.exe /f
  TASKKILL /im labvnc.exe /f
  TASKKILL /im labtechupdate.exe /f /t
  net start ltsvcmon
  net start ltservice
}
"@ -TimeOut 120000 -MaxLength 20480 -BatchSize $BatchSize -OfflineAction Skip -ResultPropertyName $RepairProperty -PassthroughObjects
               $ObjectCapture | Where-Object {$_.OperatingSystemName -like '*OS X*'}  | ForEach-Object {
                  If ($PSCmdlet.ShouldProcess("Automate Services on $($_.ComputerID) - $($_.ComputerName)",$Action)) {
                     Write-Host -BackgroundColor DarkGray -ForegroundColor Yellow "$($_.ComputerID) - $($_.ComputerName) - Attempting to $Action Automate Services - job will be submitted to online systems"
                     $_
                  }
               } | Invoke-ControlCommand -Command @'
LOGGEDUSERS=`who | grep console | awk '{ print $1 }'`
echo "Stopping Services"
(
  launchctl unload /Library/LaunchDaemons/com.labtechsoftware.LTSvc.plist
  launchctl unload /Library/LaunchDaemons/com.labtechsoftware.LTUpdate.plist
  for CURRUSER in $LOGGEDUSERS; do su -l $CURRUSER -c 'launchctl unload /Library/LaunchAgents/com.labtechsoftware.LTTray.plist'; done
)
echo "Starting Services"
sleep 5
launchctl load /Library/LaunchDaemons/com.labtechsoftware.LTSvc.plist
for CURRUSER in $LOGGEDUSERS; do su -l $CURRUSER -c 'launchctl load /Library/LaunchAgents/com.labtechsoftware.LTTray.plist'; done
echo "Checking Services"
(for CURRUSER in $LOGGEDUSERS; do su -l $CURRUSER -c 'launchctl list'; done) | grep -i "com.labtechsoftware"
launchctl list | grep -i "com.labtechsoftware"&&echo "LTService Restarted successfully"
'@.Replace("`r",'') -TimeOut 120000 -MaxLength 10240 -BatchSize $BatchSize -OfflineAction Skip -ResultPropertyName $RepairProperty -PassthroughObjects
               $ObjectCapture | Where-Object {$_.OperatingSystemName -like '*Linux*'}  | ForEach-Object {
#                  If ($PSCmdlet.ShouldProcess("Automate Services on $($_.ComputerID) - $($_.ComputerName)",$Action)) {
                     Write-Host -BackgroundColor Yellow -ForegroundColor Red "$($_.ComputerID) - $($_.ComputerName) - $Action action for Operating System ($($_.OperatingSystemName)) is not supported at present in this module"
#                  }
               }
            )
            $ObjectCapture | Where-Object {!($_.OperatingSystemName -like '*Windows*' -or $_.OperatingSystemName -like '*OS X*' -or $_.OperatingSystemName -like '*Linux*')}  | ForEach-Object {
               Write-Host -BackgroundColor Yellow -ForegroundColor Red "$($_.ComputerID) - $($_.ComputerName) - $Action action for Operating System ($($_.OperatingSystemName)) is not supported at present in this module"
            }
         } ElseIf ($Action -eq 'Reinstall') {
            $ServiceResults = $(
               $InstallerToken = Get-AutomateInstallerToken
               $ObjectCapture | Where-Object {$_.OperatingSystemName -like '*Windows*'} | ForEach-Object {
                  If ($PSCmdlet.ShouldProcess("Automate Services on $($_.ComputerID) - $($_.ComputerName)",$Action)) {
                     Write-Host -BackgroundColor DarkGray -ForegroundColor Yellow "$($_.ComputerID) - $($_.ComputerName) - Attempting to $Action Automate Services - job will be submitted to online systems"
                     $_ 
                  }
               } | Invoke-ControlCommand -Powershell -Command @"
(new-object Net.WebClient).DownloadString('$($LTPoShURI)') | iex
Install-LTService -Server '$($Script:CWAServer)' -LocationID $($_.Location.Id) -InstallerToken '$($InstallerToken)' -Force -SkipDotNet
"@ -TimeOut 300000 -MaxLength 20480 -BatchSize $BatchSize -OfflineAction Skip -ResultPropertyName $RepairProperty -PassthroughObjects

               $InstallerToken = Get-AutomateInstallerToken -InstallerType 5
               $ObjectCapture | Where-Object {$_.OperatingSystemName -like '*OS X*'} | ForEach-Object {
                  If ($PSCmdlet.ShouldProcess("Automate Services on $($_.ComputerID) - $($_.ComputerName)",$Action)) {
                     Write-Host -BackgroundColor DarkGray -ForegroundColor Yellow "$($_.ComputerID) - $($_.ComputerName) - Attempting to $Action Automate Services - job will be submitted to online systems"
                     $_ 
                  }
               } | Invoke-ControlCommand -Command @"
LOCATIONID=$($_.Location.Id)
cd /tmp&&(
 (rm -f cwaagent.zip; rm -Rf CWAutomate)&>/dev/null
 curl '$($Script:CWAServer)/LabTech/Deployment.aspx?InstallerToken=$($InstallerToken)' -s -o cwaagent.zip
 [[ `$(find cwaagent.zip -type f -size +700000c 2>/dev/null) ]]&&(
  echo "SUCCESS-cwaagent.zip was downloaded"
  unzip -n -d CWAutomate cwaagent.zip &>/dev/null
  [ -f CWAutomate/config.sh ]&&(
   [ -f /usr/local/ltechagent/uninstaller.sh ]&&(echo "Existing installation found. Removing."; /usr/local/ltechagent/uninstaller.sh)
   cd /tmp/CWAutomate&&(
    mv -f config.sh config.sh.bak 2>/dev/null
    [ -f config.sh.bak ]&&sed "s/LOCATION_ID=[0-9]*/LOCATION_ID=`$LOCATIONID/" config.sh.bak > config.sh&&[ -f config.sh ]&&echo "SUCCESS-Installer Data Updated for location `$LOCATIONID" 
    . ./config.sh ; installer -pkg ./LTSvc.mpkg -verbose -target /
    [ -d /usr/local/ltechagent ]&&echo "SUCCESS-Installer completed"
    launchctl list | grep -i "com.labtechsoftware"&&echo "LTService Started successfully"
   )  
  )||echo ERROR-Failed to extract
 )||echo ERROR-Failed to download cwaagent.zip
)||echo ERROR-Failed to change path to /tmp
"@.Replace("`r",'') -TimeOut 300000 -MaxLength 20480 -BatchSize $BatchSize -OfflineAction Skip -ResultPropertyName $RepairProperty -PassthroughObjects

               $InstallerToken = Get-AutomateInstallerToken -InstallerType 3
               $ObjectCapture | Where-Object {$_.OperatingSystemName -like '*Linux*'} | ForEach-Object {
                  Write-Host -BackgroundColor Yellow -ForegroundColor Red "$($_.ComputerID) - $($_.ComputerName) - $Action action for Operating System ($($_.OperatingSystemName)) is not supported at present in this module"
<#
                  If ($PSCmdlet.ShouldProcess("Automate Services on $($_.ComputerID) - $($_.ComputerName)",$Action)) {
                     Write-Host -BackgroundColor DarkGray -ForegroundColor Yellow "$($_.ComputerID) - $($_.ComputerName) - Attempting to $Action Automate Services - job will be submitted to online systems"
                     $_ 
                  }
#>
               } <# | Invoke-ControlCommand -Command @"
LOCATIONID=$($_.Location.Id)
cd /tmp&&(
 (rm -f cwaagent.zip; rm -Rf CWAutomate)&>/dev/null
 curl '$($Script:CWAServer)/LabTech/Deployment.aspx?InstallerToken=$($InstallerToken)' -s -o cwaagent.zip
 [[ `$(find cwaagent.zip -type f -size +1500000c 2>/dev/null) ]]&&(
  echo SUCCESS-cwaagent.zip was downloaded
  unzip -n -d CWAutomate cwaagent.zip &>/dev/null
  [ -f CWAutomate/config.sh ]&&(
   [ -f /usr/local/ltechagent/uninstaller.sh ]&&(echo Existing installation found. Removing.; /usr/local/ltechagent/uninstaller.sh)
   cd /tmp/CWAutomate&&(
    mv -f config.sh config.sh.bak 2>/dev/null
    [ -f config.sh.bak ]&&sed "s/LOCATION_ID=[0-9]*/LOCATION_ID=`$LOCATIONID/" config.sh.bak > config.sh&&[ -f config.sh ]&&echo "SUCCESS-Installer Data Updated for location `$LOCATIONID" 
    . ./config.sh ; installer -pkg ./LTSvc.mpkg -verbose -target /; [ -d /usr/local/ltechagent ]&&echo SUCCESS-Installer completed
    launchctl list | grep -i "com.labtechsoftware"&&echo "LTService Started successfully"
   )  
  )||echo ERROR-Failed to extract
 )||echo ERROR-Failed to download cwaagent.zip
)||echo ERROR-Failed to change path to /tmp
"@.Replace("`r",'') -TimeOut 300000 -MaxLength 10240 -BatchSize $BatchSize -OfflineAction Skip -ResultPropertyName $RepairProperty -PassthroughObjects 
#>
            )
            $ObjectCapture | Where-Object {!($_.OperatingSystemName -like '*Windows*' -or $_.OperatingSystemName -like '*OS X*' -or $_.OperatingSystemName -like '*Linux*')}  | ForEach-Object {
               Write-Host -BackgroundColor Yellow -ForegroundColor Red "$($_.ComputerID) - $($_.ComputerName) - $Action action for Operating System ($($_.OperatingSystemName)) is not supported at present in this module"
            }
         } Else {
            Write-Host -BackgroundColor Yellow -ForegroundColor Red "Action $Action is not currently supported."
         }

         #Prepare a lookup for results
         $SResultLookup=@{}
         $ServiceResults | ForEach-Object {If (!($SResultLookup.ContainsKey("$($_.SessionID)"))) {$SResultLookup.Add("$($_.SessionID)",$_)}}
         Foreach ($singleObject in $ObjectCapture) {
            [string]$SessionID=$singleObject.SessionID
            If ($SResultLookup.ContainsKey($SessionID)) {
               $singleResult=$SResultLookup[$SessionID] | Select-Object -Expand $RepairProperty
               $AutofixSuccess = $false
               If ($Action -eq 'Check') {
                  If ($singleResult.$RepairProperty -like '*LastSuccessStatus*' -or $singleResult.$RepairProperty -like '*is_signed_in*') {$AutofixSuccess = $true}
               } ElseIf ($Action -eq 'Update') {
                  If ($singleResult.$RepairProperty -like '*successfully*') {$AutofixSuccess = $true}
               } ElseIf ($Action -eq 'Restart') {
                  If ($singleResult.$RepairProperty -like '*started successfully*') {$AutofixSuccess = $true}
               } ElseIf ($Action -eq 'ReInstall') {
                  If ($singleResult.$RepairProperty -like '*successfully*') {$AutofixSuccess = $true}
               } Else {
                  $AutofixSuccess = $true
               }
            } Else {
               $singleResult=[pscustomobject]@{
                  $RepairProperty = "No result was returned for sessionID $($SessionID)"
               }
               $AutofixSuccess = $False
            }
            #Output the final object
            $singleObject | Select-Object -ExcludeProperty $RepairProperty -Property *,@{n=$RepairProperty;e={[pscustomobject]@{'AutofixSuccess'=$AutofixSuccess; 'AutofixResult'=$singleResult.$RepairProperty}}}
         }

         Write-Host -ForegroundColor Green "All jobs completed"
      } Else {
         'No Input Objects could be processed'
      }
   }
}
