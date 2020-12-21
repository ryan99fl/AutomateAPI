function Get-AutomateControlInfo {
<#
.SYNOPSIS
Retrieve data from Automate API Control Extension
.DESCRIPTION
Connects to the Automate API Control Extension and returns an object with Control Session data
.PARAMETER ComputerID
The Automate ComputerID to retrieve information on
.PARAMETER ID
Taken from the Pipeline, IE Get-AutomateComputer -ComputerID 5 | Get-AutomateControlInfo
.PARAMETER ComputerObjects
Used for Pipeline input from Get-AutomateComputer
.OUTPUTS
Custom object with the ComputerID and Control SessionID. Additional properties from the return data will be included.
.NOTES
Version:        1.2.1
Author:         Gavin Stone
Creation Date:  2019-01-20
Purpose/Change: Initial script development

Update Date:    2019-02-12
Author:         Darren White
Purpose/Change: Modified returned object data

Update Date:    2020-07-20
Author:         Darren White
Purpose/Change: Standardized on ComputerID for parameter name

Update Date:    2020-08-04
Author:         Darren White
Purpose/Change: Use Get-AutomateAPIGeneric internally, Error handling

.EXAMPLE
Get-AutomateControlInfo -ComputerId 123
#>
    [CmdletBinding(DefaultParameterSetName = 'ID')]
    param
    (
        [Parameter(ParameterSetName = 'ID', Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName=$False)]
        [int32[]]$ComputerID,

        [Parameter(ParameterSetName = 'pipeline', ValueFromPipeline = $true, Mandatory = $True)]
        $ComputerObjects
    )

    Begin {
        $defaultDisplaySet = 'SessionID'
        #Create the default property display set
        $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultDisplaySet)
        $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
    } #End Begin

    Process {
        #If not pipeline mode, build custom objects.
        If ($PSCmdlet.ParameterSetName -eq 'ID') {
            $ComputerObjects = @()
            ForEach ($ComputerIDSingle in $ComputerID) {
                $OurResult = [pscustomobject]@{
                ComputerID = $ComputerIdSingle
                SessionID = 'Not Found'
                }
                $Null = $OurResult.PSObject.TypeNames.Insert(0,'CWControl.Information')
                $Null = $OurResult | Add-Member MemberSet PSStandardMembers $PSStandardMembers
                $ComputerObjects+=$OurResult
            }
        }

        ForEach ($Computer in $ComputerObjects) {
            If ($PSCmdlet.ParameterSetName -eq 'pipeline') {
                $Null = $Computer | Add-Member -NotePropertyName 'SessionID' -NotePropertyValue 'Not Found' -Force -EA 0
            }
            If ($Computer.ComputerID -and $Computer.ComputerID -gt 0) {
                Try {
                    $Result = Get-AutomateAPIGeneric -Endpoint "extensionactions/control/$($Computer.ComputerID)" -ResultSetSize 1

                    $ResultMatch=$Result|select-string -Pattern '^(https?://[^?]*)\??(.*)' -AllMatches
                    If ($ResultMatch.Matches) {
                        $Null = $Computer | Add-Member -NotePropertyName LaunchURL -NotePropertyValue $($ResultMatch.Matches.Groups[0].Value) -Force
                        $Null = $Computer | Add-Member -MemberType ScriptMethod -Name 'LaunchSession' -Value {Start-Process "$($this.LaunchURL)"} -Force
                        ForEach ($NameValue in $($ResultMatch.Matches.Groups[2].Value -split '&')) {
                            $xName = $NameValue -replace '=.*$',''
                            $xValue = $NameValue -replace '^[^=]*=?',''
                            If ($Computer | Get-Member -Name $xName) {
                                $Computer.$xName=$xValue
                            } Else {
                                $Null = $Computer | Add-Member -NotePropertyName $xName -NotePropertyValue $xValue -Force -EA 0
                            } #End If
                        } #End ForEach
                    } #End If
                } Catch {}
                $Null = $Computer | Add-Member -MemberType AliasProperty -Name ControlGUID -Value SessionID -Force -EA 0
                $Computer
            } Else {
                Write-Host -BackgroundColor Yellow -ForegroundColor Red "An object was passed that is missing a required property (ComputerID)"
            }
        } #End ForEach
    } #End Process

} #End Get-AutomateControlInfo