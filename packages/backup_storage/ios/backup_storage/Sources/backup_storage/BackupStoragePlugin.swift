import CryptoKit
import Darwin
import Flutter
import Foundation
import UIKit
import UniformTypeIdentifiers

public final class BackupStoragePlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
    private let io = DispatchQueue(label: "com.bullbitcoin.backup_storage.folder")
    private weak var registrar: FlutterPluginRegistrar?
    private var picker: UIDocumentPickerViewController?
    private var pendingPick: FlutterResult?

    private init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.bullbitcoin.backup_storage/folder",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(BackupStoragePlugin(registrar: registrar), channel: channel)
        ICloudBackupStorageChannel.register(with: registrar)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "pick":
            pick(result)
        case "inspect", "list", "create", "read", "delete":
            io.async {
                self.respond(result) { try self.operate(call) }
            }
        case "release":
            // The bookmark lives only in the injected Dart store.
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func pick(_ result: @escaping FlutterResult) {
        guard picker == nil, var presenter = registrar?.viewController else {
            result(FlutterError(code: "unavailable", message: nil, details: nil))
            return
        }
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        guard presenter.viewIfLoaded?.window != nil else {
            result(FlutterError(code: "unavailable", message: nil, details: nil))
            return
        }

        let dialog = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        dialog.delegate = self
        dialog.allowsMultipleSelection = false
        picker = dialog
        pendingPick = result
        presenter.present(dialog, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 115) { [weak self, weak dialog] in
            guard let self, let dialog, let callback = self.finishPick(dialog) else { return }
            dialog.dismiss(animated: true)
            callback(FlutterError(code: "unavailable", message: nil, details: nil))
        }
    }

    private func finishPick(_ dialog: UIDocumentPickerViewController) -> FlutterResult? {
        guard picker === dialog else { return nil }
        let callback = pendingPick
        picker = nil
        pendingPick = nil
        return callback
    }

    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finishPick(controller)?(FlutterError(code: "cancelled", message: nil, details: nil))
    }

    public func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let callback = finishPick(controller) else { return }
        io.async {
            self.respond(callback) {
                guard let url = urls.first else { throw FolderError.revoked }
                return try self.withScope(url) {
                    // iOS document picker URLs carry the security scope in a minimal bookmark.
                    let bookmark = try url.bookmarkData(
                        options: .minimalBookmark,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    var info = try self.inspect(url)
                    info["token"] = bookmark.base64EncodedString()
                    return info
                }
            }
        }
    }

    private func operate(_ call: FlutterMethodCall) throws -> Any? {
        guard let args = call.arguments as? [String: Any],
              let token = args["token"] as? String,
              let data = Data(base64Encoded: token) else { throw FolderError.revoked }
        var stale = false
        let root: URL
        do {
            root = try URL(
                resolvingBookmarkData: data,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
        } catch {
            throw FolderError.revoked
        }
        guard !stale else { throw FolderError.revoked }

        return try withScope(root) {
            let info = try inspect(root)
            if call.method != "inspect", args["accountId"] as? String != info["id"] {
                throw FolderError.revoked
            }
            switch call.method {
            case "inspect":
                return info
            case "list":
                return try coordinate(root, writing: nil) { folder in
                    let files = try FileManager.default.contentsOfDirectory(
                        at: folder,
                        includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey],
                        options: []
                    )
                    return try files.compactMap { try self.entry($0) }
                }
            case "create":
                guard let name = args["name"] as? String,
                      let bytes = args["bytes"] as? FlutterStandardTypedData else {
                    throw FolderError.unexpected
                }
                let target = try directChild(root, name)
                try coordinate(target, writing: []) { url in
                    try bytes.data.write(to: url, options: .withoutOverwriting)
                }
                return ["id": name, "name": name, "size": bytes.data.count]
            case "read":
                guard let id = args["id"] as? String,
                      let maxBytes = args["maxBytes"] as? Int else {
                    throw FolderError.unexpected
                }
                let target = try directChild(root, id)
                guard let metadata = try entry(target) else { throw FolderError.notFound }
                if let size = metadata["size"] as? Int, size > maxBytes { throw FolderError.tooLarge }
                return try coordinate(target, writing: nil) { url in
                    guard try self.entry(url) != nil else { throw FolderError.notFound }
                    return FlutterStandardTypedData(bytes: try self.read(url, maxBytes: maxBytes))
                }
            case "delete":
                guard let id = args["id"] as? String else { throw FolderError.unexpected }
                let target = try directChild(root, id)
                try coordinate(target, writing: .forDeleting) { url in
                    guard try self.entry(url) != nil else { throw FolderError.notFound }
                    try self.unlinkFile(url)
                }
                return nil
            default:
                throw FolderError.unexpected
            }
        }
    }

    private func withScope<T>(_ url: URL, operation: () throws -> T) throws -> T {
        guard url.startAccessingSecurityScopedResource() else { throw FolderError.revoked }
        defer { url.stopAccessingSecurityScopedResource() }
        return try operation()
    }

    private func inspect(_ root: URL) throws -> [String: String] {
        do {
            let values = try root.resourceValues(forKeys: [
                .isDirectoryKey, .localizedNameKey, .documentIdentifierKey, .volumeUUIDStringKey
            ])
            guard values.isDirectory == true else { throw FolderError.revoked }
            // Use the resolved location rather than the bookmark serialization, which may
            // change each time the user selects the same folder.
            let location: String
            if let volume = values.volumeUUIDString, let document = values.documentIdentifier {
                location = "document:\(volume):\(document)"
            } else {
                location = "path:\(root.standardizedFileURL.resolvingSymlinksInPath().path)"
            }
            let identity = SHA256.hash(data: Data(location.utf8))
                .map { String(format: "%02x", $0) }.joined()
            return ["id": identity, "name": values.localizedName ?? root.lastPathComponent]
        } catch {
            if failureCode(error) == "notFound" { throw FolderError.revoked }
            throw error
        }
    }

    private func directChild(_ root: URL, _ name: String) throws -> URL {
        guard !name.isEmpty, name != ".", name != "..",
              !name.contains("/"), !name.contains("\\"), !name.contains("\0") else {
            throw FolderError.unexpected
        }
        return root.appendingPathComponent(name, isDirectory: false)
    }

    private func entry(_ url: URL) throws -> [String: Any]? {
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey
        ])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { return nil }
        let name = url.lastPathComponent
        var info: [String: Any] = ["id": name, "name": name]
        if let size = values.fileSize { info["size"] = size }
        if let modified = values.contentModificationDate {
            info["modifiedMs"] = Int64(modified.timeIntervalSince1970 * 1000)
        }
        return info
    }

    private func read(_ url: URL, maxBytes: Int) throws -> Data {
        guard maxBytes >= 0 else { throw FolderError.tooLarge }
        guard let descriptor = url.withUnsafeFileSystemRepresentation({ path in
            path.map { Darwin.open($0, O_RDONLY | O_NOFOLLOW) }
        }) else { throw FolderError.notFound }
        guard descriptor >= 0 else { throw posixError() }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var bytes = Data()
        while let chunk = try handle.read(upToCount: min(8191, maxBytes - bytes.count) + 1),
              !chunk.isEmpty {
            guard chunk.count <= maxBytes - bytes.count else { throw FolderError.tooLarge }
            bytes.append(chunk)
        }
        return bytes
    }

    private func unlinkFile(_ url: URL) throws {
        guard let result = url.withUnsafeFileSystemRepresentation({ path in
            path.map { Darwin.unlink($0) }
        }) else { throw FolderError.notFound }
        guard result == 0 else { throw posixError() }
    }

    private func posixError() -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
    }

    private func coordinate<T>(
        _ url: URL,
        writing: NSFileCoordinator.WritingOptions?,
        operation: @escaping (URL) throws -> T
    ) throws -> T {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var failure: NSError?
        var outcome: Result<T, Error>?
        let accessor: (URL) -> Void = { coordinated in
            outcome = Result { try operation(coordinated) }
        }
        if let writing {
            coordinator.coordinate(writingItemAt: url, options: writing, error: &failure, byAccessor: accessor)
        } else {
            coordinator.coordinate(readingItemAt: url, options: [], error: &failure, byAccessor: accessor)
        }
        if let failure { throw failure }
        guard let outcome else { throw FolderError.unavailable }
        return try outcome.get()
    }

    private func respond(_ result: FlutterResult, operation: () throws -> Any?) {
        let response: Any?
        do {
            response = try operation()
        } catch {
            response = FlutterError(code: failureCode(error), message: nil, details: nil)
        }
        DispatchQueue.main.async { result(response) }
    }

    private func failureCode(_ error: Error) -> String {
        if let folder = error as? FolderError { return folder.rawValue }
        let native = error as NSError
        if native.domain == NSCocoaErrorDomain {
            switch CocoaError.Code(rawValue: native.code) {
            case .fileWriteOutOfSpace: return "quotaExceeded"
            case .fileReadNoPermission, .fileWriteNoPermission: return "permissionRevoked"
            case .fileNoSuchFile, .fileReadNoSuchFile: return "notFound"
            default: break
            }
        }
        if native.domain == NSPOSIXErrorDomain {
            switch native.code {
            case Int(ENOSPC), Int(EDQUOT): return "quotaExceeded"
            case Int(EACCES), Int(EPERM): return "permissionRevoked"
            case Int(ENOENT), Int(ELOOP), Int(EISDIR): return "notFound"
            default: break
            }
        }
        if let underlying = native.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying !== native {
            return failureCode(underlying)
        }
        return "unavailable"
    }

    private enum FolderError: String, Error {
        case revoked = "permissionRevoked"
        case notFound
        case tooLarge
        case unavailable
        case unexpected
    }
}
