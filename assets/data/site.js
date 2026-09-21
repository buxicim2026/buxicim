/**
 * 不息传播官网 —— 唯一内容配置源
 *
 * 维护说明：
 *   1. 站内所有品牌文案、链接、数据都从这里读取，改这里即可全站生效。
 *   2. 标注 TODO 的字段表示「尚未核实」，请先补齐再对外发布，不要直接编造。
 *   3. 已核实字段来源：B站个人空间 https://space.bilibili.com/385015308
 *      （UID 385015308，简介原文、粉丝数 1189、关注数 49 均为实测）
 */

export const site = {
  name: '不息传播',
  shortName: '不息',
  enName: 'BUXI',
  // B站 简介原文，不做改写
  slogan: '追梦不停，创造无限',
  intro:
    '我们是专注于科技生活内容的自媒体，偶尔会直播有趣的发布会。欢迎在ac，wx关注我们',
  avatar: 'https://i0.hdslb.com/bfs/face/091a0d0dfdd5bd044cb084d85906851cbb13a60b.jpg',
  // TODO: 上线后替换为真实站点地址（GitHub Pages 或自定义域）
  url: 'https://buxicim2026.github.io/buxicim',
  email: '', // TODO: 商务合作邮箱

  nav: [
    { text: '首页', href: 'index.html' },
    { text: '关于我们', href: 'about.html' },
    { text: '内容与直播', href: 'content.html' },
    { text: '字幕插件', href: 'plugin.html' },
    { text: '联系合作', href: 'contact.html' },
  ],
};

/** 平台矩阵：B站 已核实，AcFun / 微信待补链接 */
export const platforms = [
  {
    key: 'bilibili',
    name: '哔哩哔哩',
    handle: 'UID 385015308',
    desc: '主阵地。科技生活内容、发布会直播与插件演示视频都在这里更新。',
    url: 'https://space.bilibili.com/385015308',
    cta: '去 B 站关注',
  },
  {
    key: 'acfun',
    name: 'AcFun',
    handle: 'ac',
    desc: '同步分发部分内容，欢迎在 ac 关注我们。',
    url: '', // TODO: 补充 AcFun 主页链接
    cta: '前往 AcFun',
  },
  {
    key: 'wechat',
    name: '微信公众号',
    handle: 'wx',
    desc: '图文与开播提醒，公众号搜索「不息传播」关注。',
    url: '', // TODO: 补充公众号主页链接或二维码图片
    cta: '微信关注',
  },
];

/** 账号数据：仅列可核实项，其余留 TODO */
export const stats = [
  { value: 1189, suffix: '', label: 'B 站粉丝', source: 'B站 公开数据' },
  { value: 3, suffix: '', label: '内容平台', source: 'B站 / AcFun / 微信' },
  { value: 1, suffix: '', label: '自研开源工具', source: 'OBS 实时字幕插件' },
];

/** 内容方向 */
export const topics = [
  {
    icon: 'sparkle',
    title: '科技生活',
    desc: '把新技术放回真实生活场景里讲清楚：好用什么、坑在哪、值不值得买。',
  },
  {
    icon: 'live',
    title: '发布会直播',
    desc: '有意思的发布会我们都会播，边看边聊，和弹幕一起等那个「One more thing」。',
  },
  {
    icon: 'code',
    title: '效率工具',
    desc: '自己用得顺手才推荐，不顺手就自己写一个 —— 字幕插件就是这么来的。',
  },
  {
    icon: 'share',
    title: '内容分发',
    desc: 'B站 主阵地，AcFun 与微信公众号同步更新，哪里方便你就在哪里看。',
  },
];

/** 发展历程：仅列可核实节点，其余 TODO */
export const timeline = [
  {
    year: '至今',
    title: '科技生活内容持续更新',
    desc: '专注科技生活选题，同时不定期直播有趣的发布会。',
  },
  {
    year: '近期',
    title: '自研 OBS 实时 AI 字幕插件',
    desc: '为了直播海外发布会时能有实时中文字幕，做了 Stream Live Translate，已开源。',
  },
  // TODO: 补充成立/首支视频/首个里程碑等真实节点
];

/** 内容栏目 */
export const channels = [
  { title: '科技生活', desc: '产品体验、使用技巧与生活化的科技选题。', tag: '视频' },
  { title: '发布会直播', desc: '有意思的发布会直播，实时解说与讨论。', tag: '直播' },
  { title: '工具与插件', desc: '自研工具的功能演示、上手教程与更新记录。', tag: '教程' },
];

/**
 * 视频列表：BV 号待补。
 * 补齐方式：把 B站 视频链接里的 BV 号填到 bvid 字段即可，
 * 例如 https://www.bilibili.com/video/BV1xx411c7mD → bvid: 'BV1xx411c7mD'
 */
export const videos = [
  // TODO: 补充真实视频，示例：
  // { bvid: 'BV1xx411c7mD', title: '视频标题', desc: '一句话简介', tag: '科技生活' },
];

/** 下一场直播：待补 */
export const nextLive = {
  title: '', // TODO: 如「XX 秋季发布会」
  time: '', // TODO: 如「2026-09-30 20:00」
  note: '开播信息会在 B站 动态与微信公众号提前通知。',
};

/** 插件：Stream Live Translate */
export const plugin = {
  name: 'Stream Live Translate',
  tagline: '给直播画面加上实时中文字幕的 OBS 插件',
  desc:
    '从 OBS 媒体源内部取音频，交给大模型流式翻译，再把字幕叠加回画面。海外发布会直播时，外语内容实时变成中文字幕。',
  platforms: ['Windows 10/11 x64', 'macOS 13+ (Apple Silicon)', 'Linux x64 (Debian 11+ / Ubuntu 20.04+)'],
  // TODO: 替换为真实 Releases 地址
  downloadUrl: 'https://github.com/USERNAME/stream-live-translate/releases',
  repoUrl: 'https://github.com/USERNAME/stream-live-translate',
  features: [
    { icon: 'box', title: '复制即用', desc: '插件文件夹复制进 OBS 插件目录，无需安装器；OBS 启动自动拉起引擎。' },
    { icon: 'audio', title: 'OBS 内部取音频', desc: '音频滤镜直接捕获媒体源声音，不受系统其它声音干扰。' },
    { icon: 'device', title: '跨平台', desc: 'Windows / macOS (Apple Silicon) / Linux 三平台都有发布包。' },
    { icon: 'panel', title: '侧边栏控制台', desc: 'OBS 自带停靠部件打开管理面板，填 Key、调样式不用切出 OBS。' },
    { icon: 'bolt', title: '流式翻译', desc: 'WebSocket 流式接口，中文直通不翻译，其它语种自动同传为中文。' },
    { icon: 'wave', title: 'VAD + 音乐检测', desc: '静音与音乐片段自动跳过，省 token 也不污染字幕。' },
  ],
  steps: [
    { title: '安装插件', desc: '把插件文件夹复制进 OBS 插件目录，重启 OBS。' },
    { title: '挂音频滤镜', desc: '右键要出字幕的源 → 滤镜 → 添加「实时字幕捕获」。' },
    { title: '填 API Key', desc: 'OBS 视图 → 停靠部件 → 自定义浏览器停靠部件，打开管理面板填 Key 保存。' },
    { title: '加字幕源', desc: '场景添加浏览器源，URL 填字幕叠加地址，建议 1920×240。' },
  ],
  models: {
    ok: [
      { name: '通义 Qwen Realtime 语音', note: '同传 / ASR / Qwen-Audio，云端开箱即用' },
      { name: '智谱 GLM-Realtime', note: 'OpenAI Realtime 兼容' },
      { name: 'OpenAI Realtime', note: '官方实时接口' },
      { name: 'FunASR 流式识别', note: '本地自部署，中文 / 粤语强，默认端口 10095' },
      { name: 'speech-to-speech 网关', note: '本地部署，可换 Whisper / Parakeet / SenseVoice 后端' },
    ],
    no: [
      { name: '纯文本 / 纯视觉模型', note: '无法接收实时音频' },
      { name: '纯语音合成（TTS）', note: '只出不进，不产生字幕' },
      { name: 'HTTP 上传式 ASR', note: '非实时，接上也不会有字幕' },
    ],
  },
  requirements: [
    { platform: 'Windows', version: 'Windows 10 1809+', dep: '无额外依赖' },
    { platform: 'macOS', version: 'macOS 13 (Ventura)', dep: '仅 Apple Silicon（M1–M4）' },
    { platform: 'Linux x64', version: 'Ubuntu 20.04 LTS / Debian 11（glibc 2.31+）', dep: 'libasound2 (alsa)，推荐 ffmpeg' },
  ],
  faq: [
    {
      q: '必须要用 OBS 吗？',
      a: '插件模式面向 OBS，把插件文件夹复制进插件目录即可。引擎也支持脱离 OBS 单独运行（系统音频环回模式），详见项目文档。',
    },
    {
      q: '中文内容会不会被翻译？',
      a: '不会。检测到中文会直接输出原文，只有其它语种才走同传翻译。',
    },
    {
      q: '延迟大概多少？',
      a: '用 ASR 模型（云端 qwen3-asr-flash-realtime 或本地 FunASR）有流式 partial，延迟可到约 1 秒；同传翻译模型按整句返回，可开启低延迟模式按段推进。',
    },
    {
      q: 'API Key 安全吗？',
      a: '配置只保存在本地 config.toml，不联网回传。便携模式下 config.toml 与可执行文件同目录，迁移时整个文件夹拷走即可。',
    },
    {
      q: '可以完全本地跑吗？',
      a: '可以。用 FunASR 流式识别或套一个 OpenAI-Realtime 兼容网关（如 speech-to-speech），插件选「本机部署 API」连上即可，换模型只改网关里的 STT 后端。',
    },
    {
      q: '放音乐或没人说话时会出字幕吗？',
      a: '不会。VAD 与音乐检测会跳过静音和音乐片段。',
    },
  ],
};
