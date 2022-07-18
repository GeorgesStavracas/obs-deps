param(
    [string] $Name = 'libpanel',
    [string] $Version = '1.0.alpha1',
    [string] $Uri = 'https://gitlab.gnome.org/GNOME/libpanel.git',
    [string] $Hash = 'acaf0109e3548e20e2d6deada81a99544e390a86'
)

function Setup-Paths {
    $Env:OriginalPath = $Env:Path
    $PathElements = ([Collections.Generic.HashSet[string]]::new([string[]]($Env:Path -split [System.IO.Path]::PathSeparator), [StringComparer]::OrdinalIgnoreCase))
    $OutputPaths = @(
        "$($ConfigData.OutputPath)\bin"
    )
    $Env:Path = ($PathElements + $OutputPaths) -join [System.IO.Path]::PathSeparator

    $Env:OriginalPkgConfigPath = $Env:PKG_CONFIG_PATH
    $PathElements = ([Collections.Generic.HashSet[string]]::new([string[]]($Env:PKG_CONFIG_PATH -split [System.IO.Path]::PathSeparator), [StringComparer]::OrdinalIgnoreCase))
    $OutputPaths = @(
        "$($ConfigData.OutputPath)\lib\pkgconfig"
    )
    $Env:PKG_CONFIG_PATH = ($OutputPaths + $PathElements) -join [System.IO.Path]::PathSeparator
}

function Unset-Paths {
    $Env:PKG_CONFIG_PATH = $Env:OriginalPkgConfigPath
    $Env:Path = $Env:OriginalPath

    Remove-Item Env:OriginalPkgConfigPath
    Remove-Item Env:OriginalPath
}

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path
}

function Clean {
    Set-Location $Path

    if ( Test-Path "build_${Target}" ) {
        Log-Information "Clean build directory (${Target})"
        Remove-Item -Path "build_${Target}" -Recurse -Force
    }
}

function Configure {
    Log-Information "Configure (${Target})"
    Set-Location $Path

    Setup-Paths

    $Options = @(
        '--prefix', "$($ConfigData.OutputPath)",
        '-Ddocs=disabled',
        '-Dintrospection=disabled',
        '-Dvapi=false'
    )

    $BuildType = ''
    switch -Exact ($Configuration) {
        'Debug' {
            $BuildType = 'debug'
            Break;
        }
        'RelWithDebInfo' {
            $BuildType = 'debugoptimized'
            Break;
        }
        'Release' {
            $BuildType = 'release'
            Break;
        }
        'MinSizeRel' {
            $BuildType = 'minsize'
            Break;
        }
        default {
            $BuildType = 'debug'
            Break;
        }
    }

    $Options += @('--buildtype', $BuildType)

    Invoke-External meson setup "build_${Target}" @Options

    Unset-Paths
}

function Build {
    Log-Information "Build (${Target})"
    Set-Location $Path

    Invoke-External meson compile -C "build_${Target}"
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location $Path

    Invoke-External meson install -C "build_${Target}"
}
