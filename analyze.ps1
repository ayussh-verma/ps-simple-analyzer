# https://stackoverflow.com/a/4647985
function Write-ColorOutput() {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$ForegroundColor,

        [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
        $args
    )
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Get-SettingsFilePath {
    $SettingsFile = Get-ChildItem -Path . -Filter 'PSScriptAnalyzerSettings.*' | Where-Object { $_.Extension -in @('.psd1', '.ps1', '.psm1') } | Where-Object { $_.Extension -in @('.psd1', '.ps1', '.psm1') } | Select-Object -First 1
    if ($SettingsFile) {
        Write-Debug "Settings file found: $($SettingsFile.FullName)"
        return $SettingsFile.FullName
    }
    else {
        throw "A settings file couldn't be found in the current directory."
    }
}


function Format-AnalyzerRecord {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('plain', 'github', 'color')]
        [string]$Format = 'color',

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$RuleName,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$Severity,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$ScriptPath,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [int]$Line,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$Message,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [int]$Column
    )

    process {
        $RelativePath = Resolve-Path -Relative -Path $ScriptPath
        $ReadableOutputString = "${RelativePath}:${Line}:${Column}: ${RuleName} (${Severity}): ${Message}"
        switch ($Format) {
            'plain' {
                Write-Output $ReadableOutputString
            }
            'color' {
                $Color = switch ($Severity) {
                    'Information' { 'Blue' }
                    'Warning' { 'Yellow' }
                    'ParseError' { 'Red' }
                    'Error' { 'Red' }
                }
                Write-ColorOutput $Color $ReadableOutputString
            }
            'github' {
                $GithubSeverity = switch ($Severity) {
                    'Information' { 'warning' }
                    'Warning' { 'warning' }
                    'ParseError' { 'error' }
                    'Error' { 'error' }
                }
                Write-Output "::${GithubSeverity} file=${RelativePath},line=${Line},col=${Column}::${RuleName}: ${Message}"
            }
        }
    }
}


<#
.SYNOPSIS
    Analyzes specified script files using Invoke-ScriptAnalyzer.
.DESCRIPTION
    This script takes a list of files and calls Invoke-ScriptAnalyzer for each file,
    applying any additional arguments passed to the script.
.PARAMETER Files
    A list of file paths to be analyzed by Invoke-ScriptAnalyzer.
    These can be passed as positional arguments.
.PARAMETER NoDetectSettings
    Pass this flag to prevent an attempt at applying a settings file in the current directory.
    Settings file name: "PSScriptAnalyzerSettings.psd1".
.PARAMETER Extras
    Additional arguments to be passed to Invoke-ScriptAnalyzer.
    This must be a single string.
.EXAMPLE
    Invoke-SimpleAnalyzer a.ps1
.EXAMPLE
# TODO
    Invoke-SimpleAnalyzer file1.ps1 file2.ps1 -NoDetectSettings -F "-IncludeDefaultRules rule1"
.NOTES
    Author: Ayussh Verma (ayussh-verma)
.INPUTS
    None. You cannot pipe objects to this script.
#>
function Invoke-SimpleAnalyzer {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromRemainingArguments = $true)]
        [ValidateCount(1, [int]::MaxValue)]
        [string[]]$Files,

        [Parameter()]
        [switch]$UseDefaults,

        [Parameter()]
        [ValidateSet('plain', 'github', 'color')]
        [string]$Format = 'color',

        [Parameter(   )]
        [Hashtable]$AnalyzerArgs = @{}
    )
    $ErrorActionPreference = 'Stop'
    Write-Debug "Files: $Files, UseDefaults: $UseDefaults, Format: $Format"
    if ($UseDefaults) {
        $AnalyzerArgs.Add('-Settings', $((Get-SettingsFilePath)))
        $AnalyzerArgs.Add('-Fix', $true)
        $AnalyzerArgs.Add('-ReportSummary', $true)
    }
    Write-Debug "Analyzer args: $(( $AnalyzerArgs | ConvertTo-Json ))"

    $FilesNotFound = 0
    $LintCounts = 0
    foreach ($File in $Files) {
        try {
            $ScriptAnalyzerOutput = Invoke-ScriptAnalyzer -Path $File @AnalyzerArgs
            $LintCounts += $ScriptAnalyzerOutput.Length
            $ScriptAnalyzerOutput | Format-AnalyzerRecord -Format $Format
        }
        catch [System.Management.Automation.ItemNotFoundException] {
            $FilesNotFound += 1
            Write-Error -Message $_ -ErrorAction Continue
        }
    }
    $FilesChecked = $Files.Length - $FilesNotFound
    if ($LintCounts -eq 0) {
        Write-ColorOutput GREEN "No checked file(s) have any linting errors. Checked $FilesChecked file(s)."
    }
    else {
        Write-ColorOutput RED "Some files have linting errors. Checked $FilesChecked file(s)."
    }

    if ($LintCounts -gt 0 -or $FilesNotFound -gt 0) {
        Write-Error "Linting errors or command failures are present. Checked $FilesChecked out of $(( $Files.Length )) files"
    }
}

<#
.SYNOPSIS
    Formats specified script files using Invoke-Formatter.
.DESCRIPTION
    This script takes a list of files and calls Invoke-Formatter for each file,
    applying any additional arguments passed to the script.
.PARAMETER Files
    A list of file paths to be analyzed by Invoke-Formatter.
    These can be passed as positional arguments.
.PARAMETER NoDetectSettings
    Pass this flag to prevent an attempt at applying a settings file in the current directory.
    Settings file name: "PSScriptAnalyzerSettings.psd1".
.PARAMETER Extras
    Additional arguments to be passed to Invoke-Formatter.
    This must be a single string.
.EXAMPLE
    Invoke-SimpleFormatter file1.ps1 file2.ps1 -NoDetectSettings -Extras "-IncludeDefaultRules rule1"
.EXAMPLE
    Invoke-SimpleFormatter a.ps1
.NOTES
    Author: Ayussh Verma (ayussh-verma)
.INPUTS
    None. You cannot pipe objects to this script.
#>
function Invoke-SimpleFormatter {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromRemainingArguments = $true)]
        [ValidateCount(1, [int]::MaxValue)]
        [string[]]$Files,

        [switch]$DetectSettings,

        [switch]$DryRun,

        [Parameter()]
        [Hashtable]$FormatterArgs = @{}
    )
    $ErrorActionPreference = 'Stop'
    Write-Debug "Files: $Files ; DetectSettings: $DetectSettings ; DryRun: $DryRun"
    if ($DetectSettings) {
        $FormatterArgs.Add('-Settings', $((Get-SettingsFilePath)))
    }
    Write-Debug "Formatter args: $(( $FormatterArgs | ConvertTo-Json ))"

    $FileChangeCount = 0
    $Failures = 0

    foreach ($File in $Files) {
        try {
            $OriginalContent = Get-Content -Path $File -Raw
        }
        catch {
            $Failures += 1
            Write-Error -Message $_ -ErrorAction Continue
            continue
        }
        $FormattedContent = Invoke-Formatter -ScriptDefinition $OriginalContent @FormatterArgs

        if ($OriginalContent -eq $FormattedContent) {
            continue
        }

        $FileChangeCount += 1
        if (-not $DryRun) {
            Set-Content -Path $File -Value $FormattedContent
        }
    }

    $FilesChecked = $Files.Length - $Failures
    if ($FileChangeCount -eq 0) {
        Write-ColorOutput GREEN "No files needed to be modified. Checked $FilesChecked file(s)."
    }
    elseif ($DryRun) {
        Write-Output "$FileChangeCount out of $FilesChecked file(s) are poorly formatted."
    }
    else {
        Write-Output "Some files were formatted. $FileChangeCount out of $FilesChecked file(s) were modified."
    }

    if ($Failures -gt 0) {
        Write-Error "Failed to format $Failures file(s)."
    }
}
