//
//  DataGroup11.swift
//
//  Created by Andy Qua on 01/02/2021.
//

import Foundation

@available(iOS 13, macOS 10.15, *)
public class DataGroup11 : DataGroup {
    
    public private(set) var fullName : String?
    public private(set) var personalNumber : String?
    public private(set) var dateOfBirth : String?
    public private(set) var placeOfBirth : String?
    public private(set) var address : String?
    public private(set) var telephone : String?
    public private(set) var profession : String?
    public private(set) var title : String?
    public private(set) var personalSummary : String?
    public private(set) var proofOfCitizenship : String?
    public private(set) var tdNumbers : String?
    public private(set) var custodyInfo : String?
    public private(set) var otherNames : [String]?

    public override var datagroupType: DataGroupId { .DG11 }

    required init( _ data : [UInt8] ) throws {
        try super.init(data)
    }

    override func parse(_ data: [UInt8]) throws {
        var tag = try getNextTag()
        try verifyTag(tag, equals: 0x5C)
        _ = try getNextValue()
        
        repeat {
            tag = try getNextTag()
            let value = try getNextValue()

            switch tag {
            case 0x5F0E:
                fullName = decodedString(from: value) ?? fullName
            case 0x5F0F:
                appendOtherName(from: value)
            case 0x5F10:
                personalNumber = decodedString(from: value) ?? personalNumber
            case 0x5F11:
                placeOfBirth = decodedString(from: value) ?? placeOfBirth
            case 0x5F2B:
                dateOfBirth = decodedString(from: value) ?? dateOfBirth
            case 0x5F42:
                address = decodedString(from: value) ?? address
            case 0x5F12:
                telephone = decodedString(from: value) ?? telephone
            case 0x5F13:
                profession = decodedString(from: value) ?? profession
            case 0x5F14:
                title = decodedString(from: value) ?? title
            case 0x5F15:
                personalSummary = decodedString(from: value) ?? personalSummary
            case 0x5F16:
                proofOfCitizenship = decodedString(from: value) ?? proofOfCitizenship
            case 0x5F17:
                tdNumbers = decodedString(from: value) ?? tdNumbers
            case 0x5F18:
                custodyInfo = decodedString(from: value) ?? custodyInfo
            case 0xA0:
                parseOtherNameList(value)
            default:
                continue
            }
        } while pos < data.count
    }

    private func decodedString(from value: [UInt8]) -> String? {
        guard !value.isEmpty else { return nil }
        return String(bytes: value, encoding: .utf8)
    }

    private func appendOtherName(from value: [UInt8]) {
        guard let name = String(bytes: value, encoding: .utf8), !name.isEmpty else { return }
        if otherNames != nil {
            otherNames?.append(name)
        } else {
            otherNames = [name]
        }
    }

    private func parseOtherNameList(_ value: [UInt8]) {
        var offset = 0
        var expectedNameCount: Int?
        var parsedNames: [String] = []
        var shouldStop = false

        while offset < value.count && !shouldStop {
            guard let innerTag = readTag(in: value, offset: &offset),
                  let length = readLength(in: value, offset: &offset),
                  offset + length <= value.count else { break }

            let fieldValue = [UInt8](value[offset ..< offset + length])
            offset += length

            switch innerTag {
            case 0x02:
                expectedNameCount = fieldValue.reduce(0) { ($0 << 8) | Int($1) }
            case 0x5F0F:
                if let name = String(bytes: fieldValue, encoding: .utf8), !name.isEmpty {
                    parsedNames.append(name)
                    if let expected = expectedNameCount, parsedNames.count >= expected {
                        shouldStop = true
                    }
                }
            default:
                continue
            }
        }

        guard !parsedNames.isEmpty else { return }

        if otherNames != nil {
            otherNames?.append(contentsOf: parsedNames)
        } else {
            otherNames = parsedNames
        }
    }

    private func readTag(in data: [UInt8], offset: inout Int) -> Int? {
        guard offset < data.count else { return nil }

        let current = data[offset]
        if current & 0x1F == 0x1F {
            guard offset + 1 < data.count else { return nil }
            let tagBytes = [UInt8](data[offset...offset + 1])
            offset += 2
            return Int(binToHex(tagBytes))
        } else {
            offset += 1
            return Int(current)
        }
    }

    private func readLength(in data: [UInt8], offset: inout Int) -> Int? {
        guard offset < data.count else { return nil }

        let end = min(offset + 4, data.count)
        let slice = [UInt8](data[offset..<end])
        guard let (length, lengthOffset) = try? asn1Length(slice) else { return nil }
        offset += lengthOffset
        return length
    }
}
