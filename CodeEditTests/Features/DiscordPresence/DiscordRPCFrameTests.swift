@testable import CodeEdit
import XCTest

final class DiscordRPCFrameTests: XCTestCase {
    func testEncodeWritesLittleEndianHeaderThenPayload() {
        let json = Data("{}".utf8) // 2 bytes
        let frame = DiscordRPCFrame.encode(opcode: 0, json: json)
        XCTAssertEqual([UInt8](frame.prefix(4)), [0, 0, 0, 0])       // op 0 LE
        XCTAssertEqual([UInt8](frame[4..<8]), [2, 0, 0, 0])          // length 2 LE
        XCTAssertEqual(Data(frame[8...]), json)
    }

    func testDecodeHeaderRoundTrips() {
        let frame = DiscordRPCFrame.encode(opcode: 1, json: Data("hello".utf8))
        let header = DiscordRPCFrame.decodeHeader(frame)
        XCTAssertEqual(header?.opcode, 1)
        XCTAssertEqual(header?.length, 5)
    }

    func testDecodeHeaderRejectsShortData() {
        XCTAssertNil(DiscordRPCFrame.decodeHeader(Data([0, 0, 0])))
    }
}
