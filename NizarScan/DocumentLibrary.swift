import Foundation
import UIKit
import Combine

struct ScanDocument: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var createdAt: Date = Date()
    var imageNames: [String]
    var extractedText: String = ""
}

@MainActor final class DocumentLibrary: ObservableObject {
    @Published private(set) var documents: [ScanDocument] = []
    private let folder: URL
    private let indexURL: URL

    init() {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folder = base.appendingPathComponent("Scans", isDirectory: true)
        indexURL = folder.appendingPathComponent("documents.json")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        load()
    }

    func imageURL(named name: String) -> URL { folder.appendingPathComponent(name) }

    func add(images: [UIImage], title: String) {
        let names = images.compactMap { image -> String? in
            let name = UUID().uuidString + ".jpg"
            guard let data = image.jpegData(compressionQuality: 0.92) else { return nil }
            do { try data.write(to: imageURL(named: name), options: .atomic); return name }
            catch { return nil }
        }
        guard !names.isEmpty else { return }
        documents.insert(ScanDocument(title: title.isEmpty ? "New Scan" : title, imageNames: names), at: 0)
        persist()
    }

    func updateText(_ text: String, for id: UUID) {
        guard let i = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[i].extractedText = text; persist()
    }

    func rename(_ doc: ScanDocument, to title: String) {
        guard let i = documents.firstIndex(where: { $0.id == doc.id }) else { return }
        documents[i].title = title; persist()
    }

    func delete(_ doc: ScanDocument) {
        documents.removeAll { $0.id == doc.id }
        doc.imageNames.forEach { try? FileManager.default.removeItem(at: imageURL(named: $0)) }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL), let saved = try? JSONDecoder().decode([ScanDocument].self, from: data) else { return }
        documents = saved.sorted { $0.createdAt > $1.createdAt }
    }
    private func persist() {
        guard let data = try? JSONEncoder().encode(documents) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
