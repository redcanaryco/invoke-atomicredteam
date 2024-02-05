function Get-InputArgs([hashtable]$ip, $customInputArgs, $PathToAtomicsFolder) {
    $defaultArgs = @{ }
    foreach ($key in $ip.Keys) {
        $defaultArgs[$key] = $ip[$key].default
    }
    # overwrite defaults with any user supplied values
    foreach ($key in $customInputArgs.Keys) {
        if ($defaultArgs.Keys -contains $key) {
            # replace default with user supplied
            $defaultArgs.set_Item($key, $customInputArgs[$key])
        }
        else {
            Write-Verbose "The specified input argument *$key* was ignored as not applicable"
        }
    }
    $defaultArgs
}

function Merge-InputArgs($finalCommand, $test, $customInputArgs, $PathToAtomicsFolder) {
    if (($null -ne $finalCommand) -and ($test.input_arguments.Count -gt 0)) {
        Write-Verbose -Message 'Replacing inputArgs with user specified values, or default values if none provided'
        $inputArgs = Get-InputArgs $test.input_arguments $customInputArgs $PathToAtomicsFolder

        foreach ($key in $inputArgs.Keys) {
            $findValue = '#{' + $key + '}'
            $finalCommand = $finalCommand.Replace($findValue, $inputArgs[$key])
        }
    }

    # Replace $PathToAtomicsFolder or PathToAtomicsFolder with the actual -PathToAtomicsFolder value
    $finalCommand = ($finalCommand -replace "\`$PathToAtomicsFolder", $PathToAtomicsFolder) -replace "PathToAtomicsFolder", $PathToAtomicsFolder

    $finalCommand
}

function Invoke-PromptForInputArgs([hashtable]$ip) {
    $InputArgs = @{ }
    foreach ($key in $ip.Keys) {
        $InputArgs[$key] = $ip[$key].default
        $newValue = Read-Host -Prompt "Enter a value for $key , or press enter to accept the default.`n$($ip[$key].description.trim()) [$($ip[$key].default.trim())]"
        # replace default with user supplied
        if (-not [string]::IsNullOrWhiteSpace($newValue)) {
            $InputArgs.set_Item($key, $newValue)
        }
    }
    $InputArgs
}
