# Pillxai Dispenser 品牌素材

产品名称为 **Pillxai Dispenser**。应用图标采用摆药机正面轮廓。文字标志保留用户原稿字形，收紧 SVG 空白画布。

品牌名为 **Pillxai**，2026-10-19 按用户要求恢复。当前 Flutter 界面、加载页、应用标题及安装后的显示名称统一使用 Pillxai。素材路径、包名、内部类名及演示登录凭据沿用现有技术标识。当前客户端采用简约图标与文字字标；本目录中的原始素材保留为参考。

| 文件 | 用户原文件 | 用途 |
| --- | --- | --- |
| [pillxa-mark-rounded.png](pillxa-mark-rounded.png) | 已重绘 PNG 的圆角导出 | 历史品牌素材 |
| [pillxa-mark.png](pillxa-mark.png) | 基于原标志 PNG 视觉参考重新绘制 | 保留的不透明原稿 |
| [pillxa-app-icon.svg](pillxa-app-icon.svg) | 内嵌已批准的 PNG 和圆角裁切 | 历史图标导出源 |
| [pillxa-wordmark.svg](pillxa-wordmark.svg) | 图片3.svg | 横排文字标志，收紧空白画布后用于主导航与登录页 |
| [pillxa-mark.svg](pillxa-mark.svg) | 图片2.svg | 仅保留用户原稿，应用不再使用 |

当前 Windows、Android 和网页启动图标直接从 Flutter 的 DispenserIcon 导出，使用黑色线稿和白色底板。在 apps/client 下运行 flutter test tool/export_app_icons.dart 即可重新生成各尺寸 PNG 和多尺寸 Windows ICO。

## 原稿重绘提示词（历史记录）

使用内置 imagegen，参考图为原应用的 128×128 PNG；没有复用原方形 SVG。最终采用 1254×1254 PNG。

> Use case: identity-preserve brand logo redraw. Asset: square Windows application icon and main brand mark for Pillxai Dispenser. Redraw the supplied PNG reference from scratch as a pristine high-resolution 1024x1024 raster logo; do not reuse or trace the existing SVG file. Preserve its recognizable lowercase typography and arrangement: 'pill' on the top line and 'xa' on the bottom line, compact rounded geometric letterforms, dark charcoal gray #595A5A. Two lines form a balanced almost-square block, centered with about 10% safe margins. Reference is only the identity and composition guide. Correct all rough edges and render crisp, consistent line weights and smooth rounded shapes. Entire square canvas must be solid pure white, including the counters inside p and a and the spaces between letters. Absolutely no transparency anywhere, no checkerboard, no outline of the reference image boundary, no gradient, no shadow, no 3D, no decorative motifs, no extra words. It must look correct on both dark and light desktop backgrounds.
