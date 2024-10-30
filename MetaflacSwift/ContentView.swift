//
//  ContentView.swift
//  MetaflacSwift
//
//  Created by 荒野老男人 on 2024/10/29.
//

import SwiftUI

struct ContentView: View {
    @State private var isPresented = false
    @State private var importResult = ""
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Button("Select Flac File") {
                    isPresented = true
                }
                .fileImporter(isPresented: $isPresented, allowedContentTypes: [.audio]) { result in
                    switch result {
                    case .success(let url):
                        importResult = url.path(percentEncoded: false)
                        readMetadata(url)
                    case .failure(let error):
                        importResult = error.localizedDescription
                    }
                }
                Text(importResult)
                Spacer()
            }
            .padding()
            Spacer()
        }
    }
    
    private func readMetadata(_ url: URL) {
        do {
            let _ = url.startAccessingSecurityScopedResource()
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
            
            while !isLastBlock && offset + 4 <= buffer.count {
                // Read METADATA_BLOCK_HEADER
                let metadataHeader = buffer[offset]
                
                // Extract the last-metadata-block flag and block type
                isLastBlock = (metadataHeader & 0x80) != 0 // 0x80 = 0b10000000
                let blockType = metadataHeader & 0x7F       // 0x7F = 0b01111111
                
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
            
            url.stopAccessingSecurityScopedResource()
        } catch {
            print("Failed to read data from file: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 400)
}
