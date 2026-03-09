import Cocoa
import FlutterMacOS

func isCompatibleBuild() -> Bool {
    if let compatibleBuild = Bundle.main.object(forInfoDictionaryKey: "CompatibleBuild") as? String {
        return compatibleBuild == "true"
    }
    return false
}

autoreleasepool {
    if isCompatibleBuild() {
        setenv("FLTDisableImpeller", "1", 1)
    }
    
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
