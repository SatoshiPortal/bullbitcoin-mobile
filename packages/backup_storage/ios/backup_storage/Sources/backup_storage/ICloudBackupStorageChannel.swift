import Flutter
import Foundation

final class ICloudBackupStorageChannel {
    private static let queue = DispatchQueue(label: "com.bullbitcoin.backup_storage.icloud")
    private let files = FileManager.default
    private let preferences = UserDefaults.standard

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.bullbitcoin.backup_storage/icloud",
            binaryMessenger: registrar.messenger()
        )
        let storage = ICloudBackupStorageChannel()
        channel.setMethodCallHandler(storage.handle)
    }

    private enum Failure: String, Error {
        case authorizationRequired, quotaExceeded, notFound, tooLarge, unavailable, cancelled, unexpected
    }

    private struct Deadline {
        let end: DispatchTime

        func check() throws {
            guard DispatchTime.now() < end else { throw Failure.unavailable }
        }
    }

    private struct Scope {
        let container: String
        let account: String
        let documents: URL
        let deadline: Deadline
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let container = arguments["container"] as? String,
              container.hasPrefix("iCloud."),
              let milliseconds = arguments["timeoutMs"] as? Int,
              (1...20_000).contains(milliseconds) else {
            result(Self.platformError(Failure.unexpected))
            return
        }
        let deadline = Deadline(end: .now() + .milliseconds(milliseconds))
        // Both completion paths run on the main queue, including the watchdog.
        var finished = false
        let finish: FlutterResult = { value in
            guard !finished else { return }
            finished = true
            result(value)
        }
        DispatchQueue.main.asyncAfter(deadline: deadline.end) {
            finish(Self.platformError(Failure.unavailable))
        }
        let respond: FlutterResult = { value in
            DispatchQueue.main.async { finish(value) }
        }
        Self.queue.async {
            do {
                try deadline.check()
                let expected = arguments["account"] as? String
                guard call.method == "authorize" || expected != nil else {
                    throw Failure.authorizationRequired
                }
                let account = try self.identity(
                    container, expected: expected, deadline: deadline
                )
                guard let root = self.files.url(forUbiquityContainerIdentifier: container) else {
                    try self.checkIdentity(container, account: account, deadline: deadline)
                    throw Failure.unavailable
                }
                let scope = Scope(
                    container: container, account: account,
                    documents: root.appendingPathComponent("Documents", isDirectory: true),
                    deadline: deadline
                )
                try self.check(scope)
                try self.checkDocuments(scope.documents)
                switch call.method {
                case "authorize":
                    respond(account)
                case "checkAccount":
                    respond(true)
                case "list":
                    self.list(scope, prefix: arguments["prefix"] as? String, respond: respond)
                case "read":
                    let url = try self.target(arguments, in: scope)
                    guard let maximum = arguments["maxBytes"] as? Int, maximum >= 0 else {
                        throw Failure.tooLarge
                    }
                    if let knownSize = arguments["knownSize"] as? Int, knownSize > maximum {
                        throw Failure.tooLarge
                    }
                    respond(FlutterStandardTypedData(bytes: try self.read(url, scope, maximum: maximum)))
                case "create":
                    let url = try self.target(arguments, in: scope)
                    guard let bytes = arguments["bytes"] as? FlutterStandardTypedData else {
                        throw Failure.unexpected
                    }
                    respond(try self.create(url, scope, bytes: bytes.data))
                case "delete":
                    let url = try self.target(arguments, in: scope)
                    try self.materialize(url, in: scope)
                    try self.coordinateWrite(url, options: .forDeleting, deadline: scope.deadline) { coordinated in
                        try self.check(coordinated, in: scope)
                        let kind = try coordinated.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                        guard kind.isRegularFile == true, kind.isSymbolicLink != true else {
                            throw Failure.notFound
                        }
                        try self.check(scope)
                        try self.files.removeItem(at: coordinated)
                    }
                    try self.check(scope)
                    respond(true)
                default:
                    respond(FlutterMethodNotImplemented)
                }
            } catch {
                respond(Self.platformError(error))
            }
        }
    }

    private func identity(_ container: String, expected: String?, deadline: Deadline) throws -> String {
        try deadline.check()
        guard let token = files.ubiquityIdentityToken else { throw Failure.authorizationRequired }
        let key = "com.bullbitcoin.backup_storage.icloud.identity." + container
        if let identity = preferences.dictionary(forKey: key),
           let account = identity["account"] as? String,
           let archive = identity["token"] as? Data,
           let previous = (try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(archive)) as? NSObject,
           previous.isEqual(token) {
            if let expected, expected != account { throw Failure.authorizationRequired }
            return account
        }
        guard expected == nil else { throw Failure.authorizationRequired }
        let account = UUID().uuidString
        let archive = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: false)
        try deadline.check()
        preferences.set(["account": account, "token": archive], forKey: key)
        return account
    }

    private func checkIdentity(_ container: String, account: String, deadline: Deadline) throws {
        _ = try identity(container, expected: account, deadline: deadline)
    }

    private func check(_ scope: Scope) throws {
        try checkIdentity(scope.container, account: scope.account, deadline: scope.deadline)
        try scope.deadline.check()
    }

    private func target(_ arguments: [String: Any], in scope: Scope) throws -> URL {
        guard let name = arguments["name"] as? String, Self.isBackupName(name) else {
            throw Failure.notFound
        }
        return scope.documents.appendingPathComponent(name, isDirectory: false)
    }

    private func checkDocuments(_ documents: URL) throws {
        do {
            let values = try documents.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw Failure.unavailable }
        } catch where Self.failure(error) == .notFound {
            // The Documents directory is created on the first write.
        }
    }

    private func check(_ url: URL, in scope: Scope) throws {
        guard url.deletingLastPathComponent().standardizedFileURL.path ==
                scope.documents.standardizedFileURL.path else {
            throw Failure.notFound
        }
        try checkDocuments(scope.documents)
        try check(scope)
    }

    private func placeholder(for url: URL) -> URL {
        url.deletingLastPathComponent()
            .appendingPathComponent("." + url.lastPathComponent + ".icloud")
    }

    private static func isBackupName(_ name: String) -> Bool {
        name.hasSuffix(".bip138") && !name.hasPrefix(".") &&
            !name.contains("/") && !name.contains("\\") && !name.contains("\0")
    }

    private struct CloudObject {
        let url: URL
        let values: [String: Any]
    }

    private static let resourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey,
        .ubiquitousItemIsUploadedKey, .ubiquitousItemIsUploadingKey, .ubiquitousItemUploadingErrorKey,
    ]

    private func attributes(
        _ url: URL, name: String, fallback: [String: Any], isPlaceholder: Bool = false
    ) throws -> [String: Any] {
        let values = try url.resourceValues(forKeys: Self.resourceKeys)
        if let error = values.ubiquitousItemUploadingError,
           Self.failure(error) == .quotaExceeded {
            throw Failure.quotaExceeded
        }
        var object = fallback
        object["name"] = name
        if values.ubiquitousItemIsUploading == true {
            object["uploaded"] = false
        } else if let uploaded = values.ubiquitousItemIsUploaded {
            object["uploaded"] = uploaded
        }
        if !isPlaceholder, let size = values.fileSize { object["size"] = size }
        if let created = values.creationDate { object["createdMs"] = Self.milliseconds(created) }
        if let modified = values.contentModificationDate {
            object["modifiedMs"] = Self.milliseconds(modified)
        }
        return object
    }

    private static func milliseconds(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }

    private func list(_ scope: Scope, prefix: String?, respond: @escaping FlutterResult) {
        DispatchQueue.main.async {
            let query = NSMetadataQuery()
            query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
            query.predicate = NSPredicate(format: "%K ENDSWITH %@", NSMetadataItemFSNameKey, ".bip138")
            var observer: NSObjectProtocol?
            var completed = false
            func complete(_ remote: [CloudObject]?) {
                guard !completed else { return }
                completed = true
                if let observer { NotificationCenter.default.removeObserver(observer) }
                observer = nil
                query.stop()
                guard let remote else {
                    respond(Self.platformError(Failure.unavailable))
                    return
                }
                Self.queue.async {
                    do {
                        respond(try self.mergeListing(remote, scope, prefix: prefix))
                    } catch {
                        respond(Self.platformError(error))
                    }
                }
            }

            guard DispatchTime.now() < scope.deadline.end else {
                complete(nil)
                return
            }
            observer = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main
            ) { _ in
                query.disableUpdates()
                var objects: [CloudObject] = []
                for result in query.results {
                    guard DispatchTime.now() < scope.deadline.end else {
                        complete(nil)
                        return
                    }
                    guard let item = result as? NSMetadataItem,
                          let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else {
                        continue
                    }
                    let types = item.value(forAttribute: NSMetadataItemContentTypeTreeKey) as? [String]
                    if types?.contains("public.directory") == true { continue }
                    let uploaded = item.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? Bool
                    let uploading = item.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool
                    var values: [String: Any] = ["uploaded": uploaded == true && uploading != true]
                    values["size"] = item.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber
                    if let date = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date {
                        values["modifiedMs"] = Self.milliseconds(date)
                    }
                    if let date = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date {
                        values["createdMs"] = Self.milliseconds(date)
                    }
                    objects.append(CloudObject(url: url, values: values))
                }
                complete(objects)
            }
            if !query.start() { complete(nil) }
            DispatchQueue.main.asyncAfter(deadline: scope.deadline.end) { complete(nil) }
        }
    }

    private func mergeListing(_ remote: [CloudObject], _ scope: Scope, prefix: String?) throws -> [[String: Any]] {
        try check(scope)
        let directory = scope.documents.standardizedFileURL.path
        func matches(_ url: URL) -> Bool {
            url.isFileURL && url.deletingLastPathComponent().standardizedFileURL.path == directory &&
                Self.isBackupName(url.lastPathComponent) &&
                (prefix.map { url.lastPathComponent.hasPrefix($0) } ?? true)
        }

        var objects: [String: [String: Any]] = [:]
        for item in remote where matches(item.url) && !item.url.hasDirectoryPath {
            try scope.deadline.check()
            let name = item.url.lastPathComponent
            var fallback = item.values
            fallback["name"] = name
            do {
                let kind = try item.url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                if kind.isDirectory == true || kind.isSymbolicLink == true { continue }
                objects[name] = try attributes(item.url, name: name, fallback: fallback)
            } catch where Self.failure(error) == .notFound {
                objects[name] = fallback
            }
        }

        let local: [URL]
        do {
            local = try files.contentsOfDirectory(
                at: scope.documents,
                includingPropertiesForKeys: Array(Self.resourceKeys),
                options: []
            )
        } catch where Self.failure(error) == .notFound {
            local = []
        }
        // iOS represents some evicted files as hidden .<name>.icloud stubs.
        // Resolve their logical names and retain the query's logical size.
        for url in local {
            try scope.deadline.check()
            let diskName = url.lastPathComponent
            let isPlaceholder = diskName.hasPrefix(".") && diskName.hasSuffix(".icloud")
            let name = isPlaceholder ? String(diskName.dropFirst().dropLast(7)) : diskName
            let logicalURL = scope.documents.appendingPathComponent(name)
            guard matches(logicalURL) else { continue }
            do {
                let kind = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard kind.isRegularFile == true, kind.isSymbolicLink != true else {
                    objects.removeValue(forKey: name)
                    continue
                }
                let fallback = (isPlaceholder ? objects[name] : nil) ?? ["uploaded": false]
                objects[name] = try attributes(
                    url, name: name, fallback: fallback, isPlaceholder: isPlaceholder
                )
            } catch where Self.failure(error) == .notFound {
                continue
            }
        }
        try check(scope)
        return objects.keys.sorted().compactMap { objects[$0] }
    }

    private func materialize(_ url: URL, in scope: Scope) throws {
        let downloadKeys: Set<URLResourceKey> = [
            .ubiquitousItemDownloadingStatusKey, .ubiquitousItemDownloadingErrorKey,
            .isRegularFileKey, .isSymbolicLinkKey,
        ]
        func status() throws -> URLResourceValues? {
            do {
                // Use a fresh NSURL so polling does not reuse cached status.
                let freshURL = URL(fileURLWithPath: url.path)
                return try freshURL.resourceValues(forKeys: downloadKeys)
            } catch where Self.failure(error) == .notFound {
                return nil
            }
        }
        let initial = try status()
        if initial?.isSymbolicLink == true { throw Failure.notFound }
        if initial?.ubiquitousItemDownloadingStatus == .current ||
            (initial?.ubiquitousItemDownloadingStatus == nil &&
             initial?.isRegularFile == true && files.fileExists(atPath: url.path)) {
            // A fresh local write can be readable before iCloud publishes metadata.
            return
        }
        try check(scope)
        try files.startDownloadingUbiquitousItem(at: url)
        while true {
            try check(scope)
            let current = try status()
            if let error = current?.ubiquitousItemDownloadingError { throw error }
            if current?.ubiquitousItemDownloadingStatus == .current { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    private func read(_ url: URL, _ scope: Scope, maximum: Int) throws -> Data {
        try materialize(url, in: scope)
        let (coordinator, cancellation) = scheduledCoordinator(scope.deadline)
        defer { cancellation.cancel() }
        var coordinationError: NSError?
        var outcome: Result<Data, Error>?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinated in
            outcome = Result {
                try self.check(coordinated, in: scope)
                let values = try coordinated.resourceValues(forKeys: [
                    .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey,
                ])
                guard values.isRegularFile == true, values.isSymbolicLink != true else {
                    throw Failure.notFound
                }
                if let size = values.fileSize, size > maximum { throw Failure.tooLarge }

                let file = try FileHandle(forReadingFrom: coordinated)
                defer { try? file.close() }
                var bytes = Data()
                while true {
                    try scope.deadline.check()
                    let remaining = maximum - bytes.count
                    let count = min(remaining, 64 * 1024 - 1) + 1
                    guard let chunk = try file.read(upToCount: count), !chunk.isEmpty else { break }
                    guard chunk.count <= remaining else { throw Failure.tooLarge }
                    bytes.append(chunk)
                }
                return bytes
            }
        }
        try scope.deadline.check()
        if let coordinationError { throw coordinationError }
        guard let outcome else { throw Failure.unavailable }
        let bytes = try outcome.get()
        try check(scope)
        return bytes
    }

    private func create(_ url: URL, _ scope: Scope, bytes: Data) throws -> [String: Any] {
        try check(scope)
        try files.createDirectory(at: scope.documents, withIntermediateDirectories: true)
        try checkDocuments(scope.documents)
        try coordinateWrite(url, options: [], deadline: scope.deadline) { coordinated in
            try self.check(coordinated, in: scope)
            guard !self.files.fileExists(atPath: self.placeholder(for: coordinated).path) else {
                throw Failure.unavailable
            }
            let staging = coordinated.deletingLastPathComponent()
                .appendingPathComponent("." + UUID().uuidString)
            defer { try? self.files.removeItem(at: staging) }
            try bytes.write(to: staging, options: .withoutOverwriting)
            try self.check(scope)
            try self.files.moveItem(at: staging, to: coordinated)
        }
        try check(scope)
        return try attributes(
            url, name: url.lastPathComponent, fallback: ["uploaded": false, "size": bytes.count]
        )
    }

    private func scheduledCoordinator(_ deadline: Deadline) -> (NSFileCoordinator, DispatchWorkItem) {
        let coordinator = NSFileCoordinator()
        // Foundation allows cancelling from another thread while access is pending.
        let cancellation = DispatchWorkItem { coordinator.cancel() }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: deadline.end, execute: cancellation)
        return (coordinator, cancellation)
    }

    private func coordinateWrite(
        _ url: URL, options: NSFileCoordinator.WritingOptions, deadline: Deadline,
        action: (URL) throws -> Void
    ) throws {
        let (coordinator, cancellation) = scheduledCoordinator(deadline)
        defer { cancellation.cancel() }
        var coordinationError: NSError?
        var outcome: Result<Void, Error>?
        coordinator.coordinate(writingItemAt: url, options: options, error: &coordinationError) { coordinated in
            outcome = Result { try action(coordinated) }
        }
        try deadline.check()
        if let coordinationError { throw coordinationError }
        guard let outcome else { throw Failure.unavailable }
        try outcome.get()
    }

    private static func failure(_ error: Error) -> Failure {
        if let failure = error as? Failure { return failure }
        let native = error as NSError
        if native.domain == NSPOSIXErrorDomain {
            switch native.code {
            case Int(POSIXErrorCode.ENOSPC.rawValue): return .quotaExceeded
            case Int(POSIXErrorCode.ENOENT.rawValue): return .notFound
            default: break
            }
        }
        if native.domain == NSCocoaErrorDomain {
            switch native.code {
            case NSUbiquitousFileNotUploadedDueToQuotaError, NSFileWriteOutOfSpaceError:
                return .quotaExceeded
            case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
                return .notFound
            case NSUbiquitousFileUnavailableError, NSUbiquitousFileUbiquityServerNotAvailable:
                return .unavailable
            case NSUserCancelledError:
                return .cancelled
            default:
                break
            }
        }
        if let underlying = native.userInfo[NSUnderlyingErrorKey] as? NSError, underlying !== native {
            return failure(underlying)
        }
        return .unavailable
    }

    private static func platformError(_ error: Error) -> FlutterError {
        FlutterError(code: failure(error).rawValue, message: nil, details: nil)
    }
}
