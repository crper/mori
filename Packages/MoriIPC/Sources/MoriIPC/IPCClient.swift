@preconcurrency import Foundation
import Network

/// Client for communicating with the Mori app over Unix domain socket.
/// Provides both async and synchronous (semaphore-based) APIs.
public struct IPCClient: Sendable {

    /// Errors specific to the IPC client.
    public enum ClientError: Error, LocalizedError, Sendable {
        case connectionFailed(String)
        case timeout
        case invalidResponse
        case serverError(String)

        public var errorDescription: String? {
            switch self {
            case .connectionFailed(let msg): return "Connection failed: \(msg)"
            case .timeout: return "Request timed out (5s)"
            case .invalidResponse: return "Invalid response from server"
            case .serverError(let msg): return "Server error: \(msg)"
            }
        }
    }

    private let socketPath: String

    /// Create an IPC client.
    /// - Parameter socketPath: Path to the Unix domain socket. Defaults to the standard location.
    public init(socketPath: String? = nil) {
        self.socketPath = socketPath ?? IPCServer.defaultSocketPath
    }

    /// Send a request and wait for a response (async).
    public func send(_ request: IPCRequest) async throws -> IPCResponseEnvelope {
        let requestData = try IPCFraming.encode(request)
        let path = socketPath

        return try await withCheckedThrowingContinuation { continuation in
            let connection = NWConnection(
                to: .unix(path: path),
                using: .tcp
            )

            // Use a sendable box for one-shot continuation resumption
            let box = ContinuationBox(continuation: continuation)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: requestData, completion: .contentProcessed { sendError in
                        if let sendError {
                            connection.cancel()
                            box.resume(with: .failure(ClientError.connectionFailed(sendError.localizedDescription)))
                            return
                        }
                        // Read response
                        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { content, _, _, recvError in
                            defer { connection.cancel() }
                            if let recvError {
                                box.resume(with: .failure(ClientError.connectionFailed(recvError.localizedDescription)))
                                return
                            }
                            guard let content else {
                                box.resume(with: .failure(ClientError.invalidResponse))
                                return
                            }
                            do {
                                let envelope = try IPCFraming.decodeResponse(from: content)
                                box.resume(with: .success(envelope))
                            } catch {
                                box.resume(with: .failure(ClientError.invalidResponse))
                            }
                        }
                    })

                case .failed(let error):
                    box.resume(with: .failure(ClientError.connectionFailed(error.localizedDescription)))

                case .cancelled:
                    box.resume(with: .failure(ClientError.connectionFailed("Connection cancelled")))

                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .utility))

            // Timeout: cancel the connection after 5 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                connection.cancel()
                box.resume(with: .failure(ClientError.timeout))
            }
        }
    }

    /// Send a request synchronously (blocks the calling thread).
    /// Suitable for CLI use where async is not available at the top level.
    public func sendSync(_ request: IPCRequest) throws -> IPCResponseEnvelope {
        let resultBox = ResultBox()
        let semaphore = DispatchSemaphore(value: 0)
        let client = self

        Task {
            do {
                let envelope = try await client.send(request)
                resultBox.set(.success(envelope))
            } catch {
                resultBox.set(.failure(error))
            }
            semaphore.signal()
        }

        let waitResult = semaphore.wait(timeout: .now() + 6)
        if waitResult == .timedOut {
            throw ClientError.timeout
        }

        return try resultBox.get()
    }
}

// MARK: - Result Box (thread-safe, Sendable)

/// Thread-safe box for passing a result across concurrency boundaries.
private final class ResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<IPCResponseEnvelope, Error> = .failure(IPCClient.ClientError.timeout)

    func set(_ value: Result<IPCResponseEnvelope, Error>) {
        lock.lock()
        result = value
        lock.unlock()
    }

    func get() throws -> IPCResponseEnvelope {
        lock.lock()
        let r = result
        lock.unlock()
        return try r.get()
    }
}

// MARK: - Continuation Box (thread-safe, one-shot)

/// A `Sendable` wrapper that ensures a `CheckedContinuation` is resumed exactly once.
private final class ContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<IPCResponseEnvelope, Error>?

    init(continuation: CheckedContinuation<IPCResponseEnvelope, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<IPCResponseEnvelope, Error>) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(with: result)
    }
}
