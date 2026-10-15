<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>iptables 知识点总结 · 软考信息安全工程师</title>
<style>
:root{--bg:#f3f5f7;--panel:#fff;--ink:#1b2430;--mute:#5d6b7a;--line:#d9dfe6;--acc:#0f766e;--red:#b42318;--code:#eef2f5}
@media (prefers-color-scheme:dark){:root{--bg:#10151b;--panel:#171e26;--ink:#e6ebf0;--mute:#93a1b0;--line:#2b3541;--acc:#4fd1c0;--red:#ff8a7a;--code:#0d1217}}
*{box-sizing:border-box}
html{scroll-behavior:smooth;scroll-padding-top:16px}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.75 "Noto Sans SC","PingFang SC","Microsoft YaHei",system-ui,sans-serif}
main{max-width:860px;margin:0 auto;padding:40px 20px 72px}
h1{font-size:2rem;line-height:1.3;margin:0 0 8px}
h2{font-size:1.3rem;margin:48px 0 12px;padding-left:12px;border-left:4px solid var(--acc)}
p{margin:8px 0}
.sub{color:var(--mute);margin:0 0 20px}
nav{display:flex;flex-wrap:wrap;gap:8px;margin:0 0 8px}
nav a{padding:4px 12px;border:1px solid var(--line);border-radius:999px;color:var(--ink);text-decoration:none;font-size:.9rem;background:var(--panel)}
nav a:hover,nav a:focus-visible{border-color:var(--acc);color:var(--acc);outline:none}
code,pre{font-family:"JetBrains Mono",Consolas,Menlo,monospace;font-size:.88rem}
code{background:var(--code);padding:1px 6px;border-radius:4px}
pre{background:var(--code);border:1px solid var(--line);border-radius:6px;padding:12px 14px;overflow-x:auto;margin:8px 0;line-height:1.7}
pre b{color:var(--acc)} pre i{color:var(--red);font-style:normal} pre s{color:var(--mute);text-decoration:none}
.tw{overflow-x:auto;margin:8px 0}
table{width:100%;border-collapse:collapse;background:var(--panel);border:1px solid var(--line)}
th,td{text-align:left;padding:8px 12px;border-bottom:1px solid var(--line);vertical-align:top}
th{background:var(--code);font-weight:600}
td:first-child,th:first-child{width:30%;white-space:nowrap}
td:first-child{font-family:"JetBrains Mono",Consolas,monospace;font-size:.88rem;font-weight:600}
.path{background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:14px 16px;margin:12px 0}
.path .row{display:flex;flex-wrap:wrap;align-items:center;gap:6px 8px;margin:6px 0}
.path .lab{width:100%;color:var(--mute);font-size:.85rem}
.n{padding:3px 10px;border:1px solid var(--line);border-radius:4px;font-family:Consolas,monospace;font-size:.88rem}
.n.k{border-color:var(--acc);color:var(--acc);font-weight:700}
.n.h{border-style:dashed;color:var(--mute)}
.ar{color:var(--mute)}
.note{border-left:3px solid var(--red);background:var(--panel);padding:8px 14px;margin:12px 0}
footer{margin-top:56px;color:var(--mute);font-size:.85rem}
@media (max-width:560px){h1{font-size:1.6rem}td:first-child{white-space:normal}}
</style>
</head>
<body>
<main>
<h1>iptables 知识点总结</h1>
<p class="sub">软考信息安全工程师 · Linux 包过滤防火墙 · 按“表 → 链 → 规则 → 案例”整理</p>
<nav>
<a href="#frame">表与链</a><a href="#cmd">命令格式</a><a href="#act">目标动作</a><a href="#state">连接状态</a><a href="#common">常用规则</a><a href="#fwd">FORWARD 案例</a><a href="#nat">NAT</a><a href="#pit">易错点</a>
</nav>

<h2 id="frame">1. 表与链：数据包经过的关卡</h2>
<p>iptables 工作在内核 netfilter 之上，规则按“表 → 链 → 规则”组织。数据包到达后，沿链从上到下匹配，命中即停。</p>
<div class="path">
<div class="row"><span class="lab">发往本机</span><span class="n h">PREROUTING</span><span class="ar">→</span><span class="n k">INPUT</span><span class="ar">→</span><span class="n">本机进程</span><span class="ar">→</span><span class="n k">OUTPUT</span><span class="ar">→</span><span class="n h">POSTROUTING</span></div>
<div class="row"><span class="lab">经本机转发</span><span class="n h">PREROUTING</span><span class="ar">→</span><span class="n k">FORWARD</span><span class="ar">→</span><span class="n h">POSTROUTING</span></div>
<div class="lab" style="color:var(--mute);font-size:.85rem">虚线框的两条链只存在于 nat 表：PREROUTING 做 DNAT，POSTROUTING 做 SNAT。</div>
</div>
<div class="tw"><table>
<tr><th>表</th><th>要点</th></tr>
<tr><td>filter</td><td>默认表，负责放行或丢弃；含 INPUT、FORWARD、OUTPUT</td></tr>
<tr><td>nat</td><td>地址转换（DNAT、SNAT、MASQUERADE）；含 PREROUTING、POSTROUTING、OUTPUT</td></tr>
<tr><td>mangle</td><td>修改包头（TOS、TTL、打标记）</td></tr>
<tr><td>raw</td><td>设置免连接跟踪（NOTRACK）；优先级最高</td></tr>
<tr><td>表优先级</td><td>raw → mangle → nat → filter</td></tr>
<tr><td>INPUT</td><td>目的地址是本机的包</td></tr>
<tr><td>OUTPUT</td><td>本机进程发出的包</td></tr>
<tr><td>FORWARD</td><td>穿过本机、不进入本机进程的包（拼写是 FORWARD，不是 FORWARE）</td></tr>
</table></div>

<h2 id="cmd">2. 命令格式、操作与匹配条件</h2>
<pre>iptables <b>[-t 表]</b> <b>操作命令</b> <b>链名</b> <b>匹配条件</b> <i>-j 目标动作</i>
<s># 不写 -t 时默认操作 filter 表</s></pre>
<div class="tw"><table>
<tr><th>操作命令</th><th>要点</th></tr>
<tr><td>-A</td><td>追加到链尾</td></tr>
<tr><td>-I [序号]</td><td>插入；不写序号则插到第 1 条</td></tr>
<tr><td>-D</td><td>按序号或完整规则删除</td></tr>
<tr><td>-R</td><td>替换指定序号的规则</td></tr>
<tr><td>-L -n -v</td><td>列出规则；-n 不解析主机名，-v 显示详细信息（加 --line-numbers 显示序号）</td></tr>
<tr><td>-F</td><td>清空规则（不改默认策略）；不写链名则清空所有链</td></tr>
<tr><td>-N / -X</td><td>新建 / 删除自定义链（删除前须清空且无引用）</td></tr>
<tr><td>-P</td><td>设置默认策略，只对内置主链生效</td></tr>
<tr><td>-Z</td><td>计数器清零</td></tr>
</table></div>
<div class="tw"><table>
<tr><th>匹配条件</th><th>要点</th></tr>
<tr><td>-p</td><td>协议：tcp / udp / icmp / all</td></tr>
<tr><td>-s / -d</td><td>源 / 目的地址或网段；<code>0/0</code> 表示任意，可省略</td></tr>
<tr><td>-i / -o</td><td>入 / 出网卡；-i 用于 INPUT、FORWARD、PREROUTING，-o 用于 OUTPUT、FORWARD、POSTROUTING</td></tr>
<tr><td>--sport / --dport</td><td>源 / 目的端口，必须配合 -p tcp 或 -p udp；区间写法 <code>20:21</code></td></tr>
<tr><td>-m state</td><td>按连接状态匹配（见第 4 节）</td></tr>
<tr><td>-m multiport</td><td>多个不连续端口：<code>--dports 80,443</code></td></tr>
<tr><td>-m iprange</td><td>IP 区间：<code>--src-range 192.168.1.10-20</code></td></tr>
<tr><td>-m mac</td><td>匹配源 MAC：<code>--mac-source</code></td></tr>
</table></div>

<h2 id="act">3. 目标动作（-j）</h2>
<div class="tw"><table>
<tr><th>动作</th><th>要点</th></tr>
<tr><td>ACCEPT</td><td>放行</td></tr>
<tr><td>DROP</td><td>直接丢弃，不回应，对方只能等超时</td></tr>
<tr><td>REJECT</td><td>拒绝并返回错误信息</td></tr>
<tr><td>LOG</td><td>记日志；非终止动作，继续往下匹配</td></tr>
<tr><td>RETURN</td><td>结束本链匹配，返回上层链</td></tr>
<tr><td>SNAT</td><td>改源 IP，用于共享上网（固定公网 IP）</td></tr>
<tr><td>MASQUERADE</td><td>用出口网卡 IP 替换源 IP，适合动态拨号</td></tr>
<tr><td>DNAT</td><td>改目标 IP / 端口，用于端口映射</td></tr>
<tr><td>自定义链名</td><td>跳转到该链继续匹配</td></tr>
</table></div>

<h2 id="state">4. 连接状态（-m state）</h2>
<div class="tw"><table>
<tr><th>状态</th><th>含义</th></tr>
<tr><td>NEW</td><td>新建连接的第一个包</td></tr>
<tr><td>ESTABLISHED</td><td>已建立连接的后续包（含响应包）</td></tr>
<tr><td>RELATED</td><td>与已有连接相关的新连接（如 FTP 数据连接、ICMP 差错）</td></tr>
<tr><td>INVALID</td><td>无法识别或状态异常的包，通常直接丢弃</td></tr>
</table></div>

<h2 id="common">5. 常用规则速记</h2>
<pre><s># 放行已建立的连接及相关包</s>
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
<s># 允许所有人访问本机 TCP 80</s>
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
<s># 只允许指定 IP 访问本机 UDP 53</s>
iptables -A INPUT -p udp -s 192.168.1.100 --dport 53 -j ACCEPT
<s># 禁止本机访问外部 TCP 23</s>
iptables -A OUTPUT -p tcp -d 8.8.8.8 --dport 23 -j DROP
<s># 默认策略：不匹配则丢弃</s>
iptables -P INPUT DROP</pre>

<h2 id="fwd">6. FORWARD 链案例：Web 与 FTP 服务器</h2>
<p>场景：网关后有两台服务器，规则放在 FORWARD 链。</p>
<div class="tw"><table>
<tr><th>服务器</th><th>访问要求</th></tr>
<tr><td>Web 10.10.10.20:80</td><td>内网、外网均可访问</td></tr>
<tr><td>FTP 10.10.10.33:20,21</td><td>仅内网 192.168.1.0/24 可访问</td></tr>
</table></div>
<pre><s># Web：请求方向 + 响应方向</s>
iptables -A FORWARD -s 0/0 -d 10.10.10.20/32 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s 10.10.10.20/32 -d 0/0 -p tcp --sport 80 -j ACCEPT
<s># FTP：只对内网开放</s>
iptables -A FORWARD -s 192.168.1.0/24 -d 10.10.10.33/32 -p tcp --dport 20:21 -j ACCEPT
iptables -A FORWARD -s 10.10.10.33/32 -d 192.168.1.0/24 -p tcp --sport 20:21 -j ACCEPT
<s># 兜底：没有命中任何规则的包一律丢弃</s>
iptables -P FORWARD DROP</pre>
<p>更简洁的现代写法：用连接跟踪放行所有响应方向，只写请求方向。</p>
<pre>iptables -P FORWARD DROP
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -d 10.10.10.20 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -d 10.10.10.33 -p tcp --dport 20:21 -j ACCEPT</pre>
<div class="tw"><table>
<tr><th>答题要点</th><th>说明</th></tr>
<tr><td>一对方向</td><td>iptables 对去、回两个方向分别判断，放行了请求还要单独放行回程</td></tr>
<tr><td>端口方向</td><td>请求包用 --dport（目的端口），响应包用 --sport（源端口）</td></tr>
<tr><td>顺序</td><td>四条 ACCEPT 都要排在默认策略生效之前；-P 是兜底动作，不占链内顺序</td></tr>
<tr><td>省略写法</td><td><code>-s 0/0</code> 等同于不写 -s</td></tr>
</table></div>

<h2 id="nat">7. NAT 地址转换</h2>
<pre><s># 共享上网（固定公网 IP）</s>
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o eth1 -j SNAT --to-source 公网IP
<s># 共享上网（动态拨号）</s>
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o eth1 -j MASQUERADE
<s># 端口映射：访问本机 80 转到内网 192.168.1.10:8080</s>
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 192.168.1.10:8080
<s># 作为网关转发，须开启内核转发</s>
echo 1 &gt; /proc/sys/net/ipv4/ip_forward</pre>

<h2 id="pit">8. 易错点</h2>
<div class="tw"><table>
<tr><th>易错点</th><th>要点</th></tr>
<tr><td>顺序</td><td>规则自上而下匹配、命中即停；越具体的规则越靠上</td></tr>
<tr><td>-P</td><td>只对 INPUT、FORWARD、OUTPUT 等内置主链生效</td></tr>
<tr><td>端口</td><td>--sport / --dport 前面必须先有 -p tcp 或 -p udp</td></tr>
<tr><td>单向放行</td><td>只放请求不放回程，连接建立不起来</td></tr>
<tr><td>LOG</td><td>非终止动作，后面还要写 ACCEPT 或 DROP</td></tr>
<tr><td>DROP 与 REJECT</td><td>DROP 无回应，REJECT 有错误回应；对外一般用 DROP 减少暴露信息</td></tr>
<tr><td>-F</td><td>只清规则，不改默认策略；远程操作时若策略是 DROP，清空后会断连</td></tr>
<tr><td>-I 与 -A</td><td>-I 默认插到最前，-A 追加到末尾，顺序不同结果不同</td></tr>
<tr><td>持久化</td><td>命令行写入重启即失效，用 <code>iptables-save &gt; /etc/iptables/rules.v4</code> 保存</td></tr>
</table></div>

<footer>整理自 iptables 速查表与 FORWARD 链访问控制规则两份资料；第 7 节 SNAT、MASQUERADE 与转发开关为补充内容。</footer>
</main>
</body>
</html>
