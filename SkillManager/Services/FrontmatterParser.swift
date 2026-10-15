import Foundation

struct FrontmatterParser {
    static func parse(_ content: String) -> SkillMetadata? {
        let pattern = #"^﻿?---\r?\n([\s\S]*?)\r?\n---"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let yamlRange = Range(match.range(at: 1), in: content) else {
            return nil
        }

        let yaml = String(content[yamlRange])
        var fields: [String: String] = [:]

        var currentKey: String?
        var currentValue: String = ""
        var inMultilineQuote = false
        var quoteChar: Character?

        for line in yaml.components(separatedBy: .newlines) {
            if inMultilineQuote {
                if let qc = quoteChar, line.contains(qc) {
                    let endIdx = line.firstIndex(of: qc)!
                    currentValue += " " + line[line.startIndex..<endIdx]
                    if let key = currentKey {
                        fields[key] = currentValue.trimmingCharacters(in: .whitespaces)
                    }
                    inMultilineQuote = false
                    currentKey = nil
                    currentValue = ""
                } else {
                    currentValue += " " + line.trimmingCharacters(in: .whitespaces)
                }
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            guard let colonIdx = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[trimmed.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

            if key.isEmpty { continue }

            if (value.hasPrefix("\"") && !value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && !value.hasSuffix("'")) {
                quoteChar = value.first
                currentKey = key
                currentValue = String(value.dropFirst())
                inMultilineQuote = true
                continue
            }

            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            fields[key] = value
        }

        guard let name = fields["name"] else { return nil }
        let description = fields["description"] ?? ""

        return SkillMetadata(name: name, description: description, rawContent: content)
    }
}
