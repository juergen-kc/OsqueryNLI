import Testing
import Foundation
@testable import OsqueryNLICore

@Suite("ProcessRunner Tests")
struct ProcessRunnerTests {

    // MARK: - ProcessResult Tests

    @Test("ProcessResult stdoutString returns decoded string")
    func testProcessResultStdoutString() {
        let stdout = "Hello, World!".data(using: .utf8)!
        let result = ProcessRunner.ProcessResult(stdout: stdout, stderr: Data(), exitCode: 0)

        #expect(result.stdoutString == "Hello, World!")
    }

    @Test("ProcessResult stderrString returns decoded string")
    func testProcessResultStderrString() {
        let stderr = "Error occurred".data(using: .utf8)!
        let result = ProcessRunner.ProcessResult(stdout: Data(), stderr: stderr, exitCode: 1)

        #expect(result.stderrString == "Error occurred")
    }

    @Test("ProcessResult handles empty data")
    func testProcessResultEmptyData() {
        let result = ProcessRunner.ProcessResult(stdout: Data(), stderr: Data(), exitCode: 0)

        #expect(result.stdoutString == "")
        #expect(result.stderrString == "")
    }

    @Test("ProcessResult preserves exit code")
    func testProcessResultExitCode() {
        let result = ProcessRunner.ProcessResult(stdout: Data(), stderr: Data(), exitCode: 42)
        #expect(result.exitCode == 42)
    }

    @Test("ProcessResult handles multiline output")
    func testProcessResultMultiline() {
        let multiline = "line1\nline2\nline3"
        let stdout = multiline.data(using: .utf8)!
        let result = ProcessRunner.ProcessResult(stdout: stdout, stderr: Data(), exitCode: 0)

        #expect(result.stdoutString == multiline)
        #expect(result.stdoutString?.components(separatedBy: "\n").count == 3)
    }

    @Test("ProcessResult handles unicode")
    func testProcessResultUnicode() {
        let unicode = "Hello 世界 🌍"
        let stdout = unicode.data(using: .utf8)!
        let result = ProcessRunner.ProcessResult(stdout: stdout, stderr: Data(), exitCode: 0)

        #expect(result.stdoutString == unicode)
    }

    // MARK: - ProcessError Tests

    @Test("ProcessError notFound includes path")
    func testProcessErrorNotFound() {
        let error = ProcessRunner.ProcessError.notFound(path: "/usr/bin/missing")
        #expect(error.errorDescription?.contains("not found") == true)
        #expect(error.errorDescription?.contains("/usr/bin/missing") == true)
    }

    @Test("ProcessError executionFailed includes exit code and stderr")
    func testProcessErrorExecutionFailed() {
        let error = ProcessRunner.ProcessError.executionFailed(exitCode: 127, stderr: "command not found")
        #expect(error.errorDescription?.contains("127") == true)
        #expect(error.errorDescription?.contains("command not found") == true)
    }

    @Test("ProcessError timeout has correct description")
    func testProcessErrorTimeout() {
        let error = ProcessRunner.ProcessError.timeout
        #expect(error.errorDescription?.contains("timed out") == true)
    }

    @Test("ProcessError cancelled has correct description")
    func testProcessErrorCancelled() {
        let error = ProcessRunner.ProcessError.cancelled
        #expect(error.errorDescription?.contains("cancelled") == true)
    }

    @Test("ProcessError conforms to LocalizedError")
    func testProcessErrorConformsToLocalizedError() {
        let error: LocalizedError = ProcessRunner.ProcessError.timeout
        #expect(error.errorDescription != nil)
    }

    @Test("ProcessError conforms to Sendable")
    func testProcessErrorConformsToSendable() {
        let error: any Sendable = ProcessRunner.ProcessError.cancelled
        #expect(error is ProcessRunner.ProcessError)
    }

    // MARK: - ProcessRunner Actor Tests

    @Test("ProcessRunner can be initialized")
    func testProcessRunnerInit() async {
        let runner = ProcessRunner()
        // Actor should be created successfully
        #expect(runner != nil)
    }

    @Test("ProcessRunner runs simple command")
    func testProcessRunnerSimpleCommand() async throws {
        let runner = ProcessRunner()
        let result = try await runner.run(executable: "/bin/echo", arguments: ["hello"])

        #expect(result.exitCode == 0)
        #expect(result.stdoutString?.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
    }

    @Test("ProcessRunner captures stderr")
    func testProcessRunnerCapturesStderr() async throws {
        let runner = ProcessRunner()
        // Use sh -c to redirect to stderr
        let result = try await runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "echo error >&2"]
        )

        #expect(result.stderrString?.contains("error") == true)
    }

    @Test("ProcessRunner returns correct exit code")
    func testProcessRunnerExitCode() async throws {
        let runner = ProcessRunner()
        let result = try await runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "exit 42"]
        )

        #expect(result.exitCode == 42)
    }

    @Test("ProcessRunner throws for missing executable")
    func testProcessRunnerMissingExecutable() async {
        let runner = ProcessRunner()

        do {
            _ = try await runner.run(executable: "/nonexistent/path", arguments: [])
            #expect(Bool(false), "Should have thrown")
        } catch let error as ProcessRunner.ProcessError {
            if case .notFound(let path) = error {
                #expect(path == "/nonexistent/path")
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    // MARK: - Additional Edge Case Tests

    @Test("ProcessRunner handles empty arguments")
    func testProcessRunnerEmptyArguments() async throws {
        let runner = ProcessRunner()
        let result = try await runner.run(executable: "/bin/pwd", arguments: [])

        #expect(result.exitCode == 0)
        #expect(result.stdoutString?.isEmpty == false)
    }

    @Test("ProcessRunner handles arguments with spaces")
    func testProcessRunnerArgumentsWithSpaces() async throws {
        let runner = ProcessRunner()
        let result = try await runner.run(
            executable: "/bin/echo",
            arguments: ["hello world", "foo bar"]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdoutString?.contains("hello world") == true)
        #expect(result.stdoutString?.contains("foo bar") == true)
    }

    @Test("ProcessRunner handles special characters in arguments")
    func testProcessRunnerSpecialCharacters() async throws {
        let runner = ProcessRunner()
        let result = try await runner.run(
            executable: "/bin/echo",
            arguments: ["$HOME", "\"quoted\"", "'single'"]
        )

        #expect(result.exitCode == 0)
        // Echo should output the literal strings (not expand $HOME)
        #expect(result.stdoutString?.contains("$HOME") == true)
    }

    @Test("ProcessRunner handles large output")
    func testProcessRunnerLargeOutput() async throws {
        let runner = ProcessRunner()
        // Generate 1000 lines of output
        let result = try await runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "for i in $(seq 1 1000); do echo line$i; done"]
        )

        #expect(result.exitCode == 0)
        let lines = result.stdoutString?.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines?.count == 1000)
    }

    @Test("ProcessRunner handles binary in stdout")
    func testProcessRunnerBinaryOutput() async throws {
        let runner = ProcessRunner()
        // Generate some binary-ish data (null bytes)
        let result = try await runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "printf 'hello\\x00world'"]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.count > 0)
    }

    @Test("ProcessRunner handles environment correctly")
    func testProcessRunnerEnvironment() async throws {
        let runner = ProcessRunner()
        let result = try await runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "echo $PATH"]
        )

        #expect(result.exitCode == 0)
        // Should have some PATH value
        #expect(result.stdoutString?.isEmpty == false)
    }

    @Test("ProcessResult with both stdout and stderr")
    func testProcessResultBothOutputs() async throws {
        let runner = ProcessRunner()
        let result = try await runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "echo stdout; echo stderr >&2"]
        )

        #expect(result.stdoutString?.contains("stdout") == true)
        #expect(result.stderrString?.contains("stderr") == true)
    }

    @Test("ProcessRunner handles rapid sequential calls")
    func testProcessRunnerSequentialCalls() async throws {
        let runner = ProcessRunner()

        for i in 1...10 {
            let result = try await runner.run(
                executable: "/bin/echo",
                arguments: ["\(i)"]
            )
            #expect(result.exitCode == 0)
            #expect(result.stdoutString?.trimmingCharacters(in: .whitespacesAndNewlines) == "\(i)")
        }
    }

    @Test("ProcessError cases are distinct")
    func testProcessErrorCasesDistinct() {
        let notFound = ProcessRunner.ProcessError.notFound(path: "/test")
        let timeout = ProcessRunner.ProcessError.timeout
        let cancelled = ProcessRunner.ProcessError.cancelled
        let failed = ProcessRunner.ProcessError.executionFailed(exitCode: 1, stderr: "error")

        // Each should have unique descriptions
        let descriptions = [
            notFound.errorDescription ?? "",
            timeout.errorDescription ?? "",
            cancelled.errorDescription ?? "",
            failed.errorDescription ?? ""
        ]

        let uniqueDescriptions = Set(descriptions)
        #expect(uniqueDescriptions.count == 4)
    }
}
