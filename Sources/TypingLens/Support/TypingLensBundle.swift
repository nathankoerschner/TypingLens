import Foundation

enum TypingLensBundle {
    static var resources: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle.main
        #endif
    }
}
