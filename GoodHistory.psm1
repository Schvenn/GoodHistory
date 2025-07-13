# Set variables for advanced powershell usage
$Global:history = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
$Global:powershell = Split-Path $profile
$Global:goodhistory = "$powershell\Transcripts\successful_history.txt"

Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
Set-PSReadLineOption -MaximumHistoryCount 1000
Set-PSReadLineOption -MaximumKillRingCount 50

# Modify fields sent to it with proper word wrapping.
function wordwrap ($field, $maximumlinelength) {if ($null -eq $field) {return $null}
$breakchars = ',.;?!\/ '; $wrapped = @()
if (-not $maximumlinelength) {[int]$maximumlinelength = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($maximumlinelength -lt 60) {[int]$maximumlinelength = 60}
if ($maximumlinelength -gt $Host.UI.RawUI.BufferSize.Width) {[int]$maximumlinelength = $Host.UI.RawUI.BufferSize.Width}
foreach ($line in $field -split "`n", [System.StringSplitOptions]::None) {if ($line -eq "") {$wrapped += ""; continue}
$remaining = $line
while ($remaining.Length -gt $maximumlinelength) {$segment = $remaining.Substring(0, $maximumlinelength); $breakIndex = -1
foreach ($char in $breakchars.ToCharArray()) {$index = $segment.LastIndexOf($char)
if ($index -gt $breakIndex) {$breakIndex = $index}}
if ($breakIndex -lt 0) {$breakIndex = $maximumlinelength - 1}
$chunk = $segment.Substring(0, $breakIndex + 1); $wrapped += $chunk; $remaining = $remaining.Substring($breakIndex + 1)}
if ($remaining.Length -gt 0 -or $line -eq "") {$wrapped += $remaining}}
return ($wrapped -join "`n")}

# Display a horizontal line.
function line ($colour, $length, [switch]$pre, [switch]$post, [switch]$double) {if (-not $length) {[int]$length = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($length) {if ($length -lt 60) {[int]$length = 60}
if ($length -gt $Host.UI.RawUI.BufferSize.Width) {[int]$length = $Host.UI.RawUI.BufferSize.Width}}
if ($pre) {Write-Host ""}
$character = if ($double) {"="} else {"-"}
Write-Host -f $colour ($character * $length)
if ($post) {Write-Host ""}}

function goodhistory {# Inline help.
function scripthelp ($section) {# (Internal) Generate the help sections from the comments section of the script.
line yellow 100 -pre; $pattern = "(?ims)^## ($section.*?)(##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; Write-Host $lines[0] -f yellow; line yellow 100
if ($lines.Count -gt 1) {wordwrap $lines[1] 100 | Write-Host -f white | Out-Host -Paging}; line yellow 100}
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)")
if ($sections.Count -eq 1) {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help:" -f cyan; scripthelp $sections[0].Groups[1].Value; ""; return}

$selection = $null
do {cls; Write-Host "$(Get-ChildItem (Split-Path $PSCommandPath) | Where-Object { $_.FullName -ieq $PSCommandPath } | Select-Object -ExpandProperty BaseName) Help Sections:`n" -f cyan; for ($i = 0; $i -lt $sections.Count; $i++) {Write-Host "$($i + 1). " -f cyan -n; Write-Host $sections[$i].Groups[1].Value -f white}
if ($selection) {scripthelp $sections[$selection - 1].Groups[1].Value}
Write-Host -f yellow "`nEnter a section number to view " -n; $input = Read-Host
if ($input -match '^\d+$') {$index = [int]$input
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index}
else {$selection = $null}} else {""; return}}
while ($true); return}

# Keep history clean and deduplicated.
function maintainhistory {Register-EngineEvent PowerShell.OnIdle -SupportEvent -Action {if (-not (Test-Path $goodhistory) -or -not $history) {return}
$raw = Get-Content $goodhistory; $cleaned = $raw | Select-Object -Unique | Select-Object -Last 1000
$cleanedHash = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($cleaned -join "`n")))) -replace '-'
$originalHash = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($raw -join "`n")))) -replace '-'
if ($cleanedHash -ne $originalHash) {$cleaned | Set-Content $goodhistory}
if ($cleanedHash -ne $script:lastGoodHistoryHash) {$cleaned | Set-Content $history; $script:lastGoodHistoryHash = $cleanedHash}}}

# Create a custom PowerShell prompt that shortens long paths and logs only successful commands.
function prompt {if ($?) {$lastCmd = (Get-History -Count 1).CommandLine; Add-Content $goodhistory $lastCmd; $lines = Get-Content $goodhistory -Tail 1000; Set-Content $goodhistory $lines}; Return $pwd.Path+"> "}

function showhistory($value){# Show saved history.
$width = 60;  $content1 = Get-Content $goodhistory; $content2 = Get-Content $history
$actualMax = [Math]::Max($content1.Count, $content2.Count)
$linesToShow = if ($value -gt 0) {[Math]::Min($value, $actualMax)} else {$actualMax}
while ($content1.Count -lt $linesToShow) {$content1 += ''}
while ($content2.Count -lt $linesToShow) {$content2 += ''}
Write-Host -f white "`nGood History".PadRight($width) -n; Write-Host -f white "  | Console History"; Write-Host -f cyan ("-" * 120)
for ($i = 0; $i -lt $linesToShow; $i++) {$left = $content1[$i].PadRight($width).Substring(0, $width); $right = $content2[$i].PadRight($width).Substring(0, $width)
if ($left -ne $right) {Write-Host "$left │ " -NoNewline; Write-Host -f red $right} else {Write-Host "$left │ $right"}}; ""}

sal -name gethistory -value showhistory

maintainhistory; prompt

Export-ModuleMember -Function goodhistory, maintainhistory, prompt, showhistory
Export-ModuleMember -Alias gethistory

<#
## MaintainHistory
This module ensures continual refresh of the default $history file with only the valid and deduplicated commands from $goodhistory whenever the session is in an idle state. History is set to 1000 entries by default.
## Prompt
This is a wrapper for the PowerShell prompt to ensure only successful commands are saved to the $goodhistory file and eventually therefore, passed to the console $history. History is set to 1000 entries by default.
## ShowHistory
See the customized command line history of successful commands side-by-side with the console history. You can specify the number of lines to show. If a line exists in the console history but not in the $goodhistory, then you know that the command either failed, or the console history has not yet been updated with the $goodhistory values.
## Active Module Status
This module operates in live state, rather than a passive one, meaning that it starts executing from the minute you load it, rather than having commands sitting dormant in memory, waiting for the user to call on them. Here is how some of that works:

	# Set variables for advanced powershell usage
	$Global:history = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
	$Global:powershell = Split-Path $profile
	$Global:goodhistory = "$powershell\Transcripts\successful_history.txt"

The first 3 lines set variables for reference in this and other modules. Having a $profile directory for quick reference is handy for scripting in most instances. The other two variables are used directly in this module.

	Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
	Set-PSReadLineOption -MaximumHistoryCount 1000
	Set-PSReadLineOption -MaximumKillRingCount 50

The next 3 lines tell PowerShell to save every command to disk immediately, set the history length to 1000 commands, which is a bit overkill, but should meet even the most advanced user needs, and sets the undo/redo editing via the shell to 50 entries, which is good for being able to backtrack a lot of steps, if you so choose.
## Operation
	function maintainhistory ...
	function prompt ...

The prompt function is configured to saved only successfully executed commands to the $goodhistory and the maintainhistory function is designed to sort, deduplicate and import the current $goodhistory into the console $history everytime the session is idle. Since this takes fractions of a second to happen, it would be very unlikely for any user to notice any performance impact from this activity.

	maintainhistory; prompt

The showhistory and goodhistory functions are passive. They will only run when you call them.

The final step of this module is the act of calling both of the first two functions into action, which is what makes this module work in a live state.
## License
MIT License

Copyright © 2025 Craig Plath

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
THE SOFTWARE.
##>
