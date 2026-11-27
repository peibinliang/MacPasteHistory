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

    @MainActor
    func testRelaunchAndTerminate_whenWorkspaceLauncherSucceeds_shouldTerminateOnceWithoutShellFallback() async {
        var didRunShellFallback = false
        var launchedURL: URL?
        var terminateCount = 0
        let relauncher = AppRelauncher(
            launchCommand: { _, _ in
                didRunShellFallback = true
            },
            workspaceLauncher: { url, completion in
                launchedURL = url
                completion(true)
            }
        )

        relauncher.relaunchAndTerminate(
            bundlePath: "/Applications/粘易.app",
            terminate: { terminateCount += 1 }
        )
        for _ in 0..<5 { await Task.yield() }

        XCTAssertEqual(launchedURL?.path, "/Applications/粘易.app")
        XCTAssertFalse(didRunShellFallback)
        XCTAssertEqual(terminateCount, 1)
    }

    @MainActor
    func testRelaunchAndTerminate_whenWorkspaceLauncherFails_shouldFallbackToShellCommandAndTerminateOnce() async {
        var didRunShellFallback = false
        var terminateCount = 0
        let relauncher = AppRelauncher(
            launchCommand: { _, _ in
                didRunShellFallback = true
            },
            workspaceLauncher: { _, completion in
                completion(false)
            }
        )

        relauncher.relaunchAndTerminate(
            bundlePath: "/Applications/粘易.app",
            terminate: { terminateCount += 1 }
        )
        for _ in 0..<5 { await Task.yield() }

        XCTAssertTrue(didRunShellFallback)
        XCTAssertEqual(terminateCount, 1)
    }
}
