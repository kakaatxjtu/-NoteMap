package notemap

import std.collection.*

/**
 * 存储层：元数据持久化。
 * 中期用「单文件 + 原子写」实现，接口与表结构按 SQLite 设计，
 * 结题时用 SqliteMetaStore 替换本类即可，业务层不需改动。
 */
public class MetaStore {
    let file: String
    public var notes: ArrayList<NoteMeta>
    public var folders: ArrayList<FolderNode>

    public init(file: String) {
        this.file = file
        this.notes = ArrayList<NoteMeta>()
        this.folders = ArrayList<FolderNode>()
        load()
    }

    public func load(): Unit {
        let text = readText(this.file)
        if (text.size == 0) {
            return
        }
        for (line in text.split("\n")) {
            if (line.size == 0) {
                continue
            }
            let f = line.split("\t")
            if (f.size >= 4 && f[0] == "F") {
                this.folders.add(FolderNode(unesc(f[1]), unesc(f[2]), unesc(f[3])))
            } else if (f.size >= 6 && f[0] == "N") {
                let n = NoteMeta(unesc(f[1]), unesc(f[2]), unesc(f[3]), unesc(f[4]), unesc(f[5]))
                this.notes.add(n)
            } else if (f.size >= 3 && f[0] == "T") {
                let nid = unesc(f[1])
                for (n in this.notes) {
                    if (n.id == nid) {
                        n.tags.add(unesc(f[2]))
                        break
                    }
                }
            }
        }
    }

    public func save(): Unit {
        let sb = StringBuilder()
        for (f in this.folders) {
            sb.append("F\t" + esc(f.id) + "\t" + esc(f.name) + "\t" + esc(f.parentId) + "\n")
        }
        for (n in this.notes) {
            sb.append("N\t" + esc(n.id) + "\t" + esc(n.title) + "\t" + esc(n.folderId) + "\t" +
                esc(n.createdAt) + "\t" + esc(n.updatedAt) + "\n")
            for (t in n.tags) {
                sb.append("T\t" + esc(n.id) + "\t" + esc(t) + "\n")
            }
        }
        writeAtomic(this.file, sb.toString())
    }

    public func findNote(id: String): Option<NoteMeta> {
        for (n in this.notes) {
            if (n.id == id) {
                return Some(n)
            }
        }
        return None
    }

    public func findFolder(id: String): Option<FolderNode> {
        for (f in this.folders) {
            if (f.id == id) {
                return Some(f)
            }
        }
        return None
    }
}

public func esc(s: String): String {
    let sb = StringBuilder()
    for (r in s.toRuneArray()) {
        if (r == r'\\') {
            sb.append("\\\\")
        } else if (r == r'\t') {
            sb.append("\\t")
        } else if (r == r'\n') {
            sb.append("\\n")
        } else if (r == r'\r') {
            sb.append("")
        } else {
            sb.append(r.toString())
        }
    }
    return sb.toString()
}

public func unesc(s: String): String {
    let sb = StringBuilder()
    let runes = s.toRuneArray()
    var i = 0
    while (i < runes.size) {
        let c = runes[i]
        if (c == r'\\' && i + 1 < runes.size) {
            let nx = runes[i + 1]
            if (nx == r'\\') {
                sb.append("\\")
            } else if (nx == r't') {
                sb.append("\t")
            } else if (nx == r'n') {
                sb.append("\n")
            } else {
                sb.append(nx.toString())
            }
            i += 2
            continue
        }
        sb.append(c.toString())
        i += 1
    }
    return sb.toString()
}
