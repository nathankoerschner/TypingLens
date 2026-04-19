import AppKit
import SwiftUI

struct FingerAccuracyKeyCaptureView: NSViewRepresentable {
    let isDisabled: Bool
    let onKey: (Character) -> Void

    func makeNSView(context: Context) -> KeyCapture {
        let view = KeyCapture()
        view.isDisabled = isDisabled
        view.onKey = onKey
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyCapture, context: Context) {
        nsView.isDisabled = isDisabled
        nsView.onKey = onKey
        if !isDisabled {
            DispatchQueue.main.async {
                if nsView.window?.firstResponder !== nsView {
                    nsView.window?.makeFirstResponder(nsView)
                }
            }
        }
    }

    final class KeyCapture: NSView {
        var isDisabled = false
        var onKey: ((Character) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) {
            guard !isDisabled else {
                super.keyDown(with: event)
                return
            }

            let blockers: NSEvent.ModifierFlags = [.command, .control, .option]
            guard event.modifierFlags.intersection(blockers).isEmpty else {
                super.keyDown(with: event)
                return
            }

            guard let characters = event.charactersIgnoringModifiers,
                  let first = characters.first else {
                super.keyDown(with: event)
                return
            }

            onKey?(first)
        }
    }
}
