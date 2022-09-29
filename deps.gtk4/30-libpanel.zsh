autoload -Uz log_debug log_error log_info log_status log_output

## Dependency Information
local name='libpanel'
local version='1.0.1'
local url='https://gitlab.gnome.org/GNOME/libpanel.git'
local hash="1403a020e5d65e21bc0e16133aeb2b6e7cdca2de"

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
    -Ddocs=disabled
    -Dintrospection=disabled
    -Dvapi=false
    -Dpkg_config_path="${target_config[output_dir]}/lib/pkgconfig"
  )

  log_debug "Meson configure options: ${args}"
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
