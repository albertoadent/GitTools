param(
    [Parameter(Mandatory = $true)]
    [string]$User
)

if(-not $User) {
    $User = Read-Host "Enter your Git profile name"
}

$modulePath = Join-Path ($env:PSModulePath -split ';' | Select-Object -First 1) "GitTools"
$repoUrl = "https://github.com/albertoadent/GitTools.git"

if(-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed. Installing Git..."
    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    Start-Sleep -Seconds 10
    if(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error "Git is not installed. Please install Git and try again."
        exit 1
    }
    Write-Host "Git installed successfully."
}

if(-not (Test-Path $modulePath)) {
    Write-Host "Cloning GitTools into $modulePath..."   
    git clone $repoUrl $modulePath
} else {
    Write-Host "GitTools already exists in $modulePath..."
}

Import-Module -Name $modulePath/GitTools.psm1 -Force

$profilePath = Join-Path $modulePath "git-users\$User.json"

if(Test-Path $profilePath) {
    Set-Git -User $User
    Write-Host "Git profile $User applied."
} else {
    Write-Warning "Git profile $User not found. Run New-Git to create it."
    $confirm = Read-Host "Do you want to create a new profile? (y/n)"
    if($confirm -eq "y") {
        $name = Read-Host "Enter your name"
        $email = Read-Host "Enter your email"
        $token = Read-Host "Enter your Github token (paste carefuly)"
        New-Git -User $User -Name $name -Email $email -Token $token
        Write-Host "Git profile $User created successfully."
    } else {
        Write-Host "Git profile $User not created."
        exit 1
    }
}