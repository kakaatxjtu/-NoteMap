package notemap

import std.time.*
import std.collection.*

/** 基础工具层：纯函数，不碰业务。 */

public func htmlEscape(s: String): String {
    let sb = StringBuilder()
    let runes = s.toRuneArray()
    for (r in runes) {
        let c = r
        if (c == r'&') {
            sb.append("&amp;")
        } else if (c == r'<') {
            sb.append("&lt;")
        } else if (c == r'>') {
            sb.append("&gt;")
        } else if (c == r'"') {
            sb.append("&quot;")
        } else {
            sb.append(c)
        }
    }
    return sb.toString()
}

/** JSON 字符串转义（只输出，不解析）。 */
public func jsonStr(s: String): String {
    let sb = StringBuilder()
    sb.append("\"")
    for (r in s.toRuneArray()) {
        if (r == r'"') {
            sb.append("\\\"")
        } else if (r == r'\\') {
            sb.append("\\\\")
        } else if (r == r'\n') {
            sb.append("\\n")
        } else if (r == r'\r') {
            sb.append("\\r")
        } else if (r == r'\t') {
            sb.append("\\t")
        } else {
            sb.append(r)
        }
    }
    sb.append("\"")
    return sb.toString()
}

private func hexVal(b: Int64): Int64 {
    if (b >= 48 && b <= 57) {
        return b - 48
    }
    if (b >= 65 && b <= 70) {
        return b - 55
    }
    if (b >= 97 && b <= 102) {
        return b - 87
    }
    return -1
}

/** 解析 application/x-www-form-urlencoded 与 query string。 */
public func urlDecode(s: String): String {
    let src = s.toArray()
    let out = ArrayList<Byte>()
    var i: Int64 = 0
    let n = Int64(src.size)
    while (i < n) {
        let b = Int64(src[i])
        if (b == 37 && i + 2 < n) {
            let h1 = hexVal(Int64(src[i + 1]))
            let h2 = hexVal(Int64(src[i + 2]))
            if (h1 >= 0 && h2 >= 0) {
                out.add(UInt8(h1 * 16 + h2))
                i += 3
                continue
            }
        }
        if (b == 43) {
            out.add(32)
        } else {
            out.add(UInt8(b))
        }
        i += 1
    }
    return String.fromUtf8(out.toArray())
}

/** 解析 k1=v1&k2=v2，返回 key 对应的值（已解码）。 */
public func formGet(body: String, key: String): String {
    for (pair in body.split("&")) {
        if (pair.size == 0) {
            continue
        }
        let eq = pair.indexOf("=")
        match (eq) {
            case Some(pos) =>
                let k = urlDecode(pair[..pos])
                if (k == key) {
                    return urlDecode(pair[(pos + 1)..])
                }
            case None =>
                if (urlDecode(pair) == key) {
                    return ""
                }
        }
    }
    return ""
}

public func nowStamp(): String {
    return DateTime.now().toString()
}

/** 把标题变成安全的文件名片段。 */
public func safeName(s: String): String {
    let sb = StringBuilder()
    for (r in s.toRuneArray()) {
        let illegal = r == r'/' || r == r'\\' || r == r':' || r == r'*' || r == r'?' ||
            r == r'"' || r == r'<' || r == r'>' || r == r'|' || r == r'\n' || r == r'\t'
        if (illegal) {
            sb.append("_")
        } else {
            sb.append(r)
        }
    }
    let t = sb.toString()
    if (t.size == 0) {
        return "untitled"
    }
    if (t.size > 40) {
        return t[..40]
    }
    return t
}

public func pad2(n: Int64): String {
    if (n < 10) {
        return "0" + n.toString()
    }
    return n.toString()
}


/** 只保留数字，用于生成文件名安全的 id。 */
public func digitsOnly(s: String): String {
    let sb = StringBuilder()
    for (r in s.toRuneArray()) {
        if (r >= r'0' && r <= r'9') {
            sb.append(r.toString())
        }
    }
    return sb.toString()
}
