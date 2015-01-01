#!/bin/bash

set -e

if [[ $# -ne 2 ]]; then
    echo "用法：$0 开始日期 结束日期"
    echo "示例：$0 2022-01-01 2024-12-31"
    exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "当前目录不是 git 仓库，请先执行 git init"
    exit 1
fi

if date -d "1970-01-01" "+%s" >/dev/null 2>&1; then
    DATE_TYPE="gnu"
else
    DATE_TYPE="bsd"
fi

parse_date() {
    if [[ "${DATE_TYPE}" == "gnu" ]]; then
        date -d "$1 12:00:00" "+%s"
    else
        date -jf "%Y-%m-%d %H:%M:%S" "$1 12:00:00" "+%s"
    fi
}

format_datetime() {
    if [[ "${DATE_TYPE}" == "gnu" ]]; then
        date -d "@$1" "+%Y-%m-%dT%H:%M:%S"
    else
        date -r "$1" "+%Y-%m-%dT%H:%M:%S"
    fi
}

format_year() {
    if [[ "${DATE_TYPE}" == "gnu" ]]; then
        date -d "@$1" "+%Y"
    else
        date -r "$1" "+%Y"
    fi
}

START_DAY=$(parse_date "$1")
END_DAY=$(parse_date "$2")

if (( START_DAY > END_DAY )); then
    echo "开始日期不能晚于结束日期"
    exit 1
fi

YEAR=""
YEAR_DAYS_LEFT=0
YEAR_BLACK_LEFT=0
YEAR_GRAY_LEFT=0
YEAR_DARK_LEFT=0
YEAR_PALE_LEFT=0
YEAR_BRIGHT_LEFT=0

BLACK_TOTAL=0
GRAY_TOTAL=0
DARK_TOTAL=0
PALE_TOTAL=0
BRIGHT_TOTAL=0

random_between() {
    local min=$1
    local max=$2
    local range=$((max - min + 1))
    local rand=$((RANDOM * 32768 + RANDOM))

    echo $((rand % range + min))
}

count_days_in_current_year() {
    local cursor=$START_DAY
    local year=$1
    local count=0

    while (( cursor <= END_DAY )) && [[ "$(format_year "${cursor}")" == "${year}" ]]; do
        count=$((count + 1))
        cursor=$((cursor + 86400))
    done

    echo "${count}"
}

prepare_year_targets() {
    local days
    local used

    YEAR=$(format_year "${START_DAY}")
    days=$(count_days_in_current_year "${YEAR}")
    YEAR_DAYS_LEFT=${days}

    if (( days >= 280 )); then
        YEAR_BLACK_LEFT=80
        YEAR_GRAY_LEFT=100
        YEAR_DARK_LEFT=60
        YEAR_PALE_LEFT=40
        YEAR_BRIGHT_LEFT=$((days - 280))
    else
        YEAR_BLACK_LEFT=$((days * 80 / 365))
        YEAR_GRAY_LEFT=$((days * 100 / 365))
        YEAR_DARK_LEFT=$((days * 60 / 365))
        YEAR_PALE_LEFT=$((days * 40 / 365))
        used=$((YEAR_BLACK_LEFT + YEAR_GRAY_LEFT + YEAR_DARK_LEFT + YEAR_PALE_LEFT))
        YEAR_BRIGHT_LEFT=$((days - used))
    fi

    echo "计划 ${YEAR}：纯黑 ${YEAR_BLACK_LEFT} 天，灰绿色 ${YEAR_GRAY_LEFT} 天，暗绿色 ${YEAR_DARK_LEFT} 天，淡绿色 ${YEAR_PALE_LEFT} 天，亮绿色 ${YEAR_BRIGHT_LEFT} 天"
}

pick_level_for_day() {
    local remain_total=$((YEAR_BLACK_LEFT + YEAR_GRAY_LEFT + YEAR_DARK_LEFT + YEAR_PALE_LEFT + YEAR_BRIGHT_LEFT))
    local roll

    roll=$(random_between 1 "${remain_total}")

    if (( roll <= YEAR_BLACK_LEFT )); then
        YEAR_BLACK_LEFT=$((YEAR_BLACK_LEFT - 1))
        BLACK_TOTAL=$((BLACK_TOTAL + 1))
        COLOR_LEVEL="纯黑"
        COMMIT_COUNT=0
    elif (( roll <= YEAR_BLACK_LEFT + YEAR_GRAY_LEFT )); then
        YEAR_GRAY_LEFT=$((YEAR_GRAY_LEFT - 1))
        GRAY_TOTAL=$((GRAY_TOTAL + 1))
        COLOR_LEVEL="灰绿色"
        COMMIT_COUNT=$(random_between 1 2)
    elif (( roll <= YEAR_BLACK_LEFT + YEAR_GRAY_LEFT + YEAR_DARK_LEFT )); then
        YEAR_DARK_LEFT=$((YEAR_DARK_LEFT - 1))
        DARK_TOTAL=$((DARK_TOTAL + 1))
        COLOR_LEVEL="暗绿色"
        COMMIT_COUNT=$(random_between 4 7)
    elif (( roll <= YEAR_BLACK_LEFT + YEAR_GRAY_LEFT + YEAR_DARK_LEFT + YEAR_PALE_LEFT )); then
        YEAR_PALE_LEFT=$((YEAR_PALE_LEFT - 1))
        PALE_TOTAL=$((PALE_TOTAL + 1))
        COLOR_LEVEL="淡绿色"
        COMMIT_COUNT=$(random_between 14 28)
    else
        YEAR_BRIGHT_LEFT=$((YEAR_BRIGHT_LEFT - 1))
        BRIGHT_TOTAL=$((BRIGHT_TOTAL + 1))
        COLOR_LEVEL="亮绿色"
        COMMIT_COUNT=$(random_between 55 95)
    fi
}

random_commit_message() {
    case "$(random_between 1 16)" in
        1) echo "update notes" ;;
        2) echo "refine docs" ;;
        3) echo "adjust config" ;;
        4) echo "fix typo" ;;
        5) echo "cleanup script" ;;
        6) echo "refresh data" ;;
        7) echo "tune workflow" ;;
        8) echo "sync changes" ;;
        9) echo "update README" ;;
        10) echo "minor cleanup" ;;
        11) echo "improve logging" ;;
        12) echo "update examples" ;;
        13) echo "rework helper" ;;
        14) echo "format output" ;;
        15) echo "adjust defaults" ;;
        *) echo "maintenance" ;;
    esac
}

write_commit() {
    local commit_time=$1
    local random_value
    local message

    random_value="${RANDOM}${RANDOM}${RANDOM}"
    message=$(random_commit_message)

    echo "${commit_time} ${message} ${random_value}" > log.txt
    git add .
    GIT_AUTHOR_DATE="${commit_time}" GIT_COMMITTER_DATE="${commit_time}" git commit -m "${message}"
}

modify() {
    local cur_day
    local commit_time
    local offset
    local i

    echo "处理中……"

    while (( START_DAY <= END_DAY )); do
        if (( YEAR_DAYS_LEFT <= 0 )); then
            prepare_year_targets
        fi

        cur_day=$(format_datetime "${START_DAY}")
        pick_level_for_day

        if (( COMMIT_COUNT == 0 )); then
            echo "${cur_day} ${COLOR_LEVEL}"
        else
            echo "${cur_day} ${COLOR_LEVEL}，生成 ${COMMIT_COUNT} 次提交"

            for ((i = 1; i <= COMMIT_COUNT; i++)); do
                offset=$(random_between -18000 41400)
                commit_time=$(format_datetime "$((START_DAY + offset + i))")
                write_commit "${commit_time}" "${i}" "${COMMIT_COUNT}"
            done
        fi

        START_DAY=$((START_DAY + 86400))
        YEAR_DAYS_LEFT=$((YEAR_DAYS_LEFT - 1))
    done

    echo "处理完成"
    echo "统计：纯黑 ${BLACK_TOTAL} 天，灰绿色 ${GRAY_TOTAL} 天，暗绿色 ${DARK_TOTAL} 天，淡绿色 ${PALE_TOTAL} 天，亮绿色 ${BRIGHT_TOTAL} 天"
}

modify

exit 0
