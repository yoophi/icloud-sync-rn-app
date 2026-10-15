import Foundation

@main
struct CloudDocumentsTests {
  static func main() throws {
    let manager = FileManager.default
    let temporary = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? manager.removeItem(at: temporary) }
    let documents = temporary.appendingPathComponent("Documents")
    let store = try CloudDocuments(root: documents)
    func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
      if try !condition() { fatalError(message) }
    }
    func fails(_ message: String, _ action: () throws -> Void) {
      do { try action(); fatalError(message) } catch { /* expected */ }
    }
    try expect(store.list().isEmpty, "A new directory should be empty")
    try store.writeText(name: "한글.md", text: "# 제목\n**원문** 📷", create: true)
    try expect(store.readText(name: "한글.md") == "# 제목\n**원문** 📷", "UTF-8 markdown must roundtrip")
    try store.writeText(name: "한글.md", text: "수정", create: false)
    try expect(store.readText(name: "한글.md") == "수정", "Edits must persist")
    fails("Creation must not overwrite a file") { try store.writeText(name: "한글.md", text: "lost", create: true) }
    fails("An update must not recreate a deleted file") { try store.writeText(name: "missing.md", text: "lost", create: false) }
    fails("A filename must not escape the documents folder") { _ = try store.url(name: "../outside.md") }
    let source = temporary.appendingPathComponent("source.png")
    let bytes = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6WQAAAABJRU5ErkJggg==")!
    try bytes.write(to: source)
    let imported = try store.importImage(from: source)
    let preview = try store.previewImage(name: imported, cache: temporary.appendingPathComponent("cache"))
    try expect(Data(contentsOf: preview) == bytes, "Image preview must contain the imported bytes")
    try expect(store.list().count == 2, "Both file types should be listed")
    try store.deleteImage(name: imported)
    try expect(store.list().count == 1, "The image should be removed from the list")
    fails("Image deletion must not delete markdown") { try store.deleteImage(name: "한글.md") }
    // Simulate an undownloaded iCloud placeholder and metadata-only file discovery.
    try Data().write(to: documents.appendingPathComponent(".remote.md.icloud"))
    fails("Cloud placeholders must not be overwritten") { try store.writeText(name: "remote.md", text: "lost", create: true) }
    try manager.createDirectory(at: documents.appendingPathComponent("folder.md"), withIntermediateDirectories: true)
    let listed = try store.list(metadataURLs: [documents.appendingPathComponent("metadata.md")])
    try expect(listed.contains { $0["name"] as? String == "remote.md" }, "Placeholder names must be normalized")
    try expect(listed.contains { $0["name"] as? String == "metadata.md" }, "Metadata-only files must be visible")
    try expect(!listed.contains { $0["name"] as? String == "folder.md" }, "Directories must not appear as files")
    print("PASS: native coordinated markdown IO, UTF-8, duplicate/missing file handling, image import/preview/delete, cloud file discovery")
  }
}
