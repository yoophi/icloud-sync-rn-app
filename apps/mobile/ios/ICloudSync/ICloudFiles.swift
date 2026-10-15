import Foundation
import React
import UIKit
import PhotosUI
import UniformTypeIdentifiers

@objc(ICloudFiles)
final class ICloudFiles: NSObject, PHPickerViewControllerDelegate {
  private let queue = DispatchQueue(label: "com.yoophi.icloudsync.files")
  private var queries: [UUID: NSMetadataQuery] = [:]
  private var pickerResolve: RCTPromiseResolveBlock?
  private var pickerReject: RCTPromiseRejectBlock?

  @objc static func requiresMainQueueSetup() -> Bool { true }

  private func documents() throws -> CloudDocuments {
    let manager = FileManager.default
    guard manager.ubiquityIdentityToken != nil else {
      throw NSError(domain: "ICloudFiles", code: 1, userInfo: [NSLocalizedDescriptionKey:
        "iCloud에 연결할 수 없습니다. iPhone 설정에서 Apple 계정과 iCloud Drive를 확인하세요."])
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
    // Check cloud access before presenting a picker: never silently fall back to local storage.
    perform({ _ in
      DispatchQueue.main.async {
        guard self.pickerResolve == nil else {
          reject("PICKER_BUSY", "사진 선택기가 이미 열려 있습니다.", nil)
          return
        }
        guard var presenter = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
          .flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController else {
          reject("PICKER_ERROR", "사진 선택기를 열 수 없습니다.", nil)
          return
        }
        while let presented = presenter.presentedViewController { presenter = presented }
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        // Compatible representations allow HEIC photos to be viewed consistently.
        configuration.preferredAssetRepresentationMode = .compatible
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        self.pickerResolve = resolve
        self.pickerReject = reject
        presenter.present(picker, animated: true)
      }
    }, reject) { _ in true }
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let resolve = pickerResolve, let reject = pickerReject else { return }
    pickerResolve = nil
    pickerReject = nil
    guard let provider = results.first?.itemProvider else { resolve(NSNull()); return }
    let type = provider.registeredTypeIdentifiers.first {
      guard let contentType = UTType($0) else { return false }
      return contentType.conforms(to: .image)
    } ?? UTType.image.identifier
    provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
      guard let source = url else {
        reject("IMAGE_IMPORT_ERROR", error?.localizedDescription ?? "이미지를 가져올 수 없습니다.", error)
        return
      }
      // Provider URLs live only for this callback. Copy before the callback returns.
      do {
        let store = try self.documents()
        resolve(try store.importImage(from: source))
      } catch { reject("IMAGE_IMPORT_ERROR", error.localizedDescription, error) }
    }
  }
}
