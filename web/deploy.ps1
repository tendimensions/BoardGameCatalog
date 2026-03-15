<#
.SYNOPSIS
    Deploy the Board Game Catalog web application to a remote Docker host via SSH.

.DESCRIPTION
    Packages the web application source, transfers it to the remote Linux server over
    SSH/SCP, then builds and starts the Docker container and runs any pending database
    migrations.

    Run this script from the web/ directory (where docker-compose.yml lives).

    Prerequisites on the local machine:
      - ssh and scp  (OpenSSH — built into Windows 10/11)
      - tar.exe      (built into Windows 10 1803+)

    Prerequisites on the remote server:
      - Docker and docker compose (v2) or docker-compose (v1)
      - A .env file at <RemotePath>/.env  (copy from web/.env.example and fill in secrets)
      - SSH access with key-based authentication recommended

.PARAMETER Ssh
    SSH target in the form  user@hostname  or  user@ip-address.
    Example:  deploy@boardgames.tendimensions.com

.PARAMETER RemotePath
    Absolute or home-relative path on the server where the project lives.
    Defaults to ~/boardgames.  Created automatically if it does not exist.

.PARAMETER SkipBuild
    Skip the  docker compose build  step and go straight to  up -d.
    Useful when only config or static files changed and no code rebuild is needed.

.PARAMETER SkipMigrate
    Skip running  python manage.py migrate  after the container starts.
    Useful when you know no schema changes are included in this deployment.

.PARAMETER SshPort
    SSH port on the remote server.  Defaults to 22.

.PARAMETER AppDomain
    Public hostname of the deployed application — used only in the summary output.
    Defaults to boardgames.tendimensions.com.
    Use this when the SSH hostname differs from the public app domain.

.EXAMPLE
    .\deploy.ps1 -Ssh jason@ssh.tendimensions.com

.EXAMPLE
    .\deploy.ps1 -Ssh jason@ssh.tendimensions.com -AppDomain boardgames.tendimensions.com

.EXAMPLE
    .\deploy.ps1 -Ssh deploy@192.168.1.100 -RemotePath ~/boardgames -SshPort 2222

.EXAMPLE
    .\deploy.ps1 -Ssh deploy@192.168.1.100 -SkipMigrate
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0,
               HelpMessage = "SSH target: user@hostname or user@ip")]
    [ValidatePattern('^[^@]+@.+$')]
    [string]$Ssh,

    [string]$RemotePath = '~/boardgames',

    [switch]$SkipBuild,

    [switch]$SkipMigrate,

    [ValidateRange(1, 65535)]
    [int]$SshPort = 22,

    [string]$AppDomain = 'boardgames.tendimensions.com'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Colour helpers ────────────────────────────────────────────────────────────

function Write-Step   { param([string]$Msg) Write-Host "`n▶  $Msg"       -ForegroundColor Cyan    }
function Write-Ok     { param([string]$Msg) Write-Host "   ✓  $Msg"     -ForegroundColor Green   }
function Write-Warn   { param([string]$Msg) Write-Host "   ⚠  $Msg"     -ForegroundColor Yellow  }
function Write-Fail   { param([string]$Msg) Write-Host "   ✗  $Msg"     -ForegroundColor Red     }
function Write-Detail { param([string]$Msg) Write-Host "      $Msg"     -ForegroundColor DarkGray }

$SshOpts = @('-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=15', '-p', "$SshPort")
$ScpOpts = @('-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=15', '-P', "$SshPort")

function Invoke-RemoteCommand {
    <#  Run a command on the remote host; throw on non-zero exit. #>
    param([string]$Command, [string]$Description = '')
    if ($Description) { Write-Detail $Description }
    $Command = $Command -replace "`r`n", "`n"
    ssh @SshOpts $Ssh $Command
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Remote command failed (exit $LASTEXITCODE)"
        throw "Remote command failed: $Command"
    }
}

# ── Check local tools ─────────────────────────────────────────────────────────

Write-Step 'Checking local prerequisites (ssh, scp, tar)...'

foreach ($tool in @('ssh', 'scp', 'tar')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Fail "$tool not found"
        throw (
            "'$tool' is required but not in PATH.`n" +
            "  ssh / scp: enable OpenSSH via Settings → Apps → Optional Features`n" +
            "  tar:       available on Windows 10 version 1803 and later`n"
        )
    }
}
Write-Ok 'ssh, scp, tar all present'

# ── Locate web directory ──────────────────────────────────────────────────────

$RepoRoot = $PSScriptRoot
if (-not (Test-Path (Join-Path $RepoRoot 'docker-compose.yml'))) {
    throw "deploy.ps1 must be run from the web/ directory (next to docker-compose.yml)."
}

# ── Test SSH connectivity ─────────────────────────────────────────────────────

Write-Step "Connecting to $Ssh (port $SshPort)..."
$testOutput = ssh @SshOpts $Ssh 'echo __ssh_ok__' 2>&1
if ($LASTEXITCODE -ne 0 -or $testOutput -notmatch '__ssh_ok__') {
    Write-Fail 'SSH connection failed'
    throw (
        "Cannot reach $Ssh on port $SshPort.`n" +
        "Verify the hostname, port, and that your SSH key is authorised on the server.`n" +
        "Details: $testOutput"
    )
}
Write-Ok 'SSH connection established'

# ── Ensure remote directories exist ──────────────────────────────────────────

Write-Step 'Preparing remote directories...'
Invoke-RemoteCommand "mkdir -p $RemotePath/data $RemotePath/logs" 'Creating data and logs directories'
Write-Ok "Remote path: $RemotePath"

# ── Check for .env on server ─────────────────────────────────────────────────

Write-Step 'Checking for .env on server...'
$envStatus = ssh @SshOpts $Ssh "test -f $RemotePath/.env && echo exists || echo missing" 2>&1
if ($envStatus -match 'missing') {
    Write-Warn ".env not found at $RemotePath/.env"
    Write-Warn 'The app will not start without it.  After this deployment runs:'
    Write-Warn "  1. ssh $Ssh"
    Write-Warn "  2. cp $RemotePath/.env.example $RemotePath/.env"
    Write-Warn "  3. nano $RemotePath/.env   # fill in SECRET_KEY, MS_GRAPH_*, etc."
    Write-Warn "  4. docker compose -f $RemotePath/docker-compose.yml up -d"
} else {
    Write-Ok '.env present on server'
}

# ── Build local archive ───────────────────────────────────────────────────────

Write-Step 'Packaging source files...'

$timestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$tmpArchive = Join-Path ([System.IO.Path]::GetTempPath()) "boardgame-deploy-$timestamp.tar.gz"

$excludeArgs = @(
    '--exclude=.venv',
    '--exclude=__pycache__',
    '--exclude=*.pyc',
    '--exclude=*.pyo',
    '--exclude=*.pyd',
    '--exclude=.env',
    '--exclude=data',
    '--exclude=logs',
    '--exclude=staticfiles',
    '--exclude=db.sqlite3'
)

Push-Location $RepoRoot
try {
    & tar -czf $tmpArchive @excludeArgs .
    if ($LASTEXITCODE -ne 0) { throw 'tar failed to create the deployment archive.' }
} finally {
    Pop-Location
}

$archiveSizeKB = [math]::Round((Get-Item $tmpArchive).Length / 1KB, 0)
Write-Ok "Archive ready: $archiveSizeKB KB"

# ── Upload archive ────────────────────────────────────────────────────────────

Write-Step "Uploading to ${Ssh}:${RemotePath} ..."

$remoteArchivePath = "$RemotePath/_deploy.tar.gz"
scp @ScpOpts $tmpArchive "${Ssh}:${remoteArchivePath}"
if ($LASTEXITCODE -ne 0) {
    Remove-Item $tmpArchive -Force -ErrorAction SilentlyContinue
    throw 'scp upload failed.  Check your SSH connection and disk space on the server.'
}

Remove-Item $tmpArchive -Force
Write-Ok 'Upload complete'

# ── Extract on server ─────────────────────────────────────────────────────────

Write-Step 'Extracting files on server...'
Invoke-RemoteCommand (
    "cd $RemotePath && " +
    "tar -xzf _deploy.tar.gz --overwrite && " +
    "rm _deploy.tar.gz"
) 'Extracting archive'
Write-Ok 'Files extracted'

# ── Docker build ──────────────────────────────────────────────────────────────

if (-not $SkipBuild) {
    Write-Step 'Building Docker image (may take a minute on first run)...'

    $buildScript = @"
cd $RemotePath
if docker compose version > /dev/null 2>&1; then
    COMPOSE='docker compose'
else
    COMPOSE='docker-compose'
fi
`$COMPOSE build --no-cache 2>&1
"@

    Invoke-RemoteCommand $buildScript 'docker compose build'
    Write-Ok 'Image built'
} else {
    Write-Warn 'Skipping build (-SkipBuild was set)'
}

# ── Start container ───────────────────────────────────────────────────────────

Write-Step 'Starting container...'

$upScript = @"
cd $RemotePath
if docker compose version > /dev/null 2>&1; then
    COMPOSE='docker compose'
else
    COMPOSE='docker-compose'
fi
`$COMPOSE up -d 2>&1
"@

Invoke-RemoteCommand $upScript 'docker compose up -d'
Write-Ok 'Container started'

# ── Database migrations ───────────────────────────────────────────────────────

if (-not $SkipMigrate) {
    Write-Step 'Waiting for container to be ready...'
    Start-Sleep -Seconds 4

    Write-Step 'Running database migrations...'
    Invoke-RemoteCommand 'docker exec boardgame_catalog python manage.py migrate --no-input' 'manage.py migrate'
    Write-Ok 'Migrations applied'
} else {
    Write-Warn 'Skipping migrations (-SkipMigrate was set)'
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ''
Write-Host '  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Green
Write-Host "  Deployment complete!  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"      -ForegroundColor Green
Write-Host "  Application: https://${AppDomain}/"                                   -ForegroundColor Cyan
Write-Host "  Admin panel: https://${AppDomain}/admin/"                             -ForegroundColor Cyan
Write-Host ''
Write-Host '  Useful remote commands:'                                               -ForegroundColor DarkGray
Write-Host "    ssh $Ssh 'docker logs boardgame_catalog'"                           -ForegroundColor DarkGray
Write-Host "    ssh $Ssh 'docker exec boardgame_catalog python manage.py createsuperuser'" -ForegroundColor DarkGray
Write-Host '  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Green
Write-Host ''
