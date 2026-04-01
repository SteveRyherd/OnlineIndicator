import Foundation
import AppKit

// MARK: - Semantic Version

/// Parses and compares version strings robustly.
/// Handles leading "v"/"V" prefix, pre-release suffixes ("-beta", "-rc.1", etc.),
/// build metadata ("+001"), and version strings shorter than three components.
/// Only the numeric release segment (X.Y.Z…) participates in ordering.
private struct SemanticVersion: Comparable, Equatable {

    let components: [Int]

    init?(_ raw: String) {
        var s = raw.trimmingCharacters(in: .whitespaces)

        // Strip leading "v" or "V"
        if s.first == "v" || s.first == "V" { s = String(s.dropFirst()) }

        // Strip pre-release suffix (anything from the first "-" or "+")
        for delimiter in ["-", "+"] {
            if let idx = s.firstIndex(of: delimiter.first!) {
                s = String(s[..<idx])
            }
        }

        // Split on "." and parse numeric components; reject fully empty result
        let parts = s.split(separator: ".").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        components = parts
    }

    // Pads shorter array with zeroes so 1.2 == 1.2.0
    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let len = max(lhs.components.count, rhs.components.count)
        for i in 0..<len {
            let l = i < lhs.components.count ? lhs.components[i] : 0
            let r = i < rhs.components.count ? rhs.components[i] : 0
            if l < r { return true  }
            if l > r { return false }
        }
        return false
    }
}

// MARK: - UpdateChecker

class UpdateChecker: NSObject {

    // MARK: - Shared instance (owns the active download task)
    static let shared = UpdateChecker()

    // MARK: - Repository coordinates
    static let repoOwner = "bornexplorer"
    static let repoName  = "OnlineIndicator"

    private static var apiURL: URL? {
        URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")
    }

    // MARK: - Download state
    private var downloadTask: URLSessionDownloadTask?
    private var progressTimer: Timer?

    // MARK: - Result types

    enum UpdateResult {
        case upToDate
        case updateAvailable(releaseTag: String, notes: String?, downloadURL: URL?, pageURL: URL)
        case error(String)
    }

    enum InstallResult {
        /// Automated install succeeded — a new instance is launching; this one is terminating.
        case relaunching
        /// Copy failed (permissions, etc.) — DMG has been mounted and shown in Finder.
        /// App will quit after a short delay so the user can drag-install manually.
        case openedForManualInstall(mountURL: URL)
        /// Everything failed — error message to show the user.
        case failed(String)
    }

    // MARK: - Check for updates

    static func check(completion: @escaping (UpdateResult) -> Void) {
        guard let url = apiURL else {
            completion(.error("Invalid repository URL"))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.error(error.localizedDescription))
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    completion(.error("Invalid response from GitHub"))
                    return
                }

                // GitHub returns a "message" key when the repo / release is not found
                if let message = json["message"] as? String {
                    completion(.error(message))
                    return
                }

                guard let tag = json["tag_name"] as? String,
                      let pageURLString = json["html_url"] as? String,
                      let pageURL = URL(string: pageURLString)
                else {
                    completion(.error("Unexpected response format"))
                    return
                }

                // Robust version comparison via SemanticVersion
                guard let remote = SemanticVersion(tag),
                      let local  = SemanticVersion(AppInfo.marketingVersion)
                else {
                    completion(.error("Could not parse version numbers"))
                    return
                }

                guard remote > local else {
                    completion(.upToDate)
                    return
                }

                let notes = json["body"] as? String

                // Prefer the first .dmg asset; fall back to nil (UI will show release page instead)
                var downloadURL: URL?
                if let assets = json["assets"] as? [[String: Any]] {
                    let dmg = assets.first { ($0["name"] as? String)?.hasSuffix(".dmg") == true }
                    if let urlString = dmg?["browser_download_url"] as? String {
                        downloadURL = URL(string: urlString)
                    }
                }

                completion(.updateAvailable(
                    releaseTag:  tag,
                    notes:       notes,
                    downloadURL: downloadURL,
                    pageURL:     pageURL
                ))
            }
        }.resume()
    }

    // MARK: - Download

    /// Starts downloading `url` to a temporary file.
    /// `progressHandler` is called on the main thread with values in 0…1.
    /// `completion` is called on the main thread with the local .dmg URL on success.
    func startDownload(
        from url: URL,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        cancelDownload()

        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, _, error in
            self?.stopProgressTimer()

            // Swallow task-cancelled errors silently (user cancelled)
            if let urlError = error as? URLError, urlError.code == .cancelled { return }

            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let tempURL = tempURL else {
                    completion(.failure(DownloadError.noFile))
                    return
                }
                // Move to a stable temp path before the completion handler returns
                let stableURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("dmg")
                do {
                    try FileManager.default.moveItem(at: tempURL, to: stableURL)
                    completion(.success(stableURL))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        downloadTask = task
        task.resume()
        startProgressTimer(task: task, handler: progressHandler)
    }

    func cancelDownload() {
        stopProgressTimer()
        downloadTask?.cancel()
        downloadTask = nil
    }

    private func startProgressTimer(task: URLSessionDownloadTask, handler: @escaping (Double) -> Void) {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let expected = task.countOfBytesExpectedToReceive
            let received = task.countOfBytesReceived
            let fraction = expected > 0 ? min(1.0, Double(received) / Double(expected)) : 0.0
            DispatchQueue.main.async { handler(fraction) }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private enum DownloadError: LocalizedError {
        case noFile
        var errorDescription: String? { "Download completed but produced no file." }
    }

    // MARK: - Install

    /// Tries to install the .dmg automatically:
    /// 1. Mount the DMG with hdiutil.
    /// 2. Find the .app bundle inside the mounted volume.
    /// 3. Replace the currently running copy with the new one.
    /// 4. Detach the DMG.
    /// 5. Relaunch the new copy and terminate the current one.
    ///
    /// If the copy step fails (e.g. permission denied), falls back to opening the
    /// mounted volume in Finder and quitting, so the user can drag-install manually.
    static func install(dmgAt dmgURL: URL, completion: @escaping (InstallResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {

            // ── Step 1: Mount ──────────────────────────────────────────────────
            let mountPoint: String
            do {
                mountPoint = try attachDMG(at: dmgURL)
            } catch {
                DispatchQueue.main.async { completion(.failed("Could not mount disk image: \(error.localizedDescription)")) }
                return
            }

            let mountURL = URL(fileURLWithPath: mountPoint)

            // ── Step 2: Find the .app inside the volume ────────────────────────
            guard let sourceAppURL = (try? FileManager.default.contentsOfDirectory(
                at: mountURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ))?.first(where: { $0.pathExtension == "app" }) else {
                // Can't find the .app — open Finder at the mount point as fallback
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(mountURL)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { NSApp.terminate(nil) }
                    completion(.openedForManualInstall(mountURL: mountURL))
                }
                return
            }

            // ── Step 3: Replace the running copy ──────────────────────────────
            let destAppURL = URL(fileURLWithPath: Bundle.main.bundlePath)

            do {
                if FileManager.default.fileExists(atPath: destAppURL.path) {
                    try FileManager.default.removeItem(at: destAppURL)
                }
                try FileManager.default.copyItem(at: sourceAppURL, to: destAppURL)
            } catch {
                // Automated copy failed — open Finder at mount point for manual drag-install
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(mountURL)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { NSApp.terminate(nil) }
                    completion(.openedForManualInstall(mountURL: mountURL))
                }
                return
            }

            // ── Step 4: Detach (best-effort) ──────────────────────────────────
            try? detachDMG(mountPoint: mountPoint)

            // ── Step 5: Relaunch & quit ────────────────────────────────────────
            DispatchQueue.main.async {
                completion(.relaunching)
                relaunchAndQuit(appURL: destAppURL)
            }
        }
    }

    // MARK: - DMG helpers

    private static func attachDMG(at url: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", url.path, "-nobrowse", "-noverify", "-noautoopen", "-plist"]

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError  = Pipe() // suppress stderr noise

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw InstallError.mountFailed("hdiutil exited \(process.terminationStatus)")
        }

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()

        guard
            let plist     = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let entities  = plist["system-entities"] as? [[String: Any]],
            let mountPoint = entities.compactMap({ $0["mount-point"] as? String }).first
        else {
            throw InstallError.mountFailed("Could not parse hdiutil plist output")
        }

        return mountPoint
    }

    private static func detachDMG(mountPoint: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint, "-quiet"]
        process.standardOutput = Pipe()
        process.standardError  = Pipe()
        try process.run()
        process.waitUntilExit()
    }

    /// Launches the app at `appURL` after a short delay (to let the current process exit cleanly),
    /// then terminates the running instance.  Must be called on the main thread.
    private static func relaunchAndQuit(appURL: URL) {
        // Escape single quotes in the path for the shell script
        let safePath = appURL.path.replacingOccurrences(of: "'", with: "'\\''")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 0.8 && open '\(safePath)'"]
        try? process.run()
        NSApp.terminate(nil)
    }

    // MARK: - Error types

    private enum InstallError: LocalizedError {
        case mountFailed(String)
        var errorDescription: String? {
            if case .mountFailed(let msg) = self { return msg }
            return nil
        }
    }
}
