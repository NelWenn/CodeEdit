//
//  DiscordRPCFrame.swift
//  CodeEdit
//

import Foundation

/// Encodes/decodes Discord IPC frames: a little-endian `op` (UInt32) + `length` (UInt32) header
/// followed by the JSON payload. Pure — no networking.
enum DiscordRPCFrame {
    static func encode(opcode: UInt32, json: Data) -> Data {
        var data = Data()
        for value in [opcode, UInt32(json.count)] {
            data.append(UInt8(value & 0xFF))
            data.append(UInt8((value >> 8) & 0xFF))
            data.append(UInt8((value >> 16) & 0xFF))
            data.append(UInt8((value >> 24) & 0xFF))
        }
        data.append(json)
        return data
    }

    static func decodeHeader(_ data: Data) -> (opcode: UInt32, length: UInt32)? {
        guard data.count >= 8 else { return nil }
        let bytes = [UInt8](data.prefix(8))
        let opValue = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
        let lenValue = UInt32(bytes[4]) | UInt32(bytes[5]) << 8 | UInt32(bytes[6]) << 16 | UInt32(bytes[7]) << 24
        return (opValue, lenValue)
    }
}
