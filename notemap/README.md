# NoteMap · 本地 Markdown 知识库

基于**仓颉语言**（Cangjie 1.0.5）实现的本地优先 Markdown 笔记应用。
笔记正文以 `.md` 文件存放在本地，元数据由仓颉侧维护，界面通过本地 HTTP 服务在浏览器中呈现。

## 快速开始

```powershell
# 1. 编译（需要 CANGJIE_HOME 与 cjc 在 PATH 中）
./build.ps1

# 2. 运行
./build/notemap.exe
# 或双击 run.cmd
```

启动后浏览器打开 <http://127.0.0.1:8777> 。

## 目录结构（五层）

```
notemap/
├─ src/
│  ├─ main.cj              入口：初始化数据目录、启动服务
│  ├─ model/model.cj       模型层：NoteMeta / FolderNode / MNode / SearchHit …
│  ├─ util/text.cj         基础层：URL 编解码、JSON 转义、id 生成
│  ├─ util/store.cj        基础层：目录与文件、原子写
│  ├─ db/meta.cj           存储层：元数据持久化（按 SQLite 表结构设计）
│  ├─ service/parser.cj    业务层：Markdown 解析（块级 + 行内）
│  ├─ service/mindmap.cj   业务层：大纲提取 + 树形布局
│  ├─ service/search.cj    业务层：关键词检索
│  ├─ service/notes.cj     业务层：笔记 / 文件夹 / 标签 / 快照
│  └─ pages/http.cj        界面层：HTTP 服务与路由
├─ web/                    界面资源（HTML / CSS / JS）
├─ build.ps1               构建脚本
└─ run.cmd                 启动脚本
```

## 已实现（中期版本）

| 模块 | 状态 |
|---|---|
| 文档树（新建 / 重命名 / 删除 / 层级） | 完成 |
| 双栏编辑 + 实时预览（6 类语法） | 完成 |
| 自动保存 + 历史快照（保留最近 10 份，可回滚） | 完成 |
| 本地持久化（.md + 元数据，原子写） | 完成 |
| 标签（打标 / 筛选） | 完成 |
| 思维导图（结构转换 + 树形布局 + 渲染） | 基础版 |
| 全文检索（关键词 + 命中定位） | 基础版 |
| 主题 / 设置 | 未开始 |

## 数据目录

首次运行会在当前目录生成 `notemap-data/`：

```
notemap-data/
├─ notes/            正文，一篇一个 .md
├─ snapshots/<id>/   历史版本
└─ meta.tsv         元数据（笔记、文件夹、标签）
```

拷走整个目录即完成备份与迁移。

## 已知说明

- **cjpm 不能用**：本机 cjpm 在中文路径下会崩溃（`Invalid utf8 byte sequence`），因此用 `cjc` 直接编译，未使用 `cjpm.toml`；如果换到纯英文路径，可随时切回 cjpm。
- **界面用浏览器**：仓颉 SDK 1.0.5 不自带 GUI 库，界面层用本地 HTTP + 浏览器实现，保证界面质量与可演示性；业务与渲染逻辑全部在仓颉侧。
