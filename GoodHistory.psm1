# Set variables for advanced powershell usage
$Global:history = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
$Global:powershell = Split-Path $profile
$Global:goodhistory = "$powershell\Transcripts\successful_history.txt"

Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
Set-PSReadLineOption -MaximumHistoryCount 1000
Set-PSReadLineOption -MaximumKillRingCount 50

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

Export-ModuleMember -Function maintainhistory, prompt, showhistory
Export-ModuleMember -Alias gethistory

<#
## maintainhistory

This module ensures continual refresh of the default $history file with only the valid and deduplicated commands from $goodhistory whenever the session is in an idle state. History is set to 1000 entries by default.
## prompt

This is a wrapper for the PowerShell prompt to ensure only successful commands are saved to the $goodhistory file and eventually therefore, passed to the console $history. History is set to 1000 entries by default.
## showhistory

See the customized command line history of successful commands side-by-side with the console history. You can specify the number of lines to show. If a line exists in the console history but not in the $goodhistory, then you know that the command either failed, or the console history has not yet been updated with the $goodhistory values.
## Active Module Status

This module operates in live state, rather than a passive one, meaning that it starts executing from the minute you load it, rather than having commands sitting dormant in memory, waiting for the user to call on them. Here is how some of that works:

	# Set variables for advanced powershell usage
	$Global:history = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
	$Global:powershell = Split-Path $profile
	$Global:goodhistory = "$powershell\Transcripts\successful_history.txt"

	Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
	Set-PSReadLineOption -MaximumHistoryCount 1000
	Set-PSReadLineOption -MaximumKillRingCount 50

	function maintainhistory ...
	
	function prompt ...
	
	function showhistory ...
	
	maintainhistory; prompt

The first 3 lines set variables for reference in this and other modules. Having a $profile directory for quick reference is handy for scripting in most instances. The other two variables are used directly in this module.

The next 3 lines tell PowerShell to save every command to disk immediately, set the history length to 1000 commands, which is a bit overkill, but should meet even the most advanced user needs, and sets the undo/redo editing via the shell to 50 entries, which is good for being able to backtrack a lot of steps, if you so choose.

The prompt function is configured to saved only successfully executed commands to the $goodhistory and the maintainhistory function is designed to sort, deduplicate and import the current $goodhistory into the console $history everytime the session is idle. Since this takes fractions of a second to happen, it would be very unlikely for any user to notice any performance impact from this activity.

Only the showhistory function is passive. It will only run when you call it.

The final step of this module is the act of calling both of the first two functions into action, which is what makes this module work in a live state.
##>