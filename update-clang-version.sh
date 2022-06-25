register_clang_version() {
    local version=$1
    # if [[ -d /usr/lib/llvm-$version/bin ]];then
    #     CMDx=(--install /usr/bin/clang clang /usr/lib/llvm-$version/bin/clang 500)
    #     for ListCmds in $(ls /usr/lib/llvm-$version/bin)
    #     do
    #         [[ "$ListCmds" != "clang" ]] && CMDx+=(--slave /usr/bin/$ListCmds $ListCmds /usr/lib/llvm-$version/bin/$ListCmds)
    #     done
    # fi
    # update-alternatives ${CMDx[@]}
    [[ -d /usr/lib/llvm-$version/bin ]] && export PATH="/usr/lib/llvm-$version/bin:${PATH}"
    [[ -d /usr/lib/llvm-$version/lib ]] && export LD_LIBRARY_PATH="/usr/lib/llvm-$version/lib:${LD_LIBRARY_PATH}"
}
apt-get -y install clang-11 lld-11 linux-tools-common linux-tools-azure xxhash patchelf elfutils
register_clang_version 11