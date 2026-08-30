#!/system/bin/sh
# copy-partitions (TWRP不要版) - Termux + root shell 用
# 使い方: Termuxで `su` を実行してrootシェルに入ってから、これをそのまま貼り付けて実行

# root確認
if [ "$(id -u)" != "0" ]; then
    echo "root権限がありません。先に su を実行してください。"
    exit 1
fi

IGNORED_LIST="dtbo_a dtbo_b system_a system_b boot_a boot_b vbmeta_a vbmeta_b"

suffix_active=$(getprop ro.boot.slot_suffix)

if [ "$suffix_active" != "_a" ] && [ "$suffix_active" != "_b" ]; then
    echo "A/Bスロット端末ではないようです (ro.boot.slot_suffix='$suffix_active')。中止します。"
    exit 1
fi

if [ "$suffix_active" = "_a" ]; then
    suffix_swap="_b"
else
    suffix_swap="_a"
fi

BYNAME=/dev/block/bootdevice/by-name
if [ ! -d "$BYNAME" ]; then
    # 端末によってはこちらのパスの場合がある
    BYNAME=/dev/block/by-name
fi

echo "アクティブスロット: $suffix_active  ->  非アクティブスロットへコピー: $suffix_swap"
echo "by-nameパス: $BYNAME"

for active in "$BYNAME"/*"$suffix_active"; do
    partition=$(basename "$active")

    skip=0
    for ig in $IGNORED_LIST; do
        if [ "$partition" = "$ig" ]; then
            skip=1
            break
        fi
    done
    if [ "$skip" = "1" ]; then
        echo "スキップ(除外対象): $partition"
        continue
    fi

    inactive=$(echo "$active" | sed "s/${suffix_active}\$/${suffix_swap}/")
    part_active=$(readlink -f "$active")
    part_inactive=$(readlink -f "$inactive")

    if [ -n "$part_active" ] && [ -n "$part_inactive" ] \
       && [ "$active" != "$part_active" ] && [ "$inactive" != "$part_inactive" ]; then
        echo "コピー中: $partition  ($part_active -> $part_inactive)"
        blockdev --setrw "$part_inactive"
        dd if="$part_active" of="$part_inactive" bs=4k
    fi
done

echo "完了しました。"