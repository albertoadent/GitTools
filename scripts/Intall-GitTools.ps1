param(
    [Parameter(Mandatory = $true)]
    [string]$User
)

$modulePath = Join-Path $env:PSModulePath "GitTools"
$repoUrl = "https://github.com/albertoadent/GitTools.git"

if(-not Get-Command git -ErrorAction SilentlyContinue) {
    Write-Error "Git is not installed. Please install Git and try again."
    exit 1
}

if(-not (Test-Path $modulePath)) {
    Write-Host "Cloning GitTools into $modulePath..."   
    git clone $repoUrl $modulePath
} else {
    Write-Host "GitTools already exists in $modulePath..."
}

Import-Module -Name $modulePath/GitTools.psm1 -Force

if(Test-Path $modulePath/GitTools.psm1) {
    Set-Git -User $User
    Write-Host "Git profile $User applied."
} else {
    Write-Warning "Git profile $User not found. Run New-Git to create it."
}