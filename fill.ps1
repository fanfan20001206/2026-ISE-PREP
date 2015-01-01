param(
    [Parameter(Position = 0)]
    [string]$StartDate,

    [Parameter(Position = 1)]
    [string]$EndDate
)

$ErrorActionPreference = "Stop"

trap {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}

function Stop-WithMessage {
    param([string]$Message)

    [Console]::Error.WriteLine($Message)
    exit 1
}

function Invoke-Git {
    param([string[]]$Arguments)

    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage "git 命令执行失败：git $($Arguments -join ' ')"
    }
}

function Parse-Date {
    param([string]$Value)

    try {
        return [datetime]::ParseExact(
            $Value,
            "yyyy-MM-dd",
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None
        ).Date.AddHours(12)
    }
    catch {
        Stop-WithMessage "日期格式错误：$Value，请使用 yyyy-MM-dd，如 2022-01-01"
    }
}

function Get-RandomBetween {
    param(
        [int]$Min,
        [int]$Max
    )

    return Get-Random -Minimum $Min -Maximum ($Max + 1)
}

function Get-RandomCommitMessage {
    $messages = @(
        "update notes",
        "refine docs",
        "adjust config",
        "fix typo",
        "cleanup script",
        "refresh data",
        "tune workflow",
        "sync changes",
        "update README",
        "minor cleanup",
        "improve logging",
        "update examples",
        "rework helper",
        "format output",
        "adjust defaults",
        "maintenance"
    )

    return $messages[(Get-Random -Minimum 0 -Maximum $messages.Count)]
}

function Get-YearDaysInRange {
    param(
        [datetime]$Cursor,
        [datetime]$End
    )

    $year = $Cursor.Year
    $count = 0

    while ($Cursor -le $End -and $Cursor.Year -eq $year) {
        $count++
        $Cursor = $Cursor.AddDays(1)
    }

    return $count
}

function New-YearTargets {
    param(
        [datetime]$Cursor,
        [datetime]$End
    )

    $days = Get-YearDaysInRange -Cursor $Cursor -End $End

    if ($days -ge 280) {
        $black = 80
        $gray = 100
        $dark = 60
        $pale = 40
        $bright = $days - 280
    }
    else {
        $black = [int][Math]::Floor($days * 80 / 365)
        $gray = [int][Math]::Floor($days * 100 / 365)
        $dark = [int][Math]::Floor($days * 60 / 365)
        $pale = [int][Math]::Floor($days * 40 / 365)
        $bright = $days - $black - $gray - $dark - $pale
    }

    return @{
        Year = $Cursor.Year
        DaysLeft = $days
        Black = $black
        Gray = $gray
        Dark = $dark
        Pale = $pale
        Bright = $bright
    }
}

function Get-LevelForDay {
    param([hashtable]$Targets)

    $remainTotal = $Targets.Black + $Targets.Gray + $Targets.Dark + $Targets.Pale + $Targets.Bright
    $roll = Get-RandomBetween -Min 1 -Max $remainTotal

    if ($roll -le $Targets.Black) {
        $Targets.Black--
        return @{ Level = "纯黑"; CommitCount = 0 }
    }

    if ($roll -le ($Targets.Black + $Targets.Gray)) {
        $Targets.Gray--
        return @{ Level = "灰绿色"; CommitCount = (Get-RandomBetween -Min 1 -Max 2) }
    }

    if ($roll -le ($Targets.Black + $Targets.Gray + $Targets.Dark)) {
        $Targets.Dark--
        return @{ Level = "暗绿色"; CommitCount = (Get-RandomBetween -Min 4 -Max 7) }
    }

    if ($roll -le ($Targets.Black + $Targets.Gray + $Targets.Dark + $Targets.Pale)) {
        $Targets.Pale--
        return @{ Level = "淡绿色"; CommitCount = (Get-RandomBetween -Min 14 -Max 28) }
    }

    $Targets.Bright--
    return @{ Level = "亮绿色"; CommitCount = (Get-RandomBetween -Min 55 -Max 95) }
}

function Write-FakeCommit {
    param([datetime]$CommitTime)

    $message = Get-RandomCommitMessage
    $randomValue = Get-Random -Minimum 100000 -Maximum 999999999
    $commitTimeText = $CommitTime.ToString("yyyy-MM-ddTHH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)

    [System.IO.File]::WriteAllText(
        (Join-Path (Get-Location) "log.txt"),
        "$commitTimeText $message $randomValue`n",
        [System.Text.UTF8Encoding]::new($false)
    )

    Invoke-Git @("add", ".")

    $env:GIT_AUTHOR_DATE = $commitTimeText
    $env:GIT_COMMITTER_DATE = $commitTimeText
    try {
        Invoke-Git @("commit", "-m", $message)
    }
    finally {
        Remove-Item Env:\GIT_AUTHOR_DATE -ErrorAction SilentlyContinue
        Remove-Item Env:\GIT_COMMITTER_DATE -ErrorAction SilentlyContinue
    }
}

if ([string]::IsNullOrWhiteSpace($StartDate) -or [string]::IsNullOrWhiteSpace($EndDate)) {
    Stop-WithMessage "用法：.\fill.cmd 开始日期 结束日期，如：.\fill.cmd 2022-01-01 2024-12-31"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Stop-WithMessage "未找到 git 命令，请先安装 Git for Windows 并确认 git 已加入 PATH"
}

$insideWorkTree = & git rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $insideWorkTree.Trim() -ne "true") {
    Stop-WithMessage "当前目录不是 git 仓库，请先执行 git init"
}

$startDay = Parse-Date $StartDate
$endDay = Parse-Date $EndDate

if ($startDay -gt $endDay) {
    Stop-WithMessage "开始日期不能晚于结束日期"
}

$blackTotal = 0
$grayTotal = 0
$darkTotal = 0
$paleTotal = 0
$brightTotal = 0
$targets = $null

Write-Output "处理中……"

for ($day = $startDay; $day -le $endDay; $day = $day.AddDays(1)) {
    if ($null -eq $targets -or $targets.DaysLeft -le 0) {
        $targets = New-YearTargets -Cursor $day -End $endDay
        Write-Output "计划 $($targets.Year)：纯黑 $($targets.Black) 天，灰绿色 $($targets.Gray) 天，暗绿色 $($targets.Dark) 天，淡绿色 $($targets.Pale) 天，亮绿色 $($targets.Bright) 天"
    }

    $level = Get-LevelForDay -Targets $targets
    $dayText = $day.ToString("yyyy-MM-ddT12:00:00", [System.Globalization.CultureInfo]::InvariantCulture)

    switch ($level.Level) {
        "纯黑" { $blackTotal++ }
        "灰绿色" { $grayTotal++ }
        "暗绿色" { $darkTotal++ }
        "淡绿色" { $paleTotal++ }
        "亮绿色" { $brightTotal++ }
    }

    if ($level.CommitCount -eq 0) {
        Write-Output "$dayText $($level.Level)"
    }
    else {
        Write-Output "$dayText $($level.Level)，生成 $($level.CommitCount) 次提交"

        for ($i = 1; $i -le $level.CommitCount; $i++) {
            $offset = Get-RandomBetween -Min -18000 -Max 41400
            $commitTime = $day.AddSeconds($offset + $i)
            Write-FakeCommit -CommitTime $commitTime
        }
    }

    $targets.DaysLeft--
}

Write-Output "处理完成"
Write-Output "统计：纯黑 $blackTotal 天，灰绿色 $grayTotal 天，暗绿色 $darkTotal 天，淡绿色 $paleTotal 天，亮绿色 $brightTotal 天"
