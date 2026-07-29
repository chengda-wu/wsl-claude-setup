# SearXNG 配置

SearXNG 是元搜索引擎——不索引网页，而是把查询转发给 Google/Bing/Baidu 等上游引擎再聚合。本地部署 = 搜索前端跑在自己机器上，不向搜索 API 服务商付费，但结果仍来自上游引擎。

## 部署

```bash
mkdir -p ~/searxng
# 写 settings.yml（见下）
docker run -d --name searxng --restart unless-stopped \
  -p 8080:8080 \
  -e SEARXNG_BASE_URL=http://localhost:8080/ \
  -v ~/searxng/settings.yml:/etc/searxng/settings.yml:ro \
  searxng/searxng:latest
```

## settings.yml

```yaml
use_default_settings: true
general:
  instance_name: "Local SearXNG"
search:
  formats:
    - html
    - json        # MCP 调用必须开启 JSON 输出，否则 403
server:
  secret_key: "local-dev-secret-change-me"
  bind_address: "0.0.0.0"
  port: 8080
# 上游代理（见下文「代理」）
outgoing:
  request_timeout: 10.0
  enable_http2: false
  proxies:
    all://:
      - http://host.docker.internal:7897
engines:
  # 通用（稳定）
  - name: bing
    disabled: false
  - name: baidu
    disabled: false
  - name: yandex
    disabled: false
  - name: mojeek
    disabled: false
  - name: sogou
    disabled: false
  - name: 360search
    disabled: false
  # 反爬不可用（见下文「引擎稳定性」）
  - name: google cse
    disabled: true
  - name: brave
    disabled: true
  - name: duckduckgo
    disabled: true
  - name: startpage
    disabled: true
  - name: qwant
    disabled: true
```

改完配置重启容器：
```bash
docker compose down && docker compose up -d   # 不要用 restart，见踩坑笔记 #13
```

## 代理（让上游引擎可达）

SearXNG 容器默认连不通外网引擎（bing/baidu 等全部 `HTTP connection error`）。必须给容器配上游代理，**且要用 SearXNG 自己的 `outgoing.proxies`，光配 `HTTP_PROXY` 环境变量不够**——实测 env 在场时引擎仍报 connection error，加上 `outgoing.proxies` 才通。

三个必选项（缺一不可）：

| 项 | 值 | 原因 |
|---|---|---|
| `outgoing.proxies` | `http://host.docker.internal:7897` | SearXNG 真正读取的代理配置；env 变量不生效 |
| `enable_http2` | `false` | 经 HTTP 代理走 HTTPS+HTTP/2 握手会失败 |
| `request_timeout` | `10.0` | 默认 3s 经代理太短，频繁超时 |

`host.docker.internal` 由 Docker Desktop 解析到宿主机（固定 `192.168.65.254`，**不随局域网 IP 变化**），代理客户端（Clash/Mihomo）要开"允许局域网连接"。

> 验证：`docker exec searxng sh -c 'wget -qO- --timeout=6 -e use_proxy=yes -e https_proxy=http://host.docker.internal:7897 https://www.google.com -O /dev/null; echo exit=$?'` 应为 `exit=0`。容器内通但搜索仍无结果 → 检查 `enable_http2: false` 和 `request_timeout`。

## 验证

```bash
# HTTP
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/
# JSON 搜索
curl -s 'http://localhost:8080/search?q=test&format=json' | head -c 300
```

## 关键点

- **必须开 JSON 输出**：`search.formats` 加 `json`，否则 MCP 调用返回 403
- **禁用引擎用 `disabled: true`**，不是 `enabled: false`（SearXNG 的字段名）
- SearXNG 本身不限流，限流的是它背后的上游引擎

## 引擎稳定性（实测）

自建 SearXNG 访问大引擎会触发反爬，**和代理通不通无关**（容器内代理 200 正常，是上游引擎主动拒）。实测结论：

| 引擎 | 状态 | 说明 |
|---|---|---|
| bing / baidu | ✅ 稳定 | 主力，中英文都行 |
| yandex | ✅ 稳定 | 英文补充，结果多 |
| mojeek | ✅ 稳定 | 独立索引，不依赖大厂 |
| sogou / 360search | ✅ 稳定 | 中文补充（sogou wechat 可搜公众号文章） |
| google cse | ❌ 封禁 | "unusual traffic" suspend 180s，需配 CSE API key 才稳 |
| brave | ❌ 不可用 | 需配 API key（有免费额度）才稳 |
| duckduckgo | ❌ CAPTCHA | 几乎必然触发 |
| startpage | ❌ CAPTCHA | 几乎必然触发 |
| qwant | ❌ CAPTCHA | 几乎必然触发 |

**推荐配置**：开 bing/baidu/yandex/mojeek/sogou/360search，禁用 google cse/brave/duckduckgo/startpage/qwant。禁用的引擎留着只会返回 0 结果、刷 ERROR 日志。如需启用 google cse 或 brave，配对应 API key 后再 `disabled: false`。

> 验证方法：`curl -s 'http://localhost:8080/search?q=test&format=json&engines=brave'` 看返回结果数；看报错 `docker logs searxng 2>&1 | grep -iE 'captcha|suspend|unusual'`。

## 引擎状态查询

```bash
curl -s http://localhost:8080/config | python3 -c "
import sys,json
d=json.load(sys.stdin)
for e in d.get('engines',[]):
    print(e.get('name'),'->',e.get('enabled'))
"
```
