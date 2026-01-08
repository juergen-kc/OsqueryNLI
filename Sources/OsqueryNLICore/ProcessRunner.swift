import Foundation

/// Thread-safe atomic flag for timeout tracking
private final class AtomicFlag: @unchecked Sendable {
    private var _value: Bool = false
    private let lock = NSLock()

    var value: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
}

/// Async wrapper for running external processes
public actor ProcessRunner {
    /// Process execution errors
    public enum ProcessError: LocalizedError, Sendable {
        case notFound(path: String)
        case executionFailed(exitCode: Int32, stderr: String)
        case timeout
        case cancelled

        public var errorDescription: String? {
            switch self {
            case .notFound(let path):
                return "Executable not found: \(path)"
            case .executionFailed(let exitCode, let stderr):
                return "Process failed with exit code \(exitCode): \(stderr)"
            case .timeout:
                return "Process timed out"
            case .cancelled:
                return "Process was cancelled"
            }
        }
    }

    /// Result of a process execution
    public struct ProcessResult: Sendable {
        public let stdout: Data
        public let stderr: Data
        public let exitCode: Int32

        public var stdoutString: String? {
            String(data: stdout, encoding: .utf8)
        }

        public var stderrString: String? {
            String(data: stderr, encoding: .utf8)
        }

        public init(stdout: Data, stderr: Data, exitCode: Int32) {
            self.stdout = stdout
            self.stderr = stderr
            self.exitCode = exitCode
        }
    }

    private var currentProcess: Process?
    private var currentTask: Task<ProcessResult, Error>?

    public init() {}

    /// Run a process with the given executable and arguments
    /// - Parameters:
    ///   - executable: Path to the executable
    ///   - arguments: Command line arguments
    ///   - timeout: Timeout in seconds (default 30)
    /// - Returns: Process result with stdout, stderr, and exit code
    public func run(
        executable: String,
        arguments: [String],
        timeout: TimeInterval = 30.0
    ) async throws -> ProcessResult {
        // Check if executable exists (if it's an absolute path)
        if executable.hasPrefix("/") && !FileManager.default.fileExists(atPath: executable) {
            throw ProcessError.notFound(path: executable)
        }

        // Thread-safe timeout flag
        let timedOut = AtomicFlag()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Store process reference for cancellation
        currentProcess = process

        let task = Task<ProcessResult, Error> {
            // Set up timeout with thread-safe flag
            let timeoutWorkItem = DispatchWorkItem { [weak process] in
                if process?.isRunning == true {
                    timedOut.value = true
                    process?.terminate()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)

            do {
                try process.run()

                // Wait for completion in a non-blocking way
                await withCheckedContinuation { continuation in
                    process.terminationHandler = { _ in
                        continuation.resume()
                    }
                }

                // Cancel timeout since process completed
                timeoutWorkItem.cancel()

                // Read output after process completes
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                // Check if we timed out
                if timedOut.value {
                    throw ProcessError.timeout
                }

                return ProcessResult(
                    stdout: stdoutData,
                    stderr: stderrData,
                    exitCode: process.terminationStatus
                )
            } catch let error as ProcessError {
                timeoutWorkItem.cancel()
                throw error
            } catch {
                timeoutWorkItem.cancel()
                throw ProcessError.executionFailed(
                    exitCode: -1,
                    stderr: error.localizedDescription
                )
            }
        }

        currentTask = task

        defer {
            // Clean up references after completion to prevent memory leaks
            currentProcess = nil
            currentTask = nil
        }

        do {
            return try await task.value
        } catch is CancellationError {
            currentProcess?.terminate()
            throw ProcessError.cancelled
        }
    }

    /// Cancel any running process
    public func cancel() {
        currentProcess?.terminate()
        currentTask?.cancel()
        currentTask = nil
        currentProcess = nil
    }
}
