import Foundation
import CoreGraphics
import ImageIO

enum F3DError: Error { case notAZip, noPreview, badImage }

/// Minimal ZIP reader (central directory; "stored" and "deflate" entries).
struct ZipReader {
    struct Entry {
        let name: String
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localOffset: Int
    }

    let data: Data
    let entries: [Entry]

    private static func u16(_ d: Data, _ o: Int) -> Int {
        Int(d[d.startIndex + o]) | Int(d[d.startIndex + o + 1]) << 8
    }
    private static func u32(_ d: Data, _ o: Int) -> Int {
        u16(d, o) | u16(d, o + 2) << 16
    }

    init(data: Data) throws {
        self.data = data
        guard data.count >= 22 else { throw F3DError.notAZip }

        // Find End Of Central Directory record, scanning backwards.
        var eocd = -1
        var i = data.count - 22
        let lowest = max(0, data.count - 22 - 65535)
        while i >= lowest {
            if Self.u32(data, i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw F3DError.notAZip }

        let count = Self.u16(data, eocd + 10)
        var p = Self.u32(data, eocd + 16)
        var result: [Entry] = []
        for _ in 0..<count {
            guard p + 46 <= data.count, Self.u32(data, p) == 0x02014b50 else { break }
            let method = UInt16(Self.u16(data, p + 10))
            let csize = Self.u32(data, p + 20)
            let usize = Self.u32(data, p + 24)
            let nlen = Self.u16(data, p + 28)
            let elen = Self.u16(data, p + 30)
            let clen = Self.u16(data, p + 32)
            let off = Self.u32(data, p + 42)
            let nameData = data.subdata(in: (data.startIndex + p + 46)..<(data.startIndex + p + 46 + nlen))
            let name = String(data: nameData, encoding: .utf8) ?? ""
            result.append(Entry(name: name, method: method, compressedSize: csize,
                                uncompressedSize: usize, localOffset: off))
            p += 46 + nlen + elen + clen
        }
        self.entries = result
    }

    func read(_ e: Entry) throws -> Data {
        let o = e.localOffset
        guard o + 30 <= data.count, Self.u32(data, o) == 0x04034b50 else { throw F3DError.notAZip }
        let start = o + 30 + Self.u16(data, o + 26) + Self.u16(data, o + 28)
        guard start + e.compressedSize <= data.count else { throw F3DError.notAZip }
        let raw = data.subdata(in: (data.startIndex + start)..<(data.startIndex + start + e.compressedSize))
        switch e.method {
        case 0: return raw
        case 8: return try (raw as NSData).decompressed(using: .zlib) as Data
        default: throw F3DError.notAZip
        }
    }
}

enum F3DPreview {
    /// Returns the preview PNG that Fusion 360 stores inside every .f3d file.
    static func pngData(at url: URL) throws -> Data {
        // mappedIfSafe: the geometry streams make files big, but we only touch a few KB.
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let zip = try ZipReader(data: data)
        let candidates = zip.entries.filter {
            $0.name.lowercased().contains("previews/") && $0.name.lowercased().hasSuffix(".png")
        }
        // Prefer the largest preview image if there are several.
        guard let best = candidates.max(by: { $0.uncompressedSize < $1.uncompressedSize }) else {
            throw F3DError.noPreview
        }
        return try zip.read(best)
    }

    static func cgImage(at url: URL) throws -> CGImage {
        let png = try pngData(at: url)
        guard let src = CGImageSourceCreateWithData(png as CFData, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { throw F3DError.badImage }
        return img
    }
}
