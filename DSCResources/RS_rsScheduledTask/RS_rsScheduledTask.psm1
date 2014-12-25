    Function Get-TargetResource {
        param (
            [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ExecutablePath,
            [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Params,
            [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Name,
            [ValidateSet("MINUTE", "HOURLY", "DAILY", "WEEKLY", "ONSTART", "ONLOGON")][string]$IntervalModifier = "MINUTE",
            [ValidateSet("PRESENT", "ABSENT")][string]$Ensure = "PRESENT",
            [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][int]$Interval = 5
        )
        @{
            ExecutablePath = $ExecutablePath;
            Params = $Params;
            Name = $Name;
            IntervalModifier = $IntervalModifier;
            Ensure = $Ensure;
            Interval = $Interval;
        }
    }

    Function Test-TargetResource {
        param (
            [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ExecutablePath,
            [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Params,
            [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Name,
            [ValidateSet("MINUTE", "HOURLY", "DAILY", "WEEKLY", "ONSTART", "ONLOGON")][string]$IntervalModifier = "MINUTE",
            [ValidateSet("PRESENT", "ABSENT")][string]$Ensure = "PRESENT",
            [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][int]$Interval = 5
        )
        $tasks = Get-ScheduledTask

        if($tasks.TaskName -contains $Name) {
            return $true
        }
        else {
            return $false
        }

    }

    Function Set-TargetResource {
        param (
            [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ExecutablePath,
            [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Params,
            [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Name,
            [ValidateSet("MINUTE", "HOURLY", "DAILY", "WEEKLY", "ONSTART", "ONLOGON")][string]$IntervalModifier = "MINUTE",
            [ValidateSet("PRESENT", "ABSENT")][string]$Ensure = "PRESENT",
            [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][int]$Interval = 5
        )
        $tasks = Get-ScheduledTask

        if($Ensure -eq "ABSENT") {
            if($tasks.TaskName -contains $Name) {
                Write-Verbose "Deleting Scheduled Task $Name"
                try{
                    schtasks.exe /delete /tn $Name /f
                }
                catch {
                    Write-EventLog -LogName DevOps -Source RS_rsScheduledTask -EntryType Error -EventId 1002 -Message "Failed to delete scheduled task $Name `n $_.Exception.Message"
                }
            }
        }

        if($Ensure -eq "PRESENT") {
            if($tasks -notcontains $Name) {
                Write-Verbose "Creating New Scheduled Task $Name $ExecutablePath $Params"
                try{
                    schtasks.exe /create /tn $Name /tr $($ExecutablePath, $Params -join ' ') /sc $IntervalModifier /mo $Interval /ru system /f
                }
                catch {
                    Write-EventLog -LogName DevOps -Source RS_rsScheduledTask -EntryType Information -EventId 1000 -Message "Failed to create scheduled task $Name `n $_.Exception.Message"
                }
            }   
        }

    }
Export-ModuleMember -Function *-TargetResource