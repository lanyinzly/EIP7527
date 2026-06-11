# ERC-7527 × WrapX 全景解读站

一个零构建依赖的双语静态网站,用于展示 ERC-7527(函数预言机 AMM)体系四个仓库
(EIP7527 / wrap-auction / wrap-interface / wrapx_app)的架构解读。

- 英文版(默认):`index.html` → 部署后为 `/`
- 中文版:`zh.html` → 部署后为 `/zh`(Vercel cleanUrls)
- 导航右上角一键切换语言;图表轴标签、模拟器文案随语言切换(`window.I18N` + 共享 `app.js`)

## 内容结构

- **TL;DR** — FOAMM 核心思想三要点
- **四个仓库** — 各仓库定位与关键事实
- **架构关系** — 4 张 Mermaid 图(总体关系 / 链上架构 / 交易时序 / 标准依赖)
- **核心机制** — 线性曲线与拍卖曲线图表(Chart.js)+ 可交互的 LIFO 价格栈模拟器
- **亮点 / 风险 / 生态关联 / 未来应用**

## 本地预览

无需安装任何依赖:

```bash
cd wrap-site
python3 -m http.server 8000
# 打开 http://localhost:8000
```

(直接双击 index.html 也可以,但部分浏览器对 ESM CDN 有 file:// 限制,建议起本地服务。)

## 部署到 Vercel

三种方式任选:

1. **拖拽**:打开 vercel.com/new,把 `wrap-site` 文件夹拖进去即可;
2. **CLI**:`npm i -g vercel && cd wrap-site && vercel --prod`;
3. **Git**:把本目录推到任意仓库,在 Vercel 导入,Framework 选 "Other",无需构建命令,输出目录留空。

也可部署到 GitHub Pages / Cloudflare Pages / Netlify,均为纯静态托管。

## 技术说明

- `index.html`(EN)+ `zh.html`(中文)+ 共享 `styles.css` / `app.js`,编辑部(editorial)风格视觉体系,参考 New Form Capital 设计语言:
  - 配色:米白纸感 `#FAFFFA` + 墨黑 `#121613` + 荧光绿 `#2BEE4B`,米白/纯黑分区交替
  - 字体:Instrument Serif + Noto Serif SC(衬线大标题)、Noto Sans SC(正文)、Space Mono(编号/标签)
  - 版式:细线分隔、编号小节、跑马灯文字条、引言区块、直角无圆角卡片
- Mermaid 10(CDN, ESM)渲染架构图(深色分区内);Chart.js 4(CDN)渲染定价曲线
- LIFO 模拟器为原生 JS,无框架依赖
- 中英双语,响应式布局
