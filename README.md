# 贡献热力图数据填充 (Contribution Heatmap Data Filler)

按指定日期范围批量生成历史提交，用来填充 GitHub Profile 的 Contributions Calendar。

## 作者说明

本项目受[@lecepin](https://github.com/lecepin)作者[fill-github-calendar-heatmap](https://github.com/lecepin/fill-github-calendar-heatmap)项目的启发，针对 Windows、macOS、Linux 操作系统重新开发，旨在提供一个跨平台、无需修改系统时间、可按年度活跃度规则生成贡献热力图数据的脚本工具。

- 作者：XinTycd

## 支持系统

- Windows
- macOS
- Linux

脚本不会修改系统时间，而是通过 `GIT_AUTHOR_DATE` 和 `GIT_COMMITTER_DATE` 写入历史提交时间。

## 活跃度规则

每个完整年份会按以下配额随机分布：

| 活跃度 | 每年天数 | 每天提交数 |
| --- | ---: | ---: |
| 纯黑 | 80 天 | 0 |
| 灰绿色 | 100 天 | 1-2 |
| 暗绿色 | 60 天 | 4-7 |
| 淡绿色 | 40 天 | 14-28 |
| 亮绿色 | 其余天数 | 55-95 |

活跃度从低到高为：`纯黑 < 灰绿色 < 暗绿色 < 淡绿色 < 亮绿色`。

如果日期范围不是完整年份，脚本会按比例缩放当年的配额。

## 使用前准备

1. 克隆本仓库到本地。
2. 删除原有 `.git` 目录。
3. 重新初始化仓库并设置用户名和邮箱。

macOS / Ubuntu：

```bash
rm -rf .git
git init
git config user.name "你的 GitHub 用户名"
git config user.email "你的 GitHub 邮箱"
```

Windows PowerShell：

```powershell
Remove-Item -Recurse -Force .git
git init
git config user.name "你的 GitHub 用户名"
git config user.email "你的 GitHub 邮箱"
```

Windows CMD：

```cmd
rmdir /s /q .git
git init
git config user.name "你的 GitHub 用户名"
git config user.email "你的 GitHub 邮箱"
```

## 运行

macOS / Ubuntu：

```bash
./fill.sh 2022-01-01 2024-12-31
```

Windows：

```cmd
.\fill.cmd 2022-01-01 2024-12-31
```

生成完成后，添加远程仓库并推送：

```bash
git remote add origin 你的仓库地址
git push -u origin main
```

如果你的默认分支是 `master`，把上面的 `main` 改成 `master`。

## 注意事项

- `2022-01-01` 到 `2024-12-31` 会生成约两万次提交，可能需要数小时。
- 如果你已经用旧脚本生成并推送过历史，需要重新初始化仓库生成新历史，或者重写历史后强推。
- GitHub Contributions Calendar 统计可能有缓存，推送后颜色更新不是实时的。
- GitHub 只统计与你 GitHub 账号邮箱匹配的提交，请确保 `git config user.email` 使用 GitHub 账号邮箱。
