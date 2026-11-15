package notemap

import std.collection.*

/**
 * 模型层：只放纯数据，不含任何 IO 与业务逻辑。
 */

/** 笔记元数据（正文不进模型，只存文件路径对应的 id）。 */
public class NoteMeta {
    public var id: String
    public var title: String
    public var folderId: String
    public var createdAt: String
    public var updatedAt: String
    public var tags: ArrayList<String>

    public init(id: String, title: String, folderId: String, createdAt: String, updatedAt: String) {
        this.id = id
        this.title = title
        this.folderId = folderId
        this.createdAt = createdAt
        this.updatedAt = updatedAt
        this.tags = ArrayList<String>()
    }
}

/** 文档树节点：文件夹。 */
public class FolderNode {
    public var id: String
    public var name: String
    public var parentId: String

    public init(id: String, name: String, parentId: String) {
        this.id = id
        this.name = name
        this.parentId = parentId
    }
}

/** 思维导图节点（已计算好布局坐标）。 */
public class MNode {
    public var id: String
    public var text: String
    public var parent: String
    public var depth: Int64
    public var x: Float64
    public var y: Float64

    public init(id: String, text: String, parent: String, depth: Int64, x: Float64, y: Float64) {
        this.id = id
        this.text = text
        this.parent = parent
        this.depth = depth
        this.x = x
        this.y = y
    }
}

/** 大纲条目：从 Markdown 里抽出的标题或列表项。 */
public class OutlineItem {
    public var level: Int64
    public var text: String
    public var isList: Bool

    public init(level: Int64, text: String, isList: Bool) {
        this.level = level
        this.text = text
        this.isList = isList
    }
}

/** 检索命中。 */
public class SearchHit {
    public var noteId: String
    public var title: String
    public var lineNo: Int64
    public var lineText: String

    public init(noteId: String, title: String, lineNo: Int64, lineText: String) {
        this.noteId = noteId
        this.title = title
        this.lineNo = lineNo
        this.lineText = lineText
    }
}

/** 快照条目。 */
public class SnapshotMeta {
    public var noteId: String
    public var stamp: String
    public var size: Int64

    public init(noteId: String, stamp: String, size: Int64) {
        this.noteId = noteId
        this.stamp = stamp
        this.size = size
    }
}
