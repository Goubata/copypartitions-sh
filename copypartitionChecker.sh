#!/system/bin/sh
# copy-partitions 検証スクリプト(表形式・名前ペア版) - Termux + root shell 用

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
    BYNAME=/dev/block/by-name
fi

echo "アクティブ:$suffix_active / 比較:$suffix_swap"
echo ""
printf "%-17s %-17s %s\n" "SLOT A" "SLOT B" "結果"
echo "-------------------------------------------------"

ok_count=0
mismatch_count=0
skip_count=0

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
        skip_count=$((skip_count+1))
        continue
    fi

    inactive_link=$(echo "$BYNAME/$partition" | sed "s/${suffix_active}\$/${suffix_swap}/")
    partition_b=$(basename "$inactive_link")

    part_active=$(readlink -f "$active")
    part_inactive=$(readlink -f "$inactive_link")

    if [ -z "$part_active" ] || [ -z "$part_inactive" ]; then
        printf "%-17s %-17s %s\n" "$partition" "$partition_b" "スキップ"
        skip_count=$((skip_count+1))
        continue
    fi

    hash_a=$(dd if="$part_active" bs=4k 2>/dev/null | sha256sum | awk '{print $1}')
    hash_b=$(dd if="$part_inactive" bs=4k 2>/dev/null | sha256sum | awk '{print $1}')

    if [ "$hash_a" = "$hash_b" ]; then
        printf "%-17s %-17s %s\n" "$partition" "$partition_b" "OK 一致"
        ok_count=$((ok_count+1))
    else
        printf "%-17s %-17s %s\n" "$partition" "$partition_b" "!! 不一致"
        mismatch_count=$((mismatch_count+1))
    fi
done

echo "-------------------------------------------------"
echo "一致:$ok_count件 / 不一致:$mismatch_count件 / 除外:$skip_count件"