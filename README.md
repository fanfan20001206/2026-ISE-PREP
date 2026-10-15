# iptables 知识点总结

软考信息安全工程师 · Linux 包过滤防火墙 · 按“表 → 链 → 规则 → 案例”整理

## 1. 表与链：数据包经过的关卡

iptables 工作在内核 netfilter 之上，规则按“表 → 链 → 规则”组织。数据包沿链从上到下匹配，命中即停。

```
发往本机： PREROUTING → INPUT → 本机进程 → OUTPUT → POSTROUTING
经本机转发：PREROUTING → FORWARD → POSTROUTING
```

PREROUTING、POSTROUTING 只存在于 nat 表：前者做 DNAT，后者做 SNAT。

| 表 | 要点 |
| --- | --- |
| filter | 默认表，负责放行或丢弃；含 INPUT、FORWARD、OUTPUT |
| nat | 地址转换（DNAT、SNAT、MASQUERADE）；含 PREROUTING、POSTROUTING、OUTPUT |
| mangle | 修改包头（TOS、TTL、打标记） |
| raw | 设置免连接跟踪（NOTRACK）；优先级最高 |
| 表优先级 | raw → mangle → nat → filter |

| 链 | 要点 |
| --- | --- |
| INPUT | 目的地址是本机的包 |
| OUTPUT | 本机进程发出的包 |
| FORWARD | 穿过本机、不进入本机进程的包（拼写是 FORWARD，不是 FORWARE） |

## 2. 命令格式、操作与匹配条件

```
iptables [-t 表] 操作命令 链名 匹配条件 -j 目标动作
# 不写 -t 时默认操作 filter 表
```

| 操作命令 | 要点 |
| --- | --- |
| `-A` | 追加到链尾 |
| `-I [序号]` | 插入；不写序号则插到第 1 条 |
| `-D` | 按序号或完整规则删除 |
| `-R` | 替换指定序号的规则 |
| `-L -n -v` | 列出规则；-n 不解析主机名，-v 显示详细信息（加 `--line-numbers` 显示序号） |
| `-F` | 清空规则（不改默认策略）；不写链名则清空所有链 |
| `-N` / `-X` | 新建 / 删除自定义链（删除前须清空且无引用） |
| `-P` | 设置默认策略，只对内置主链生效 |
| `-Z` | 计数器清零 |

| 匹配条件 | 要点 |
| --- | --- |
| `-p` | 协议：tcp / udp / icmp / all |
| `-s` / `-d` | 源 / 目的地址或网段；`0/0` 表示任意，可省略 |
| `-i` / `-o` | 入 / 出网卡；-i 用于 INPUT、FORWARD、PREROUTING，-o 用于 OUTPUT、FORWARD、POSTROUTING |
| `--sport` / `--dport` | 源 / 目的端口，必须配合 `-p tcp` 或 `-p udp`；区间写法 `20:21` |
| `-m state` | 按连接状态匹配（见第 4 节） |
| `-m multiport` | 多个不连续端口：`--dports 80,443` |
| `-m iprange` | IP 区间：`--src-range 192.168.1.10-20` |
| `-m mac` | 匹配源 MAC：`--mac-source` |

## 3. 目标动作（-j）

| 动作 | 要点 |
| --- | --- |
| ACCEPT | 放行 |
| DROP | 直接丢弃，不回应，对方只能等超时 |
| REJECT | 拒绝并返回错误信息 |
| LOG | 记日志；非终止动作，继续往下匹配 |
| RETURN | 结束本链匹配，返回上层链 |
| SNAT | 改源 IP，用于共享上网（固定公网 IP） |
| MASQUERADE | 用出口网卡 IP 替换源 IP，适合动态拨号 |
| DNAT | 改目标 IP / 端口，用于端口映射 |
| 自定义链名 | 跳转到该链继续匹配 |

## 4. 连接状态（-m state）

| 状态 | 含义 |
| --- | --- |
| NEW | 新建连接的第一个包 |
| ESTABLISHED | 已建立连接的后续包（含响应包） |
| RELATED | 与已有连接相关的新连接（如 FTP 数据连接、ICMP 差错） |
| INVALID | 无法识别或状态异常的包，通常直接丢弃 |

## 5. 常用规则速记

```bash
# 放行已建立的连接及相关包
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
# 允许所有人访问本机 TCP 80
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
# 只允许指定 IP 访问本机 UDP 53
iptables -A INPUT -p udp -s 192.168.1.100 --dport 53 -j ACCEPT
# 禁止本机访问外部 TCP 23
iptables -A OUTPUT -p tcp -d 8.8.8.8 --dport 23 -j DROP
# 默认策略：不匹配则丢弃
iptables -P INPUT DROP
```

## 6. FORWARD 链案例：Web 与 FTP 服务器

场景：网关后有两台服务器，规则放在 FORWARD 链。

| 服务器 | 访问要求 |
| --- | --- |
| Web 10.10.10.20:80 | 内网、外网均可访问 |
| FTP 10.10.10.33:20,21 | 仅内网 192.168.1.0/24 可访问 |

```bash
# Web：请求方向 + 响应方向
iptables -A FORWARD -s 0/0 -d 10.10.10.20/32 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s 10.10.10.20/32 -d 0/0 -p tcp --sport 80 -j ACCEPT
# FTP：只对内网开放
iptables -A FORWARD -s 192.168.1.0/24 -d 10.10.10.33/32 -p tcp --dport 20:21 -j ACCEPT
iptables -A FORWARD -s 10.10.10.33/32 -d 192.168.1.0/24 -p tcp --sport 20:21 -j ACCEPT
# 兜底：没有命中任何规则的包一律丢弃
iptables -P FORWARD DROP
```

更简洁的现代写法：用连接跟踪放行所有响应方向，只写请求方向。

```bash
iptables -P FORWARD DROP
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -d 10.10.10.20 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -d 10.10.10.33 -p tcp --dport 20:21 -j ACCEPT
```

| 答题要点 | 说明 |
| --- | --- |
| 一对方向 | iptables 对去、回两个方向分别判断，放行了请求还要单独放行回程 |
| 端口方向 | 请求包用 `--dport`（目的端口），响应包用 `--sport`（源端口） |
| 顺序 | 四条 ACCEPT 都要排在默认策略生效之前；`-P` 是兜底动作，不占链内顺序 |
| 省略写法 | `-s 0/0` 等同于不写 `-s` |

## 7. NAT 地址转换

```bash
# 共享上网（固定公网 IP）
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o eth1 -j SNAT --to-source 公网IP
# 共享上网（动态拨号）
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o eth1 -j MASQUERADE
# 端口映射：访问本机 80 转到内网 192.168.1.10:8080
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 192.168.1.10:8080
# 作为网关转发，须开启内核转发
echo 1 > /proc/sys/net/ipv4/ip_forward
```

## 8. 易错点

| 易错点 | 要点 |
| --- | --- |
| 顺序 | 规则自上而下匹配、命中即停；越具体的规则越靠上 |
| `-P` | 只对 INPUT、FORWARD、OUTPUT 等内置主链生效 |
| 端口 | `--sport` / `--dport` 前面必须先有 `-p tcp` 或 `-p udp` |
| 单向放行 | 只放请求不放回程，连接建立不起来 |
| LOG | 非终止动作，后面还要写 ACCEPT 或 DROP |
| DROP 与 REJECT | DROP 无回应，REJECT 有错误回应；对外一般用 DROP 减少暴露信息 |
| `-F` | 只清规则，不改默认策略；远程操作时若策略是 DROP，清空后会断连 |
| `-I` 与 `-A` | `-I` 默认插到最前，`-A` 追加到末尾，顺序不同结果不同 |
| 持久化 | 命令行写入重启即失效，用 `iptables-save > /etc/iptables/rules.v4` 保存 |

---

整理自 iptables 速查表与 FORWARD 链访问控制规则两份资料；第 7 节 SNAT、MASQUERADE 与转发开关为补充内容。
