import Foundation

/// All operations target the supplied Documents directory. Production supplies an
/// iCloud ubiquity container; tests supply an isolated temporary directory.
final class CloudDocuments {
  let root: URL
  private let manager = FileManager.default
  static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff"]

  init(root: URL) throws {
    self.root = root.standardizedFileURL
    try manager.createDirectory(at: root, withIntermediateDirectories: true)
  }

  enum Failure: LocalizedError {
    case invalidName, missing, exists, coordination, unsupported
    var errorDescription: String? {
      switch self {
      case .invalidName: return "파일 이름을 확인하세요. 경로 구분자는 사용할 수 없습니다."
      case .missing: return "파일이 없습니다. 목록을 새로고침하세요."
      case .exists: return "같은 이름의 파일이 있습니다. 다른 이름을 사용하세요."
      case .coordination: return "iCloud 파일 작업을 완료하지 못했습니다. 다시 시도하세요."
      case .unsupported: return "지원하지 않는 파일 형식입니다."
      }
    }
  }

  func url(name: String) throws -> URL {
    guard !name.isEmpty, name != ".", name != "..", !name.contains("/"),
          !name.contains(":"), !name.contains("\\"), !name.hasPrefix(".") else {
      throw Failure.invalidName
    }
    return root.appendingPathComponent(name)
  }

  private func coordinated<T>(_ url: URL, writing: NSFileCoordinator.WritingOptions? = nil,
                              action: (URL) throws -> T) throws -> T {
    let coordinator = NSFileCoordinator()
    var coordinationError: NSError?
    var result: Result<T, Error>?
    if let options = writing {
      coordinator.coordinate(writingItemAt: url, options: options, error: &coordinationError) { coordinatedURL in
        result = Result { try action(coordinatedURL) }
      }
    } else {
      coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
        result = Result { try action(coordinatedURL) }
      }
    }
    if let error = coordinationError { throw error }
    guard let result = result else { throw Failure.coordination }
    return try result.get()
  }

  func list(metadataURLs: [URL] = []) throws -> [[String: Any]] {
    let diskURLs = try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
    var names = Set<String>()
    for item in diskURLs + metadataURLs where item.deletingLastPathComponent().standardizedFileURL.path == root.path {
      if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { continue }
      var name = item.lastPathComponent
      // Ubiquitous files which have not downloaded may have placeholder names.
      if name.hasPrefix("."), name.hasSuffix(".icloud") {
        name = String(name.dropFirst().dropLast(7))
      }
      let ext = (name as NSString).pathExtension.lowercased()
      if !name.hasPrefix("."), ext == "md" || Self.imageExtensions.contains(ext) { names.insert(name) }
    }
    return try names.sorted().map { name in
      let item = try url(name: name)
      let values = try? item.resourceValues(forKeys: [.ubiquitousItemIsUploadingKey,
        .ubiquitousItemIsUploadedKey, .ubiquitousItemDownloadingStatusKey,
        .ubiquitousItemDownloadingErrorKey, .ubiquitousItemUploadingErrorKey])
      var status = "저장됨"
      if values?.ubiquitousItemIsUploading == true { status = "업로드 중" }
      else if values?.ubiquitousItemIsUploaded == true { status = "업로드됨" }
      if values?.ubiquitousItemDownloadingStatus == .notDownloaded { status = "iCloud에 있음" }
      if values?.ubiquitousItemDownloadingStatus == .downloaded { status = "업데이트 대기" }
      if let error = values?.ubiquitousItemDownloadingError ?? values?.ubiquitousItemUploadingError {
        status = error.localizedDescription
      }
      return ["name": name, "kind": item.pathExtension.lowercased() == "md" ? "markdown" : "image", "status": status]
    }
  }

  func writeText(name: String, text: String, create: Bool) throws {
    guard (name as NSString).pathExtension.lowercased() == "md" else { throw Failure.unsupported }
    let destination = try url(name: name)
    // .forReplacing permits the atomic save to coordinate with the iCloud daemon.
    try coordinated(destination, writing: create ? [] : .forReplacing) { target in
      if create && (manager.fileExists(atPath: target.path) || manager.fileExists(atPath: root.appendingPathComponent(".\(name).icloud").path)) { throw Failure.exists }
      if !create && !manager.fileExists(atPath: target.path) { throw Failure.missing }
      try Data(text.utf8).write(to: target, options: .atomic)
    }
  }

  func readText(name: String) throws -> String {
    guard (name as NSString).pathExtension.lowercased() == "md" else { throw Failure.unsupported }
    let source = try url(name: name)
    try download(source)
    return try coordinated(source) { try String(contentsOf: $0, encoding: .utf8) }
  }

  func importImage(from source: URL) throws -> String {
    let ext = source.pathExtension.lowercased()
    guard Self.imageExtensions.contains(ext) else { throw Failure.unsupported }
    let name = "photo-\(UUID().uuidString).\(ext)"
    let destination = try url(name: name)
    try coordinated(destination, writing: []) { try manager.copyItem(at: source, to: $0) }
    return name
  }

  func previewImage(name: String, cache: URL) throws -> URL {
    let source = try url(name: name)
    guard Self.imageExtensions.contains(source.pathExtension.lowercased()) else { throw Failure.unsupported }
    try download(source)
    try manager.createDirectory(at: cache, withIntermediateDirectories: true)
    // A fresh URI ensures React Native does not show stale cached image contents.
    let destination = cache.appendingPathComponent("\(UUID().uuidString).\(source.pathExtension)")
    try coordinated(source) { try manager.copyItem(at: $0, to: destination) }
    return destination
  }

  func deleteImage(name: String) throws {
    let source = try url(name: name)
    guard Self.imageExtensions.contains(source.pathExtension.lowercased()) else { throw Failure.unsupported }
    try coordinated(source, writing: .forDeleting) { try manager.removeItem(at: $0) }
  }

  private func download(_ url: URL) throws {
    if (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true
        || !manager.fileExists(atPath: url.path) {
      try manager.startDownloadingUbiquitousItem(at: url)
    }
    // The coordinated read waits for iCloud to make the file available locally.
  }
}
