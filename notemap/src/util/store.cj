package notemap

import std.fs.*
import std.collection.*

/** 存储工具层：文件与目录的原子操作。 */

public func ensureDir(p: String): Unit {
    if (!exists(p)) {
        Directory.create(p, recursive: true)
    }
}

public func pathExists(p: String): Bool {
    return exists(p)
}

public func readText(p: String): String {
    if (!exists(p)) {
        return ""
    }
    return String.fromUtf8(File.readFrom(p))
}

public func writeText(p: String, s: String): Unit {
    File.writeTo(p, s.toArray())
}

/** 先写 .tmp 再重命名：避免写到一半崩溃导致文件损坏。 */
public func writeAtomic(p: String, s: String): Unit {
    let tmp = p + ".tmp"
    File.writeTo(tmp, s.toArray())
    if (exists(p)) {
        remove(p)
    }
    rename(Path(tmp), to: Path(p), overwrite: true)
}

public func removeIfExists(p: String): Unit {
    if (exists(p)) {
        remove(p)
    }
}

public func listDir(p: String): Array<String> {
    if (!exists(p)) {
        return Array<String>()
    }
    let names = ArrayList<String>()
    for (info in Directory.readFrom(p)) {
        names.add(info.name)
    }
    return names.toArray()
}
