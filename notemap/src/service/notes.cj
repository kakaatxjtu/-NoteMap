package notemap

import std.collection.*
import std.fs.*

/**
 * 业务层：笔记 / 文件夹 / 标签 / 快照 / 检索 / 导图的统一入口。
 * 正文永远落 .md 文件，元数据落 MetaStore，两者分离。
 */
public class NotesService {
    let root: String
    let notesDir: String
    let snapDir: String
    let store: MetaStore
    var seq: Int64 = 0

    public init(root: String) {
        this.root = root
        this.notesDir = root + "/notes"
        this.snapDir = root + "/snapshots"
        ensureDir(this.notesDir)
        ensureDir(this.snapDir)
        this.store = MetaStore(root + "/meta.tsv")
        if (this.store.notes.size == 0) {
            seed()
        }
    }

    /** 首次启动时放两篇示例，方便直接演示。 */
    func seed(): Unit {
        let f = createFolder("", "演示")
        let a = createNote(f.id, "欢迎使用 NoteMap")
        saveContent(a.id, "# 欢迎使用 NoteMap\n\n这是一个**本地优先**的 Markdown 笔记应用。\n\n## 能做什么\n\n- 左侧文档树管理文件夹与笔记\n- 中间写 Markdown，右侧实时预览\n- 给笔记打标签，按标签筛选\n\n## 支持的语法\n\n- 标题、**加粗**、*斜体*\n- 无序列表、有序列表\n1. 第一项\n2. 第二项\n\n> 引用：数据就是磁盘上的 .md 文件。\n\n```\nlet note = \"hello\"\n```\n\n### 下一步\n\n用「导图」把这篇笔记变成结构图。\n")
        toggleTag(a.id, "入门")
        let b = createNote(f.id, "Markdown 语法速查")
        saveContent(b.id, "# 语法速查\n\n## 标题\n\n用 # 的数量表示层级。\n\n## 列表\n\n- 减号是无序\n- 星号也可以\n\n## 代码\n\n```\nprintln(\"hello\")\n```\n")
        toggleTag(b.id, "参考")
    }

    // ---------- 笔记 ----------
    public func listNotes(): ArrayList<NoteMeta> {
        let list = ArrayList<NoteMeta>()
        for (n in this.store.notes) {
            list.add(n)
        }
        // 按更新时间倒序（简单插入排序，数据量小）
        var i: Int64 = 1
        while (i < list.size) {
            var j = i
            while (j > 0 && list[j - 1].updatedAt < list[j].updatedAt) {
                let tmp = list[j - 1]
                list[j - 1] = list[j]
                list[j] = tmp
                j -= 1
            }
            i += 1
        }
        return list
    }

    public func listFolders(): ArrayList<FolderNode> {
        return this.store.folders
    }

    public func findNote(id: String): Option<NoteMeta> {
        return this.store.findNote(id)
    }

    public func createNote(folderId: String, title: String): NoteMeta {
        this.seq += 1
        let id = "n" + digitsOnly(nowStamp()) + this.seq.toString()
        var t = title
        if (t.size == 0) {
            t = "未命名笔记"
        }
        let stamp = nowStamp()
        let n = NoteMeta(id, t, folderId, stamp, stamp)
        this.store.notes.add(n)
        writeAtomic(this.notesDir + "/" + id + ".md", "# " + t + "\n")
        this.store.save()
        return n
    }

    public func renameNote(id: String, title: String): Unit {
        match (this.store.findNote(id)) {
            case Some(n) =>
                n.title = title
                n.updatedAt = nowStamp()
                this.store.save()
            case None => ()
        }
    }

    public func deleteNote(id: String): Unit {
        var i: Int64 = 0
        while (i < this.store.notes.size) {
            if (this.store.notes[i].id == id) {
                this.store.notes.remove(at: i)
                break
            }
            i += 1
        }
        removeIfExists(this.notesDir + "/" + id + ".md")
        this.store.save()
    }

    public func readContent(id: String): String {
        return readText(this.notesDir + "/" + id + ".md")
    }

    /** 保存正文：写 md + 必要时留快照 + 更新元数据。 */
    public func saveContent(id: String, content: String): Unit {
        let old = readContent(id)
        if (old == content) {
            return
        }
        if (old.size > 0) {
            snapshot(id, old)
        }
        writeAtomic(this.notesDir + "/" + id + ".md", content)
        match (this.store.findNote(id)) {
            case Some(n) =>
                n.updatedAt = nowStamp()
                this.store.save()
            case None => ()
        }
    }

    // ---------- 文件夹 ----------
    public func createFolder(parentId: String, name: String): FolderNode {
        this.seq += 1
        let id = "f" + this.seq.toString()
        var nm = name
        if (nm.size == 0) {
            nm = "新建文件夹"
        }
        let f = FolderNode(id, nm, parentId)
        this.store.folders.add(f)
        this.store.save()
        return f
    }

    public func renameFolder(id: String, name: String): Unit {
        match (this.store.findFolder(id)) {
            case Some(f) =>
                f.name = name
                this.store.save()
            case None => ()
        }
    }

    public func deleteFolder(id: String): Unit {
        var i: Int64 = 0
        while (i < this.store.folders.size) {
            if (this.store.folders[i].id == id) {
                this.store.folders.remove(at: i)
                break
            }
            i += 1
        }
        // 该文件夹下的笔记移到根目录
        for (n in this.store.notes) {
            if (n.folderId == id) {
                n.folderId = ""
            }
        }
        this.store.save()
    }

    // ---------- 标签 ----------
    public func toggleTag(id: String, tag: String): Unit {
        if (tag.size == 0) {
            return
        }
        match (this.store.findNote(id)) {
            case Some(n) =>
                var removed = false
                var i: Int64 = 0
                while (i < n.tags.size) {
                    if (n.tags[i] == tag) {
                        n.tags.remove(at: i)
                        removed = true
                        break
                    }
                    i += 1
                }
                if (!removed) {
                    n.tags.add(tag)
                }
                this.store.save()
            case None => ()
        }
    }

    public func allTags(): ArrayList<String> {
        let tags = ArrayList<String>()
        for (n in this.store.notes) {
            for (t in n.tags) {
                if (!tags.contains(t)) {
                    tags.add(t)
                }
            }
        }
        return tags
    }

    // ---------- 快照 ----------
    func snapshot(id: String, content: String): Unit {
        let dir = this.snapDir + "/" + id
        ensureDir(dir)
        let stamp = safeName(nowStamp())
        writeText(dir + "/" + stamp + ".md", content)
        // 只保留最近 10 份
        let names = listDir(dir)
        if (names.size > 10) {
            let sorted = ArrayList<String>()
            for (nm in names) {
                sorted.add(nm)
            }
            var i: Int64 = 1
            while (i < sorted.size) {
                var j = i
                while (j > 0 && sorted[j - 1] > sorted[j]) {
                    let t = sorted[j - 1]
                    sorted[j - 1] = sorted[j]
                    sorted[j] = t
                    j -= 1
                }
                i += 1
            }
            for (k in 0..(sorted.size - 10)) {
                removeIfExists(dir + "/" + sorted[k])
            }
        }
    }

    public func listSnapshots(id: String): ArrayList<SnapshotMeta> {
        let out = ArrayList<SnapshotMeta>()
        let dir = this.snapDir + "/" + id
        for (nm in listDir(dir)) {
            let p = dir + "/" + nm
            var size: Int64 = 0
            if (exists(p)) {
                size = File.readFrom(p).size
            }
            out.add(SnapshotMeta(id, nm.replace(".md", ""), size))
        }
        return out
    }

    public func restoreSnapshot(id: String, stamp: String): String {
        let p = this.snapDir + "/" + id + "/" + stamp + ".md"
        let content = readText(p)
        if (content.size > 0) {
            saveContent(id, content)
        }
        return content
    }

    // ---------- 检索 / 导图 ----------
    public func search(q: String): ArrayList<SearchHit> {
        let docs = ArrayList<NoteDoc>()
        for (n in this.store.notes) {
            docs.add(NoteDoc(n.id, n.title, readContent(n.id)))
        }
        return SearchService().search(q, docs)
    }

    public func mindmap(id: String): ArrayList<MNode> {
        return MindMapBuilder().build(readContent(id))
    }

    public func preview(content: String): String {
        return MdParser().toHtml(content)
    }
}
