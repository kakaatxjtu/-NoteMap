package notemap

import std.convert.*

/**
 * NoteMap 入口。
 * 默认只监听 127.0.0.1（仅本机可访问）；
 * 加 --lan 参数则监听 0.0.0.0，同一局域网内的其他设备也能访问。
 */
main(args: Array<String>) {
    var host = "127.0.0.1"
    var port: UInt16 = 8777
    var lan = false
    for (a in args) {
        if (a == "--lan") {
            lan = true
        } else {
            match (UInt16.tryParse(a)) {
                case Some(p) => port = p
                case None => ()
            }
        }
    }
    if (lan) {
        host = "0.0.0.0"
    }

    let dataDir = "./notemap-data"
    let webDir = "./web"
    let svc = NotesService(dataDir)
    println("======================================")
    println(" NoteMap · 本地 Markdown 知识库")
    println("======================================")
    if (lan) {
        println("局域网模式：监听 0.0.0.0:" + port.toString())
        println("本机访问：http://127.0.0.1:" + port.toString())
        println("其他设备：http://<本机内网IP>:" + port.toString() + "（用 ipconfig 查看 IPv4 地址）")
        println("注意：Windows 防火墙首次会弹窗询问，需要允许访问。")
    } else {
        println("本机访问：http://127.0.0.1:" + port.toString())
    }
    println("数据目录：" + dataDir)
    println("按 Ctrl+C 退出")
    let server = HttpServer(port, svc, webDir, host)
    server.start()
}
