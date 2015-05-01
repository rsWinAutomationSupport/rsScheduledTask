# rsScheduledTask

The rsScheduledTask module allows management of the Windows Task Scheduler tasks.

## Resources

### rsScheduledTask
Configure Windows Scheduled tasks

* **Name**: Name of the task
* **Ensure**: Ensures that the task is **Present** or **Absent**
* **ActionParams**: A hashtable that contains all parameters that need to be passed to *New-ScheduledTaskAction* to define what you wish to execute
* **TriggerParams**: A hashtable that contains all parameters that need to be passed to *New-ScheduledTaskTrigger* to define the trigger for the task 
* **TaskSettings**: An optional hashtable that contains all parameters that need to be passed to *New-ScheduledTaskSettingsSet* to define task options

#### Note on valid cmdlet parameters
Please review help files for [New-ScheduledTaskAction](http://go.microsoft.com/fwlink/p/?linkid=287552), [New-ScheduledTaskTrigger](http://go.microsoft.com/fwlink/p/?linkid=287555) and [New-ScheduledTaskSettingsSet](http://go.microsoft.com/fwlink/p/?linkid=287554") to identify valid parameters and correct sets to use.

Some mandatory cmdlet parameters will be assigned a sensible value to simplify usage. For example, if you define a task that repeats every 5 minutes, you need to provide the RepetitionDuration parameter. If not provided, the rsScheduledTask resource will assign a maxvalue (```([timeSpan]::maxvalue)```) to this parameter by default to simplify usage. Similarly, the **At** parameter will be assigned the current date/time value by default.

## Versions

### 1.1.0
* Converting to native PowerShell cmdlets
	* Added support for the complete set of task-creation options

### 1.0.0
* Original release
	* schtasks.exe used to create scheduled tasks

## Examples
### Create a 5-minute reoccurring task
In this example we're running powershell.exe (*Execute* action parameter)and executing Test-Connection cmdlet to ping a remote host (*Argument* action parameter that is passed to the executable). Note that the optional TaskSettings parameter is not used and default settings will be applied as a result.

The Trigger parameters are defined in a similar fashion. 

***Please note*** that any switch cmdlet parameters need to have a $true or $false value associated with them. Interval parameters, such as *RepetitionInterval* need to have a TimeSpan formatted value assigned to them (see *help New-TimeSpan* for more details). An alternative to the value for *RepetitionInterval* in below example would be ```"RepetitionInterval" = (New-TimeSpan -Minutes 5)``` 

```posh
# Parameter variable definition
$AParams = @{
            "Execute" = "$pshome\powershell.exe";
            "Argument" = "Test-Connection -ComputerName www.google.com -Quiet";
            }

$TParams = @{
            "Once" = $true;
            "RepetitionInterval" = "00:05:00";
            }

# Resource Usage
rsScheduledTask TestTask
{
    Ensure = "Present"
    Name = "Ping Task"
    ActionParams = $AParams
    TriggerParams = $TParams
}
```

### Create a Weekly task that runs every Monday at 3am
In this example, we're creating the same action, but this time it will be executed every Monday, at 3am.


```posh
# Parameter variable definition
$AParams = @{
            "Execute" = "$pshome\powershell.exe";
            "Argument" = "Test-Connection -ComputerName www.google.com -Quiet";
            }

$TParams = @{
            "Weekly" = $true;
            "At" = "3am";
            "DaysOfWeek" = "Monday"
            }

# Resource Usage
rsScheduledTask TestTask
{
    Ensure = "Present"
    Name = "Ping Task"
    ActionParams = $AParams
    TriggerParams = $TParams
}
```