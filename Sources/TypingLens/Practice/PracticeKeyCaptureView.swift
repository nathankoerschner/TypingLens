import AppKit
import SwiftUI

struct PracticeKeyCaptureView: NSViewRepresentable {
    let isDisabled: Bool
    let focusToken: UUID
    let onInsert: (Character) -> Void
    let onSubmit: () -> Void
    let onDeleteBackward: () -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.isDisabled = isDisabled
        view.onInsert = onInsert
        view.onSubmit = onSubmit
        view.onDeleteBackward = onDeleteBackward

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.isDisabled = isDisabled
        nsView.onInsert = onInsert
        nsView.onSubmit = onSubmit
        nsView.onDeleteBackward = onDeleteBackward

        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class KeyCaptureNSView: NSView {
    var isDisabled = false
    var onInsert: ((Character) -> Void)?
    var onSubmit: (() -> Void)?
    var onDeleteBackward: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard !isDisabled else { return }

        if event.keyCode == 51 || event.keyCode == 117 {
            onDeleteBackward?()
            return
        }

        let disallowedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard event.modifierFlags.intersection(disallowedModifiers).isEmpty,
              let characters = event.characters,
              !characters.isEmpty else {
            super.keyDown(with: event)
            return
        }

        for character in characters {
            if character.isWhitespace || character.isNewline {
                onSubmit?()
            } else {
                let scalars = String(character).unicodeScalars
                let isPrintable = scalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
                guard isPrintable else { continue }

                onInsert?(character)
            }
        }
    }
}
