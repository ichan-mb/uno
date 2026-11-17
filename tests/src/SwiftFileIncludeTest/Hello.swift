import Foundation

public class HelloSwiftWorld: NSObject {
    // `@objc` is required for the method to be visible from Objective-C since Swift 4,
    // where implicit `@objc` inference for NSObject subclasses was removed.
    @objc public func hello() -> String {
        return "Hello Swift world!"
    }
}
