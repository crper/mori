import Foundation

/// Simple fuzzy matching utility for command palette search.
/// Scoring: exact prefix > word boundary > substring > no match.
/// Case-insensitive throughout.
public enum FuzzyMatcher {

    /// Returns a score for how well `query` matches `candidate`.
    /// 0 means no match; higher is better.
    ///
    /// - Empty query returns maximum score (matches everything).
    /// - Exact prefix match: 100 points
    /// - Word boundary match (query matches start of a word in candidate): 75 points
    /// - Substring match (query found anywhere): 50 points
    /// - No match: 0 points
    public static func score(query: String, candidate: String) -> Int {
        // Empty query matches everything with max score
        guard !query.isEmpty else { return 100 }

        let lowerQuery = query.lowercased()
        let lowerCandidate = candidate.lowercased()

        // Exact prefix match
        if lowerCandidate.hasPrefix(lowerQuery) {
            return 100
        }

        // Word boundary match — query matches the start of any word
        let words = splitIntoWords(lowerCandidate)
        for word in words {
            if word.hasPrefix(lowerQuery) {
                return 75
            }
        }

        // Substring match
        if lowerCandidate.contains(lowerQuery) {
            return 50
        }

        // No match
        return 0
    }

    /// Split a string into words at common boundaries:
    /// spaces, hyphens, underscores, slashes, dots, and camelCase transitions.
    private static func splitIntoWords(_ text: String) -> [String] {
        var words: [String] = []
        var current = ""

        for (index, char) in text.enumerated() {
            if char == " " || char == "-" || char == "_" || char == "/" || char == "." {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
            } else if char.isUppercase && index > 0 {
                // camelCase boundary
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
                current.append(char)
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            words.append(current)
        }

        return words
    }
}
