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
        Token = (git config user.token)
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

function Create-Repo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [string] $Description = "",
        [string] $Path = ".",
        [ValidateSet("public","private")]
        [string] $Visibility = "private"
    )

    #Load active git profile
    $profile = Get-Git
    
    if(-not $profile) {
        Write-Error "No active git profile found."
        return
    }

    $headers = @{
        "Authorization" = "Bearer $($profile.Token)"
        "Accept" = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
        "User-Agent" = "$($profile.User)"
    }

    $body = @{
        name = $Name
        description = $Description
        private = ($Visibility -eq "private")
        auto_init = $false
    } | ConvertTo-Json -Depth 3

    $response = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Headers $headers -Method Post -Body $body

    if($response.message -eq "Bad credentials") {
        Write-Error "Invalid token. Please check your token and try again."
        return
    }

    Write-Host "Repository $Name created successfully."

    #push local content to remote repo

    $abspath = Resolve-Path $Path
    Push-Location $abspath

    if(-not (Test-Path .git)) {
        git init
        git add .
        git commit -m "Initial commit"
    }

    git remote add origin $response.clone_url
    git branch -M main
    git push -u origin main

    Pop-Location
    
    
}

Export-ModuleMember -Function New-Git, Get-Git, Set-Git, Remove-Git, Update-GitTools, Create-Repo