import Foundation

/// The execution location for git/tmux operations.
/// `.local` runs on the host machine; `.ssh` runs via `ssh` on a remote host.
public enum WorkspaceLocation: Codable, Equatable, Hashable, Sendable {
    case local
    case ssh(SSHWorkspaceLocation)

    private enum CodingKeys: String, CodingKey {
        case kind
        case ssh
    }

    private enum Kind: String, Codable {
        case local
        case ssh
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .local:
            self = .local
        case .ssh:
            self = .ssh(try container.decode(SSHWorkspaceLocation.self, forKey: .ssh))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .local:
            try container.encode(Kind.local, forKey: .kind)
        case .ssh(let config):
            try container.encode(Kind.ssh, forKey: .kind)
            try container.encode(config, forKey: .ssh)
        }
    }

    /// Stable key used for endpoint maps and runtime namespacing.
    public var endpointKey: String {
        switch self {
        case .local:
            return "local"
        case .ssh(let ssh):
            return "ssh:\(ssh.endpointKey)"
        }
    }
}

/// SSH endpoint configuration for remote projects.
public struct SSHWorkspaceLocation: Codable, Equatable, Hashable, Sendable {
    public var host: String
    public var user: String?
    public var port: Int?

    public init(host: String, user: String? = nil, port: Int? = nil) {
        self.host = host
        self.user = user
        self.port = port
    }

    /// Target value passed to `ssh` (e.g. `user@example.com`).
    public var target: String {
        if let user, !user.isEmpty {
            return "\(user)@\(host)"
        }
        return host
    }

    /// Stable key for dictionaries and namespacing.
    public var endpointKey: String {
        if let user, !user.isEmpty {
            if let port {
                return "\(user)@\(host):\(port)"
            }
            return "\(user)@\(host)"
        }
        if let port {
            return "\(host):\(port)"
        }
        return host
    }
}
