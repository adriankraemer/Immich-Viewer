import Foundation

/// Debug logging helper - only prints in DEBUG builds
@inline(__always)
func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}




