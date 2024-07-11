
$artConfig = [PSCustomObject]@{

  # [optional] These two configs are calculated programatically, you probably don't need to change them
  basehostname               = $((hostname | Select-String -Pattern "(.*?)(-[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})?$").Matches.Groups[1].value)
  OS                         = $( if ($IsLinux) { "linux" } elseif ($IsMacOS) { "macos" } else { "windows" })

  # [optional(if using default install paths)] Paths to your Atomic Red Team "atomics" folder and your "invoke-atomicredteam" folder
  PathToInvokeFolder         = Join-Path $( if ($IsLinux -or $IsMacOS) { "~" } else { "C:" })  "/AtomicRedTeam/invoke-atomicredteam" # this is the default install path so you probably don't need to change this
  PathToPublicAtomicsFolder  = Join-Path $( if ($IsLinux -or $IsMacOS) { "~" } else { "C:" })  "AtomicRedTeam/atomics" # this is the default install path so you probably don't need to change this
  PathToPrivateAtomicsFolder = Join-Path $( if ($IsLinux -or $IsMacOS) { "~" } else { "C:" })   "PrivateAtomics/atomics" # if you aren't providing your own private atomics that are custom written by you, just leave this as is

  # [ Optional ] The user that will be running each atomic test
  user                       = $( if ($IsLinux -or $IsMacOS) { $env:USER } else { "$env:USERDOMAIN\$env:USERNAME" }) # example "corp\atomicrunner"

  # [optional] the path where you want the folder created that houses the logs and the runner schedule. Defaults to users home directory
  basePath                   = $( if (!$IsLinux -and !$IsMacOS) { $env:USERPROFILE } else { $env:HOME }) # example "C:\Users\atomicrunner"

  # [optional]
  scheduleTimeSpan           = New-TimeSpan -Days 7 # the time in which all tests on the schedule should complete
  kickOffDelay               = New-TimeSpan -Minutes 0 # an additional delay before Invoke-KickoffAtomicRunner calls Invoke-AtomicRunner
  scheduleFileName           = "AtomicRunnerSchedule.csv"

  # [optional] Logging Module, uses Syslog-ExecutionLogger if left blank and the syslogServer and syslogPort are set, otherwise it uses the Default-ExecutionLogger
  LoggingModule              = ''

  # [optional] Syslog configuration, default execution logs will be sent to this server:port
  syslogServer               = '' # set to empty string '' if you don't want to log atomic execution details to a syslog server (don't includle http(s):\\)
  syslogPort                 = 514
  syslogProtocol             = 'UDP' # options are UDP, TCP, TCPwithTLS

  verbose                    = $true; # set to true for more log output

  # [optional] logfile filename configs
  logFolder                  = "AtomicRunner-Logs"
  timeLocal                  = (Get-Date(get-date) -uformat "%Y-%m-%d").ToString()
  logFileName                = "$($artConfig.timeLocal)`_$($artConfig.basehostname)-ExecLog.csv"

  # amsi bypass script block (applies to Windows only)
  absb                       = $null

  # AtomicRunnerService install directory
  ServiceInstallDir                 = "${ENV:windir}\System32"

}

# If you create a file called privateConfig.ps1 in the same directory as you installed Invoke-AtomicRedTeam you can overwrite any of these settings with your custom values
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$pathToPrivateConfig = Join-Path $root "privateConfig.ps1"
if (Test-Path ($pathToPrivateConfig)) {
  if ($IsLinux -or $IsMacOS) {
    chmod +x $pathToPrivateConfig
  }
  & ($pathToPrivateConfig)
}

#####################################################################################
# All of the configs below are calculated using the script block in the "Value" field.
# This way, when you change the 'basePath' everything else is updated.
# You should probably leave all of the stuff below alone.
#####################################################################################

$scriptParam = @{
  MemberType  = "ScriptProperty"
  InputObject = $artConfig
  Name        = "runnerFolder"
  Value       = { Join-Path $artConfig.basePath "AtomicRunner" }
}
Add-Member @scriptParam

$scriptParam = @{
  MemberType  = "ScriptProperty"
  InputObject = $artConfig
  Name        = "atomicLogsPath"
  Value       = { Join-Path $artConfig.basePath $artConfig.logFolder }
}
Add-Member @scriptParam

$scriptParam = @{
  MemberType  = "ScriptProperty"
  InputObject = $artConfig
  Name        = "scheduleFile"
  Value       = { Join-Path $artConfig.runnerFolder  $artConfig.scheduleFileName }
}
Add-Member @scriptParam

$scriptParam = @{
  MemberType  = "ScriptProperty"
  InputObject = $artConfig
  Name        = "credFile"
  Value       = { Join-Path $artConfig.runnerFolder "psc_$($artConfig.basehostname).txt" }
}
Add-Member @scriptParam

$scriptParam = @{
  MemberType  = "ScriptProperty"
  InputObject = $artConfig
  Name        = "execLogPath"
  Value       = { Join-Path $artConfig.atomicLogsPath $artConfig.logFileName }
}
Add-Member @scriptParam

$scriptParam = @{
  MemberType  = "ScriptProperty"
  InputObject = $artConfig
  Name        = "stopFile"
  Value       = { Join-Path $artConfig.runnerFolder "stop.txt" }
}
Add-Member @scriptParam

$scriptParam = @{
  MemberType  = "ScriptProperty"
  InputObject = $artConfig
  Name        = "logFile"
  Value       = { Join-Path $artConfig.atomicLogsPath "log-$($artConfig.basehostname).txt" }
}
Add-Member @scriptParam
