import Foundation

enum SubtitleDocumentExporter {
    static let noSubtitlesMessage = "No subtitle file was available to export as a Microsoft Word document."

    static func exportDOCXDocuments(
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

        guard !subtitleFiles.isEmpty else { return [] }

        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        return try subtitleFiles.map { sourceURL in
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            let paragraphs = transcriptParagraphs(fromSRT: source)
            let title = sourceURL.deletingPathExtension().lastPathComponent
            let destination = availableDestination(
                in: outputDirectory,
                basename: title,
                fileManager: fileManager
            )
            try createDOCX(
                title: title,
                paragraphs: paragraphs,
                destination: destination,
                fileManager: fileManager
            )
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

    static func documentXML(title: String, paragraphs: [String]) -> String {
        let titleParagraph = """
        <w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light" w:eastAsia="Arial Unicode MS" w:cs="Arial Unicode MS" w:hint="eastAsia"/></w:rPr><w:t xml:space="preserve">\(xmlEscaped(title))</w:t></w:r></w:p>
        """
        let bodyParagraphs = paragraphs.map {
            "<w:p><w:pPr><w:pStyle w:val=\"Normal\"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii=\"Calibri\" w:hAnsi=\"Calibri\" w:eastAsia=\"Arial Unicode MS\" w:cs=\"Arial Unicode MS\" w:hint=\"eastAsia\"/></w:rPr><w:t xml:space=\"preserve\">\(xmlEscaped($0))</w:t></w:r></w:p>"
        }.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            \(titleParagraph)
            \(bodyParagraphs)
            <w:sectPr>
              <w:pgSz w:w="12240" w:h="15840"/>
              <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>
            </w:sectPr>
          </w:body>
        </w:document>
        """
    }

    private static func createDOCX(
        title: String,
        paragraphs: [String],
        destination: URL,
        fileManager: FileManager
    ) throws {
        let packageRoot = fileManager.temporaryDirectory
            .appendingPathComponent("MediaHarborDOCX-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: packageRoot) }

        try write(
            contentTypesXML,
            to: packageRoot.appendingPathComponent("[Content_Types].xml"),
            fileManager: fileManager
        )
        try write(
            packageRelationshipsXML,
            to: packageRoot.appendingPathComponent("_rels/.rels"),
            fileManager: fileManager
        )
        try write(
            documentXML(title: title, paragraphs: paragraphs),
            to: packageRoot.appendingPathComponent("word/document.xml"),
            fileManager: fileManager
        )
        try write(
            stylesXML,
            to: packageRoot.appendingPathComponent("word/styles.xml"),
            fileManager: fileManager
        )
        try write(
            documentRelationshipsXML,
            to: packageRoot.appendingPathComponent("word/_rels/document.xml.rels"),
            fileManager: fileManager
        )
        try write(
            corePropertiesXML(title: title),
            to: packageRoot.appendingPathComponent("docProps/core.xml"),
            fileManager: fileManager
        )
        try write(
            appPropertiesXML,
            to: packageRoot.appendingPathComponent("docProps/app.xml"),
            fileManager: fileManager
        )

        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = packageRoot
        process.arguments = [
            "-q", "-X", "-r", destination.path,
            "[Content_Types].xml", "_rels", "docProps", "word"
        ]
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw YTDLPError.commandFailed(message?.isEmpty == false ? message! : "Could not create the Word document.")
        }
    }

    private static func availableDestination(
        in directory: URL,
        basename: String,
        fileManager: FileManager
    ) -> URL {
        let initial = directory.appendingPathComponent(basename).appendingPathExtension("docx")
        guard fileManager.fileExists(atPath: initial.path) else { return initial }
        for suffix in 2...999 {
            let candidate = directory
                .appendingPathComponent("\(basename) (\(suffix))")
                .appendingPathExtension("docx")
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
        }
        return directory
            .appendingPathComponent("\(basename)-\(UUID().uuidString)")
            .appendingPathExtension("docx")
    }

    private static func write(_ value: String, to url: URL, fileManager: FileManager) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try value.write(to: url, atomically: true, encoding: .utf8)
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

    private static func xmlEscaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
      <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
      <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
      <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
    </Types>
    """

    private static let packageRelationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
      <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
    </Relationships>
    """

    private static let documentRelationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """

    private static let stylesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:docDefaults>
        <w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Arial Unicode MS" w:cs="Arial Unicode MS" w:hint="eastAsia"/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr></w:rPrDefault>
        <w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="300" w:lineRule="auto"/></w:pPr></w:pPrDefault>
      </w:docDefaults>
      <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
        <w:name w:val="Normal"/>
        <w:qFormat/>
        <w:pPr><w:spacing w:after="120" w:line="300" w:lineRule="auto"/></w:pPr>
        <w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Arial Unicode MS" w:cs="Arial Unicode MS" w:hint="eastAsia"/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>
      </w:style>
      <w:style w:type="paragraph" w:styleId="Title">
        <w:name w:val="Title"/>
        <w:basedOn w:val="Normal"/>
        <w:next w:val="Normal"/>
        <w:qFormat/>
        <w:pPr><w:keepNext/><w:spacing w:after="240"/></w:pPr>
        <w:rPr><w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light" w:eastAsia="Arial Unicode MS" w:cs="Arial Unicode MS" w:hint="eastAsia"/><w:b/><w:color w:val="1F4D78"/><w:sz w:val="40"/><w:szCs w:val="40"/></w:rPr>
      </w:style>
    </w:styles>
    """

    private static func corePropertiesXML(title: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:title>\(xmlEscaped(title))</dc:title>
          <dc:creator>MediaHarbor</dc:creator>
        </cp:coreProperties>
        """
    }

    private static let appPropertiesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
      <Application>MediaHarbor</Application>
    </Properties>
    """
}
