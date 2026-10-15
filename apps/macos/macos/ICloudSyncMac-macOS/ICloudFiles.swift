import Foundation
import React
import AppKit
import UniformTypeIdentifiers

@objc(ICloudFiles)
final class ICloudFiles: NSObject {
  private let queue = DispatchQueue(label: "com.yoophi.icloudsync.files")
  private var queries: [UUID: NSMetadataQuery] = [:]
  private var pickerOpen = false

  @objc static func requiresMainQueueSetup() -> Bool { true }

  private func documents() throws -> CloudDocuments {
    let manager = FileManager.default
    guard manager.ubiquityIdentityToken != nil else {
      throw NSError(domain: "ICloudFiles", code: 1, userInfo: [NSLocalizedDescriptionKey:
        "iCloud에 연결할 수 없습니다. Mac 시스템 설정에서 Apple 계정과 iCloud Drive를 확인하세요."])
    }
    let identifier = Bundle.main.object(forInfoDictionaryKey: "ICloudContainerIdentifier") as? String
    guard let root = manager.url(forUbiquityContainerIdentifier: identifier) else {
      throw NSError(domain: "ICloudFiles", code: 2, userInfo: [NSLocalizedDescriptionKey:
        "iCloud 컨테이너에 접근할 수 없습니다. 개발 팀, iCloud capability 및 서명 설정을 확인하세요."])
    }
    return try CloudDocuments(root: root.appendingPathComponent("Documents", isDirectory: true))
  }

  private func perform(_ resolve: @escaping RCTPromiseResolveBlock,
                       _ reject: @escaping RCTPromiseRejectBlock,
                       action: @escaping (CloudDocuments) throws -> Any) {
    queue.async {
      do { resolve(try action(self.documents())) }
      catch { reject("ICLOUD_FILE_ERROR", error.localizedDescription, error) }
    }
  }

  @objc func getState(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    perform(resolve, reject) { ["available": true, "directory": $0.root.path] }
  }

  @objc func listFiles(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    queue.async {
      do {
        let store = try self.documents()
        // Metadata queries discover files on other devices, including undownloaded files.
        DispatchQueue.main.async {
          let id = UUID()
          let query = NSMetadataQuery()
          query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
          query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*")
          self.queries[id] = query
          var observer: NSObjectProtocol?
          var finished = false
          let finish: (Bool) -> Void = { timedOut in
            guard !finished else { return }
            finished = true
            query.disableUpdates()
            let urls = (query.results as? [NSMetadataItem] ?? []).compactMap {
              $0.value(forAttribute: NSMetadataItemURLKey) as? URL
            }
            query.stop()
            if let token = observer { NotificationCenter.default.removeObserver(token) }
            self.queries.removeValue(forKey: id)
            if timedOut {
              reject("ICLOUD_QUERY_ERROR", "iCloud 목록을 가져오지 못했습니다. 다시 새로고침하세요.", nil)
            } else {
              self.queue.async {
                do { resolve(try store.list(metadataURLs: urls)) }
                catch { reject("ICLOUD_FILE_ERROR", error.localizedDescription, error) }
              }
            }
          }
          observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering,
            object: query, queue: .main) { _ in finish(false) }
          if !query.start() { finish(true) }
          DispatchQueue.main.asyncAfter(deadline: .now() + 20) { finish(true) }
        }
      } catch { reject("ICLOUD_FILE_ERROR", error.localizedDescription, error) }
    }
  }

  @objc func readText(_ name: String, resolver resolve: @escaping RCTPromiseResolveBlock,
                      rejecter reject: @escaping RCTPromiseRejectBlock) {
    perform(resolve, reject) { try $0.readText(name: name) }
  }

  @objc func writeText(_ name: String, text: String, create: Bool,
                       resolver resolve: @escaping RCTPromiseResolveBlock,
                       rejecter reject: @escaping RCTPromiseRejectBlock) {
    perform(resolve, reject) { store in
      try store.writeText(name: name, text: text, create: create)
      return NSNull()
    }
  }

  @objc func imageURI(_ name: String, resolver resolve: @escaping RCTPromiseResolveBlock,
                      rejecter reject: @escaping RCTPromiseRejectBlock) {
    perform(resolve, reject) { store in
      let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("CloudPreviews", isDirectory: true)
      return try store.previewImage(name: name, cache: cache).absoluteString
    }
  }

  @objc func deleteImage(_ name: String, resolver resolve: @escaping RCTPromiseResolveBlock,
                         rejecter reject: @escaping RCTPromiseRejectBlock) {
    perform(resolve, reject) { store in
      try store.deleteImage(name: name)
      return NSNull()
    }
  }

  @objc func importImage(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    perform({ _ in
      DispatchQueue.main.async {
        guard !self.pickerOpen else {
          reject("PICKER_BUSY", "파일 선택기가 이미 열려 있습니다.", nil)
          return
        }
        self.pickerOpen = true
        let panel = NSOpenPanel()
        panel.title = "iCloud에 등록할 이미지 선택"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = CloudDocuments.imageExtensions.compactMap { UTType(filenameExtension: $0) }
        panel.begin { response in
          self.pickerOpen = false
          guard response == .OK, let source = panel.url else { resolve(NSNull()); return }
          self.queue.async {
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            do { resolve(try self.documents().importImage(from: source)) }
            catch { reject("IMAGE_IMPORT_ERROR", error.localizedDescription, error) }
          }
        }
      }
    }, reject) { _ in true }
  }
}
