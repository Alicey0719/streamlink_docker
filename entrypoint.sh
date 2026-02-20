#!/bin/bash
set -e

# set variables
URL="$1"
QUALITY="${2:-best}"
OUTPUT_DIR="/data"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-mp4}"

# URLが指定されていない場合は終了
if [ -z "$URL" ]; then
    echo "Usage: $0 <URL> [quality] [options...]"
    exit 1
fi

# 配信DL
echo "Recording stream: $URL"

# プロセスごとの一時ディレクトリを作成（複数コンテナ同時実行時の競合防止）
WORK_DIR=$(mktemp -d "${OUTPUT_DIR}/tmp_XXXXXX")
OUTPUT_FILE="${WORK_DIR}/{author}_{title}_{time:%Y%m%d_%H%M%S}.ts"

# 残りの引数を取得（--retry-streamsなどのオプション）
shift 2
STREAMLINK_LOG=$(mktemp)
set +e
streamlink "$URL" "$QUALITY" -o "$OUTPUT_FILE" "$@" 2>&1 | tee "$STREAMLINK_LOG"
EXIT_CODE=${PIPESTATUS[0]}
set -e

if [ $EXIT_CODE -ne 0 ]; then
    if grep -q "No playable streams found" "$STREAMLINK_LOG"; then
        echo "No playable streams found, exiting cleanly."
        rm -f "$STREAMLINK_LOG"
        exit 0
    fi
    rm -f "$STREAMLINK_LOG"
    exit $EXIT_CODE
fi
rm -f "$STREAMLINK_LOG"

# このプロセスの一時ディレクトリ内のtsファイルだけを対象にする
LATEST_TS=$(ls "${WORK_DIR}"/*.ts 2>/dev/null | head -1)

if [ -z "$LATEST_TS" ]; then
    echo "No .ts file found"
    rmdir "$WORK_DIR"
    exit 1
fi

echo "Converting: $LATEST_TS"

# tsファイルのベース名を取得（拡張子なし）
BASENAME="${LATEST_TS%.ts}"
OUTPUT_PATH="${OUTPUT_DIR}/$(basename "$BASENAME").${OUTPUT_FORMAT}"

# ffmpegで変換 or move
if [ "$OUTPUT_FORMAT" = "ts" ]; then
    mv "$LATEST_TS" "$OUTPUT_PATH"
elif [ "$OUTPUT_FORMAT" = "webm" ]; then
    ffmpeg -i "$LATEST_TS" -c:v libvpx-vp9 -crf 30 -b:v 0 -c:a libopus "$OUTPUT_PATH"
else
    ffmpeg -i "$LATEST_TS" -c:v copy -c:a copy "$OUTPUT_PATH"
fi

if [ $? -eq 0 ]; then
    echo "Output: $OUTPUT_PATH"
    rm -rf "$WORK_DIR"
else
    echo "Conversion failed. .ts file preserved: $LATEST_TS"
    exit 1
fi
