struct NormalizedKeyEvent: Equatable {
    let type: EventType
    let keyCode: UInt16
    let characters: String?
    let charactersIgnoringModifiers: String?
    let modifiers: [String]
    let isRepeat: Bool
    let keyboardLayout: String?
}
