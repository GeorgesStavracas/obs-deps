param(
    [string] $Name = 'gtk4',
    [string] $Version = '4.8.0',
    [string] $Uri = 'https://gitlab.gnome.org/GNOME/gtk.git',
    [string] $Hash = '9cc1dcf2a4739d55460675903c595f68478e0811'
)

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

    $Options = @(
        '--prefix', "$($ConfigData.OutputPath)",
        '-Dbackend_max_links=1',
        '-Dbuild-tests=false',
        '-Dbuild-examples=false',
        '-Ddemos=false',
        '-Dintrospection=disabled',
        '-Dmedia-gstreamer=disabled',
        '-Dwin32-backend=true',
        '-Dvulkan=disabled',
        '-Dcairo:tests=disabled',
        '-Dgdk-pixbuf:tests=false',
        '-Dglib:tests=false',
        '-Dgraphene:tests=false',
        '-Dgtk:werror=true',
        '-Dharfbuzz:tests=disabled',
        '-Dharfbuzz:docs=disabled',
        '-Dpixman:tests=disabled'
    )

    $BuildType = ''
    switch -Exact ($Configuration) {
        'Debug' {
            $BuildType = 'debug'
            Break;
        }
        'RelWithDebInfo' {
            $BuildType = 'debugoptimized'
            $Options += @('-Ddebug=false')
            Break;
        }
        'Release' {
            $BuildType = 'release'
            $Options += @('-Ddebug=false')
            Break;
        }
        'MinSizeRel' {
            $BuildType = 'minsize'
            $Options += @('-Ddebug=false')
            Break;
        }
        default {
            $BuildType = 'debug'
            Break;
        }
    }

    $Options += @('--buildtype', $BuildType)

    Invoke-External meson setup "build_${Target}" @Options
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
