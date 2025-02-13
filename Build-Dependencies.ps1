[CmdletBinding()]
param(
    [ValidateSet('Debug', 'RelWithDebInfo', 'Release', 'MinSizeRel')]
    [string] $Configuration = 'Release',
    [string[]] $Dependencies,
    [ValidateSet('x86', 'x64')]
    [string] $Target,
    [switch] $Clean,
    [switch] $Quiet,
    [switch] $Shared,
    [switch] $SkipAll,
    [switch] $SkipBuild,
    [switch] $SkipDeps,
    [switch] $SkipUnpack
)

$ErrorActionPreference = "Stop"

if ( $DebugPreference -eq "Continue" ) {
    $VerbosePreference = "Continue"
    $InformationPreference = "Continue"
}

if ( $PSVersionTable.PSVersion -lt '7.0.0' ) {
    Write-Warning 'The obs-deps PowerShell build script requires PowerShell Core 7. Install or upgrade your PowerShell version: https://aka.ms/pscore6'
    exit 0
}

function Run-Stages {
    $Stages = @('Setup')

    if ( ( $SkipAll ) -or ( $SkipBuild ) ) {
        $Stages += @('Install', 'Fixup')
    } else {
        if ( $Clean ) {
            $Stages += 'Clean'
        }
        $Stages += @(
            'Patch'
            'Configure'
            'Build'
            'Install'
            'Fixup'
        )
    }

    Log-Debug $DependencyFiles

    $DependencyFiles | Sort | ForEach-Object {
        $Dependency = $_

        $Version = 0
        $Uri = ''
        $Hash = ''
        $Path = ''
        $Versions = @()
        $Hashes = @()
        $Uris = @()
        $Patches = @()
        $Options = @{}
        $Targets = @($script:Target)

        . $Dependency

        if ( ! ( $Targets.contains($Target) ) ) { continue }

        if ( $Version -eq '' ) { $Version = $Versions[$Target] }
        if ( $Uri -eq '' ) { $Uri = $Uris[$Target] }
        if ( $Hash -eq '' ) { $Hash = $Hashes[$Target] }

        if ( $Path -eq '' ) { $Path = [System.IO.Path]::GetFileNameWithoutExtension($Uri) }

        Log-Output 'Initializing build'

        $Stages | ForEach-Object {
            $Stage = $_
            $script:StageName = $Name
            try {
                Push-Location -Stack BuildTemp
                if ( Test-Path function:$Stage ) {
                    . $Stage
                }
            } catch {
                Pop-Location -Stack BuildTemp
                Log-Error "Error during build step ${Stage} - $_"
            } finally {
                $StageName = ''
                Pop-Location -Stack BuildTemp
            }
        }

        $Stages | ForEach-Object {
            Log-Debug "Removing function $_"
            Remove-Item -ErrorAction 'SilentlyContinue' function:$_
            $script:StageName = ''
        }

        if ( Test-Path "$PSScriptRoot/licenses/${Name}" ) {
            Log-Information "Install license files"

            $null = New-Item -ItemType Directory -Path "$($ConfigData.OutputPath)/licenses" -ErrorAction SilentlyContinue
            Copy-Item -Path "$PSScriptRoot/licenses/${Name}" -Recurse -Force -Destination "$($ConfigData.OutputPath)/licenses"
        }
    }
}

function Package-Dependencies {
    $Items = @(
            "./bin/bison.exe"
            "./bin/m4.exe"
            "./man1/pcre2*"
            "./man3/pcre2*"
            "./share/bison"
            "./share/doc/pcre2"
    )
    if ( $script:PackageName -eq 'gtk4' ) {
        $ArchiveFileName = "windows-deps-${PackageName}-${CurrentDate}-${Target}-${Configuration}.zip"
        $Items += @(
            "./bin/sass*"
            "./bin/pango*.exe"
            "./bin/pcre2*.exe"
            "./etc"
            "./bin/sass*"
        )
    } else {
        $ArchiveFileName = "windows-${PackageName}-${CurrentDate}-${Target}.zip"
        $Items += @(
            "./bin/libiconv2.dll"
            "./bin/libintl3.dll"
            "./bin/pcre2*"
            "./bin/regex2.dll"
            "./cmake/pcre2*"
            "./include/pcre2*"
            "./lib/pcre2*"
            "./lib/pkgconfig/libpcre2*"
        )
    }

    Push-Location -Stack BuildTemp
    Set-Location $ConfigData.OutputPath

    Log-Information "Cleanup unnecessary files"

    Remove-Item -ErrorAction 'SilentlyContinue' -Path $Items -Force -Recurse

    Log-Information "Package dependencies"

    $Params = @{
        Path = (Get-ChildItem -Path $(Get-Location))
        DestinationPath = $ArchiveFileName
        CompressionLevel = "Optimal"
    }

    Log-Information "Create archive ${ArchiveFileName}"
    Compress-Archive @Params

    Move-Item -Force -Path $ArchiveFileName -Destination ..

    Pop-Location -Stack BuildTemp
}

function Build-Main {
    trap {
        Write-Host '---------------------------------------------------------------------------------------------------'
        Write-Host -NoNewLine '[OBS-DEPS] '
        Write-Host -ForegroundColor Red 'Error(s) occurred:'
        Write-Host '---------------------------------------------------------------------------------------------------'
        Write-Error $_
        exit 2
    }

    $script:PackageName = ((Get-Item $PSCommandPath).Basename).Split('-')[1]
    if ( $script:PackageName -eq 'Dependencies' ) {
        $script:PackageName = 'deps'
    }
    if ( $Dependencies -eq 'gtk4' ) {
        $script:PackageName = 'gtk4'
    }

    $UtilityFunctions = Get-ChildItem -Path $PSScriptRoot/utils.pwsh/*.ps1 -Recurse

    foreach($Utility in $UtilityFunctions) {
        Write-Debug "Loading $($Utility.FullName)"
        . $Utility.FullName
    }

    Bootstrap

    $SubDir = ''
    if ( $script:PackageName -eq 'gtk4' ) {
        $SubDir = 'deps.gtk4'
    } else {
        $SubDir = 'deps.windows'
    }

    if ( $Dependencies.Count -eq 0 -or $script:PackageName -eq 'gtk4' ) {
        $DependencyFiles = Get-ChildItem -Path $PSScriptRoot/${SubDir}/*.ps1 -File -Recurse
    } else {
        $DependencyFiles = $Dependencies | ForEach-Object {
            $Item = $_
            try {
                Get-ChildItem $PSScriptRoot/${SubDir}/*$Item.ps1
            } catch {
                throw "Script for requested dependency ${Item} not found"
            }
        }
    }

    Log-Debug "Using found dependency scripts:`n${DependencyFiles}"

    Push-Location -Stack BuildTemp

    Ensure-Location $WorkRoot

    Run-Stages

    Pop-Location -Stack BuildTemp

    if ( $Dependencies.Count -eq 0 -or $script:PackageName -eq 'gtk4' ) {
        Package-Dependencies
    }

    Write-Host '---------------------------------------------------------------------------------------------------'
    Write-Host -NoNewLine '[OBS-DEPS] '
    Write-Host -ForegroundColor Green 'All done'
    Write-Host "Built Dependencies: $(if ( $Dependencies -eq $null ) { 'All' } else { $Dependencies })"
    Write-Host '---------------------------------------------------------------------------------------------------'
}

Build-Main
