import Foundation
import PencilKit
import Compression

extension PKDrawing {
    // Compress drawing data using ZLIB
    func compressedDataRepresentation() -> Data? {
        let originalData = self.dataRepresentation()
        return originalData.compressed(using: .zlib)
    }
    
    // Create a drawing from compressed data
    static func drawing(fromCompressedData compressedData: Data) -> PKDrawing? {
        guard let decompressedData = compressedData.decompressed(using: .zlib) else {
            print("Failed to decompress drawing data")
            return nil
        }
        
        do {
            return try PKDrawing(data: decompressedData)
        } catch {
            print("Error recreating drawing from decompressed data: \(error)")
            return nil
        }
    }
}

// Extension to Data for easy compression and decompression
extension Data {
    func compressed(using algorithm: Compression.Algorithm = .zlib) -> Data? {
        guard !isEmpty else { return nil }
        
        var destinationBuffer = [UInt8]()
        let bufferSize = count * 2 // Allow some extra space
        destinationBuffer.reserveCapacity(bufferSize)
        
        let compressionStatus = destinationBuffer.withUnsafeMutableBufferPointer { destBuffer in
            withUnsafeBytes { sourceBuffer in
                compression_encode_buffer(
                    destBuffer.baseAddress!, destBuffer.count,
                    sourceBuffer.bindMemory(to: UInt8.self).baseAddress!, count,
                    nil,
                    algorithm.compressionAlgorithm
                )
            }
        }
        
        guard compressionStatus > 0 else {
            print("Compression failed")
            return nil
        }
        
        return Data(bytes: destinationBuffer, count: compressionStatus)
    }
    
    func decompressed(using algorithm: Compression.Algorithm = .zlib) -> Data? {
        guard !isEmpty else { return nil }
        
        var destinationBuffer = [UInt8]()
        let bufferSize = count * 10 // Allow significant expansion
        destinationBuffer.reserveCapacity(bufferSize)
        
        let decompressionStatus = destinationBuffer.withUnsafeMutableBufferPointer { destBuffer in
            withUnsafeBytes { sourceBuffer in
                compression_decode_buffer(
                    destBuffer.baseAddress!, destBuffer.count,
                    sourceBuffer.bindMemory(to: UInt8.self).baseAddress!, count,
                    nil,
                    algorithm.compressionAlgorithm
                )
            }
        }
        
        guard decompressionStatus > 0 else {
            print("Decompression failed")
            return nil
        }
        
        return Data(bytes: destinationBuffer, count: decompressionStatus)
    }
}

// Add a helper extension for compression algorithm
extension Compression.Algorithm {
    var compressionAlgorithm: compression_algorithm {
        switch self {
        case .lzbitmap: return COMPRESSION_LZBITMAP
        case .brotli: return COMPRESSION_BROTLI
        case .zlib: return COMPRESSION_ZLIB
        case .lzfse: return COMPRESSION_LZFSE
        case .lz4: return COMPRESSION_LZ4
        case .lzma: return COMPRESSION_LZMA
        @unknown default: return COMPRESSION_ZLIB
        }
    }
}
