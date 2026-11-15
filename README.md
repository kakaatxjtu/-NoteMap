# NoteMap · 基于仓颉语言的 Markdown 本地知识管理应用

《仓颉语言程序设计》课程项目。用仓颉（Cangjie 1.0.5）实现一款本地优先的 Markdown 笔记应用：
左侧文档树管理笔记，中间写 Markdown，右侧实时预览；正文以 `.md` 存在本地，元数据独立保存；
在此之上提供标签、历史快照、全文检索，以及由笔记标题层级直接生成的思维导图。

## 目录说明

| 路径 | 内容 |
|---|---|
| `notemap/` | 项目源码（仓颉 + 前端资源）、构建脚本、README |
| `notemap/src/` | 按五层组织：`pages / service / model / db / util` |
| `notemap/web/` | 界面资源（HTML / CSS / JS） |
| `NoteMap_开题报告.pptx` / `NoteMap_开题报告_马钰帛.docx` | 开题报告与汇报 PPT |
| `NoteMap_中期检查.pptx` / `NoteMap_中期报告_马钰帛.docx` | 中期检查 PPT 与报告 |
| `截图_编辑.png` / `截图_导图.png` | 运行截图（报告中引用） |

## 运行

```powershell
cd notemap
./build.ps1                  # 编译（需要 CANGJIE_HOME，cjc 在 PATH 中）
./build/notemap.exe          # 默认只监听 127.0.0.1，浏览器打开 http://127.0.0.1:8777
./build/notemap.exe --lan    # 局域网模式，同一 Wi-Fi 的设备也能访问
```

详细说明见 [notemap/README.md](notemap/README.md)。

## 当前进度（中期）

八个模块：文档树、双栏编辑与实时预览、自动保存、历史快照、本地持久化、标签管理六项完成；
思维导图与全文检索为基础版；主题与设置未开始。按功能权重加权完成度约 72%。

## 开发环境

- 仓颉 SDK 1.0.5（cjnative），Windows 10/11
- 构建：`cjc` 直接编译（`cjpm` 在中文路径下有编码缺陷，见项目 README）
- 界面：本地 HTTP 服务 + 浏览器，样式自绘

## 说明

本项目为课程作业，代码与文档均为原创；引用的第三方资料见报告参考文献。
