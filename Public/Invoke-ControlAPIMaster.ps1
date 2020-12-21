function Invoke-ControlAPIMaster {
    <#
    .SYNOPSIS
        Internal function used to make API calls
    .DESCRIPTION
        Internal function used to make API calls
    .PARAMETER Arguments
        Required parameters for the API call
        A URI without a leading "/" will default to the Automate Extension path.
        A URI without a protocol/server will default to the Control Server established by Connect-ControlAPI
    .OUTPUTS
        The returned results from the API call
    .NOTES
        Version:        1.0
        Author:         Darren White
        Creation Date:  2020-08-01
        Purpose/Change: Initial script development

        Version:        1.1.0
        Author:         Darren White
        Creation Date:  2020-12-01
        Purpose/Change: Include values in $Script:CWCHeaders variable in request

    .EXAMPLE
        $APIRequest = @{
            'URI' = "ReportService.ashx/GenerateReportForAutomate"
            'Body' = ConvertTo-Json @("Session","",@('SessionID','SessionType','Name','CreatedTime'),"NOT IsEnded", "", 10000)
        }
        $AllSessions = Invoke-ControlAPIMaster -Arguments $APIRequest
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        $Arguments,
        [int]$MaxRetry = 3
    )

    Begin { 
        $Result = $Null
    }

    Process {
        # Check that we have cached connection info
        If(!$Script:CWCIsConnected) {
            $ErrorMessage = @()
            $ErrorMessage += "Not connected to a Control server."
            $ErrorMessage +=  $_.ScriptStackTrace
            $ErrorMessage += ''
            $ErrorMessage += "----> Run 'Connect-ControlAPI' to initialize the connection before issuing other ControlAPI commands."
            Write-Error ($ErrorMessage | Out-String)
            Return
        }

        # Add default set of arguments
        $Arguments.Item('UseBasicParsing')=$Null
        If (!$Arguments.Headers) {$Arguments.Headers=@{}}
        Foreach($Key in $script:CWCHeaders.Keys){
            If($Arguments.Headers.Keys -notcontains $Key){
                $Arguments.Headers += @{$Key = $script:CWCHeaders.$Key}
            }
        }
        If ($Script:ControlAPIKey) {
            $Arguments.Headers.Item('CWAIKToken') = (Get-CWAIKToken)
        } ElseIf (!$Arguments.Headers.Authorization) {
            $Authstring  = "$($Script:ControlAPICredentials.UserName):$($Script:ControlAPICredentials.GetNetworkCredential().Password)"
            $encodedAuth  = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($Authstring));
            $Arguments.Headers.Item('Authorization') = "Basic $encodedAuth"
        }

        # Check URI format
        if($Arguments.URI -notlike '*`?*' -and $Arguments.URI -like '*`&*') {
            $Arguments.URI = $Arguments.URI -replace '(.*?)&(.*)', '$1?$2'
        }        
        if($Arguments.URI -notmatch '^(https?://|/)') {
            $Arguments.URI = "/App_Extensions/${Script:CWCExtensionID}/$($Arguments.URI)"
        }
        if($Arguments.URI -notmatch '^https?://') {
            $Arguments.URI = "${Script:ControlServer}$($Arguments.URI)"
        }

        If(!$Arguments.ContainsKey('Method')) {
            $Arguments.Add('Method','POST')
        }
        If(!$Arguments.ContainsKey('ContentType')) {
            $Arguments.Add('ContentType','application/json; charset=utf-8')
        }

        # Issue request
        Write-Debug "Calling Control Server Extension with the following arguments:`n$(($Arguments|Out-String -Stream) -join "`n")"
        Try {
            $ProgressPreference = 'SilentlyContinue'
            $Result = Invoke-WebRequest @Arguments
        } Catch {
            # Start error message
            $ErrorMessage = @()
            If($_.Exception.Response){
                # Read exception response
                $ErrorStream = $_.Exception.Response.GetResponseStream()
                $Reader = New-Object System.IO.StreamReader($ErrorStream)
                $global:ErrBody = $Reader.ReadToEnd() | ConvertFrom-Json
                $Result=$_.Exception | Select-Object -ExpandProperty Response

                If($errBody.code){
                    $ErrorMessage += "An exception has been thrown."
                    $ErrorMessage +=  $_.ScriptStackTrace
                    $ErrorMessage += ''    
                    $ErrorMessage += "--> $($ErrBody.code)"
                    If($errBody.code -eq 'Unauthorized'){
                        $Script:CWCIsConnected=$False
                        $ErrorMessage += "-----> $($ErrBody.message)"
                        $ErrorMessage += "-----> Use 'Connect-ControlAPI' to set new authentication."
                    } Else {
                        $ErrorMessage += "-----> $($ErrBody.message)"
                        $ErrorMessage += "-----> ^ Error has not been documented please report. ^"
                    }
                }
            }

            If ($_.ErrorDetails) {
                $Result=$Result | Select-Object -ExcludeProperty Content -Property *,@{n='Content';e={$_.Exception.Message}}
                $ErrorMessage += "An error has been thrown."
                $ErrorMessage +=  $_.ScriptStackTrace
                $ErrorMessage += ''
                $global:errDetails = $_.ErrorDetails
                $ErrorMessage += "--> $($errDetails.code)"
                $ErrorMessage += "--> $($errDetails.message)"
                If($errDetails.errors.message){
                    $ErrorMessage += "-----> $($errDetails.errors.message)"
                }
                If($errDetails.message -match 'Unauthorized'){
                    $Script:CWCIsConnected=$False
                    $ErrorMessage += "-----> Use 'Connect-ControlAPI' to set new authentication."
                }
            }
            If (!$ErrorMessage) {$ErrorMessage+='An unknown error was returned'; $ErrorMessage+=$Result|Out-String -Stream}
            Write-Error ($ErrorMessage | Out-String)
            If ($Result.StatusCode -ne 500 ) {Return}
        }

        # Not sure this will be hit with current iwr error handling
        # May need to move to catch block need to find test
        # TODO Find test for retry
        # Retry the request
        $Retry = 0
        while ($Retry -lt $MaxRetry -and $Result.StatusCode -eq 500) {
            $Retry++
            $Wait = $([math]::pow( 2, $Retry))
            Write-Warning "Issue with request, status: $($Result.StatusCode.Value__) $($Result.StatusDescription)"
            Write-Warning "$($Retry)/$($MaxRetry) retries, waiting $($Wait)s."
            Start-Sleep -Seconds $Wait
            $ProgressPreference = 'SilentlyContinue'
            Try {
                $Result = Invoke-WebRequest @Arguments
            } Catch {
                $Result=$_.Exception | Select-Object -ExpandProperty Response
                $Result=$Result | Select-Object -ExcludeProperty Content -Property *,@{n='Content';e={$_.Exception.Message}}
            }
        }
        If ($Retry -ge $MaxRetry -and $Result.StatusCode -eq 500) {
            Write-Error "Max retries hit. Status: $($Result.StatusCode) $($Result.StatusDescription)"
            Return
        }
    }

    End {
        If ($Result) {
            Try {
                Get-Variable -Name CWCServerTime -Scope 1 -ErrorAction Stop
                Set-Variable -Name CWCServerTime -Scope 1 -Value (Get-Date $($Result.Headers.Date))
            } Catch {}
            $SCData=$(Try {$Result.Content | ConvertFrom-Json} Catch {})
            If ($SCData -and @($SCData.PSObject.Properties.Name) -contains 'FieldNames' -and $SCData.Items -and $SCData.Items.Count -gt 0) {
                $FNames = $SCData.FieldNames
                $SCData.Items | ForEach-Object {
                    $x = $_
                    $SCEventRecord = @{}
                    For ($i = 0; $i -lt $FNames.Length; $i++) {
                        $Null = $SCEventRecord.Add($FNames[$i],$x[$i])
                    }
                    [pscustomobject]$SCEventRecord
                }
            } ElseIf ($SCData) {
                $SCData
            } Else {
                $Result.Content
            }
        }
        Return
    }
}
