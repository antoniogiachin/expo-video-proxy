// Copyright 2024-present 650 Industries. All rights reserved.

import Foundation
import Network

/// Local HTTP proxy server for injecting dynamic headers into video segment requests.
/// Uses Network.framework's NWListener for efficient TCP handling.
///
/// The proxy URL structure is: `http://localhost:PORT/ORIGINAL_URL`
/// This allows AVPlayer to resolve relative URLs in manifests automatically,
/// so no manifest parsing/rewriting is needed for any format (HLS, DASH, SmoothStreaming).
internal final class CMCDProxy {
  static let shared = CMCDProxy()

  private var listener: NWListener?
  private(set) var port: UInt16 = 0
  private let queue = DispatchQueue(label: "expo.video.cmcd.proxy", qos: .userInitiated)
  private let headersLock = NSLock()

  private var readyContinuation: CheckedContinuation<Void, Error>?
  private var activeConnections: [NWConnection] = []
  private let connectionsLock = NSLock()

  /// Provider for dynamic headers - typically set by the VideoPlayer
  var dynamicHeadersProvider: (() -> [String: String])?

  /// Static headers that are always added to proxied requests
  private var _staticHeaders: [String: String] = [:]
  var staticHeaders: [String: String] {
    get {
      headersLock.lock()
      defer { headersLock.unlock() }
      return _staticHeaders
    }
    set {
      headersLock.lock()
      defer { headersLock.unlock() }
      _staticHeaders = newValue
    }
  }

  var isReady: Bool { port > 0 }

  private var proxyBaseUrl: String {
    "http://localhost:\(port)/"
  }

  private init() {}

  /// Starts the proxy server asynchronously.
  /// Returns when the proxy is ready to accept connections.
  func start() async throws {
    // If already running, return immediately
    if port > 0 { return }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      self.readyContinuation = continuation

      do {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        let newListener = try NWListener(using: parameters, on: .any)

        newListener.stateUpdateHandler = { [weak self] state in
          guard let self = self else { return }
          switch state {
          case .ready:
            if let listenerPort = newListener.port?.rawValue {
              self.port = listenerPort
              self.readyContinuation?.resume()
              self.readyContinuation = nil
            }
          case .failed(let error):
            self.readyContinuation?.resume(throwing: error)
            self.readyContinuation = nil
          case .cancelled:
            let cancelError = NSError(domain: "CMCDProxy", code: -1, userInfo: [NSLocalizedDescriptionKey: "Proxy was cancelled"])
            self.readyContinuation?.resume(throwing: cancelError)
            self.readyContinuation = nil
          default:
            break
          }
        }

        newListener.newConnectionHandler = { [weak self] connection in
          self?.handleConnection(connection)
        }

        self.listener = newListener
        newListener.start(queue: self.queue)
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }

  /// Stops the proxy server and closes all active connections.
  func stop() {
    listener?.cancel()
    listener = nil
    port = 0

    connectionsLock.lock()
    let connections = activeConnections
    activeConnections.removeAll()
    connectionsLock.unlock()

    for connection in connections {
      connection.cancel()
    }
  }

  /// Creates a proxy URL for the given original URL.
  /// Format: http://localhost:PORT/ORIGINAL_URL
  func createProxyUrl(for originalUrl: URL) -> URL? {
    guard port > 0 else { return nil }
    return URL(string: proxyBaseUrl + originalUrl.absoluteString)
  }

  /// Extracts the original URL from a proxy URL.
  func unproxiedUrl(_ url: URL) -> URL? {
    let urlString = url.absoluteString
    guard urlString.hasPrefix(proxyBaseUrl) else { return nil }
    let originalUrlString = String(urlString.dropFirst(proxyBaseUrl.count))
    return URL(string: originalUrlString)
  }

  // MARK: - Connection Handling

  private func handleConnection(_ connection: NWConnection) {
    connectionsLock.lock()
    activeConnections.append(connection)
    connectionsLock.unlock()

    connection.stateUpdateHandler = { [weak self, weak connection] state in
      guard let self = self, let connection = connection else { return }
      switch state {
      case .ready:
        self.receiveRequest(on: connection)
      case .failed, .cancelled:
        self.removeConnection(connection)
      default:
        break
      }
    }

    connection.start(queue: queue)
  }

  private func removeConnection(_ connection: NWConnection) {
    connectionsLock.lock()
    activeConnections.removeAll { $0 === connection }
    connectionsLock.unlock()
  }

  private func receiveRequest(on connection: NWConnection) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
      guard let self = self else { return }

      if let error = error {
        print("[CMCDProxy] Receive error: \(error)")
        connection.cancel()
        return
      }

      guard let data = data, !data.isEmpty else {
        if isComplete {
          connection.cancel()
        }
        return
      }

      self.processRequest(data: data, connection: connection)
    }
  }

  private func processRequest(data: Data, connection: NWConnection) {
    guard let requestString = String(data: data, encoding: .utf8) else {
      sendErrorResponse(connection: connection, statusCode: 400, message: "Invalid request")
      return
    }

    // Parse HTTP request
    let lines = requestString.components(separatedBy: "\r\n")
    guard let requestLine = lines.first else {
      sendErrorResponse(connection: connection, statusCode: 400, message: "Empty request")
      return
    }

    let requestParts = requestLine.components(separatedBy: " ")
    guard requestParts.count >= 2 else {
      sendErrorResponse(connection: connection, statusCode: 400, message: "Invalid request line")
      return
    }

    let method = requestParts[0]
    let path = requestParts[1]

    // Only handle GET requests
    guard method == "GET" else {
      sendErrorResponse(connection: connection, statusCode: 405, message: "Method not allowed")
      return
    }

    // Parse original headers from the request
    var originalHeaders: [String: String] = [:]
    for line in lines.dropFirst() {
      if line.isEmpty { break }
      if let colonIndex = line.firstIndex(of: ":") {
        let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
        let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
        if key.lowercased() != "host" {
          originalHeaders[key] = value
        }
      }
    }

    // Extract original URL from path: /https://example.com/video.m3u8 → https://example.com/video.m3u8
    let originalUrlString = String(path.dropFirst()) // Remove leading "/"
    guard let originalUrl = URL(string: originalUrlString) else {
      sendErrorResponse(connection: connection, statusCode: 400, message: "Invalid URL: \(originalUrlString)")
      return
    }

    // Fetch the original URL with injected headers
    fetchAndProxy(originalUrl: originalUrl, originalHeaders: originalHeaders, connection: connection)
  }

  private func fetchAndProxy(originalUrl: URL, originalHeaders: [String: String], connection: NWConnection) {
    var request = URLRequest(url: originalUrl)
    request.httpMethod = "GET"

    // Copy original headers (except Host)
    for (key, value) in originalHeaders {
      request.setValue(value, forHTTPHeaderField: key)
    }

    // Add static headers
    for (key, value) in staticHeaders {
      request.setValue(value, forHTTPHeaderField: key)
    }

    // Add dynamic headers from provider
    if let provider = dynamicHeadersProvider {
      let dynamicHeaders = provider()
      for (key, value) in dynamicHeaders {
        request.setValue(value, forHTTPHeaderField: key)
      }
    }

    // Use a session that doesn't follow redirects automatically
    let config = URLSessionConfiguration.default
    let session = URLSession(configuration: config, delegate: NoRedirectDelegate.shared, delegateQueue: nil)

    let task = session.dataTask(with: request) { [weak self] data, response, error in
      guard let self = self else { return }

      if let error = error {
        self.sendErrorResponse(connection: connection, statusCode: 502, message: "Upstream error: \(error.localizedDescription)")
        return
      }

      guard let httpResponse = response as? HTTPURLResponse else {
        self.sendErrorResponse(connection: connection, statusCode: 502, message: "Invalid upstream response")
        return
      }

      let statusCode = httpResponse.statusCode

      // Handle redirects - rewrite Location header to go through proxy
      if statusCode == 301 || statusCode == 302 || statusCode == 307 || statusCode == 308 {
        if let location = httpResponse.value(forHTTPHeaderField: "Location"),
           let redirectUrl = URL(string: location, relativeTo: originalUrl) ?? URL(string: location),
           let proxiedRedirectUrl = self.createProxyUrl(for: redirectUrl) {
          self.sendRedirectResponse(connection: connection, statusCode: statusCode, location: proxiedRedirectUrl.absoluteString)
          return
        }
      }

      // Return the response as-is (no manifest rewriting needed!)
      let responseData = data ?? Data()
      let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")

      self.sendResponse(
        connection: connection,
        statusCode: statusCode,
        contentType: contentType,
        data: responseData
      )
    }
    task.resume()
  }

  // MARK: - Response Sending

  private func sendResponse(connection: NWConnection, statusCode: Int, contentType: String?, data: Data) {
    var responseHeaders = "HTTP/1.1 \(statusCode) \(httpStatusMessage(statusCode))\r\n"
    responseHeaders += "Access-Control-Allow-Origin: *\r\n"

    if let contentType = contentType {
      responseHeaders += "Content-Type: \(contentType)\r\n"
    }

    responseHeaders += "Content-Length: \(data.count)\r\n"
    responseHeaders += "\r\n"

    guard let headerData = responseHeaders.data(using: .utf8) else {
      connection.cancel()
      return
    }

    var fullResponse = headerData
    fullResponse.append(data)

    connection.send(content: fullResponse, completion: .contentProcessed { [weak self] error in
      if let error = error {
        print("[CMCDProxy] Send error: \(error)")
      }
      connection.cancel()
      self?.removeConnection(connection)
    })
  }

  private func sendRedirectResponse(connection: NWConnection, statusCode: Int, location: String) {
    var responseHeaders = "HTTP/1.1 \(statusCode) \(httpStatusMessage(statusCode))\r\n"
    responseHeaders += "Location: \(location)\r\n"
    responseHeaders += "Content-Length: 0\r\n"
    responseHeaders += "\r\n"

    guard let headerData = responseHeaders.data(using: .utf8) else {
      connection.cancel()
      return
    }

    connection.send(content: headerData, completion: .contentProcessed { [weak self] error in
      if let error = error {
        print("[CMCDProxy] Send redirect error: \(error)")
      }
      connection.cancel()
      self?.removeConnection(connection)
    })
  }

  private func sendErrorResponse(connection: NWConnection, statusCode: Int, message: String) {
    let body = message.data(using: .utf8) ?? Data()
    sendResponse(connection: connection, statusCode: statusCode, contentType: "text/plain", data: body)
  }

  private func httpStatusMessage(_ code: Int) -> String {
    switch code {
    case 200: return "OK"
    case 301: return "Moved Permanently"
    case 302: return "Found"
    case 307: return "Temporary Redirect"
    case 308: return "Permanent Redirect"
    case 400: return "Bad Request"
    case 404: return "Not Found"
    case 405: return "Method Not Allowed"
    case 500: return "Internal Server Error"
    case 502: return "Bad Gateway"
    default: return "Unknown"
    }
  }
}

// MARK: - No Redirect Delegate

/// Delegate that prevents automatic redirect following, so we can handle redirects ourselves
private class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
  static let shared = NoRedirectDelegate()

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    // Don't follow redirects automatically - we'll handle them in the proxy
    completionHandler(nil)
  }
}
