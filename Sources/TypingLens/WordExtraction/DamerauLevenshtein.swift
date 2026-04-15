import Foundation

enum DamerauLevenshtein {
    static func distance(between lhs: String, and rhs: String, maxDistance: Int) -> Int? {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)

        if abs(lhsChars.count - rhsChars.count) > maxDistance {
            return nil
        }

        guard maxDistance >= 0 else { return nil }

        if lhsChars.isEmpty {
            return rhsChars.isEmpty ? 0 : (rhsChars.count <= maxDistance ? rhsChars.count : nil)
        }
        if rhsChars.isEmpty {
            return lhsChars.isEmpty ? 0 : (lhsChars.count <= maxDistance ? lhsChars.count : nil)
        }

        var matrix = Array(
            repeating: Array(repeating: 0, count: rhsChars.count + 1),
            count: lhsChars.count + 1
        )

        for i in 0...lhsChars.count { matrix[i][0] = i }
        for j in 0...rhsChars.count { matrix[0][j] = j }

        for i in 1...lhsChars.count {
            var rowMinimum = Int.max

            for j in 1...rhsChars.count {
                let substitutionCost = lhsChars[i - 1] == rhsChars[j - 1] ? 0 : 1

                let insertion = matrix[i][j - 1] + 1
                let deletion = matrix[i - 1][j] + 1
                let substitution = matrix[i - 1][j - 1] + substitutionCost
                matrix[i][j] = min(insertion, deletion, substitution)

                if i > 1, j > 1,
                   lhsChars[i - 1] == rhsChars[j - 2],
                   lhsChars[i - 2] == rhsChars[j - 1] {
                    matrix[i][j] = min(matrix[i][j], matrix[i - 2][j - 2] + 1)
                }

                rowMinimum = min(rowMinimum, matrix[i][j])
            }

            if rowMinimum > maxDistance {
                return nil
            }
        }

        let result = matrix[lhsChars.count][rhsChars.count]
        return result <= maxDistance ? result : nil
    }
}
