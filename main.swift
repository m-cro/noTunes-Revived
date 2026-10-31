import Cocoa
import MediaPlayer
import AVFoundation

let musicID = "com.apple.Music"
let selfID = "local.notunesrevived"

final class Delegate: NSObject, NSApplicationDelegate {
    var item: NSStatusItem?
    let menu = NSMenu()
    var showIcon = UserDefaults.standard.object(forKey: "showIcon") as? Bool ?? true
    var showItem: NSMenuItem!
    var enabled = true
    var toggle: NSMenuItem!
    var silence: AVAudioPlayer?
    var armed = false
    var others: [Int: String] = [:]   // pid -> bundle id of other Now Playing clients
    var logProc: Process?
    var buf = Data()

    func applicationDidFinishLaunching(_ n: Notification) {
        toggle = NSMenuItem(title: "Blocking Music", action: #selector(flip), keyEquivalent: "")
        toggle.state = .on
        menu.addItem(toggle)
        showItem = NSMenuItem(title: "Show Menu Bar Icon", action: #selector(toggleIcon), keyEquivalent: "")
        showItem.state = .on
        menu.addItem(showItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        applyIconSetting()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(launched(_:)),
            name: NSWorkspace.didLaunchApplicationNotification, object: nil)

        let cc = MPRemoteCommandCenter.shared()
        for c in [cc.playCommand, cc.pauseCommand, cc.togglePlayPauseCommand,
                  cc.nextTrackCommand, cc.previousTrackCommand] {
            c.isEnabled = true
            c.addTarget { _ in .success }
        }

        bootstrapClients()
        watchClients()
        killMusic()
        update()
    }

    // MARK: arming. Armed (silent audio + Now Playing info) only while no other app is a Now Playing client.

    func update() {
        if enabled && others.isEmpty { arm() } else { disarm() }
    }

    func arm() {
        guard !armed else { return }
        armed = true
        let info = MPNowPlayingInfoCenter.default()
        info.nowPlayingInfo = [MPMediaItemPropertyTitle: "noTunesRevived"]
        info.playbackState = .playing
        silence = try? AVAudioPlayer(data: silentWAV())
        silence?.numberOfLoops = -1
        silence?.play()
    }

    func disarm() {
        guard armed else { return }
        armed = false
        silence?.stop()
        silence = nil
        let info = MPNowPlayingInfoCenter.default()
        info.playbackState = .stopped
        info.nowPlayingInfo = nil
    }

    // MARK: tracking Now Playing clients via mediaremoted's log

    static let predicate = "process == \"mediaremoted\" AND eventMessage CONTAINS \"nowPlayingClient\""
    static let rx = try! NSRegularExpression(pattern: #"(Creating|Removing) nowPlayingClient.*?([A-Za-z][\w\-]*(?:\.[\w\-]+)+) \((\d+)\)"#)

    func handle(line: String) {
        let r = NSRange(line.startIndex..., in: line)
        guard let m = Delegate.rx.firstMatch(in: line, range: r),
              let kr = Range(m.range(at: 1), in: line),
              let br = Range(m.range(at: 2), in: line),
              let pr = Range(m.range(at: 3), in: line),
              let pid = Int(line[pr]) else { return }
        let bundle = String(line[br])
        guard bundle != musicID, bundle != selfID else { return }
        if line[kr] == "Creating" { others[pid] = bundle } else { others[pid] = nil }
    }

    func bootstrapClients() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        p.arguments = ["show", "--last", "12h", "--style", "compact", "--predicate", Delegate.predicate]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        try? p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        String(decoding: data, as: UTF8.self).split(separator: "\n").forEach { handle(line: String($0)) }
        others = others.filter { kill(pid_t($0.key), 0) == 0 }   // drop clients that have since died
    }

    func watchClients() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        p.arguments = ["stream", "--style", "compact", "--predicate", Delegate.predicate]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let d = h.availableData
            guard !d.isEmpty else { return }
            DispatchQueue.main.async { self?.ingest(d) }
        }
        try? p.run()
        logProc = p
    }

    func ingest(_ d: Data) {
        buf.append(d)
        while let nl = buf.firstIndex(of: 10) {
            let line = String(decoding: buf[buf.startIndex..<nl], as: UTF8.self)
            buf.removeSubrange(buf.startIndex...nl)
            handle(line: line)
        }
        update()
    }

    func applicationWillTerminate(_ n: Notification) { logProc?.terminate() }

    // MARK: Music killer fallback

    @objc func launched(_ n: Notification) {
        if let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           app.bundleIdentifier == musicID { killMusic() }
    }

    func killMusic() {
        guard enabled else { return }
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: musicID) {
            app.forceTerminate()
        }
    }

    @objc func flip() {
        enabled.toggle()
        toggle.state = enabled ? .on : .off
        refreshIcon()
        update()
        killMusic()
    }

    func image(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.size = NSSize(width: 16, height: 16)
        img.isTemplate = true
        return img
    }

    func refreshIcon() {
        guard let button = item?.button else { return }
        button.image = image(enabled ? "tray-on" : "tray-off")
    }

    func applyIconSetting() {
        showItem.state = showIcon ? .on : .off
        if showIcon && item == nil {
            item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item?.menu = menu
            refreshIcon()
        } else if !showIcon, let i = item {
            NSStatusBar.system.removeStatusItem(i)
            item = nil
        }
    }

    @objc func toggleIcon() {
        showIcon.toggle()
        UserDefaults.standard.set(showIcon, forKey: "showIcon")
        applyIconSetting()
    }

    // Opening the app again (e.g. from Finder) brings the icon back if it was hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !showIcon { toggleIcon() }
        return false
    }

    // 1s of 8kHz 16-bit mono silence
    func silentWAV() -> Data {
        let n = 8000 * 2
        var d = Data()
        func u32(_ v: Int) { var x = UInt32(v).littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: Int) { var x = UInt16(v).littleEndian; d.append(Data(bytes: &x, count: 2)) }
        d.append("RIFF".data(using: .ascii)!); u32(36 + n)
        d.append("WAVEfmt ".data(using: .ascii)!); u32(16); u16(1); u16(1); u32(8000); u32(16000); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(n)
        d.append(Data(count: n))
        return d
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let d = Delegate()
app.delegate = d
app.run()
