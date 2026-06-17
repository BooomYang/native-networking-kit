import NativeNetKit
import SwiftUI

@main
struct NativeNetKitExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

private struct ContentView: View {
    @State private var urlText = "https://example.com"
    @State private var resultText = "Ready"
    @State private var isLoading = false

    private let client = NativeNetClient()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NativeNetKit")
                .font(.title2)
                .bold()

            TextField("URL", text: $urlText)
                .textFieldStyle(.roundedBorder)

            Button(isLoading ? "Loading..." : "GET") {
                fetch()
            }
            .disabled(isLoading)

            Text(resultText)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding()
        .frame(minWidth: 360, minHeight: 260)
    }

    private func fetch() {
        guard let url = URL(string: urlText) else {
            resultText = "Invalid URL"
            return
        }

        isLoading = true
        resultText = "Requesting..."

        Task {
            defer { isLoading = false }
            do {
                let response = try await client.get(url)
                resultText = "Status: \(response.statusCode)\nBytes: \(response.body.count)\nElapsed: \(response.elapsedMilliseconds ?? -1) ms"
            } catch {
                resultText = "Error: \(error)"
            }
        }
    }
}
