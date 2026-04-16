import CoreGraphics

struct PracticeCaretTarget: Equatable {
    let x: CGFloat
    let y: CGFloat
    let height: CGFloat
}

struct PracticeWordFrame: Equatable {
    let wordIndex: Int
    let frame: CGRect
}

struct PracticeLetterFrame: Equatable {
    let wordIndex: Int
    let letterIndex: Int
    let frame: CGRect
}

struct PracticeLetterFrameID: Hashable {
    let wordIndex: Int
    let letterIndex: Int
}

func resolvePracticeCaretTarget(
    caretState: PracticeCaretState?,
    wordFrames: [Int: CGRect],
    letterFrames: [PracticeLetterFrameID: CGRect]
) -> PracticeCaretTarget? {
    guard let caretState,
          let wordFrame = wordFrames[caretState.wordIndex] else {
        return nil
    }

    let activeLetters = letterFrames.filter { entry in
        entry.key.wordIndex == caretState.wordIndex
    }

    if caretState.letterIndex <= 0 {
        return PracticeCaretTarget(
            x: wordFrame.minX,
            y: wordFrame.minY,
            height: wordFrame.height
        )
    }

    if let target = activeLetters[PracticeLetterFrameID(
        wordIndex: caretState.wordIndex,
        letterIndex: caretState.letterIndex
    )] {
        return PracticeCaretTarget(
            x: target.minX,
            y: target.minY,
            height: target.height
        )
    }

    if let trailingLetter = activeLetters
        .filter({ $0.key.letterIndex < caretState.letterIndex })
        .max(by: { $0.value.maxX < $1.value.maxX }) {
        return PracticeCaretTarget(
            x: trailingLetter.value.maxX,
            y: trailingLetter.value.minY,
            height: trailingLetter.value.height
        )
    }

    return PracticeCaretTarget(
        x: wordFrame.minX,
        y: wordFrame.minY,
        height: wordFrame.height
    )
}
