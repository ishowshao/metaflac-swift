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
            print(buffer)
            // Verify the first four bytes
            if buffer.count >= 4 &&
                buffer[0] == 0x66 &&
                buffer[1] == 0x4C &&
                buffer[2] == 0x61 &&
                buffer[3] == 0x43 {
                print("FLAC file")
                let metadataHeader = buffer[4]
                
                // Extract the last-metadata-block flag (1 bit) and block type (7 bits)
                let lastMetadataBlock = (metadataHeader & 0x80) != 0 // 0x80 = 0b10000000
                let blockType = metadataHeader & 0x7F               // 0x7F = 0b01111111
                
                // Read the next 3 bytes for the length
                if buffer.count >= 8 {
                    let length = (Int(buffer[5]) << 16) | (Int(buffer[6]) << 8) | Int(buffer[7])
                    
                    // Output the parsed values
                    print("Last Metadata Block Flag: \(lastMetadataBlock ? "Yes" : "No")")
                    print("Block Type: \(blockType)")
                    print("Metadata Length: \(length) bytes")
                } else {
                    print("Insufficient data for length field.")
                }
            } else {
                print("Not FLAC file")
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 400)
}
