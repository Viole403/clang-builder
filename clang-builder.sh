#!/usr/bin/env bash

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

export GIT_SSL_NO_VERIFY=1
git config --global http.sslverify false

# Set a directory
DIR="$(pwd ...)"
EsOne="${1}"
fail="n"
TagsDate="$(date +"%Y%m%d")"
TagsDateF="$(date +"%Y%m%d")"

# unlimitedEcho(){
#     StATS=1
#     while [ ! -f $DIR/stop-spam-echo.txt ];
#     do
#         msg ">> for prevent no output <<"
#         sleep 10s
#     done
# }

EXTRA_ARGS=()
EXTRA_PRJ=""
UseBranch=""

for ListBranch in 10 11 12 13 14 main
do
    if [[ "$ListBranch" == "$EsOne" ]];then
        if [[ "$ListBranch" == "main" ]];then
            UseBranch="main"
        else
            UseBranch="release/$EsOne.x"
        fi
    fi
done


if [[ -z "$UseBranch" ]];then
    msg "branch not found"
    exit
fi

# if [ "$EsOne" == "13" ];then
#     UseBranch="release/13.x"
# elif [ "$EsOne" == "14" ];then
#     # EXTRA_ARGS+=("--bolt")
#     # EXTRA_PRJ=";bolt"
#     UseBranch="release/14.x"
# elif [ "$EsOne" == "main" ];then
#     # EXTRA_ARGS+=("--bolt")
#     # EXTRA_PRJ=";bolt"
#     UseBranch="main"
# else
#     msg "huh ???"
#     exit
# fi

if [[ -z "${GIT_SECRET}" ]] || [[ -z "${BOT_TOKEN}" ]];then
    msg "something is missing, aborting . . ."
    exit
fi

wget https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-$EsOne-lastbuild.txt -O result.txt 1>/dev/null 2>/dev/null || echo 'blank' > result.txt
wget https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-$EsOne-commit.txt -O result-b.txt 1>/dev/null 2>/dev/null || echo 'blank' > result-b.txt

if [[ "$(cat result.txt)" == *"$TagsDateF"* ]];then
    # Stop="Y"
    msg "Today Clang $EsOne build already compiled"
    exit
# elif [[ "$(cat result.txt)" == "blank" ]];then
#     Stop="N"
fi

if [[ "$(curl -X GET -H "Cache-Control: no-cache" https://api.github.com/repos/llvm/llvm-project/commits/$UseBranch | grep commit)" == *"commits/$(cat result-b.txt)"* ]];then
    Stop="Y"
    msg "Latest clang $EsOne already compiled"
    exit
fi

rm -rf result.txt result-b.txt

if [[ "$UseBranch" != "main" ]] && [[ "$(date +"%u")" != "1" ]];then
    # Stop="Y"
    msg "for $UseBranch, only can be compiled on monday"
    exit
fi

TomTal=$(nproc)
if [[ ! -z "${2}" ]];then
    TomTal=$(($TomTal*2))
    # EXTRA_ARGS+=(--install-stage1-only)
fi 
# unlimitedEcho &
# EXTRA_ARGS+=("--pgo kernel-defconfig")
# --projects "clang;lld;polly${EXTRA_PRJ}" \
./build-llvm.py \
    --clang-vendor "ZyC" \
    --targets "AArch64;ARM;X86" \
    --defines "LLVM_PARALLEL_COMPILE_JOBS=$TomTal LLVM_PARALLEL_LINK_JOBS=$TomTal CMAKE_C_FLAGS='-g0 -O3' CMAKE_CXX_FLAGS='-g0 -O3'" \
    --shallow-clone \
    --no-ccache \
    --branch "$UseBranch" \
    --pgo "kernel-defconfig-slim" \
    "${EXTRA_ARGS[@]}" || fail="y"

# echo "idk" > $DIR/stop-spam-echo.txt

if [[ "$fail" == "n" ]];then
    $DIR/install/bin/clang --version

    # Build binutils
    ./build-binutils.py --targets aarch64 arm x86_64
    # Remove unused products
    # rm -f $DIR/install/lib/*.a $DIR/install/lib/*.la $DIR/install/lib/clang/*/lib/linux/*.a*
    # IFS=$'\n'
    # for f in $(find $DIR/install -type f -exec file {} \;); do
    #     if [ -n "$(echo $f | grep 'ELF .* interpreter')" ]; then
    #         i=$(echo $f | awk '{print $1}'); i=${i: : -1}
    #         # Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
    #         patchelf --set-rpath "$DIR/install/lib" "$i"
    #         msg "patchelf --set-rpath '$DIR/install/lib' '$i'"
    #         # Strip remaining products
    #         if [ -n "$(echo $f | grep 'not stripped')" ]; then
    #             strip --strip-unneeded "$i"
    #             msg "strip --strip-unneeded '$i'"
    #         fi
    #     elif [ -n "$(echo $f | grep 'ELF .* relocatable')" ]; then
    #         if [ -n "$(echo $f | grep 'not stripped')" ]; then
    #             i=$(echo $f | awk '{print $1}');
    #             strip --strip-unneeded "${i: : -1}"
    #             msg "strip --strip-unneeded '${i: : -1}'"
    #         fi
    #     else
    #         if [ -n "$(echo $f | grep 'not stripped')" ]; then
    #             i=$(echo $f | awk '{print $1}');
    #             strip --strip-all "${i: : -1}"
    #             msg "strip --strip-all '${i: : -1}'"
    #         fi
    #     fi
    # done

    # Remove unused products
    rm -fr $DIR/install/include
    rm -f $DIR/install/lib/*.a $DIR/install/lib/*.la

    # Strip remaining products
    for f in $(find $DIR/install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
        strip -s "${f: : -1}"
    done

    # Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
    for bin in $(find $DIR/install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
        # Remove last character from file output (':')
        bin="${bin: : -1}"

        echo "$bin"
        patchelf --set-rpath "$DIR/install/lib" "$bin"
    done

    # Release Info
    pushd llvm-project || exit
    llvm_commit="$(git rev-parse HEAD)"
    short_llvm_commit="$(cut -c-8 <<< "$llvm_commit")"
    popd || exit

    llvm_commit_url="https://github.com/llvm/llvm-project/commit/$short_llvm_commit"
    binutils_ver="$(ls | grep "^binutils-" | sed "s/binutils-//g")"
    clang_version="$($DIR/install/bin/clang --version | head -n1 | cut -d' ' -f4)"
    clang_version_f="$($DIR/install/bin/clang --version | head -n1)"

    git config --global user.name 'ZyCromerZ'
    git config --global user.email 'neetroid97@gmail.com'

    ZipName="Clang-$clang_version-${TagsDate}.tar.gz"
    ClangLink="https://github.com/ZyCromerZ/Clang/releases/download/${clang_version}-${TagsDate}-release/$ZipName"

    pushd $DIR/install || exit
    echo "# Quick Info" > README.md
    echo "* Build Date : $TagsDateF" >> README.md
    echo "* Clang Version : $clang_version_f" >> README.md
    echo "* Binutils Version : $binutils_ver" >> README.md
    echo "* Compiled Based : $llvm_commit_url" >> README.md
    echo "" >> README.md
    echo "# link downloads:" >> readme.md
    echo "* <a href=$ClangLink>$ZipName</a>" >> readme.md
    tar -czvf ../"$ZipName" *
    popd || exit
fi

UploadAgain()
{
    fail="n"
    ./github-release upload \
        --security-token "$GIT_SECRET" \
        --user ZyCromerZ \
        --repo Clang \
        --tag ${clang_version}-${TagsDate}-release \
        --name "$ZipName" \
        --file "$ZipName" || fail="y"
    TotalTry=$(($TotalTry+1))
    if [ "$fail" == "y" ];then
        if [ "$TotalTry" != "360" ];then
            sleep 10s
            UploadAgain
        fi
    fi
}

if [[ ! -z "$clang_version" ]];then
    git clone https://${GIT_SECRET}@github.com/ZyCromerZ/Clang -b main $(pwd)/FromGithub
    pushd $(pwd)/FromGithub || exit
    echo "$TagsDateF" > Clang-$EsOne-lastbuild.txt
    echo "$ClangLink" > Clang-$EsOne-link.txt
    echo "$llvm_commit" > Clang-$EsOne-commit.txt
    git add . && git commit -asm "Upload $clang_version_f"
    git checkout -b ${clang_version}-${TagsDate}
    cp ../install/README.md .
    git add . && git commit -asm "Update Readme.md"
    git tag ${clang_version}-${TagsDate}-release -m "Upload $clang_version_f"
    git push -f origin main ${clang_version}-${TagsDate}
    git push -f origin ${clang_version}-${TagsDate}-release
    if [[ "$UseBranch" == "main" ]];then
        git checkout --orphan for-strip
        rm -fr * 
        cp -af $DIR/install/bin/aarch64-linux-gnu-strip .
        cp -af $DIR/install/bin/arm-linux-gnueabi-strip .
        cp -af $DIR/install/bin/strip .
        echo "# Just For Personal Use Only" > README.md
        git add . && git commit -asm "add strip from ${clang_version_f}"
        git push -f origin for-strip
    fi
    popd || exit

    chmod +x github-release
    ./github-release release \
        --security-token "$GIT_SECRET" \
        --user ZyCromerZ \
        --repo Clang \
        --tag ${clang_version}-${TagsDate}-release \
        --name "Clang-${clang_version}-${TagsDate}-release" \
        --description "$(cat install/README.md)"

    # ./github-release upload \
    #     --security-token "$GIT_SECRET" \
    #     --user ZyCromerZ \
    #     --repo Clang \
    #     --tag ${clang_version}-${TagsDate}-release \
    #     --name "$ZipName" \
    #     --file "$ZipName" || fail="y"

    TotalTry="0"
    UploadAgain

    if [ "$fail" == "y" ];then
        pushd $(pwd)/FromGithub || exit
        git push -d origin ${clang_version}-${TagsDate}
        git push -d origin ${clang_version}-${TagsDate}-release
        git checkout main
        git reset --hard HEAD~1
        git push -f origin main
        popd || exit
    else
        curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="-1001628919239" \
            -d "disable_web_page_preview=true" \
            -d "parse_mode=html" \
            -d text="New Toolchain Already Builded boy%0ADate : <code>$TagsDateF</code>%0A<code> --- Detail Info About it --- </code>%0AClang version : <code>$clang_version_f</code>%0ABINUTILS version : <code>$binutils_ver</code>%0A%0ALink downloads : <code>$ClangLink</code>%0A%0A-- uWu --"
    fi
else
    msg "clang version not found, maybe broken :/"
fi