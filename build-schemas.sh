#!/usr/bin/env bash
# encoding: utf-8
# 移植自 Hamster InputSchemaBuild.sh（去掉 hamster.yaml，schema_list 交由 default.custom.yaml 控制）
set -e

if [[ -z "${CI_PRIMARY_REPOSITORY_PATH}" ]]; then
  CI_PRIMARY_REPOSITORY_PATH="$PWD"
  WORK="$PWD"
else
  CI_PRIMARY_REPOSITORY_PATH="${CI_PRIMARY_REPOSITORY_PATH}"
  WORK="${CI_PRIMARY_REPOSITORY_PATH}"
fi

# 下载 librime macOS 构建（提供 opencc 工具与词库数据）
rime_version=1.8.5
rime_git_hash=08dd95f
if [[ ! -d .deps ]]; then
  rime_archive="rime-${rime_git_hash}-macOS.tar.bz2"
  rime_download_url="https://github.com/rime/librime/releases/download/${rime_version}/${rime_archive}"
  rime_deps_archive="rime-deps-${rime_git_hash}-macOS.tar.bz2"
  rime_deps_download_url="https://github.com/rime/librime/releases/download/${rime_version}/${rime_deps_archive}"

  rm -rf .deps && mkdir -p .deps && (
    cd .deps
    curl -fL -O "${rime_download_url}"
    tar --bzip2 -xf "${rime_archive}"
    curl -fL -O "${rime_deps_download_url}"
    tar --bzip2 -xf "${rime_deps_archive}"
  )
fi

OUTPUT="$WORK/.tmp"
DST_PATH="$OUTPUT/SharedSupport"
rm -rf .plum "$OUTPUT"
mkdir -p "$DST_PATH/opencc"
cp -r .deps/share/opencc "$DST_PATH"

git clone --depth 1 https://github.com/rime/plum.git "$OUTPUT/.plum"

for package in prelude rime-essay; do
  bash "$OUTPUT/.plum/scripts/install-packages.sh" "${package}" "$DST_PATH"
done

# 绘文字（opencc t2s 转换 + 去重合并）
rime_emoji_version="15.0"
rime_emoji_archive="rime-emoji-${rime_emoji_version}.zip"
rime_emoji_download_url="https://github.com/rime/rime-emoji/archive/refs/tags/${rime_emoji_version}.zip"
rm -rf "$OUTPUT/.emoji" && mkdir -p "$OUTPUT/.emoji" && (
  cd "$OUTPUT/.emoji"
  curl -fL -o "${rime_emoji_archive}" "${rime_emoji_download_url}"
  unzip "${rime_emoji_archive}" -d .
  rm -rf "${rime_emoji_archive}"
  cd "rime-emoji-${rime_emoji_version}"
  for target in category word; do
    "$WORK/.deps/bin/opencc" -c "$WORK/.deps/share/opencc/t2s.json" -i "opencc/emoji_${target}.txt" > "${target}.txt"
    sed -i'.original' -e 's/鼔/鼓/g' "${target}.txt"
    cat "${target}.txt" "opencc/emoji_${target}.txt" | awk '!seen[$1]++' > "../emoji_${target}.txt"
  done
) && \
cp "$OUTPUT/.emoji/emoji_"*.txt "$DST_PATH/opencc/" && \
cp "$OUTPUT/.emoji/rime-emoji-${rime_emoji_version}/opencc/emoji.json" "$DST_PATH/opencc/"

# 清空 default.yaml 的 schema_list（交由 default.custom.yaml 控制）
pushd "$DST_PATH" > /dev/null
echo '' > schema_list.yaml
sed '{
  s/^config_version: \(["]*\)\([0-9.]*\)\(["]*\)$/config_version: \1\2.minimal\3/
  /- schema:/d
  /^schema_list:$/r schema_list.yaml
}' default.yaml > default.yaml.min
rm schema_list.yaml
mv default.yaml.min default.yaml
popd > /dev/null

# SharedSupport.zip
mkdir -p "$CI_PRIMARY_REPOSITORY_PATH/Resources/SharedSupport"
(
  cd "$DST_PATH/"
  zip -r SharedSupport.zip *
) && cp "$DST_PATH/SharedSupport.zip" "$CI_PRIMARY_REPOSITORY_PATH/Resources/SharedSupport/"

# 内置方案雾凇（含 t9 九宫格）
input_scheme_name=rime-ice
rm -rf "$OUTPUT/.$input_scheme_name" && \
  git clone --depth 1 https://github.com/iDvel/$input_scheme_name "$OUTPUT/.$input_scheme_name" && (
    cd "$OUTPUT/.$input_scheme_name"
    zip -r "$input_scheme_name.zip" ./*
  ) && \
  cp -R "$OUTPUT/.$input_scheme_name"/*.zip "$CI_PRIMARY_REPOSITORY_PATH/Resources/SharedSupport/"

echo "schema build done:"
ls -la "$CI_PRIMARY_REPOSITORY_PATH/Resources/SharedSupport/"