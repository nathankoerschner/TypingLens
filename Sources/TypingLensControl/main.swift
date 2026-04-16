import Foundation

let notificationName = Notification.Name("com.natkoersch.typinglens.practice-now")

func printUsage() {
    FileHandle.standardError.write(Data("Usage: TypingLensControl practice-now\n".utf8))
}

guard CommandLine.arguments.count == 2 else {
    printUsage()
    exit(1)
}

guard CommandLine.arguments[1] == "practice-now" else {
    printUsage()
    exit(1)
}

DistributedNotificationCenter.default().postNotificationName(
    notificationName,
    object: nil,
    userInfo: nil,
    options: [.deliverImmediately]
)
