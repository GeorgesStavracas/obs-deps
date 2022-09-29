autoload -Uz log_debug log_error log_info log_status log_output

## Dependency Information
local name='glib'
local version='2.74.0'
local url='https://gitlab.gnome.org/GNOME/glib.git'
local hash="30bd57ecf8aa051de9848ba5a2b140f4810401ff"

## Dependency Overrides
local -i shared_libs=1

## Build Steps
setup() {
  log_info "Setup (%F{3}${target}%f)"
  setup_dep ${url} ${hash}
}

clean() {
  cd "${dir}"

  if [[ ${clean_build} -gt 0 && -f "build_${arch}/build.ninja" ]] {
    log_info "Clean build directory (%F{3}${target}%f)"

    rm -rf "build_${arch}"
  }
}

config() {
  autoload -Uz mkcd progress

  local build_type

  case ${config} {
    Debug) build_type='debug' ;;
    RelWithDebInfo) build_type='debugoptimized' ;;
    Release) build_type='release' ;;
    MinSizeRel) build_type='minsize' ;;
  }

  if (( shared_libs )) {
    args+=(--default-library both)
  } else {
    args+=(--default-library static)
  }

  case "${target}" {
    macos-universal)
      autoload -Uz universal_config && universal_config
      return
      ;;
  }

  log_info "Config (%F{3}${target}%f)"
  cd "${dir}"

  args+=(
    --buildtype "${build_type}"
    --prefix "${target_config[output_dir]}"
    --cross-file "${SCRIPT_HOME}/deps.gtk4/cross-compile/macos_${arch}.txt"
    -Dtests=false
    -Dpkg_config_path="${target_config[output_dir]}/lib/pkgconfig"
  )

  log_debug "Meson configure options: ${args}"
  PKG_CONFIG_LIBDIR="${target_config[output_dir]}/lib/pkgconfig" \
  LD_LIBRARY_PATH="${target_config[output_dir]}/lib" \
  PATH="$PATH:${target_config[output_dir]}/bin" \
  meson setup "build_${arch}" ${args}
}

build() {
  autoload -Uz mkcd progress

  case ${target} {
    macos-universal)
      autoload -Uz universal_build && universal_build
      return
      ;;
  }

  log_info "Build (%F{3}${target}%f)"
  cd "${dir}"

  log_debug "Running meson compile -C build_${arch}"
  PKG_CONFIG_LIBDIR="${target_config[output_dir]}/lib/pkgconfig" \
  LD_LIBRARY_PATH="${target_config[output_dir]}/lib" \
  PATH="$PATH:${target_config[output_dir]}/bin" \
  meson compile -C "build_${arch}"
}

install() {
  autoload -Uz progress

  log_info "Install (%F{3}${target}%f)"

  cd "${dir}"

  PKG_CONFIG_LIBDIR="${target_config[output_dir]}/lib/pkgconfig" \
  LD_LIBRARY_PATH="${target_config[output_dir]}/lib" \
  PATH="$PATH:${target_config[output_dir]}/bin" \
  meson install -C "build_${arch}"
}
