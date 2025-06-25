function New-Git {
    param(
        [Parameter(Mandatory = $true)][string] $User,
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $true)] [string] $Email,
        [Parameter(Mandatory = $true)] [string] $Token
    )
    
    $userPath = Join-Path $PSScriptRoot "git-users"
    if(-not (Test-Path $userPath)) {
        New-Item -ItemType Directory -Path $userPath
    }
    
    $profile = @{
        User = $User
        Name = $Name
        Email = $Email
        Token = $Token
    }
    
    $profilePath = Join-Path $userPath "$User.json"
    $profile | ConvertTo-Json -Depth 3 | Set-Content $profilePath
    
    git config --global user.name $Name
    git config --global user.email $Email
    git config --global user.token $Token


    Write-Host "Git profile $User saved and applied successfully."
}

function Get-Git {
    [CmdletBinding()]
    param()
    
    $name = git config user.name
    $email = git config user.email

    [PSCustomObject]@{
        User = "current"
        Name = $name
        Email = $email
        Token = $null
    }   
}

function Set-Git {
    param(
        [Parameter(Mandatory = $true)][string] $User
    )
    
    $profilePath = Join-Path $PSScriptRoot "git-users\$User.json"
    if(-not (Test-Path $profilePath)) {
        throw "Git profile $User not found."
    }
    
    $profile = Get-Content $profilePath | ConvertFrom-Json
    
    git config --global user.name $profile.Name
    git config --global user.email $profile.Email
    git config --global user.token $profile.Token

    return [PSCustomObject]@{
        User = $User
        Name = $profile.Name
        Email = $profile.Email
        Token = $profile.Token
    }
}

function Remove-Git {
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High",DefaultParameterSetName="User")]
    param(
        [Parameter(Mandatory = $true)][string] $User,
        [switch] $Force
    )
    
    $profilePath = Join-Path $PSScriptRoot "git-users\$User.json"
    if(-not (Test-Path $profilePath)) {
        throw "Profile $User not found."
    }

    $currrent = git config --global user.name
    $profile = Get-Content $profilePath | ConvertFrom-Json
    
    if($profile.name -eq $currrent) {
        Write-Warning "You're removing the active Git profile."
    }

    Write-Warning "This will delete the saved profile and the token for $User."

    if(-not $Force) {
        $confirmation = Read-Host "Are you sure you want to remove this profile? (y/n)"
        if($confirmation -ne "y") {
            Write-Host "Cancelled."
            return
        }
    }

    Remove-Item $profilePath -Force
    Write-Host "Profile $User removed successfully."

    if($profile.name -eq $currrent) {
        $others = Get-ChildItem $PSScriptRoot/git-users -Filter "*.json" | Where-Object { $_.BaseName -ne $User }

        if($others.Count -gt 0) {
            $other = $others[0].BaseName
            Set-Git -User $other | Out-Null
            Write-Host "Switched to $other as active git profile."
        } else {
            git config --global --unset user.name
            git config --global --unset user.email
            git config --global --unset user.token
            Write-Host "No other profiles found. Git config cleared."
        }
    }
}

Update-GitTools {
    [CmdletBinding()]
    param()

    $modulePath = Join-Path ($env:PSModulePath -split ';' | Select-Object -First 1) "GitTools"

    if(-not (Test-Path $modulePath)) {
        Write-Error "GitTools module not found."
        return
    }

    if(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error "Git is not installed. Installing Git..."
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
        Start-Sleep -Seconds 10
        if(-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Error "Git is not installed. Please install Git and try again."
            return
        }
    }

    try{
        Write-Host "Updating GitTools..."
        git -C $modulePath pull
        Write-Host "GitTools updated successfully."
    } catch {
        Write-Error "Failed to update GitTools. Please try again."
        return
    }
}

Export-ModuleMember -Function New-Git, Get-Git, Set-Git, Remove-Git, Update-GitTools