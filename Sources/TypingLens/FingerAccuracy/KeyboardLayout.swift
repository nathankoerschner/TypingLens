import Foundation

enum Finger: String, CaseIterable {
    case leftPinky
    case leftRing
    case leftMiddle
    case leftIndex
    case leftThumb
    case rightThumb
    case rightIndex
    case rightMiddle
    case rightRing
    case rightPinky

    var isLeft: Bool {
        switch self {
        case .leftPinky, .leftRing, .leftMiddle, .leftIndex, .leftThumb: return true
        default: return false
        }
    }

    var displayName: String {
        switch self {
        case .leftPinky: return "L-Pinky"
        case .leftRing: return "L-Ring"
        case .leftMiddle: return "L-Middle"
        case .leftIndex: return "L-Index"
        case .leftThumb: return "L-Thumb"
        case .rightThumb: return "R-Thumb"
        case .rightIndex: return "R-Index"
        case .rightMiddle: return "R-Middle"
        case .rightRing: return "R-Ring"
        case .rightPinky: return "R-Pinky"
        }
    }
}

struct KeyboardKey: Equatable {
    let character: Character
    let row: Int
    let col: Double
    let expectedFinger: Finger
}

enum KeyboardLayout {
    static let rowCount = 4
    static let maxCol: Double = 12

    static let keys: [KeyboardKey] = {
        var result: [KeyboardKey] = []

        let row0 = "`1234567890-="
        for (i, ch) in row0.enumerated() {
            result.append(KeyboardKey(character: ch, row: 0, col: Double(i), expectedFinger: numberRowFinger(for: i)))
        }

        let row1 = "qwertyuiop[]"
        for (i, ch) in row1.enumerated() {
            result.append(KeyboardKey(character: ch, row: 1, col: Double(i) + 1.5, expectedFinger: topRowFinger(for: i)))
        }

        let row2 = "asdfghjkl;'"
        for (i, ch) in row2.enumerated() {
            result.append(KeyboardKey(character: ch, row: 2, col: Double(i) + 1.75, expectedFinger: homeRowFinger(for: i)))
        }

        let row3 = "zxcvbnm,./"
        for (i, ch) in row3.enumerated() {
            result.append(KeyboardKey(character: ch, row: 3, col: Double(i) + 2.25, expectedFinger: bottomRowFinger(for: i)))
        }

        return result
    }()

    private static let lookup: [Character: KeyboardKey] = {
        var map: [Character: KeyboardKey] = [:]
        for key in keys {
            map[key.character] = key
            let upper = Character(key.character.uppercased())
            if upper != key.character { map[upper] = key }
        }
        return map
    }()

    static func key(for character: Character) -> KeyboardKey? {
        lookup[character]
    }

    private static func numberRowFinger(for column: Int) -> Finger {
        switch column {
        case 0, 1: return .leftPinky
        case 2: return .leftRing
        case 3: return .leftMiddle
        case 4, 5: return .leftIndex
        case 6, 7: return .rightIndex
        case 8: return .rightMiddle
        case 9: return .rightRing
        default: return .rightPinky
        }
    }

    private static func topRowFinger(for column: Int) -> Finger {
        switch column {
        case 0: return .leftPinky
        case 1: return .leftRing
        case 2: return .leftMiddle
        case 3, 4: return .leftIndex
        case 5, 6: return .rightIndex
        case 7: return .rightMiddle
        case 8: return .rightRing
        default: return .rightPinky
        }
    }

    private static func homeRowFinger(for column: Int) -> Finger {
        switch column {
        case 0: return .leftPinky
        case 1: return .leftRing
        case 2: return .leftMiddle
        case 3, 4: return .leftIndex
        case 5, 6: return .rightIndex
        case 7: return .rightMiddle
        case 8: return .rightRing
        default: return .rightPinky
        }
    }

    private static func bottomRowFinger(for column: Int) -> Finger {
        switch column {
        case 0: return .leftPinky
        case 1: return .leftRing
        case 2: return .leftMiddle
        case 3, 4: return .leftIndex
        case 5, 6: return .rightIndex
        case 7: return .rightMiddle
        case 8: return .rightRing
        default: return .rightPinky
        }
    }
}
