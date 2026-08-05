import XCTest
@testable import MacPasteHistory

final class AppRelauncherTests: XCTestCase {
    func testRelaunchAfterTermination_shouldDelayAndOpenNewAppInstance() throws {
        var capturedExecutable: URL?
        var capturedArguments: [String]?
        let relauncher = AppRelauncher { executable, arguments in
            capturedExecutable = executable
            capturedArguments = arguments
        }

        relauncher.relaunchAfterTermination(bundlePath: "/Applications/粘易.app")

        XCTAssertEqual(capturedExecutable?.path, "/bin/sh")
        XCTAssertEqual(capturedArguments?.first, "-c")
        let shellCommand = try XCTUnwrap(capturedArguments?.last)
        XCTAssertTrue(shellCommand.contains("sleep 0.5"))
        XCTAssertTrue(shellCommand.contains("/usr/bin/open -n"))
        XCTAssertTrue(shellCommand.contains("'/Applications/粘易.app'"))
    }

    func testRelaunchAfterTermination_whenBundlePathContainsQuote_shouldShellQuoteSafely() throws {
        var capturedArguments: [String]?
        let relauncher = AppRelauncher { _, arguments in
            capturedArguments = arguments
        }

        relauncher.relaunchAfterTermination(bundlePath: "/Applications/Pei'bin Paste.app")

        let shellCommand = try XCTUnwrap(capturedArguments?.last)
        XCTAssertTrue(shellCommand.contains("'/Applications/Pei'\\''bin Paste.app'"))
    }
}
