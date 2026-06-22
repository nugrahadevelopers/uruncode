# uruncode - run Claude Code or Codex CLI through the UrunAI gateway.

$ErrorActionPreference = 'Stop'

$AppName = 'uruncode'
$DefaultBaseUrl = 'https://api.urunai.my.id/v1'
$DefaultModel_CLAUDE = 'aim-cdx-mini'
$DefaultModel_CODEX = 'gpt-5.4-mini'
$ConfigDir = Join-Path $env:APPDATA 'uruncode'
$ConfigFile = Join-Path $ConfigDir 'config'

function Save-Key([string]$Key) {
  $Key = $Key.Trim()
  if ([string]::IsNullOrEmpty($Key)) {
    Write-Host 'Refusing to save an empty key.'
    return
  }
  New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
  Set-Content -Path $ConfigFile -Value ("URUNAI_API_KEY=" + $Key) -Encoding ASCII
  try {
    $acl = New-Object System.Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
      "$env:USERDOMAIN\$env:USERNAME", 'FullControl', 'Allow')
    $acl.AddAccessRule($rule)
    Set-Acl -Path $ConfigFile -AclObject $acl
  } catch { }
  Write-Host "Key saved to $ConfigFile"
}

function Get-Key {
  if (-not (Test-Path $ConfigFile)) { return $null }
  foreach ($line in Get-Content $ConfigFile) {
    if ($line -like 'URUNAI_API_KEY=*') {
      return $line.Substring('URUNAI_API_KEY='.Length)
    }
  }
  return $null
}

function Backup-FileOnce([string]$Source, [string]$Name) {
  $backupDir = Join-Path $ConfigDir "backups"
  $backupFile = Join-Path $backupDir $Name
  $missingFile = "$backupFile.missing"
  if ((Test-Path $backupFile) -or (Test-Path $missingFile)) { return }
  New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
  if (Test-Path $Source) {
    Copy-Item -Path $Source -Destination $backupFile -Force
  } else {
    Set-Content -Path $missingFile -Value "missing" -Encoding ASCII
  }
}

function Restore-BackupFile([string]$Target, [string]$Name) {
  $backupDir = Join-Path $ConfigDir "backups"
  $backupFile = Join-Path $backupDir $Name
  $missingFile = "$backupFile.missing"
  if (Test-Path $backupFile) {
    $targetDir = Split-Path -Parent $Target
    if ($targetDir) { New-Item -ItemType Directory -Force -Path $targetDir | Out-Null }
    Copy-Item -Path $backupFile -Destination $Target -Force
    Remove-Item $backupFile -Force
    Write-Host "Restored $Target"
  } elseif (Test-Path $missingFile) {
    if (Test-Path $Target) { Remove-Item $Target -Force }
    Remove-Item $missingFile -Force
    Write-Host "Removed $Target; it did not exist before uruncode."
  }
}

function Restore-ConfigBackups {
  $claudeSettings = Join-Path $env:USERPROFILE ".claude\settings.json"
  $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
  Restore-BackupFile $claudeSettings "claude-settings.json"
  Restore-BackupFile (Join-Path $codexHome "config.toml") "codex-config.toml"
  Restore-BackupFile (Join-Path $codexHome "uruncode.config.toml") "codex-uruncode.config.toml"
  $backupDir = Join-Path $ConfigDir "backups"
  if (Test-Path $backupDir) { Remove-Item $backupDir -Recurse -Force -ErrorAction SilentlyContinue }
}

function ConvertTo-OrderedMap([object]$Object) {
  $map = [ordered]@{}
  if ($null -eq $Object) { return ,$map }
  if ($Object -is [System.Collections.IDictionary]) {
    foreach ($key in $Object.Keys) { $map[$key] = $Object[$key] }
  } else {
    foreach ($property in $Object.PSObject.Properties) { $map[$property.Name] = $property.Value }
  }
  return ,$map
}

function Write-JsonFile([string]$Path, [object]$Content) {
  $json = $Content | ConvertTo-Json -Depth 20
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($Path, $json + "`n", $utf8NoBom)
}

function Remove-ClaudeUrunAISettings {
  $settingsFile = Join-Path $env:USERPROFILE ".claude\settings.json"
  if (-not (Test-Path $settingsFile)) { return }

  try {
    $parsed = Get-Content -Raw -Path $settingsFile | ConvertFrom-Json
  } catch {
    return
  }
  if (-not $parsed) { return }

  $content = ConvertTo-OrderedMap $parsed
  if (-not $content.Contains('env') -or -not $content['env']) { return }

  $envContent = ConvertTo-OrderedMap $content['env']
  if (-not $envContent.Contains('ANTHROPIC_BASE_URL')) { return }

  $baseUrl = [string]$envContent['ANTHROPIC_BASE_URL']
  $apiKey = if ($envContent.Contains('ANTHROPIC_API_KEY')) { [string]$envContent['ANTHROPIC_API_KEY'] } else { '' }
  $authToken = if ($envContent.Contains('ANTHROPIC_AUTH_TOKEN')) { [string]$envContent['ANTHROPIC_AUTH_TOKEN'] } else { '' }
  $storedKey = Get-Key
  $expectedBaseUrl = if ($env:URUNAI_BASE_URL) { $env:URUNAI_BASE_URL } else { $DefaultBaseUrl }
  $matchesStoredKey = $storedKey -and (($apiKey -and ($apiKey -eq $storedKey)) -or ($authToken -and ($authToken -eq $storedKey)))
  if (($baseUrl -ne $expectedBaseUrl) -and ($baseUrl -notlike '*urunai*') -and (-not $matchesStoredKey)) { return }

  [void]$envContent.Remove('ANTHROPIC_BASE_URL')
  if ($envContent.Contains('ANTHROPIC_MODEL')) {
    [void]$envContent.Remove('ANTHROPIC_MODEL')
  }
  if ($envContent.Contains('ANTHROPIC_API_KEY')) {
    [void]$envContent.Remove('ANTHROPIC_API_KEY')
  }
  if ($envContent.Contains('ANTHROPIC_AUTH_TOKEN')) {
    [void]$envContent.Remove('ANTHROPIC_AUTH_TOKEN')
  }

  if ($envContent.Count -gt 0) {
    $content['env'] = $envContent
  } else {
    [void]$content.Remove('env')
  }

  if ($content.Count -gt 0) {
    Write-JsonFile $settingsFile $content
  } else {
    Remove-Item $settingsFile -Force
  }
  Write-Host "Removed UrunAI Claude settings from $settingsFile"
}

function Clear-UrunCodeState {
  $backupDir = Join-Path $ConfigDir "backups"
  $claudeBackup = Join-Path $backupDir "claude-settings.json"
  $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
  $codexProfile = Join-Path $codexHome "uruncode.config.toml"
  $codexProfileBackup = Join-Path $backupDir "codex-uruncode.config.toml"
  $hadClaudeBackup = (Test-Path $claudeBackup) -or (Test-Path "$claudeBackup.missing")
  $hadCodexProfileBackup = (Test-Path $codexProfileBackup) -or (Test-Path "$codexProfileBackup.missing")

  Restore-ConfigBackups
  if (-not $hadClaudeBackup) { Remove-ClaudeUrunAISettings }
  if (-not $hadCodexProfileBackup -and (Test-Path $codexProfile)) { Remove-Item $codexProfile -Force }
  if (Test-Path $ConfigFile) { Remove-Item $ConfigFile -Force }
  Write-Host 'Stored key removed.'
}

function Remove-UrunCodeFromPath([string]$InstallDir) {
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not $userPath) { return }

  $parts = @()
  foreach ($part in ($userPath -split ';')) {
    if ($part -and ($part.TrimEnd('\') -ne $InstallDir.TrimEnd('\'))) { $parts += $part }
  }
  $newPath = ($parts -join ';')
  if ($newPath -ne $userPath) {
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    $env:Path = ($env:Path -split ';' | Where-Object { $_ -and ($_.TrimEnd('\') -ne $InstallDir.TrimEnd('\')) }) -join ';'
    Write-Host "Removed $InstallDir from your user PATH."
  }
}

function Invoke-Uninstall {
  Clear-UrunCodeState

  $installDir = Join-Path $env:LOCALAPPDATA 'Programs\uruncode'
  Remove-UrunCodeFromPath $installDir

  $safeConfigDir = $ConfigDir -replace "'", "''"
  $safeInstallDir = $installDir -replace "'", "''"
  $script = @"
`$ErrorActionPreference = 'SilentlyContinue'
Start-Sleep -Seconds 2
Remove-Item -Recurse -Force '$safeConfigDir'
Remove-Item -Recurse -Force '$safeInstallDir'
"@
  $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
  Start-Process -WindowStyle Hidden -FilePath powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded | Out-Null

  Write-Host "Uninstall scheduled. $installDir and $ConfigDir will be removed shortly."
  Write-Host 'Open a new terminal before reinstalling uruncode.'
}

function Invoke-Setup {
  Write-Host ''
  Write-Host '+------------------------------------------+'
  Write-Host '|  uruncode - first-time setup             |'
  Write-Host '+------------------------------------------+'
  Write-Host ''
  Write-Host 'Claude Code and Codex CLI will run through UrunAI.'
  Write-Host 'You only need to enter your UrunAI API key once.'
  Write-Host ''
  for ($i = 0; $i -lt 3; $i++) {
    $secure = Read-Host -AsSecureString 'UrunAI API key'
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $key = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    $key = $key.Trim()
    if ($key) { Save-Key $key; return }
    Write-Host "Key can't be empty."
  }
  Write-Host 'Aborting after 3 empty attempts.'
  exit 1
}

function Resolve-Key {
  $key = Get-Key
  if (-not $key -and $env:URUNAI_API_KEY) {
    $key = $env:URUNAI_API_KEY.Trim()
    Write-Host 'Using URUNAI_API_KEY from environment; saving for next time.'
    Save-Key $key
  }
  if (-not $key) {
    Invoke-Setup
    $key = Get-Key
  }
  if (-not $key) {
    Write-Host "No API key available. Run '$AppName config' to set one."
    exit 1
  }
  return $key
}

function Show-Help {
  Write-Host @'
Usage:
  uruncode                  Choose Claude Code or Codex CLI interactively
  uruncode claude [ARGS...] Run Claude Code through UrunAI
  uruncode codex [ARGS...]  Run Codex CLI through UrunAI
  uruncode config [KEY]     Save or replace the UrunAI API key
  uruncode reset            Restore CLI config backups and delete the stored API key
  uruncode uninstall        Remove uruncode and stored state
  uruncode update           Re-run the installer

Environment overrides:
  URUNAI_API_KEY       API key to save/use
  URUNAI_BASE_URL      Gateway base URL
  URUNAI_CLAUDE_MODEL      Claude Code model alias
  URUNAI_CLAUDE_AUTH_MODE  Claude auth mode: bearer (default) or api-key
  URUNAI_CODEX_MODEL       Codex CLI model alias
'@
}

function Select-Launcher {
  Write-Host ''
  Write-Host 'Choose a launcher:'
  Write-Host '  1) Claude Code'
  Write-Host '  2) Codex CLI'
  Write-Host ''
  $choice = Read-Host 'Selection [1-2]'
  switch ($choice.Trim()) {
    '1' { return 'claude' }
    'claude' { return 'claude' }
    'Claude' { return 'claude' }
    '2' { return 'codex' }
    'codex' { return 'codex' }
    'Codex' { return 'codex' }
    default {
      Write-Host 'Invalid selection.'
      exit 1
    }
  }
}

function Ensure-CodexProfile([string]$BaseUrl, [string]$Model) {
  $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
  $profileFile = Join-Path $codexHome 'uruncode.config.toml'
  Backup-FileOnce (Join-Path $codexHome "config.toml") "codex-config.toml"
  Backup-FileOnce $profileFile "codex-uruncode.config.toml"
  New-Item -ItemType Directory -Force -Path $codexHome | Out-Null
  $content = @"
model = "$Model"
model_provider = "urunai"

[model_providers.urunai]
name = "UrunAI"
base_url = "$BaseUrl"
wire_api = "responses"
env_key = "URUNAI_API_KEY"
"@
  Set-Content -Path $profileFile -Value $content -Encoding ASCII
}

function Ensure-ClaudeSettings([string]$BaseUrl, [string]$Key, [string]$Model, [string]$AuthMode) {
  $settingsDir = Join-Path $env:USERPROFILE ".claude"
  $settingsFile = Join-Path $settingsDir "settings.json"
  Backup-FileOnce $settingsFile "claude-settings.json"
  New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null

  $content = [ordered]@{}
  if (Test-Path $settingsFile) {
    try {
      $parsed = Get-Content -Raw -Path $settingsFile | ConvertFrom-Json
      if ($parsed) { $content = ConvertTo-OrderedMap $parsed }
    } catch {
      $content = [ordered]@{}
    }
  }

  $envContent = [ordered]@{}
  if ($content.Contains('env') -and $content['env']) {
    $envContent = ConvertTo-OrderedMap $content['env']
  }
  $envContent['ANTHROPIC_BASE_URL'] = $BaseUrl
  $envContent['ANTHROPIC_MODEL'] = $Model
  if ($AuthMode -eq 'api-key') {
    $envContent['ANTHROPIC_API_KEY'] = $Key
    if ($envContent.Contains('ANTHROPIC_AUTH_TOKEN')) {
      [void]$envContent.Remove('ANTHROPIC_AUTH_TOKEN')
    }
  } else {
    $envContent['ANTHROPIC_AUTH_TOKEN'] = $Key
    if ($envContent.Contains('ANTHROPIC_API_KEY')) {
      [void]$envContent.Remove('ANTHROPIC_API_KEY')
    }
  }
  $content['env'] = $envContent

  Write-JsonFile $settingsFile $content
}

function Invoke-Claude([string]$Key, [string[]]$Rest) {
  if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host 'claude CLI not found on PATH.'
    Write-Host 'Install Claude Code first: https://docs.claude.com/en/docs/claude-code'
    exit 127
  }

  $baseUrl = if ($env:URUNAI_BASE_URL) { $env:URUNAI_BASE_URL } else { $DefaultBaseUrl }
  $model = if ($env:URUNAI_CLAUDE_MODEL) { $env:URUNAI_CLAUDE_MODEL } else { $DefaultModel_CLAUDE }
  $authMode = if ($env:URUNAI_CLAUDE_AUTH_MODE) { ([string]$env:URUNAI_CLAUDE_AUTH_MODE).ToLowerInvariant() } else { 'bearer' }

  $env:ANTHROPIC_BASE_URL = $baseUrl
  $env:ANTHROPIC_MODEL = $model
  if ($authMode -eq 'api-key') {
    $env:ANTHROPIC_API_KEY = $Key
    Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
  } else {
    $env:ANTHROPIC_AUTH_TOKEN = $Key
    Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
  }
  Ensure-ClaudeSettings $baseUrl $Key $model $authMode

  $hasModelArg = $false
  foreach ($arg in $Rest) {
    if (($arg -eq '--model') -or ($arg -like '--model=*')) { $hasModelArg = $true }
  }
  if ($hasModelArg) {
    & claude @Rest
  } else {
    & claude --model $model @Rest
  }
  exit $LASTEXITCODE
}

function Invoke-Codex([string]$Key, [string[]]$Rest) {
  if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Write-Host 'codex CLI not found on PATH.'
    Write-Host 'Install Codex CLI first: https://developers.openai.com/codex'
    exit 127
  }
  $baseUrl = if ($env:URUNAI_BASE_URL) { $env:URUNAI_BASE_URL } else { $DefaultBaseUrl }
  $model = if ($env:URUNAI_CODEX_MODEL) { $env:URUNAI_CODEX_MODEL } else { $DefaultModel_CODEX }
  Ensure-CodexProfile $baseUrl $model
  $env:URUNAI_API_KEY = $Key

  if ($Rest.Count -ge 1 -and (Test-Path -Path $Rest[0] -PathType Container)) {
    $target = $Rest[0]
    $remaining = @()
    if ($Rest.Count -gt 1) { $remaining = $Rest[1..($Rest.Count - 1)] }
    & codex --profile uruncode --cd $target @remaining
    exit $LASTEXITCODE
  }
  & codex --profile uruncode @Rest
  exit $LASTEXITCODE
}

if ($args.Count -ge 1) {
  switch -Regex ($args[0]) {
    '^(config|--config|set-key|--set-key|change|--change|change-key|--change-key)$' {
      if ($args.Count -ge 2) { Save-Key $args[1] } else { Invoke-Setup }
      Write-Host "Done. Run '$AppName' to start."
      exit 0
    }
    '^(reset|--reset)$' {
      Clear-UrunCodeState
      exit 0
    }
    '^(uninstall|--uninstall)$' {
      Invoke-Uninstall
      exit 0
    }
    '^(update|--update|upgrade|--upgrade)$' {
      Write-Host "Updating $AppName to the latest version..."
      $installUrl = if ($env:URUNCODE_INSTALL_URL) { $env:URUNCODE_INSTALL_URL } else { 'https://raw.githubusercontent.com/nugrahadevelopers/uruncode/main/install.ps1' }
      irm $installUrl | iex
      exit 0
    }
    '^(help|--help|-h)$' {
      Show-Help
      exit 0
    }
  }
}

$launcher = $null
$rest = @()
if ($args.Count -eq 0) {
  $launcher = Select-Launcher
} else {
  $launcher = $args[0]
  if ($args.Count -gt 1) { $rest = $args[1..($args.Count - 1)] }
}

$key = Resolve-Key
switch ($launcher) {
  'claude' { Invoke-Claude $key $rest }
  'cc' { Invoke-Claude $key $rest }
  'codex' { Invoke-Codex $key $rest }
  'cx' { Invoke-Codex $key $rest }
  default {
    Write-Host "Unknown launcher: $launcher"
    Show-Help
    exit 1
  }
}
