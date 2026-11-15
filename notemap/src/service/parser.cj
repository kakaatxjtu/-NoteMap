package notemap

import std.collection.*

/**
 * 解析层：Markdown -> HTML（块级 + 行内两遍扫描）。
 * 支持：标题、加粗、斜体、无序/有序列表、引用、代码块、分隔线。
 */
public class MdParser {
    public init() {}

    public func toHtml(md: String): String {
        let lines = md.split("\n")
        let sb = StringBuilder()
        var inCode = false
        var codeBuf = StringBuilder()
        var listTag = ""
        var paraOpen = false

        for (raw in lines) {
            let line = stripCR(raw)
            let trimmed = trimLeft(line)

            // 代码块
            if (startsWith(trimmed, "```")) {
                if (inCode) {
                    sb.append("<pre><code>")
                    sb.append(htmlEscape(codeBuf.toString()))
                    sb.append("</code></pre>\n")
                    inCode = false
                    codeBuf = StringBuilder()
                } else {
                    closeBlocks(sb, listTag, paraOpen)
                    listTag = ""
                    paraOpen = false
                    inCode = true
                }
                continue
            }
            if (inCode) {
                codeBuf.append(line)
                codeBuf.append("\n")
                continue
            }

            // 空行
            if (trimmed.size == 0) {
                closeBlocks(sb, listTag, paraOpen)
                listTag = ""
                paraOpen = false
                continue
            }

            // 标题
            let hl = headingLevel(trimmed)
            if (hl > 0) {
                closeBlocks(sb, listTag, paraOpen)
                listTag = ""
                paraOpen = false
                let content = trimLeft(trimmed[(hl + 1)..])
                sb.append("<h" + hl.toString() + ">")
                sb.append(inline(content))
                sb.append("</h" + hl.toString() + ">\n")
                continue
            }

            // 分隔线
            if (trimmed == "---" || trimmed == "***") {
                closeBlocks(sb, listTag, paraOpen)
                listTag = ""
                paraOpen = false
                sb.append("<hr/>\n")
                continue
            }

            // 引用
            if (startsWith(trimmed, ">")) {
                closeBlocks(sb, listTag, paraOpen)
                listTag = ""
                paraOpen = false
                var q = trimmed[1..]
                if (startsWith(q, " ")) {
                    q = q[1..]
                }
                sb.append("<blockquote>")
                sb.append(inline(q))
                sb.append("</blockquote>\n")
                continue
            }

            // 无序列表
            if (startsWith(trimmed, "- ") || startsWith(trimmed, "* ") || startsWith(trimmed, "+ ")) {
                if (paraOpen) {
                    sb.append("</p>\n")
                    paraOpen = false
                }
                if (listTag != "ul") {
                    if (listTag != "") {
                        sb.append("</" + listTag + ">\n")
                    }
                    sb.append("<ul>\n")
                    listTag = "ul"
                }
                sb.append("<li>")
                sb.append(inline(trimmed[2..]))
                sb.append("</li>\n")
                continue
            }

            // 有序列表
            let ol = orderedItemLen(trimmed)
            if (ol > 0) {
                if (paraOpen) {
                    sb.append("</p>\n")
                    paraOpen = false
                }
                if (listTag != "ol") {
                    if (listTag != "") {
                        sb.append("</" + listTag + ">\n")
                    }
                    sb.append("<ol>\n")
                    listTag = "ol"
                }
                sb.append("<li>")
                sb.append(inline(trimmed[ol..]))
                sb.append("</li>\n")
                continue
            }

            // 普通段落
            if (listTag != "") {
                sb.append("</" + listTag + ">\n")
                listTag = ""
            }
            sb.append("<p>")
            sb.append(inline(trimmed))
            sb.append("</p>\n")
        }
        if (inCode) {
            sb.append("<pre><code>")
            sb.append(htmlEscape(codeBuf.toString()))
            sb.append("</code></pre>\n")
        }
        closeBlocks(sb, listTag, paraOpen)
        return sb.toString()
    }

    /** 抽出标题与列表，供思维导图与大纲使用。 */
    public func outline(md: String): ArrayList<OutlineItem> {
        let items = ArrayList<OutlineItem>()
        var inCode = false
        for (raw in md.split("\n")) {
            let line = stripCR(raw)
            let trimmed = trimLeft(line)
            if (startsWith(trimmed, "```")) {
                inCode = !inCode
                continue
            }
            if (inCode) {
                continue
            }
            let hl = headingLevel(trimmed)
            if (hl > 0) {
                items.add(OutlineItem(hl, trimLeft(trimmed[(hl + 1)..]), false))
                continue
            }
            let indent = (line.size - trimmed.size) / 2
            if (startsWith(trimmed, "- ") || startsWith(trimmed, "* ") || startsWith(trimmed, "+ ")) {
                items.add(OutlineItem(100 + indent, trimmed[2..], true))
                continue
            }
            let ol = orderedItemLen(trimmed)
            if (ol > 0) {
                items.add(OutlineItem(100 + indent, trimmed[ol..], true))
            }
        }
        return items
    }
}

private func closeBlocks(sb: StringBuilder, listTag: String, paraOpen: Bool): Unit {
    if (paraOpen) {
        sb.append("</p>\n")
    }
    if (listTag != "") {
        sb.append("</" + listTag + ">\n")
    }
}

private func stripCR(s: String): String {
    if (s.size == 0) {
        return s
    }
    let b = s.toArray()
    if (b[b.size - 1] == 13) {
        return s[..(s.size - 1)]
    }
    return s
}

private func startsWith(s: String, prefix: String): Bool {
    let a = s.toArray()
    let b = prefix.toArray()
    if (a.size < b.size) {
        return false
    }
    var i = 0
    while (i < b.size) {
        if (a[i] != b[i]) {
            return false
        }
        i += 1
    }
    return true
}

private func trimLeft(s: String): String {
    var i: Int64 = 0
    let n = s.size
    while (i < n) {
        let ch = s[i]
        if (ch == 32 || ch == 9) {
            i += 1
        } else {
            break
        }
    }
    return s[i..]
}

private func headingLevel(s: String): Int64 {
    var i: Int64 = 0
    while (i < 6 && i < s.size && s[i] == 35) {
        i += 1
    }
    if (i == 0) {
        return 0
    }
    if (i < s.size && s[i] == 32) {
        return i
    }
    return 0
}

private func orderedItemLen(s: String): Int64 {
    var i: Int64 = 0
    while (i < s.size && s[i] >= 48 && s[i] <= 57) {
        i += 1
    }
    if (i == 0 || i + 1 >= s.size) {
        return 0
    }
    if (s[i] == 46 && s[i + 1] == 32) {
        return i + 2
    }
    return 0
}

/** 行内语法：加粗、斜体、行内代码。 */
private func inline(s: String): String {
    let out = StringBuilder()
    let runes = s.toRuneArray()
    var i = 0
    let n = runes.size
    var bold = false
    var ital = false
    var code = false
    while (i < n) {
        let c = runes[i]
        if (c == r'\\' && i + 1 < n) {
            out.append(escapeRune(runes[i + 1]))
            i += 2
            continue
        }
        if (c == r'`') {
            code = !code
            if (code) {
                out.append("<code>")
            } else {
                out.append("</code>")
            }
            i += 1
            continue
        }
        if (c == r'*' && !code) {
            if (i + 1 < n && runes[i + 1] == r'*') {
                bold = !bold
                if (bold) {
                    out.append("<strong>")
                } else {
                    out.append("</strong>")
                }
                i += 2
                continue
            }
            ital = !ital
            if (ital) {
                out.append("<em>")
            } else {
                out.append("</em>")
            }
            i += 1
            continue
        }
        out.append(escapeRune(c))
        i += 1
    }
    return out.toString()
}

private func escapeRune(r: Rune): String {
    if (r == r'&') {
        return "&amp;"
    }
    if (r == r'<') {
        return "&lt;"
    }
    if (r == r'>') {
        return "&gt;"
    }
    if (r == r'"') {
        return "&quot;"
    }
    return r.toString()
}
