import Foundation
import Darwin

@MainActor
final class OutputFileMonitor {
    var onChange: (() -> Void)?

    private var sources: [String: DispatchSourceFileSystemObject] = [:]

    func watch(outputPaths: [String]) {
        let directories = Set(outputPaths.map {
            URL(fileURLWithPath: $0).deletingLastPathComponent().standardizedFileURL.path
        })

        for (path, source) in sources where !directories.contains(path) {
            source.cancel()
            sources[path] = nil
        }

        for path in directories where sources[path] == nil {
            let descriptor = open(path, O_EVTONLY)
            guard descriptor >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .delete, .rename],
                queue: .main
            )
            source.setEventHandler { [weak self] in self?.onChange?() }
            source.setCancelHandler { close(descriptor) }
            source.resume()
            sources[path] = source
        }
    }

    deinit {
        for source in sources.values { source.cancel() }
    }
}
