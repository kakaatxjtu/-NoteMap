package notemap

import std.collection.*

/** 一条待检索的文档。 */
public class NoteDoc {
    public var id: String
    public var title: String
    public var content: String

    public init(id: String, title: String, content: String) {
        this.id = id
        this.title = title
        this.content = content
    }
}

/** 检索层：关键词匹配（倒排索引留到结题）。 */
public class SearchService {
    public init() {}

    public func search(q: String, docs: ArrayList<NoteDoc>): ArrayList<SearchHit> {
        let hits = ArrayList<SearchHit>()
        if (q.size == 0) {
            return hits
        }
        let needle = q.toAsciiLower()
        for (d in docs) {
            let lines = d.content.split("\n")
            var ln: Int64 = 1
            var found = false
            for (line in lines) {
                if (!found && line.toAsciiLower().contains(needle)) {
                    hits.add(SearchHit(d.id, d.title, ln, line))
                    found = true
                }
                ln += 1
            }
        }
        return hits
    }
}
