import Foundation

enum SubtitleDocumentExporter {
    static func exportRTFDocuments(
        from directory: URL,
        to outputDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> [URL] {
        let subtitleFiles = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "srt" }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        guard !subtitleFiles.isEmpty else {
            throw YTDLPError.commandFailed("No subtitle file was available to export as a Word document.")
        }

        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        return try subtitleFiles.map { sourceURL in
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            let paragraphs = transcriptParagraphs(fromSRT: source)
            let title = sourceURL.deletingPathExtension().lastPathComponent
            let document = rtfDocument(title: title, paragraphs: paragraphs)
            let destination = outputDirectory
                .appendingPathComponent(title)
                .appendingPathExtension("rtf")
            try document.write(to: destination, atomically: true, encoding: .utf8)
            return destination
        }
    }

    static func transcriptParagraphs(fromSRT source: String) -> [String] {
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var result: [String] = []
        for block in normalized.components(separatedBy: "\n\n") {
            var lines = block
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard !lines.isEmpty else { continue }

            if Int(lines[0]) != nil { lines.removeFirst() }
            if lines.first?.contains("-->") == true { lines.removeFirst() }
            let text = cleanSubtitleText(lines.joined(separator: " "))
            guard !text.isEmpty, text != result.last else { continue }
            result.append(text)
        }
        return result
    }

    static func rtfDocument(title: String, paragraphs: [String]) -> String {
        let body = paragraphs.map { "\(rtfEscaped($0))\\par\n" }.joined()
        return """
        {\\rtf1\\ansi\\ansicpg65001\\uc1\\deff0
        {\\fonttbl{\\f0\\fnil\\fcharset0 Helvetica;}}
        \\paperw12240\\paperh15840\\margl1440\\margr1440\\margt1080\\margb1080
        \\viewkind4\\pard\\sa240\\b\\f0\\fs32 \(rtfEscaped(title))\\b0\\par
        \\pard\\sa160\\sl300\\slmult1\\f0\\fs24
        \(body)}
        """
    }

    private static func cleanSubtitleText(_ text: String) -> String {
        var cleaned = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        let entities = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&nbsp;": " "
        ]
        for (entity, replacement) in entities {
            cleaned = cleaned.replacingOccurrences(of: entity, with: replacement)
        }
        return cleaned
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func rtfEscaped(_ text: String) -> String {
        var result = ""
        for codeUnit in text.utf16 {
            switch codeUnit {
            case 0x0A:
                result += "\\line "
            case 0x5C:
                result += "\\\\"
            case 0x7B:
                result += "\\{"
            case 0x7D:
                result += "\\}"
            case 0x20...0x7E:
                result.append(Character(UnicodeScalar(codeUnit)!))
            default:
                result += "\\u\(Int(Int16(bitPattern: codeUnit)))?"
            }
        }
        return result
    }
}
