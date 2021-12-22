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

if [ "$EsOne" == "13" ];then
    UseBranch="release/13.x"
elif [ "$EsOne" == "14" ];then
    UseBranch="main"
else
    msg "huh ???"
    exit
fi

if [[ -z "${GITLAB_NAME}" ]] || [[ -z "${GITLAB_SECRET}" ]] || [[ -z "${BOT_TOKEN}" ]];then
    msg "something is missing, aborting . . ."
    exit
fi

# wget https://gitlab.com/api/v4/projects/32102885/repository/commits/14 -O result.txt 1>/dev/null 2>/dev/null || echo 'blank' > result.txt

# if [[ "$(cat result.txt)" == *"$(date +"%Y-%m-%d")"* ]];then
#     Stop="Y"
#     msg "Today Clang build already compiled"
#     # exit
# # elif [[ "$(cat result.txt)" == "blank" ]];then
# #     Stop="N"
# fi
# rm -rf result.txt

TomTal=$(nproc)
EXTRA_ARGS=()
if [[ ! -z "${2}" ]];then
    TomTal=$(($TomTal*2))
    # EXTRA_ARGS+=(--install-stage1-only)
fi 
# EXTRA_ARGS+=("--pgo kernel-defconfig")
./build-llvm.py \
    --clang-vendor "ZyC" \
    --targets "ARM;AArch64;X86" \
    --defines "LLVM_PARALLEL_COMPILE_JOBS=$TomTal LLVM_PARALLEL_LINK_JOBS=$TomTal CMAKE_C_FLAGS='-g0 -O3' CMAKE_CXX_FLAGS='-g0 -O3'" \
    --shallow-clone \
    --no-ccache \
    --branch "$UseBranch" \
    "${EXTRA_ARGS[@]}"


# Build binutils
./build-binutils.py --targets arm aarch64 x86_64

# Remove unused products
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip -s "${f: : -1}"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
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
clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"
clang_version_f="$(install/bin/clang --version | head -n1)"

git config --global user.name 'ZyCromerZ'
git config --global user.email 'neetroid97@gmail.com'

pushd $(pwd)/install || exit
echo "# Quick Info" > README.md
echo "* Build Date : $(date +"%Y-%m-%d")" >> README.md
echo "* Clang Version : $clang_version_f" >> README.md
echo "* Binutils Version : $binutils_ver" >> README.md
echo "* Compiled Based : $llvm_commit_url" >> README.md
echo "" >> README.md
# tar -czvf ../"$ZipName" *
popd || exit

git clone https://${GITLAB_NAME}:${GITLAB_SECRET}@gitlab.com/ZyCromerZ/clang.git -b $clang_version $(pwd)/FromGithub || git clone https://${GITLAB_NAME}:${GITLAB_SECRET}@gitlab.com/ZyCromerZ/clang.git -b master $(pwd)/FromGithub
pushd $(pwd)/FromGithub || exit
[ -z "$(git branch | grep $clang_version)" ] && git checkout -b $clang_version
rm -fr ./*
cp -r ../install/* .
git add .
git commit -asm "$(cat README.md)"
git push -f origin $clang_version
popd || exit
ClangLink="https://gitlab.com/ZyCromerZ/clang/-/tree/$clang_version"
curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="-1001628919239" \
    -d "disable_web_page_preview=true" \
    -d "parse_mode=html" \
    -d text="New Toolchain Already Builded boy%0ADate : <code>$(date +"%Y-%m-%d")</code>%0A<code> --- Detail Info About it --- </code>%0AClang version : <code>$clang_version_f</code>%0ABINUTILS version : <code>$binutils_ver</code>%0A%0ARepo : <code>$ClangLink</code>%0A%0A-- uWu --"
