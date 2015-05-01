# Converts CimInstance array of type KeyValuePair to hashtable
function Convert-KeyValuePairArrayToHashtable
{
    param (
        [parameter(Mandatory = $true)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $array
    )
    
    $SwitchList = @(
                    "Once",
                    "Weekly",
                    "AsJob",
                    "Daily",
                    "AtLogOn",
                    "AtStartup",
                    "AllowStartIfOnBatteries",
                    "Disable",
                    "DisallowDemandStart",
                    "DisallowHardTerminate"
                    "DisallowStartOnRemoteAppSession"
                    "DontStopIfGoingOnBatteries"
                    "DontStopOnIdleEnd",
                    "Hidden",
                    "MaintenanceExclusive",
                    "RestartOnIdle",
                    "RunOnlyIfIdle",
                    "RunOnlyIfNetworkAvailable",
                    "StartWhenAvailable",
                    "WakeToRun"
                  )
    try
    {
        $hashtable = @{}
        foreach($item in $array)
        {
            # Fix switch parameter values to help cmdlets handle them better
            if ($SwitchList -contains $item.key)
            {
                $hashtable += @{$item.Key = ([bool]::Parse($item.Value))}
            }
            else
            {
                $hashtable += @{$item.Key = $item.Value}
            }
        }
        return $hashtable
    }
    catch
    {
        Write-Verbose "Failed to convert variable. `n $_.Exception.Message"
    }
}
    
Function Get-TargetResource 
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [ValidateSet("Present", "Absent")]
        [string]$Ensure,
        
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance[]]$ActionParams,

        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance[]]$TriggerParams,

        [Parameter(Mandatory = $false)]
        [Microsoft.Management.Infrastructure.CimInstance[]]$TaskSettings
    )
    
    try
    {
        $tasks = Get-ScheduledTask
        if($tasks.TaskName -contains $Name)
        {
            $Ensure = "Present"
            $task = Get-ScheduledTask -TaskName $Name
            $Action = $task.Actions
            $Trigger = $task.Triggers
            #$Settings = $task.Settings
        }
        else
        {
            $Ensure = "Absent"
            $Action = $ActionParams
            $Trigger = $TriggerParams
            #$Settings = $TaskSettings
        }
    }
    catch
    {
        Write-Verbose "$_.Exception.Message"
    }

    @{
        Name = $Name;
        ActionParams = $Action;
        TriggerParams = $Trigger;
        #TaskSettings = $Settings;
        Ensure = $Ensure;
    }
}

Function Test-TargetResource 
{
    [CmdletBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [ValidateSet("Present", "Absent")]
        [string]$Ensure = "Present",
        
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance[]]$ActionParams,

        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance[]]$TriggerParams,

        [Parameter(Mandatory = $false)]
        [Microsoft.Management.Infrastructure.CimInstance[]]$TaskSettings
    )
    
    if ($(Get-ScheduledTask).TaskName -contains $Name)
    {
        Write-Verbose "Task `"$Name`" is present"
        $TaskPresent = $true
    }
    else
    {
        Write-Verbose "Task `"$Name`" was not found"
        $TaskPresent = $false
    }

    if($TaskPresent -and $Ensure -eq "Present") 
    {
        Write-Verbose "Task `"$Name`" is present and in line with Ensure setting of `"$Ensure`""
        return $true
    }

    if(!$TaskPresent -and $Ensure -eq "Absent") 
    {
        Write-Verbose "Task `"$Name`" is absent and in line with Ensure setting of `"$Ensure`""
        return $true
    }
    Write-Verbose "Current state is not in line with Ensure setting: `"$Ensure`""
    return $false
}

Function Set-TargetResource 
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [ValidateSet("Present", "Absent")]
        [string]$Ensure = "Present",
        
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $ActionParams,

        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $TriggerParams,

        [Parameter(Mandatory = $false)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $TaskSettings
    )
    
    $tasks = Get-ScheduledTask

    if($Ensure -eq "Absent") 
    {
        if($tasks.TaskName -contains $Name) 
        {
            Write-Verbose "Deleting Scheduled Task $Name"
            try
            {
                Unregister-ScheduledTask -TaskName $Name -Confirm:$false
            }
            catch 
            {
                Write-Verbose "Failed to delete scheduled task $Name `n $_.Exception.Message"
                #Write-EventLog -LogName DevOps -Source RS_rsScheduledTask -EntryType Error -EventId 1002 -Message "Failed to delete scheduled task $Name `n $_.Exception.Message"
            }
        }
    }

    if($Ensure -eq "Present") 
    {
        try
        {
            # Check if this task is already in place and overwrite it with the current settings by removing it first
            if($tasks.TaskName -contains $Name) 
            {
                Write-Verbose "Deleting existing Scheduled Task $Name"
                Unregister-ScheduledTask -TaskName $Name -Confirm:$false
            }
            
            Write-Verbose "Creating New Scheduled Task $Name"

            # Convert all KeyValue Pair parameter sets from ciminstance to hash table
            [hashtable]$ActionParams = Convert-KeyValuePairArrayToHashtable -array $ActionParams
            [hashtable]$TriggerParams = Convert-KeyValuePairArrayToHashtable -array $TriggerParams
            if ($TaskSettings -ne $null)
            {
                [hashtable]$TaskSettings = Convert-KeyValuePairArrayToHashtable -array $TaskSettings
            }

            # Ensure for mandatory parameter
            if ($ActionParams.Execute -ne $null)
            {           
                Write-Verbose "Creating the $Name Scheduled Task Action..."
                $Action = New-ScheduledTaskAction @ActionParams
            }
            else
            {
                Throw 'Mandatory "ExecutablePath" parameter is not defined in $ActionParams'
            }
            
            # Validate parameter sets for New-ScheduledTaskTrigger cmdlet
            if (($TriggerParams.Once) -or ($TriggerParams.Daily) -or ($TriggerParams.Weekly))
            {
                if ($TriggerParams.At -eq $null)
                {
                    Write-Verbose "Mandatory At parameter not provided, assigning current date and time"
                    $TriggerParams.At = Get-Date
                }
                
                if (($TriggerParams.Weekly -ne $null) -and ($TriggerParams.DaysOfWeek -eq $null))
                {
                    Throw '$TriggerParams is missing the mandatory "DaysOfWeek" parameter from the Weekly parameter set'
                }

                if ($TriggerParams.Once)
                {
                    if ($TriggerParams.RepetitionInterval -eq $null)
                    {
                        Throw '$TriggerParams is missing the mandatory "RepetitionInterval" parameter from the Once parameter set'
                    }
                    
                    if ($TriggerParams.RepetitionDuration -eq $null)
                    {
                        Write-Verbose 'RepetitionDuration not defined, so seting to indefinite...'
                        $TriggerParams.RepetitionDuration = ([timeSpan]::maxvalue)
                    }
                }             
            }
            $Trigger = New-ScheduledTaskTrigger @TriggerParams

            if ($TaskSettings -ne $null)
            {
                $Settings = New-ScheduledTaskSettingsSet @TaskSettings
            }
            else
            {
                Write-Verbose 'TaskSettings parameter set is not defined, applying defaults'
                $Settings = New-ScheduledTaskSettingsSet
            }

            # Currently defaulting to SYSTEM account for now
            Register-ScheduledTask -TaskName $Name -Action $Action -Trigger $Trigger -Settings $Settings -User "SYSTEM"
        }
        catch 
        {
            Write-Verbose "Failed to create scheduled task $Name `n $_"
            #Write-EventLog -LogName DevOps -Source RS_rsScheduledTask -EntryType Information -EventId 1000 -Message "Failed to create scheduled task $Name `n $_.Exception.Message"
        } 
    }
}

Export-ModuleMember -Function *-TargetResource