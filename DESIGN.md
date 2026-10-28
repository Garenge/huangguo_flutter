# 黄果短剧 Flutter App — 设计文档

## 项目概述

**黄果短剧** — 基于 Flutter 的跨平台短剧浏览器，复刻自 [huangguovideo-01.pages.dev](https://huangguovideo-01.pages.dev/)。

### 核心功能
1. 加载远程扩展 JS 源码，解析站点规则（SITE、UA、分类 Tab）
2. 按分类浏览短剧列表（首页/AI成人短剧/AI成人漫剧/AI换脸/AI魔改/专题/排行榜/黄果吃瓜/回家的路/最近上新/热门推荐）
3. 关键词搜索短剧
4. 短剧详情页：剧集列表
5. 解析播放页，提取 m3u8 流地址
6. 内置播放器播放 m3u8
7. 手动解析：粘贴 URL 或 HTML 源码
8. 封面图 AES-128-CBC 解密

### 目标平台
- iOS / Android（主要）
- macOS / Windows（桌面端）
- Web（需 CORS 代理，本版本暂不做 Web 端深度适配）

### 不做的
- Web 端复杂 CORS 代理（后续单独做）
- 下载/缓存功能（后续迭代）
- 用户登录/收藏/历史（后续迭代）

---

## 技术栈

| 层 | 选型 | 理由 |
|---|------|------|
| 框架 | Flutter 3.41+ / Dart 3.11+ | 跨平台，单代码库 |
| HTTP | `dio` | 拦截器、Cookie、重试、超时 |
| HTML 解析 | `html` (dart-lang/html) | 服务端式 DOM 解析，比正则稳健 |
| AES 解密 | `encrypt` | 封面图 AES-128-CBC 解密 |
| 视频播放 | `video_player` | 移动/桌面端原生 m3u8 支持 |
| 状态管理 | `setState` | 轻量，页面级状态，不做全局状态 |
| 图标 | `cupertino_icons` + Material Icons | Flutter 内置 |

pubspec.yaml 依赖：
```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0
  html: ^0.15.4
  encrypt: ^5.0.3
  video_player: ^2.8.0
  cupertino_icons: ^1.0.6
```

---

## 目录结构

```
huangguo_flutter/
├── lib/
│   ├── main.dart                      # 入口，MaterialApp
│   ├── models/
│   │   ├── drama.dart                 # 短剧卡片模型
│   │   ├── episode.dart               # 剧集模型
│   │   └── source_config.dart         # 扩展源码解析结果
│   ├── services/
│   │   ├── source_loader.dart         # 加载远程 JS + 正则提取配置
│   │   ├── huangguo_api.dart          # 所有 HTTP 抓取接口
│   │   ├── html_parser.dart           # HTML 刮削：卡片/剧集/播放地址
│   │   ├── image_decryptor.dart       # AES-128-CBC 封面图解密
│   │   └── stream_resolver.dart       # 从播放页提取 m3u8
│   ├── pages/
│   │   ├── home_page.dart             # 主页面：分类Tab + 列表
│   │   ├── detail_page.dart           # 详情页：剧集列表 + 封面
│   │   ├── player_page.dart           # 播放页
│   │   └── manual_parse_page.dart     # 手动解析页
│   └── widgets/
│       ├── drama_card.dart            # 短剧卡片组件
│       ├── episode_grid.dart          # 剧集网格组件
│       └── loading_indicator.dart     # 加载指示器
├── test/
│   └── (留空，后续补充)
├── pubspec.yaml
└── DESIGN.md                          # 本文件
```

---

## 数据模型

### Drama（短剧卡片）
```dart
class Drama {
  final String id;        // 短剧 ID，如 "12345"
  final String name;      // 标题，如 "少妇白洁"
  final String pic;       // 封面图 URL（已剥离 auth_key 参数）
  final String remark;    // 备注，如 "更新至18集 · 8.8分"
}
```

### Episode（剧集）
```dart
class Episode {
  final String name;      // 显示名，如 "第1集"
  final String url;       // 播放页完整 URL
  final String ep;        // 集数编号，如 "1"
}
```

### SourceConfig（扩展源码解析结果）
```dart
class SourceConfig {
  final String site;           // 站点地址，如 "https://huangguoai.com"
  final String ua;             // User-Agent
  final List<TabItem> tabs;    // 分类列表
  final String rawSource;      // 原始 JS 源码（保留以备后续扩展）
}

class TabItem {
  final String name;   // 显示名，如 "首页"
  final String id;     // 路由 id，如 "home"
}
```

---

## 服务层设计

### 1. source_loader.dart — 扩展源码加载

职责：从 GitHub 拉取 `huangguo.js`，正则提取配置。

默认 URL: `https://raw.githubusercontent.com/Yswag/xptv-extensions/refs/heads/main/js/huangguo.js`

流程:
1. dio.get(url) 获取 JS 源码字符串
2. 正则提取:
   - `const SITE = '...'`           → site
   - `const UA = '...'`             → ua
   - `const TABS = [{...}]`         → tabs 列表
3. 返回 SourceConfig

缓存策略:
- 首次加载后缓存在内存，提供 reload() 方法强制刷新
- 不做本地持久化（保持轻量）

正则提取规则（与原始页面一致）：
```dart
// SITE
RegExp(r"const\s+SITE\s*=\s*['\"]([^'\"]+)['\"]")

// UA
RegExp(r"const\s+UA\s*=\s*['\"]([\s\S]*?)['\"]")

// TABS
RegExp(r"const\s+TABS\s*=\s*\[([\s\S]*?)\]")
// 然后从 TABS 块中提取每一项:
RegExp(r"\{\s*name:\s*['\"]([^'\"]+)['\"]\s*,\s*id:\s*['\"]([^'\"]+)['\"]\s*\}")
```

### 2. huangguo_api.dart — HTTP 接口层

职责：封装所有对 `huangguoai.com` 的 HTTP 请求。

Headers（每次请求）:
```
User-Agent: (从 SourceConfig.ua 取)
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: zh-CN,zh;q=0.9
Referer: (根据场景设置)
```

接口:
```
fetchHome()           → GET /                         → HTML
fetchCategory(id, page) → GET /{id}/{page}/           → HTML
fetchDetail(id)       → GET /video/{id}/              → HTML
fetchPlayPage(url)    → GET {url} (完整播放页URL)      → HTML
search(keyword)       → GET /search/video/{keyword}/  → HTML
```

错误处理:
- dio 超时 15s
- 非 200 状态码抛异常，上层 UI 捕获显示 toast
- 网络错误统一返回友好提示

### 3. html_parser.dart — HTML 刮削

职责：从 HTML 字符串中提取结构化数据。使用 `html` 包解析 DOM，比正则更稳健。

核心方法:
```
parseCardList(html, allGrids)  → List<Drama>
parseRankList(html)            → List<Drama>
parseEpisodes(html)            → List<Episode>
parsePlayUrl(html, ep)         → String (m3u8 URL)
```

实现细节（与原版一致，但用 CSS 选择器替代正则）:

1. **parseCardList**:
   - 找 `.hg-card-grid` 容器 → 找 `.hg-drama-card` 卡片
   - 提取 `a[href*="/video/"]` 或 `a[href*="/detail/"]` 的 href → 解析出 id
   - 提取 `img[data-src]` 或 `img[src]` → pic
   - 提取 `.hg-drama-card__title` → name
   - 提取 `.hg-drama-card__episode` + `.hg-drama-card__score` → remark
   - 去重（按 id）

2. **parseRankList**:
   - 找 `.hg-rank-list` 容器 → 找 `.hg-rank-item`
   - 同理解析 id, title, pic, tags

3. **parseEpisodes**:
   - 优先找 `.hg-web-play__ep-grid` 或 `.hg-web-detail__ep-grid` 容器
   - 提取所有 `<a>` 标签
   - href → url, data-ep-id → ep, textContent → name
   - 如果没找到 ep-grid，回退找 `.hg-web-play__play` 或 `.hg-web-detail__play` 的 href

4. **parsePlayUrl**:
   - 找 `<script id="videoInitialData">` 的内容
   - JSON.parse → data.epPlaySrcs[ep] || data.videoSrc
   - 处理 `\u0026` → `&`
   - 验证是合法 URL

### 4. image_decryptor.dart — 封面图解密

职责：下载加密的封面图字节，AES-128-CBC 解密，返回可用于显示的图片数据。

算法参数（来自 crypto-worker.js）:
```
key: hex 字符串 "f5d965df75336270" → 需确认实际字节数
iv:  hex 字符串 "97b60394abc2fbe1" → 需确认实际字节数
模式: AES-128-CBC, PKCS7 padding
```

流程:
1. `dio.get(picUrl, responseType: bytes)` 获取原始字节
2. 如果 raw 为空或 len % 16 != 0 → 原样返回（未加密）
3. AES-CBC 解密（NoPadding 模式，因为 PKCS7 需要手动剥离）
4. 检查解密后开头是否为图片签名:
   - JPEG: `\xff\xd8`
   - PNG:  `\x89PNG\r\n\x1a\n`
   - WEBP: `RIFF....WEBP`
   - GIF:  `GIF87a` / `GIF89a`
   - 如果不是 → 原图未加密，返回原始字节
5. 剥离 PKCS7 padding（末字节 pad 值，1<=pad<=16）
6. 收尾截断：JPEG 留到最后一个 `\xff\xd9`，PNG 留到 IEND+8
7. 返回解密后的 Uint8List

降级策略:
- 解密失败 → 返回原始字节（尝试直接显示）
- 全部失败 → 使用占位图

注意:
- 该解密是 CPU 操作，在列表中应做懒加载 + 内存缓存
- 使用 compute() 或 Isolate 避免阻塞 UI 线程

### 5. stream_resolver.dart — 流地址解析

职责：整合详情页 + 播放页的解析流程。

```
resolveStream(dramaId, episode):
  1. GET /video/{dramaId}/ → parseEpisodes → 获取剧集列表
  2. 找到目标 episode.url → GET 播放页 HTML
  3. parsePlayUrl(html, episode.ep) → 得到 m3u8 URL
  4. 返回 m3u8 URL

快捷方法:
  resolveStreamFromUrl(playUrl, ep):
    直接 GET 播放页 → parsePlayUrl → 返回 m3u8
```

---

## 页面设计

### 1. home_page.dart — 主页面

```
┌──────────────────────────────┐
│  黄果短剧              [⚙]  │  ← AppBar
├──────────────────────────────┤
│  [首页][AI成人短剧][AI漫剧]… │  ← 水平滚动 TabBar
├──────────────────────────────┤
│  🔍 搜索短剧...              │  ← 搜索框
├──────────────────────────────┤
│  ┌──────┐ ┌──────┐ ┌──────┐ │
│  │ 封面 │ │ 封面 │ │ 封面 │ │  ← GridView 卡片列表
│  │ 标题 │ │ 标题 │ │ 标题 │ │
│  │ 备注 │ │ 备注 │ │ 备注 │ │
│  └──────┘ └──────┘ └──────┘ │
│  ┌──────┐ ┌──────┐          │
│  │ 封面 │ │ 封面 │  ...     │
│  └──────┘ └──────┘          │
├──────────────────────────────┤
│     ◀ 第 1 页 ▶             │  ← 分页器（底部）
└──────────────────────────────┘
```

状态:
- `_sourceConfig: SourceConfig?`     (加载状态)
- `_dramas: List<Drama>`             (当前列表)
- `_selectedTab: String`             (当前分类)
- `_currentPage: int`                (当前页码)
- `_isLoading: bool`                 (加载中)
- `_isLoadingSource: bool`           (源码加载中)
- `_errorMessage: String?`           (错误信息)

生命周期:
- initState → 自动 loadSource()
- loadSource 完成 → 自动 loadList()
- Tab 切换 → loadList()
- 翻页 → loadList()
- 搜索 → loadList()（搜索结果不分页，显示全部）
- 点击卡片 → Navigator.push(DetailPage)

### 2. detail_page.dart — 详情页

```
┌──────────────────────────────┐
│  ← 返回    少妇白洁          │  ← AppBar
├──────────────────────────────┤
│  ┌──────────┐               │
│  │          │  标题          │  ← 封面图 + 标题
│  │  封面图  │  更新至18集    │
│  │          │  8.8分         │
│  └──────────┘               │
├──────────────────────────────┤
│  剧集列表                    │
│  [第1集] [第2集] [第3集]     │  ← Wrap 剧集按钮
│  [第4集] [第5集] [第6集]     │
│  ...                         │
└──────────────────────────────┘
```

状态:
- `_drama: Drama`                    (传入)
- `_episodes: List<Episode>`         (剧集列表)
- `_isLoading: bool`
- `_errorMessage: String?`

行为:
- initState → loadEpisodes(drama.id)
- 点击剧集按钮 → Navigator.push(PlayerPage, episode)

### 3. player_page.dart — 播放页

```
┌──────────────────────────────┐
│  ← 返回    第3集             │  ← AppBar
├──────────────────────────────┤
│                              │
│       VideoPlayer            │  ← 全屏播放器
│                              │
│                              │
├──────────────────────────────┤
│  m3u8: https://...m3u8      │  ← 可复制的流地址
├──────────────────────────────┤
│  剧集切换:                    │
│  [第1集] [第2集] [▶第3集]    │  ← 快速切换剧集
│  [第4集] [第5集] ...         │
└──────────────────────────────┘
```

状态:
- `_episodes: List<Episode>`         (全部剧集)
- `_currentEp: Episode`              (当前剧集)
- `_streamUrl: String?`              (m3u8 地址)
- `_isLoading: bool`
- `_errorMessage: String?`
- `_playerController: VideoPlayerController?`

行为:
- initState → resolveStream(episode) → 初始化播放器
- 切换剧集 → dispose 旧 controller → resolveStream(newEp) → 新 controller
- dispose → controller.dispose()

### 4. manual_parse_page.dart — 手动解析

```
┌──────────────────────────────┐
│  ← 返回    手动解析          │
├──────────────────────────────┤
│  播放页 URL:                 │
│  [________________________]  │  ← 输入框
│  [抓取并解析]                │  ← 按钮
├──────────────────────────────┤
│  或粘贴 HTML 源码:           │
│  [________________________]  │  ← 多行输入框
│  [________________________]  │
│  集数: [1]                   │  ← 集数输入
│  [解析粘贴内容]              │  ← 按钮
├──────────────────────────────┤
│  解析结果:                   │
│  https://...m3u8             │  ← 可复制
│  [复制] [播放]               │
└──────────────────────────────┘
```

状态:
- `_playUrlController: TextEditingController`
- `_htmlController: TextEditingController`
- `_episodeController: TextEditingController`
- `_resultUrl: String?`
- `_isLoading: bool`

---

## 数据流

```
用户操作              UI                   Service              外部
───────              ──                   ───────              ────
打开 App     →  home_page.initState
                   ↓
              source_loader.loadSource()  ────GET────→  GitHub
                   ↓                          ←───JS────
              SourceConfig 解析完成
                   ↓
              huangguo_api.fetchHome()    ────GET────→  huangguoai.com
                   ↓                          ←──HTML───
              html_parser.parseCardList()
                   ↓
              List<Drama> → UI 渲染列表

点击卡片     →  Navigator → detail_page
              huangguo_api.fetchDetail()  ────GET────→  huangguoai.com
                   ↓                          ←──HTML───
              html_parser.parseEpisodes()
                   ↓
              List<Episode> → UI 渲染剧集

点击剧集     →  Navigator → player_page
              huangguo_api.fetchPlayPage() ────GET────→  huangguoai.com
                   ↓                           ←──HTML───
              html_parser.parsePlayUrl()
                   ↓
              m3u8 URL → VideoPlayerController

封面图加载   →  image_decryptor.decrypt()  ────GET────→  huangguoai.com
                   ↓                           ←──bytes──
              AES-128-CBC 解密
                   ↓
              Uint8List → Image.memory()
```

---

## 关键实现细节

### 1. 封面图解密 + 懒加载
```dart
// 方案：在 DramaCard widget 中，图片加载时走解密流程
// 使用 FutureBuilder + 内存缓存 Map<String, Uint8List>

class CachedImageDecryptor {
  final _cache = <String, Uint8List>{};
  final _decryptor = ImageDecryptor();

  Future<Uint8List?> load(String url) {
    if (_cache.containsKey(url)) return Future.value(_cache[url]);
    return _decryptor.decrypt(url).then((bytes) {
      _cache[url] = bytes;
      return bytes;
    });
  }
}
```

### 2. 分页
```dart
// 原站 URL 格式: /{category}/{page}/
// home 不分页，直接 GET /
// 排行榜: /ranks/hot/
// 其他: /ai-duanju/2/

String buildUrl(String tabId, int page) {
  if (tabId == 'home') return site;
  final base = '$site/${tabId.replaceFirst(RegExp(r'^/'), '')}';
  return page > 1 ? '$base/$page/' : '$base/';
}
```

### 3. 视频播放器生命周期
```dart
// 关键：进入页面初始化，离开页面释放
@override
void initState() {
  super.initState();
  _initPlayer();
}

Future<void> _initPlayer() async {
  final url = await streamResolver.resolveStream(...);
  _controller = VideoPlayerController.networkUrl(Uri.parse(url));
  await _controller.initialize();
  setState(() {});
}

@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

### 4. 错误处理
```dart
// 统一错误处理模式：每个 async 方法 try/catch，setState 设置 errorMessage
// UI 层根据 errorMessage 是否为空显示错误提示或重试按钮

Future<void> _loadList() async {
  setState(() { _isLoading = true; _errorMessage = null; });
  try {
    final html = await huangguoApi.fetchCategory(_selectedTab, _currentPage);
    final dramas = htmlParser.parseCardList(html, _selectedTab == 'home');
    setState(() { _dramas = dramas; });
  } catch (e) {
    setState(() { _errorMessage = '加载失败：$e'; });
  } finally {
    setState(() { _isLoading = false; });
  }
}
```

---

## 实现顺序

| 步骤 | 内容 | 预计工作量 |
|------|------|-----------|
| 1 | `flutter create` + pubspec.yaml 依赖配置 | 小 |
| 2 | 数据模型 models/ | 小 |
| 3 | source_loader.dart 扩展源码加载 + 解析 | 中 |
| 4 | huangguo_api.dart HTTP 层 | 中 |
| 5 | html_parser.dart HTML 刮削 | 大 |
| 6 | image_decryptor.dart 图片解密 | 中 |
| 7 | stream_resolver.dart 流解析 | 小 |
| 8 | home_page.dart 主页 + Tab + 列表 | 大 |
| 9 | drama_card.dart 卡片组件 | 小 |
| 10 | detail_page.dart 详情页 + 剧集 | 中 |
| 11 | player_page.dart 播放页 | 中 |
| 12 | manual_parse_page.dart 手动解析 | 小 |
| 13 | 联调测试 | 中 |

---

## 未决事项（需要后续确认）

1. **AES 密钥长度**：huangguo.js 注释中 key 是 16 位 hex（8 bytes），但 AES-128 需要 16 bytes。需要实测确认实际密钥。
2. **m3u8 跨域**：移动端 `video_player` 直接播放 m3u8 无 CORS 问题，但需确认流服务器是否允许。
3. **Web 端代理**：后续如需 Web 端，需要 Cloudflare Worker 或类似方案做反向代理。
4. **封面图缓存**：当前方案是内存缓存，退出 App 后丢失。后续可加磁盘缓存。
