# Voice Interaction Module for NetworkDriverTool

Add-Type -AssemblyName System.Speech

function Invoke-VoiceCommand {
    Write-Log "Starting voice command recognition..."
    $recognizer = New-Object System.Speech.Recognition.SpeechRecognizer
    $grammar = New-Object System.Speech.Recognition.DictationGrammar
    $recognizer.LoadGrammar($grammar)

    $recognizer.SpeechRecognized | ForEach-Object {
        $command = $_.Result.Text.ToLower()
        Write-Log "Voice command recognized: $command"
        Invoke-VoiceCommand -Command $command
    }

    Write-Log "Voice recognition active. Say commands like 'check drivers' or 'backup drivers'."
    Start-Sleep -Seconds 30  # Listen for 30 seconds
    $recognizer.Dispose()
}

function Invoke-VoiceCommand {
    param([string]$Command)
    switch -Regex ($Command) {
        'check drivers' { Get-DriverInfo | Out-Voice }
        'backup drivers' { Backup-Drivers -Drivers (Get-DriverInfo); Out-Voice "Backup complete" }
        'health check' { Health-Check; Out-Voice "Health check complete" }
        'install missing' { Install-MissingDrivers -Missing ((Get-DriverInfo) | Where-Object { $_.Status -ne 'Installed' }); Out-Voice "Installation attempted" }
        'show gui' { Show-GUI }
        default { Out-Voice "Command not recognized" }
    }
}

function Out-Voice {
    param([string]$Text)
    $synthesizer = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $synthesizer.Speak($Text)
    $synthesizer.Dispose()
}

function Start-VoiceFeedback {
    param([string]$Message)
    Out-Voice $Message
}

# Export functions
Export-ModuleMember -Function Invoke-VoiceCommand, Start-VoiceFeedback