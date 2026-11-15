package notemap

import std.collection.*

/**
 * 可视化层：把 Markdown 的标题与列表转成节点树，再算成树形布局坐标。
 * 布局思路：x 由层深决定，y 自底向上把叶子均分，父节点取子节点均值。
 */
public class MindMapBuilder {
    public init() {}

    public func build(md: String): ArrayList<MNode> {
        let items = MdParser().outline(md)
        let n = items.size
        let ids = Array<String>(n, repeat: "")
        let parents = Array<String>(n, repeat: "")
        let texts = Array<String>(n, repeat: "")
        let depths = Array<Int64>(n, repeat: 0)

        // 用固定长度数组当栈，避免依赖 ArrayList 的删除接口
        let stackLevel = Array<Int64>(n + 1, repeat: 0)
        let stackId = Array<String>(n + 1, repeat: "")
        var sp: Int64 = 0

        var idx: Int64 = 0
        for (it in items) {
            let lv = it.level
            while (sp > 0 && stackLevel[sp - 1] >= lv) {
                sp -= 1
            }
            var parent = ""
            var depth: Int64 = 0
            if (sp > 0) {
                parent = stackId[sp - 1]
                depth = sp
            }
            let id = "m" + idx.toString()
            ids[idx] = id
            parents[idx] = parent
            texts[idx] = plainInline(it.text)
            depths[idx] = depth
            stackLevel[sp] = lv
            stackId[sp] = id
            sp += 1
            idx += 1
        }

        // 建立子节点索引
        let children = ArrayList<ArrayList<Int64>>()
        let roots = ArrayList<Int64>()
        for (i in 0..n) {
            children.add(ArrayList<Int64>())
        }
        for (i in 0..n) {
            if (parents[i] == "") {
                roots.add(i)
            } else {
                for (j in 0..n) {
                    if (ids[j] == parents[i]) {
                        children[j].add(i)
                        break
                    }
                }
            }
        }

        let layout = TreeLayout(children)
        let ys = layout.run(roots)

        let nodes = ArrayList<MNode>()
        for (i in 0..n) {
            let x = 40.0 + Float64(depths[i]) * 200.0
            nodes.add(MNode(ids[i], texts[i], parents[i], depths[i], x, ys[i]))
        }
        return nodes
    }
}

/** 去掉 ** / * /  等行内标记，导图里只显示纯文本。 */
public func plainInline(s: String): String {
    var t = s
    var guard = 0
    while (t.contains("*") && guard < 50) {
        t = t.replace("*", "")
        guard += 1
    }
    while (t.contains("`") && guard < 100) {
        t = t.replace("`", "")
        guard += 1
    }
    return t
}

private class TreeLayout {
    let children: ArrayList<ArrayList<Int64>>
    var cursor: Int64 = 0
    let ys: ArrayList<Float64>
    let done: ArrayList<Bool>

    init(children: ArrayList<ArrayList<Int64>>) {
        this.children = children
        this.ys = ArrayList<Float64>()
        this.done = ArrayList<Bool>()
        for (i in 0..children.size) {
            this.ys.add(0.0)
            this.done.add(false)
        }
    }

    func run(roots: ArrayList<Int64>): ArrayList<Float64> {
        for (r in roots) {
            place(r)
        }
        // 防御：任何未被访问的节点顺次排到末尾
        for (i in 0..this.done.size) {
            if (!this.done[i]) {
                this.ys[i] = Float64(this.cursor) * 46.0
                this.cursor += 1
                this.done[i] = true
            }
        }
        return this.ys
    }

    func place(i: Int64): Float64 {
        if (this.done[i]) {
            return this.ys[i]
        }
        let kids = this.children[i]
        if (kids.size == 0) {
            let y = Float64(this.cursor) * 46.0
            this.cursor += 1
            this.ys[i] = y
            this.done[i] = true
            return y
        }
        var sum = 0.0
        for (k in kids) {
            sum += place(k)
        }
        let y = sum / Float64(kids.size)
        this.ys[i] = y
        this.done[i] = true
        return y
    }
}
