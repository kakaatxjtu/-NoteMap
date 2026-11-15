package notemap

import std.net.*
import std.collection.*
import std.fs.*
import std.convert.*

/**
 * 界面层：本地 HTTP 服务。
 * 只做三件事：解析请求、调用业务层、把结果序列化返回。
 */
public class HttpServer {
    let port: UInt16
    let svc: NotesService
    let webDir: String
    let host: String

    public init(port: UInt16, svc: NotesService, webDir: String, host: String) {
        this.port = port
        this.svc = svc
        this.webDir = webDir
        this.host = host
    }

    public func start(): Unit {
        let server = TcpServerSocket(bindAt: IPSocketAddress(this.host, this.port))
        server.bind()
        println("NoteMap 已启动：http://127.0.0.1:" + this.port.toString())
        println("数据目录：" + this.svc.root)
        while (true) {
            let conn = server.accept()
            try {
                handle(conn)
            } catch (e: Exception) {
                println("请求处理异常: " + e.message)
            }
            conn.close()
        }
    }

    func handle(conn: TcpSocket): Unit {
        let buf = ArrayList<Byte>()
        let chunk = Array<Byte>(8192, repeat: 0)
        var headerEnd: Int64 = -1
        while (headerEnd < 0) {
            let n = conn.read(chunk)
            if (n <= 0) {
                return
            }
            for (i in 0..n) {
                buf.add(chunk[i])
            }
            headerEnd = findHeaderEnd(buf)
            if (buf.size > 1048576) {
                return
            }
        }

        let headBytes = Array<Byte>(headerEnd, repeat: 0)
        for (i in 0..headerEnd) {
            headBytes[i] = buf[i]
        }
        let head = String.fromUtf8(headBytes)
        let lines = head.split("\r\n")
        if (lines.size == 0) {
            return
        }
        let reqLine = lines[0].split(" ")
        if (reqLine.size < 2) {
            return
        }
        let method = reqLine[0]
        let target = reqLine[1]

        var contentLength: Int64 = 0
        for (i in 1..lines.size) {
            let ln = lines[i]
            if (startsWithLower(ln, "content-length:")) {
                var colonPos: Int64 = 0
                match (ln.indexOf(":")) {
                    case Some(p) => colonPos = p
                    case None => ()
                }
                let v = ln[(colonPos + 1)..].trimAscii()
                match (Int64.tryParse(v)) {
                    case Some(x) => contentLength = x
                    case None => ()
                }
            }
        }

        // 已缓冲的 body 字节
        let bodyBuf = ArrayList<Byte>()
        var start = headerEnd + 4
        while (start < buf.size) {
            bodyBuf.add(buf[start])
            start += 1
        }
        while (bodyBuf.size < contentLength) {
            let n = conn.read(chunk)
            if (n <= 0) {
                break
            }
            for (i in 0..n) {
                bodyBuf.add(chunk[i])
            }
        }
        let body = String.fromUtf8(bodyBuf.toArray())

        // 拆 path 与 query
        var path = target
        var query = ""
        let qpos = target.indexOf("?")
        match (qpos) {
            case Some(p) =>
                path = target[..p]
                query = target[(p + 1)..]
            case None => ()
        }
        let pathDecoded = urlDecode(path)

        let resp = route(method, pathDecoded, query, body)
        send(conn, resp)
    }

    func route(method: String, path: String, query: String, body: String): HttpResp {
        if (method == "GET") {
            if (path == "/" || path == "/index.html") {
                return fileResp(this.webDir + "/index.html", "text/html; charset=utf-8")
            }
            if (path == "/app.css") {
                return fileResp(this.webDir + "/app.css", "text/css; charset=utf-8")
            }
            if (path == "/app.js") {
                return fileResp(this.webDir + "/app.js", "application/javascript; charset=utf-8")
            }
            if (path == "/api/tree") {
                return HttpResp(200, "application/json; charset=utf-8", treeJson())
            }
            if (path == "/api/note") {
                return HttpResp(200, "application/json; charset=utf-8", noteJson(formGet(query, "id")))
            }
            if (path == "/api/search") {
                return HttpResp(200, "application/json; charset=utf-8", searchJson(formGet(query, "q")))
            }
            if (path == "/api/mindmap") {
                return HttpResp(200, "application/json; charset=utf-8", mindmapJson(formGet(query, "id")))
            }
            if (path == "/api/snapshots") {
                return HttpResp(200, "application/json; charset=utf-8", snapshotsJson(formGet(query, "id")))
            }
            if (path == "/api/tags") {
                return HttpResp(200, "application/json; charset=utf-8", tagsJson())
            }
        }
        if (method == "POST") {
            if (path == "/api/save") {
                this.svc.saveContent(formGet(body, "id"), formGet(body, "content"))
                return HttpResp(200, "application/json; charset=utf-8", "{\"ok\":true}")
            }
            if (path == "/api/preview") {
                let html = this.svc.preview(formGet(body, "content"))
                return HttpResp(200, "application/json; charset=utf-8", "{\"html\":" + jsonStr(html) + "}")
            }
            if (path == "/api/note/new") {
                let n = this.svc.createNote(formGet(body, "folder"), formGet(body, "title"))
                return HttpResp(200, "application/json; charset=utf-8",
                    "{\"id\":" + jsonStr(n.id) + ",\"title\":" + jsonStr(n.title) + "}")
            }
            if (path == "/api/note/rename") {
                this.svc.renameNote(formGet(body, "id"), formGet(body, "title"))
                return HttpResp(200, "application/json; charset=utf-8", "{\"ok\":true}")
            }
            if (path == "/api/note/delete") {
                this.svc.deleteNote(formGet(body, "id"))
                return HttpResp(200, "application/json; charset=utf-8", "{\"ok\":true}")
            }
            if (path == "/api/folder/new") {
                let f = this.svc.createFolder(formGet(body, "parent"), formGet(body, "name"))
                return HttpResp(200, "application/json; charset=utf-8",
                    "{\"id\":" + jsonStr(f.id) + ",\"name\":" + jsonStr(f.name) + "}")
            }
            if (path == "/api/folder/rename") {
                this.svc.renameFolder(formGet(body, "id"), formGet(body, "name"))
                return HttpResp(200, "application/json; charset=utf-8", "{\"ok\":true}")
            }
            if (path == "/api/folder/del") {
                this.svc.deleteFolder(formGet(body, "id"))
                return HttpResp(200, "application/json; charset=utf-8", "{\"ok\":true}")
            }
            if (path == "/api/tag") {
                this.svc.toggleTag(formGet(body, "id"), formGet(body, "tag"))
                return HttpResp(200, "application/json; charset=utf-8", "{\"ok\":true}")
            }
            if (path == "/api/restore") {
                let c = this.svc.restoreSnapshot(formGet(body, "id"), formGet(body, "stamp"))
                return HttpResp(200, "application/json; charset=utf-8", "{\"content\":" + jsonStr(c) + "}")
            }
        }
        return HttpResp(404, "text/plain; charset=utf-8", "not found")
    }

    // ---------- JSON ----------
    func treeJson(): String {
        let sb = StringBuilder()
        sb.append("{\"folders\":[")
        let folders = this.svc.listFolders()
        for (i in 0..folders.size) {
            if (i > 0) {
                sb.append(",")
            }
            let f = folders[i]
            sb.append("{\"id\":" + jsonStr(f.id) + ",\"name\":" + jsonStr(f.name) +
                ",\"parent\":" + jsonStr(f.parentId) + "}")
        }
        sb.append("],\"notes\":[")
        let notes = this.svc.listNotes()
        for (i in 0..notes.size) {
            if (i > 0) {
                sb.append(",")
            }
            let n = notes[i]
            sb.append("{\"id\":" + jsonStr(n.id) + ",\"title\":" + jsonStr(n.title) +
                ",\"folder\":" + jsonStr(n.folderId) + ",\"updated\":" + jsonStr(n.updatedAt) +
                ",\"tags\":[")
            for (j in 0..n.tags.size) {
                if (j > 0) {
                    sb.append(",")
                }
                sb.append(jsonStr(n.tags[j]))
            }
            sb.append("]}")
        }
        sb.append("]}")
        return sb.toString()
    }

    func noteJson(id: String): String {
        match (this.svc.findNote(id)) {
            case Some(n) =>
                let c = this.svc.readContent(id)
                let sb = StringBuilder()
                sb.append("{\"id\":" + jsonStr(n.id) + ",\"title\":" + jsonStr(n.title) +
                    ",\"folder\":" + jsonStr(n.folderId) + ",\"updated\":" + jsonStr(n.updatedAt) +
                    ",\"content\":" + jsonStr(c) + ",\"tags\":[")
                for (j in 0..n.tags.size) {
                    if (j > 0) {
                        sb.append(",")
                    }
                    sb.append(jsonStr(n.tags[j]))
                }
                sb.append("]}")
                return sb.toString()
            case None => return "{\"error\":\"not found\"}"
        }
    }

    func searchJson(q: String): String {
        let hits = this.svc.search(q)
        let sb = StringBuilder()
        sb.append("{\"hits\":[")
        for (i in 0..hits.size) {
            if (i > 0) {
                sb.append(",")
            }
            let h = hits[i]
            sb.append("{\"id\":" + jsonStr(h.noteId) + ",\"title\":" + jsonStr(h.title) +
                ",\"line\":" + h.lineNo.toString() + ",\"text\":" + jsonStr(h.lineText) + "}")
        }
        sb.append("]}")
        return sb.toString()
    }

    func mindmapJson(id: String): String {
        let nodes = this.svc.mindmap(id)
        let sb = StringBuilder()
        sb.append("{\"nodes\":[")
        for (i in 0..nodes.size) {
            if (i > 0) {
                sb.append(",")
            }
            let m = nodes[i]
            sb.append("{\"id\":" + jsonStr(m.id) + ",\"text\":" + jsonStr(m.text) +
                ",\"parent\":" + jsonStr(m.parent) + ",\"depth\":" + m.depth.toString() +
                ",\"x\":" + m.x.toString() + ",\"y\":" + m.y.toString() + "}")
        }
        sb.append("]}")
        return sb.toString()
    }

    func snapshotsJson(id: String): String {
        let items = this.svc.listSnapshots(id)
        let sb = StringBuilder()
        sb.append("{\"items\":[")
        for (i in 0..items.size) {
            if (i > 0) {
                sb.append(",")
            }
            let s = items[i]
            sb.append("{\"stamp\":" + jsonStr(s.stamp) + ",\"size\":" + s.size.toString() + "}")
        }
        sb.append("]}")
        return sb.toString()
    }

    func tagsJson(): String {
        let tags = this.svc.allTags()
        let sb = StringBuilder()
        sb.append("{\"tags\":[")
        for (i in 0..tags.size) {
            if (i > 0) {
                sb.append(",")
            }
            sb.append(jsonStr(tags[i]))
        }
        sb.append("]}")
        return sb.toString()
    }

    func fileResp(p: String, ctype: String): HttpResp {
        if (!exists(p)) {
            return HttpResp(404, "text/plain; charset=utf-8", "missing " + p)
        }
        return HttpResp(200, ctype, String.fromUtf8(File.readFrom(p)))
    }

    func send(conn: TcpSocket, resp: HttpResp): Unit {
        let bodyBytes = resp.body.toArray()
        let head = "HTTP/1.1 " + resp.status.toString() + " " + statusText(resp.status) + "\r\n" +
            "Content-Type: " + resp.contentType + "\r\n" +
            "Content-Length: " + bodyBytes.size.toString() + "\r\n" +
            "Cache-Control: no-store\r\n" +
            "Connection: close\r\n\r\n"
        conn.write(head.toArray())
        if (bodyBytes.size > 0) {
            conn.write(bodyBytes)
        }
    }
}

public class HttpResp {
    public var status: Int64
    public var contentType: String
    public var body: String

    public init(status: Int64, contentType: String, body: String) {
        this.status = status
        this.contentType = contentType
        this.body = body
    }
}

func statusText(s: Int64): String {
    if (s == 200) {
        return "OK"
    }
    if (s == 404) {
        return "Not Found"
    }
    return "OK"
}

func findHeaderEnd(buf: ArrayList<Byte>): Int64 {
    let n = buf.size
    if (n < 4) {
        return -1
    }
    var i: Int64 = 0
    while (i + 3 < n) {
        if (buf[i] == 13 && buf[i + 1] == 10 && buf[i + 2] == 13 && buf[i + 3] == 10) {
            return i
        }
        i += 1
    }
    return -1
}

func startsWithLower(s: String, prefix: String): Bool {
    if (s.size < prefix.size) {
        return false
    }
    return s[..prefix.size].toAsciiLower() == prefix
}
