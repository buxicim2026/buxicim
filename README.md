# 不息传播 · 官网

B站 UP 主「不息传播」的官方宣传站，纯手写 HTML / CSS / JS 静态站，托管在 GitHub Pages。

- 线上地址：`https://buxicim2026.github.io/buxicim/`
- 品牌定位：专注科技生活内容的自媒体，偶尔直播有趣的发布会
- 站内含一个自研工具板块：**Stream Live Translate**（OBS 实时 AI 字幕插件）

## 本地预览

公共头尾用 `fetch` 注入，**必须通过 http(s) 打开，不能直接双击 HTML（file://）**：

```bash
# 任选其一
npx serve .
python -m http.server 8080
```

然后访问 `http://localhost:3000`（`serve` 默认端口）或 `http://localhost:8080`。
VS Code 用户也可以用 Live Server 插件。

## 目录结构

```
.
├── index.html        首页：Hero、内容方向、数据、发布会直播、插件、平台矩阵
├── about.html        关于我们：故事、理念、发展历程、账号数据
├── content.html      内容与直播：栏目、视频、直播预告
├── software.html     不息软件：三个自研 OBS 插件总览与下载
├── plugin.html       Stream Live Translate 详情页：能力、演示、四步上手、模型兼容、FAQ
├── contact.html      联系与合作：平台入口、合作方式、留言表单
├── search.html       站内搜索
├── 404.html          404 页
├── partials/         公共头尾（由 layout.js 注入，改一次全站生效）
├── assets/
│   ├── css/          base.css 设计令牌 / components.css 组件 / pages.css 版式
│   ├── js/           layout.js 布局注入 / motion.js 动效 / search.js 搜索
│   ├── data/         site.js 内容配置源 / search-index.json 搜索索引
│   └── img/          favicon 等
├── robots.txt
├── sitemap.xml
├── CNAME             绑定自定义域时启用
└── .nojekyll         禁用 Jekyll（不要删）
```

## 改内容看这里

| 想改什么 | 改哪个文件 |
| --- | --- |
| 品牌名、slogan、简介、导航、邮箱 | `assets/data/site.js` |
| 平台链接（B站 / AcFun / 微信） | `assets/data/site.js` 的 `platforms` |
| 首页数据条数字 | 对应 HTML 里的 `data-count="..."` |
| 导航栏 / 页脚 | `partials/header.html`、`partials/footer.html` |
| 配色与字号 | `assets/css/base.css` 顶部的 `:root` 变量 |
| Logo / 台标 | 替换 `assets/img/logo.png`（导航、页脚、favicon、分享图都用它） |
| 搜索结果 | `assets/data/search-index.json`（新增页面记得补一条） |

新增一个页面：复制任一 HTML → 改标题与内容 → 在 `partials/header.html`、`partials/footer.html` 加链接 → 在 `search-index.json` 补一条 → 在 `sitemap.xml` 补一条。

## 不息软件（自研插件）

`software.html` 汇总三个自研 OBS 插件，下载按钮指向各自 GitHub Releases 的最新发行版：

| 软件 | 说明 | 下载地址 |
| --- | --- | --- |
| Stream Live Translate | 实时画面翻译、实时显示字幕（详情页 `plugin.html`） | `buxicim2026/stream-live-translate/releases/latest` |
| HDR Playlist Source | HDR 播放列表源，多条视频连播不降级 | `buxicim2026/HDR-Playlist-Source/releases/latest` |
| tv-obsbroadcast-scheduler | 电视台式自动播出（预览版） | `buxicim2026/tv-obsbroadcast-scheduler/releases` |

> 插件发新版后，记得同步 `software.html` 与 `plugin.html` 里显示的版本号。

## 待补充清单（TODO）

1. `assets/data/site.js` → `site.email`：商务合作邮箱（填了 contact 页表单才能用）
2. `assets/data/site.js` → `platforms` 里 AcFun 与微信公众号的 `url`
3. `assets/data/site.js` → `videos`：填入 B站 视频的 BV 号，再按 `content.html` 里的注释复制卡片
4. 绑定自定义域名时：在仓库 Settings → Pages 里填域名，并同步更新 `sitemap.xml`、`robots.txt`

搜索 TODO：在项目里搜 `TODO` 可以一次找齐。

## 部署到 GitHub Pages

1. Settings → Pages → Build and deployment
2. Source 选 **Deploy from a branch**
3. Branch 选 `main`，目录选 `/ (root)` → Save
4. 等 1–2 分钟，访问 `https://buxicim2026.github.io/buxicim/`

`.nojekyll` 已放好，站点全用相对路径，绑自定义域或换子路径都不用改代码。
