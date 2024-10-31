//
//  ContentView.swift
//  MetaflacSwift
//
//  Created by 荒野老男人 on 2024/10/29.
//

import SwiftUI
import UniformTypeIdentifiers

// Struct to store image information
struct ImageInfo {
    var filePath: String
    var mimeType: String
    var width: Int
    var height: Int
    var colorDepth: Int
    var dataLength: Int
    var imageData: Data
}

struct ContentView: View {
    @State private var isPresented = false
    @State private var flacUrl: URL? = nil
    @State private var importResult = ""
    
    @State private var isImagePickerPresented = false
    @State private var imageInfo: ImageInfo?
    @State private var errorMessage: String?
    
    @State private var document: FileDocument? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Button("Select Flac File") {
                    isPresented = true
                }
                .fileImporter(isPresented: $isPresented, allowedContentTypes: [.audio]) { result in
                    switch result {
                    case .success(let url):
                        flacUrl = url
                        importResult = url.path(percentEncoded: false)
                        readMetadata(url)
                    case .failure(let error):
                        importResult = error.localizedDescription
                    }
                }
                Text(importResult)
                
                Button("Select Image File") {
                    isImagePickerPresented = true
                }
                .fileImporter(isPresented: $isImagePickerPresented, allowedContentTypes: [.image]) { result in
                    switch result {
                    case .success(let url):
                        imageInfo = fetchImageInfo(from: url)
                        errorMessage = nil // Clear any previous error
                    case .failure(let error):
                        errorMessage = "Error: \(error.localizedDescription)"
                        imageInfo = nil // Clear any previous image info
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                
                if let imageInfo = imageInfo {
                    Text("File Path: \(imageInfo.filePath)")
                    Text("MIME Type: \(imageInfo.mimeType)")
                    Text("Width: \(imageInfo.width) px")
                    Text("Height: \(imageInfo.height) px")
                    Text("Color Depth: \(imageInfo.colorDepth) bpp")
                    Text("Data Length: \(imageInfo.dataLength) bytes")
                }
                
                Button("Export with PICTURE Block") {
                    if let url = flacUrl, let imageInfo = imageInfo {
                        exportWithPictureBlock(flacURL: url, imageInfo: imageInfo)
                    }
                }
                
                Spacer()
            }
            .padding()
            Spacer()
        }
    }
    
    private func readMetadata(_ url: URL) {
        do {
            let buffer = try Data(contentsOf: url)
            
            // Verify the first four bytes
            guard buffer.count >= 4,
                  buffer[0] == 0x66,
                  buffer[1] == 0x4C,
                  buffer[2] == 0x61,
                  buffer[3] == 0x43 else {
                print("First four bytes do not match the expected pattern.")
                return
            }
            
            print("First four bytes match: 0x66, 0x4C, 0x61, 0x43")
            
            // Start reading blocks after the initial four-byte FLAC marker
            var offset = 4
            var isLastBlock = false
            var hasPictureBlock = false
            
            while !isLastBlock && offset + 4 <= buffer.count {
                // Read METADATA_BLOCK_HEADER
                let metadataHeader = buffer[offset]
                
                // Extract the last-metadata-block flag and block type
                isLastBlock = (metadataHeader & 0x80) != 0 // 0x80 = 0b10000000
                let blockType = metadataHeader & 0x7F       // 0x7F = 0b01111111
                
                if blockType == 6 {
                    hasPictureBlock = true
                }
                
                // Read the next 3 bytes for the length
                guard offset + 4 <= buffer.count else {
                    print("Insufficient data for length field.")
                    break
                }
                
                let length = (Int(buffer[offset + 1]) << 16) | (Int(buffer[offset + 2]) << 8) | Int(buffer[offset + 3])
                
                // Print the parsed values for this block
                print("Block at offset \(offset):")
                print("  Last Metadata Block Flag: \(isLastBlock ? "Yes" : "No")")
                print("  Block Type: \(blockType)")
                print("  Metadata Length: \(length) bytes")
                
                // Move offset to the start of the next metadata block
                offset += 4 + length
                
                // Ensure offset does not exceed buffer count
                if offset > buffer.count {
                    print("Reached end of file unexpectedly while reading blocks.")
                    break
                }
            }
            
            if hasPictureBlock {
                print("Has picture block.")
            } else {
                print("No picture block.")
            }
            
        } catch {
            print("Failed to read data from file: \(error.localizedDescription)")
        }
    }
    
    func fetchImageInfo(from url: URL) -> ImageInfo? {
        guard let nsImage = NSImage(contentsOf: url),
              let imageData = try? Data(contentsOf: url) else {
            return nil
        }
        
        let width = Int(nsImage.size.width)
        let height = Int(nsImage.size.height)
        let colorDepth = nsImage.representations.first?.bitsPerSample ?? 8
        let dataLength = imageData.count
        let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "Unknown"
        
        return ImageInfo(filePath: url.path, mimeType: mimeType, width: width, height: height, colorDepth: colorDepth, dataLength: dataLength, imageData: imageData)
    }
    
    private func exportWithPictureBlock(flacURL: URL, imageInfo: ImageInfo) {
        do {
            let buffer = try Data(contentsOf: flacURL)
            print("Buffer count: \(buffer.count)")
            
            // Locate last-metadata-block and prepare new data with PICTURE block
            var modifiedData = Data()
            var offset = 4
            
            var isLastBlock = false
            
            modifiedData.append(buffer[..<offset]) // Append FLAC header
            
            let metadataHeader = buffer[offset]
            
            // Extract the last-metadata-block flag and block type
            isLastBlock = (metadataHeader & 0x80) != 0 // 0x80 = 0b10000000
            let blockType = metadataHeader & 0x7F       // 0x7F = 0b01111111
            let length = (Int(buffer[offset + 1]) << 16) | (Int(buffer[offset + 2]) << 8) | Int(buffer[offset + 3])
            
            // Append the current metadata block
            print("Append first block \(offset) to \(offset + 4 + length)")
            modifiedData.append(buffer[offset..<offset + 4 + length])
            offset += 4 + length
            print("Current offset: \(offset)")
            
            // Insert PICTURE block
            if let pictureBlock = createPictureBlock(from: imageInfo) {
                modifiedData.append(pictureBlock)
                print("Picture block count: \(pictureBlock.count)")
            } else {
                print("Create picture block failed")
            }
            
            // Append the remaining buffer content (audio data and other metadata)
            if offset < buffer.count {
                modifiedData.append(buffer[offset...])
                print("Output count: \(modifiedData.count)")
            }
            
            // Write to a new file with the PICTURE block inserted
            let outputURL = flacURL.deletingLastPathComponent().appendingPathComponent("ModifiedWithPicture.flac")
            try modifiedData.write(to: outputURL)
            print("File exported successfully at \(outputURL.path)")
            
        } catch {
            print("Failed to export with PICTURE block: \(error.localizedDescription)")
        }
    }
    
    private func createPictureMetadataBlockHeader(length: Int) -> Data? {
        // 检查传入的长度是否在有效范围内 (0 到 16,777,215，24 位的最大值)
        guard length >= 0 && length <= 0xFFFFFF else {
            print("Length out of valid range")
            return nil
        }

        // 构建 METADATA_BLOCK_HEADER 的字节数组
        var header = Data()
        
        // 1bit 的 Last-metadata-block flag (假设此处为 0 表示还有更多元数据块)
        let lastMetadataBlockFlag: UInt8 = 0 << 7
        
        // 7bits 的 BLOCK_TYPE，类型为 6 表示 PICTURE
        let blockType: UInt8 = 6
        
        // 组合 Last-metadata-block flag 和 BLOCK_TYPE
        let firstByte: UInt8 = lastMetadataBlockFlag | blockType
        header.append(firstByte)
        
        // 将长度分成三个字节 (24 bits)，并依次加入 header
        header.append(UInt8((length >> 16) & 0xFF))
        header.append(UInt8((length >> 8) & 0xFF))
        header.append(UInt8(length & 0xFF))
        
        return header
    }
    
    private func createPictureBlock(from imageInfo: ImageInfo) -> Data? {
        var pictureBlock = Data()
        
        // Prepare picture metadata block
        let mimeTypeData = Data(imageInfo.mimeType.utf8)
        let descriptionData = Data("Cover Image".utf8)
        
        // Calculate length and add it in 3 bytes
        let length = 4 + 4 + mimeTypeData.count + 4 + descriptionData.count + 4 + 4 + 4 + 4 + 4 + imageInfo.dataLength
        
        if let header = createPictureMetadataBlockHeader(length: length) {
            pictureBlock.append(header)
            
//            pictureBlock.append(contentsOf: withUnsafeBytes(of: length.bigEndian) { Array($0).suffix(3) })
            
            // Add picture type (cover front = 3)
            pictureBlock.append(contentsOf: [0, 0, 0, 3])
            
            // Add MIME type length and data
            pictureBlock.append(contentsOf: withUnsafeBytes(of: UInt32(mimeTypeData.count).bigEndian) { Array($0) })
            pictureBlock.append(mimeTypeData)
            
            // Add description length and data
            pictureBlock.append(contentsOf: withUnsafeBytes(of: UInt32(descriptionData.count).bigEndian) { Array($0) })
            pictureBlock.append(descriptionData)
            
            // Add picture dimensions (width, height, color depth, and reserved)
            pictureBlock.append(contentsOf: [
                UInt32(imageInfo.width).bigEndian,
                UInt32(imageInfo.height).bigEndian,
                UInt32(imageInfo.colorDepth).bigEndian,
                0 // Reserved for non-indexed pictures
            ].flatMap { withUnsafeBytes(of: $0) { Array($0) } })
            
            // Add image data length and data
            pictureBlock.append(contentsOf: withUnsafeBytes(of: UInt32(imageInfo.dataLength).bigEndian) { Array($0) })
            pictureBlock.append(imageInfo.imageData)
            
            return pictureBlock
        }
        
        return nil
    }
}

#Preview {
    ContentView()
        .frame(width: 400)
}
