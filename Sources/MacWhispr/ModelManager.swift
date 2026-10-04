import Foundation

struct WhisperModel: Equatable {
    let id: String
    let name: String
    let filename: String
    let sizeMB: Int
    let note: String
    static let all: [Self] = [
        .init(id: "base.en", name: "Base (English)", filename: "ggml-base.en.bin", sizeMB: 148, note: "Fastest; English only"),
        .init(id: "small.en", name: "Small (English)", filename: "ggml-small.en.bin", sizeMB: 488, note: "More accurate; English only"),
        .init(id: "medium.en", name: "Medium (English)", filename: "ggml-medium.en.bin", sizeMB: 1530, note: "High accuracy; slower"),
        .init(id: "large-v3-turbo", name: "Large v3 Turbo", filename: "ggml-large-v3-turbo.bin", sizeMB: 1620, note: "Multilingual, fast large model"),
        .init(id: "large-v3", name: "Large v3", filename: "ggml-large-v3.bin", sizeMB: 3100, note: "Highest accuracy; large download")
    ]
}

enum ModelManager {
    static var directory: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/MacWhispr/models", isDirectory: true) }
    static var selected: WhisperModel {
        get { WhisperModel.all.first { $0.id == UserDefaults.standard.string(forKey: "selectedModelID") } ?? WhisperModel.all[0] }
        set { UserDefaults.standard.set(newValue.id, forKey: "selectedModelID") }
    }
    static func url(for model: WhisperModel) -> URL { directory.appendingPathComponent(model.filename) }
    static func isInstalled(_ model: WhisperModel) -> Bool {
        isValidFile(url(for: model), model: model)
    }
    private static func isValidFile(_ url: URL, model: WhisperModel) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path), let size = attributes[.size] as? NSNumber else { return false }
        guard size.int64Value > Int64(Double(model.sizeMB) * 800_000), let file = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? file.close() }
        return (try? file.read(upToCount: 4)) == Data([0x6c, 0x6d, 0x67, 0x67])
    }
    static func download(_ model: WhisperModel, progress: @escaping (Double) -> Void) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(model.filename)")!
        let (temporary, response) = try await URLSession.shared.download(from: source, delegate: ProgressDelegate(progress))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw MacWhisprError("Model download failed. Check your connection and try again.") }
        guard isValidFile(temporary, model: model) else { throw MacWhisprError("Downloaded model is incomplete or invalid. Try downloading it again.") }
        let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard response.expectedContentLength <= 0 || Int64(size) == response.expectedContentLength else {
            throw MacWhisprError("Model download did not finish. Check your connection and try again.")
        }
        let destination = url(for: model)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        guard isInstalled(model) else { throw MacWhisprError("Downloaded model is incomplete.") }
    }
}

private final class ProgressDelegate: NSObject, URLSessionDownloadDelegate {
    let update: (Double) -> Void
    init(_ update: @escaping (Double) -> Void) { self.update = update }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        update(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }
}

struct MacWhisprError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
