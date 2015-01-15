$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$leaf = Split-Path -Leaf $MyInvocation.MyCommand.Path
$source = $leaf -replace ".Tests.ps1$",".psm1"

Describe "Testing rsScheduled Task resource execution" {
    Copy-Item -Path "$here\$source" -Destination TestDrive:\script.ps1
    Mock -CommandName Export-ModuleMember -MockWith {return $true}
    . TestDrive:\script.ps1

    It "Get-TargetResource should return [Hashtable]" {
        (Get-TargetResource -ExecutablePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Params "Get-Process" -Name "Test" -Interval 5).GetType() -as [String] | Should Be "hashtable"
    }

    $taskNames = @("test1","test2")
    $taskList = @()
    Foreach ($name in $taskNames) {$taskList += New-Object -TypeName psobject -Property @{"TaskPath"="\";"TaskName"=$name;"State"="Ready"}}
    Mock -CommandName Get-ScheduledTask -MockWith {return $taskList}

    Context "When the task does not exist and Ensure is set to Present" {
         
        Mock -CommandName schtasks.exe -MockWith {} -Verifiable
        Mock -CommandName Write-Verbose -MockWith {} -Verifiable -ParameterFilter {$Message -like "Creating New Scheduled Task*"}

        It "Test-TargetResource should return false" {
            Test-TargetResource -ExecutablePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Params "Get-Process" -Name "test3" -Interval 5 | Should Be $false
        }

        Set-TargetResource -ExecutablePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Params "Get-Process" -Name "test3" -Interval 5
        It "Set-TargetResource should create the task" {
            Assert-VerifiableMocks
        }
    }

    Context "When the task does exist and Ensure is set to Present" {
         
        Mock -CommandName schtasks.exe -MockWith {} -Verifiable
        Mock -CommandName Write-Verbose -MockWith {} -Verifiable -ParameterFilter {$Message -like "Creating New Scheduled Task*"}

        It "Test-TargetResource should return true" {
            Test-TargetResource -ExecutablePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Params "Get-Process" -Name "test2" -Interval 5 | Should Be $true
        }

        Set-TargetResource -ExecutablePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Params "Get-Process" -Name "test2" -Interval 5
        It "Set-TargetResource should not try to create the task" {
            Assert-MockCalled -CommandName schtasks.exe -Exactly 0
            Assert-MockCalled -CommandName Write-Verbose -ParameterFilter {$Message -like "Creating New Scheduled Task*"} -Exactly 0
        }
    }

    Context "When the task does not exist and Ensure is set to Absent" {
         
        Mock -CommandName schtasks.exe -MockWith {} -Verifiable
        Mock -CommandName Write-Verbose -MockWith {} -Verifiable -ParameterFilter {$Message -like "Deleting Scheduled Task*"}

        It "Test-TargetResource should return true" {
            Test-TargetResource -ExecutablePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Ensure Absent -Params "Get-Process" -Name "test3" -Interval 5 | Should Be $true
        }

        Set-TargetResource -ExecutablePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Ensure Absent -Params "Get-Process" -Name "test3" -Interval 5
        It "Set-TargetResource should not try to delete the task" {
            Assert-MockCalled -CommandName schtasks.exe -Exactly 0
            Assert-MockCalled -CommandName Write-Verbose -ParameterFilter {$Message -like "Deleting Scheduled Task*"} -Exactly 0
        }
    }

    Context "When the task does exist and Ensure is set to Absent" {
         
        Mock -CommandName schtasks.exe -MockWith {} -Verifiable
        Mock -CommandName Write-Verbose -MockWith {} -Verifiable -ParameterFilter {$Message -like "Deleting Scheduled Task*"}

        It "Test-TargetResource should return false" {
            Test-TargetResource -ExecutablePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Ensure Absent -Params "Get-Process" -Name "test2" -Interval 5 | Should Be $false
        }

        Set-TargetResource -ExecutablePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Ensure Absent -Params "Get-Process" -Name "test2" -Interval 5
        It "Set-TargetResource should try to delete the task" {
            Assert-VerifiableMocks
        }
    }


}


