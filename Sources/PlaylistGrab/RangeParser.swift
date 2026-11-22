import Foundation

enum RangeParser {
    /// Parses range strings like "2-9, 14, 15-23", "1..5", "2 - 9", "10-", or "-5"
    /// and returns the set of 1-based indices that fall within 1...maxCount.
    static func parse(_ input: String, maxCount: Int) -> Set<Int> {
        guard maxCount > 0 else { return [] }
        var result = Set<Int>()

        // Normalize separators: convert semicolons and newlines into commas
        let normalized = input
            .replacingOccurrences(of: ";", with: ",")
            .replacingOccurrences(of: "\n", with: ",")

        let commaChunks = normalized.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for chunk in commaChunks {
            // First, try parsing chunk directly (e.g. "2-9", "2 - 9", "14")
            let chunkSet = parseToken(chunk, maxCount: maxCount)
            if !chunkSet.isEmpty {
                result.formUnion(chunkSet)
            } else {
                // If chunk didn't parse as a single item, it might be space-separated items (e.g. "2-9 14 15-23")
                let subTokens = chunk.components(separatedBy: .whitespaces)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                for sub in subTokens {
                    result.formUnion(parseToken(sub, maxCount: maxCount))
                }
            }
        }

        return result
    }

    private static func parseToken(_ raw: String, maxCount: Int) -> Set<Int> {
        let token = raw.trimmingCharacters(in: .whitespaces)
        guard !token.isEmpty else { return [] }

        // Check for range separators: "..", " to ", ":", or "-"
        var parts: [String]?
        if token.contains("..") {
            parts = token.components(separatedBy: "..")
        } else if token.lowercased().contains(" to ") {
            parts = token.components(separatedBy: " to ")
        } else if token.contains(":") {
            parts = token.components(separatedBy: ":")
        } else if token.contains("-") {
            // Watch out for leading negative sign vs range
            // e.g. "-5" means 1...5
            if token.hasPrefix("-") {
                let rest = String(token.dropFirst()).trimmingCharacters(in: .whitespaces)
                if let end = Int(rest) {
                    let clampedEnd = min(max(1, end), maxCount)
                    return Set(1...clampedEnd)
                }
            }
            // e.g. "20-" means 20...maxCount
            if token.hasSuffix("-") {
                let rest = String(token.dropLast()).trimmingCharacters(in: .whitespaces)
                if let start = Int(rest) {
                    let clampedStart = max(1, min(start, maxCount))
                    if clampedStart <= maxCount {
                        return Set(clampedStart...maxCount)
                    }
                }
            }
            parts = token.components(separatedBy: "-")
        }

        if let parts = parts, parts.count == 2 {
            let leftStr = parts[0].trimmingCharacters(in: .whitespaces)
            let rightStr = parts[1].trimmingCharacters(in: .whitespaces)

            if let left = Int(leftStr), let right = Int(rightStr) {
                let start = min(left, right)
                let end = max(left, right)
                let clampedStart = max(1, min(start, maxCount))
                let clampedEnd = min(maxCount, max(end, 1))
                if clampedStart <= clampedEnd {
                    return Set(clampedStart...clampedEnd)
                }
            }
        }

        // Single integer
        if let single = Int(token) {
            if single >= 1 && single <= maxCount {
                return [single]
            }
        }

        return []
    }
}
