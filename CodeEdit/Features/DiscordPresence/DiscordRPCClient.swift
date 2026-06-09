//
//  DiscordRPCClient.swift
//  CodeEdit
//

import Foundation

/// Minimal Discord IPC client: connects to the local `discord-ipc-*` Unix socket, performs the
/// handshake, and sends `SET_ACTIVITY` frames. Detects a dropped connection on write failure;
/// reconnection is driven by `DiscordPresenceManager`.
final class DiscordRPCClient {
    private let clientID: String
    private var descriptor: Int32 = -1

    init(clientID: String) {
        self.clientID = clientID
    }

    var isConnected: Bool { descriptor >= 0 }

    /// Connects to the first available IPC socket and handshakes. Returns false if Discord isn't up.
    @discardableResult
    func connect() -> Bool {
        for path in DiscordSocketLocator.candidatePaths(environment: ProcessInfo.processInfo.environment) {
            guard let opened = Self.openSocket(path: path) else { continue }
            descriptor = opened
            if sendHandshake() {
                return true
            }
            close()
        }
        return false
    }

    func setActivity(_ activity: DiscordActivity?) {
        guard isConnected else { return }
        var args: [String: Any] = ["pid": Int(ProcessInfo.processInfo.processIdentifier)]
        if let activity,
           let data = try? JSONEncoder().encode(activity),
           let object = try? JSONSerialization.jsonObject(with: data) {
            args["activity"] = object
        } else {
            args["activity"] = NSNull()
        }
        let payload: [String: Any] = [
            "cmd": "SET_ACTIVITY",
            "nonce": UUID().uuidString,
            "args": args
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: payload) else { return }
        if !write(DiscordRPCFrame.encode(opcode: 1, json: json)) {
            close()
        }
    }

    func close() {
        if descriptor >= 0 {
            Darwin.close(descriptor)
            descriptor = -1
        }
    }

    // MARK: - Internals

    private func sendHandshake() -> Bool {
        let payload: [String: Any] = ["v": 1, "client_id": clientID]
        guard let json = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        return write(DiscordRPCFrame.encode(opcode: 0, json: json))
    }

    private static func openSocket(path: String) -> Int32? {
        // `sun_path` is 104 bytes on Darwin; leave room for the null terminator.
        guard path.utf8.count < 104 else { return nil }
        let opened = socket(AF_UNIX, SOCK_STREAM, 0)
        guard opened >= 0 else { return nil }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path) { pointer in
            path.withCString { cString in
                pointer.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    _ = strncpy(dest, cString, 103)
                }
            }
        }
        let length = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &addr) { raw -> Int32 in
            raw.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(opened, $0, length) }
        }
        if result != 0 {
            Darwin.close(opened)
            return nil
        }
        return opened
    }

    @discardableResult
    private func write(_ data: Data) -> Bool {
        guard descriptor >= 0 else { return false }
        return data.withUnsafeBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return true }
            var sent = 0
            let total = raw.count
            while sent < total {
                let written = Darwin.write(descriptor, base + sent, total - sent)
                if written <= 0 { return false }
                sent += written
            }
            return true
        }
    }
}
