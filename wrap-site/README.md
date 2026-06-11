# ERC-7527 × WrapX 全景解读站

一个零构建依赖的单页静态网站,用于展示 ERC-7527(函数预言机 AMM)体系四个仓库
(EIP7527 / wrap-auction / wrap-interface / wrapx_app)的架构解读。

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

- 单文件 `index.html`,自定义 CSS(暗色 + WrapX 品牌紫 #926CFF)
- Mermaid 10(CDN, ESM)渲染架构图;Chart.js 4(CDN)渲染定价曲线
- LIFO 模拟器为原生 JS,无框架依赖
- 中文内容,响应式布局
