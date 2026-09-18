# Verity AI家庭CFO · ChatGPT Sites 正式域名部署包（r42）

> 生成：2026-09-18 22:40 +08 · 产品版本 **e0.26.0**
> 用途：把家庭CFO部署到 **https://www.verityready.com/**（与 **https://verityready.com/**），
> 原投资核查工具保留在 **/check/**。本包是「Sites 连接器一旦可用，一条命令上线」的即用包。

## 一、已核实的部署事实（2026-09-18 实测）

| 项 | 值 | 证据 |
| --- | --- | --- |
| 域名归属项目 | `appgprj_6a7aae65ed148191a5ae8bca12ce4d62` | 历史 `add_custom_domain(hostname=www.verityready.com/verityready.com, project_id=...)` 成功记录 + `list_custom_domains` status=active |
| www 记录 | `CNAME → custom-domains.chatgpt.site.` | `dig +short www.verityready.com` |
| apex 记录 | `A → 162.159.143.30 / 172.66.3.26`（该项目的 apex 代理 IP） | `dig +short verityready.com` |
| 域名当前内容 | 旧英文站 “Verity — Check before you invest”（v0.2 英文核查站） | curl 实测 |
| 家庭CFO产物 | `dist/version.json` = e0.26.0（git 2f33e57 / 提交 f4f9b28） | 本轮测试 931 OK (skipped 4) |
| 验证过的同源服务器 | `dist/server/index.js` = 捆绑后的 cf-worker 适配器（静态 + /api/** + D1） | 本轮 esbuild --bundle 构建成功 |
| 本地直跑证据 | r41 生产适配器验收（HTTP 契约 17/17、真实 Chrome 18/18） | 仓库 `ops/r41/` |

## 二、包结构

```
verity-sites-deploy/
  .openai/hosting.json          # project_id + D1 绑定（DB）
  dist/                         # e0.26.0 全量静态产物（首页=家庭CFO，/check/ 原样保留，/family/=PWA 控制台）
  dist/server/index.js          # 捆绑后 Worker（esbuild，30KB，静态+API 同源）
  dist/.openai/hosting.json     # 打包清单（与源清单一致）
  migrations/0001_verity_family_cfo.sql  # D1 幂等建表（CREATE TABLE IF NOT EXISTS，与 platform/schema.sql 同源）
```

## 三、部署步骤（在带 Sites 连接器的会话里执行，即上一轮桌面 Codex/Sites 通道）

1. `get_site(project_id="appgprj_6a7aae65ed148191a5ae8bca12ce4d62")`
   解析当前受众（public/private）与最新版本号；确认域绑定仍在。
2. 无有效写凭据时：`create_source_repository_write_credential(project_id=...)`，
   用返回凭据按 `Authorization` 头逐条 `git push`（凭据不进 URL/配置/文件）。
3. 在本目录 `git init`（仓库根 = 本包根）→ 提交全部文件 → push 成功。
   `commit_sha = git rev-parse --verify HEAD`（原样完整输出，不缩写）。
4. 打包：`node <sites插件目录>/scripts/package-site.mjs <本包路径> <output.zip>`
5. `save_site_version(project_id=..., commit_sha=..., archive=<output.zip>)` → 得到 `version_id`。
6. 按第 1 步受众：owner-private → `deploy_private_site_version`；公开 → `deploy_site_version`。
7. `get_deployment_status` 轮询到 succeeded。
8. 验收（真实浏览器）：https://www.verityready.com/ = 家庭CFO；
   /check/ 可用；注册→建档→刷新/重登→档案仍在；PWA 安装并离线可开。

## 四、上线前必须完成的两件环境事（属于平台侧配置）

1. **D1 建表**：对项目 `DB` 应用 `migrations/0001_verity_family_cfo.sql`（幂等，可重复执行）。
2. **主密钥**：设置环境变量秘密 `VERITY_MASTER_KEY` = 32 字节 base64（`python3 -c 'import os,base64;print(base64.b64encode(os.urandom(32)).decode())'`）。
   一旦设置不得更换（每个用户 DEK 由其派生，换掉=已有家庭档案全部锁死）。

## 五、回滚

`list_site_versions(project_id)` 拿旧版本 → `deploy_site_version(project_id, version_id=旧版本)`
或 `deploy_private_site_version`。域名不解除，回滚即换版本。

## 六、本轮已交付的即时可用入口（非正式域名）

- GitHub Pages 镜像（正式包同步，PWA 可安装）：https://715099543-christine.github.io/
  （/check/、/family/、manifest、sw.js 全部 200，见 ops/r42 证据）
- 正式域名仍未切换：原因 = 本轮会话无 Sites 连接器（探测结论见 ops/r42/NEXT_ACTION 与 RUN_STATE）。
