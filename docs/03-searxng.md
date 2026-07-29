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
engines:
  - name: google cse
    disabled: false
  - name: bing
    disabled: false
  - name: baidu
    disabled: false
  - name: brave
    disabled: true       # 总是限流
  - name: duckduckgo
    disabled: true       # 总是 CAPTCHA
  - name: startpage
    disabled: true       # 总是 CAPTCHA
```

改完配置重启容器：
```bash
docker restart searxng
```

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
- **保留 Google**：`google cse` 引擎实测稳定，是主力
- 禁用 brave/duckduckgo/startpage 是因为它们对自动化访问触发限流/CAPTCHA，留着只会污染结果
- SearXNG 本身不限流，限流的是它背后的上游引擎

## 引擎状态查询

```bash
curl -s http://localhost:8080/config | python3 -c "
import sys,json
d=json.load(sys.stdin)
for e in d.get('engines',[]):
    print(e.get('name'),'->',e.get('enabled'))
"
```
