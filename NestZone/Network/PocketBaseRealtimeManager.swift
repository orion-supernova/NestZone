import Foundation

@MainActor
class PocketBaseRealtimeManager: NSObject, ObservableObject {
    static let shared = PocketBaseRealtimeManager()
    
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var clientId: String?
    private var subscriptions: Set<String> = []
    private var callbacks: [String: (PocketBaseRealtimeEvent) -> Void] = [:]
    private let pocketBase = PocketBaseManager.shared
    private var buffer = Data()
    
    @Published var isConnected = false
    @Published var connectionError: String?
    
    override private init() {
        super.init()
    }
    
    // MARK: - Connection Management
    
    func connect() async throws {
        // Only disconnect if we have an active connection but need to reconnect
        if dataTask != nil {
            print("DEBUG: Realtime - Existing connection found, disconnecting first")
            await disconnect()
        }
        
        guard let url = URL(string: "\(pocketBase.baseURL)/api/realtime") else {
            throw PocketBaseRealtimeError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        // Add auth token if available
        if let token = pocketBase.getAuthToken() {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        
        print("DEBUG: Realtime - Connecting to SSE endpoint with auth token: \(pocketBase.getAuthToken() != nil)")
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30 // 30 second timeout
        configuration.timeoutIntervalForResource = 0 // No timeout for SSE
        
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        dataTask = session?.dataTask(with: request)
        dataTask?.resume()
        
        // Wait for connection to be established with better timeout
        var attempts = 0
        while !isConnected && connectionError == nil && attempts < 150 { // 30 seconds total
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            attempts += 1
            
            // Log progress every 5 seconds
            if attempts % 25 == 0 {
                print("DEBUG: Realtime - Still waiting for connection... attempt \(attempts)")
            }
        }
        
        if let error = connectionError {
            print("DEBUG: Realtime - Connection failed with error: \(error)")
            throw PocketBaseRealtimeError.connectionFailed
        }
        
        if !isConnected {
            print("DEBUG: Realtime - Connection timeout")
            throw PocketBaseRealtimeError.connectionFailed
        }
        
        print("DEBUG: Realtime - Connection established successfully")
    }
    
    func disconnect() async {
        print("DEBUG: Realtime - Disconnecting")
        
        await MainActor.run {
            dataTask?.cancel()
            session?.invalidateAndCancel()
            dataTask = nil
            session = nil
            clientId = nil
            isConnected = false
            buffer = Data()
            // Keep subscriptions and callbacks for reconnection
        }
    }
    
    func clearAllSubscriptions() async {
        print("DEBUG: Realtime - Clearing all subscriptions and callbacks")
        subscriptions.removeAll()
        callbacks.removeAll()
        await disconnect()
    }
    
    // MARK: - Subscription Management
    
    func subscribe(to collection: String, recordId: String? = nil, callback: @escaping (PocketBaseRealtimeEvent) -> Void) async throws {
        let topic = recordId != nil ? "\(collection)/\(recordId!)" : collection
        
        print("DEBUG: Realtime - Subscribing to: \(topic)")
        
        // Connect if not connected FIRST
        if !isConnected {
            print("DEBUG: Realtime - Not connected, initiating connection")
            try await connect()
            
            // Wait for client ID with reasonable timeout
            var attempts = 0
            while clientId == nil && connectionError == nil && attempts < 50 { // 10 seconds
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                attempts += 1
                
                if attempts % 10 == 0 {
                    print("DEBUG: Realtime - Still waiting for client ID... attempt \(attempts)")
                }
            }
            
            guard let clientId = clientId else {
                print("DEBUG: Realtime - No client ID received after waiting")
                throw PocketBaseRealtimeError.notConnected
            }
            
            print("DEBUG: Realtime - Client ID received: \(clientId)")
        } else {
            print("DEBUG: Realtime - Already connected with client ID: \(clientId ?? "none")")
        }
        
        guard let clientId = clientId else {
            throw PocketBaseRealtimeError.notConnected
        }
        
        // NOW store callback AFTER connection is established
        callbacks[topic] = callback
        print("DEBUG: Realtime - Stored callback for topic: \(topic)")
        print("DEBUG: Realtime - Total callbacks now: \(callbacks.count)")
        
        // Add to subscriptions
        subscriptions.insert(topic)
        print("DEBUG: Realtime - Added subscription: \(topic)")
        print("DEBUG: Realtime - Total subscriptions: \(subscriptions)")
        
        // Send subscription request
        try await setSubscriptions(clientId: clientId, subscriptions: Array(subscriptions))
        
        print("DEBUG: Realtime - Successfully subscribed to \(topic)")
        print("DEBUG: Realtime - Final callback check - count: \(callbacks.count), topics: \(Array(callbacks.keys))")
    }
    
    func unsubscribe(from collection: String, recordId: String? = nil) async throws {
        let topic = recordId != nil ? "\(collection)/\(recordId!)" : collection
        
        print("DEBUG: Realtime - Unsubscribing from: \(topic)")
        
        // Remove from local state first
        subscriptions.remove(topic)
        callbacks.removeValue(forKey: topic)
        
        // If not connected or no client ID, we're already effectively unsubscribed
        guard isConnected, let clientId = clientId else {
            print("DEBUG: Realtime - Not connected or no client ID, local unsubscribe only")
            return
        }
        
        do {
            try await setSubscriptions(clientId: clientId, subscriptions: Array(subscriptions))
            print("DEBUG: Realtime - Successfully unsubscribed from server")
        } catch {
            print("DEBUG: Realtime - Server unsubscribe failed (connection might be closed): \(error)")
            // Don't throw the error - local unsubscribe is sufficient if server fails
        }
    }
    
    // MARK: - Private Implementation
    
    private func setSubscriptions(clientId: String, subscriptions: [String]) async throws {
        let body: [String: Any] = [
            "clientId": clientId,
            "subscriptions": subscriptions
        ]
        
        guard let url = URL(string: "\(pocketBase.baseURL)/api/realtime"),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            throw PocketBaseRealtimeError.invalidRequest
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        
        // Add auth token if available
        if let token = pocketBase.getAuthToken() {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PocketBaseRealtimeError.subscriptionFailed
        }
        
        if httpResponse.statusCode == 404 {
            print("DEBUG: Realtime - Client ID expired (404), reconnecting...")
            // Client ID is invalid, need to reconnect
            await disconnect()
            try await connect()
            
            // Wait for new client ID
            var attempts = 0
            while clientId == self.clientId && attempts < 50 {
                try await Task.sleep(nanoseconds: 200_000_000)
                attempts += 1
            }
            
            guard let newClientId = self.clientId else {
                throw PocketBaseRealtimeError.notConnected
            }
            
            print("DEBUG: Realtime - Got new client ID: \(newClientId), retrying subscription")
            
            // Retry with new client ID
            let newBody: [String: Any] = [
                "clientId": newClientId,
                "subscriptions": subscriptions
            ]
            
            guard let newBodyData = try? JSONSerialization.data(withJSONObject: newBody) else {
                throw PocketBaseRealtimeError.invalidRequest
            }
            
            var newRequest = URLRequest(url: url)
            newRequest.httpMethod = "POST"
            newRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            newRequest.httpBody = newBodyData
            
            if let token = pocketBase.getAuthToken() {
                newRequest.setValue(token, forHTTPHeaderField: "Authorization")
            }
            
            let (_, retryResponse) = try await URLSession.shared.data(for: newRequest)
            
            guard let retryHttpResponse = retryResponse as? HTTPURLResponse,
                  retryHttpResponse.statusCode == 204 else {
                print("DEBUG: Realtime - Retry subscription failed with status: \((retryResponse as? HTTPURLResponse)?.statusCode ?? -1)")
                throw PocketBaseRealtimeError.subscriptionFailed
            }
            
            print("DEBUG: Realtime - Retry subscriptions successful")
            
        } else if httpResponse.statusCode == 204 {
            print("DEBUG: Realtime - Subscriptions updated: \(subscriptions)")
        } else {
            print("DEBUG: Realtime - Subscription failed with status: \(httpResponse.statusCode)")
            throw PocketBaseRealtimeError.subscriptionFailed
        }
    }
    
    private func processBuffer() {
        let bufferString = String(data: buffer, encoding: .utf8) ?? ""
        print("DEBUG: Realtime - Raw buffer content: '\(bufferString.replacingOccurrences(of: "\n", with: "\\n"))'")
        
        // Process complete SSE events separated by double newline
        while let range = buffer.range(of: Data("\n\n".utf8)) {
            let eventData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            
            if let eventString = String(data: eventData, encoding: .utf8) {
                print("DEBUG: Realtime - Complete event: '\(eventString.replacingOccurrences(of: "\n", with: "\\n"))'")
                processEventString(eventString)
            }
        }
        
        // Also check if there's any remaining single newline data that might be a complete event
        let remainingString = String(data: buffer, encoding: .utf8) ?? ""
        if !remainingString.isEmpty {
            print("DEBUG: Realtime - Remaining in buffer: '\(remainingString.replacingOccurrences(of: "\n", with: "\\n"))'")
        }
    }
    
    private func processEventString(_ eventString: String) {
        print("DEBUG: Realtime - Processing event string: \(eventString)")
        let lines = eventString.components(separatedBy: .newlines)
        
        var eventType: String?
        var eventData: String?
        var eventId: String?
        
        for line in lines {
            if line.hasPrefix("event:") {
                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                print("DEBUG: Realtime - Event type: \(eventType ?? "nil")")
            } else if line.hasPrefix("data:") {
                eventData = String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                print("DEBUG: Realtime - Event data: \(eventData ?? "nil")")
            } else if line.hasPrefix("id:") {
                eventId = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                print("DEBUG: Realtime - Event ID: \(eventId ?? "nil")")
            }
        }
        
        // Process the event data
        if let eventData = eventData {
            // Skip heartbeat messages
            if eventData.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("DEBUG: Realtime - Skipping heartbeat")
                return
            }
            
            print("DEBUG: Realtime - Processing event data: \(eventData)")
            
            if let data = eventData.data(using: .utf8) {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("DEBUG: Realtime - Parsed JSON: \(json)")
                        
                        // Handle PB_CONNECT event
                        if eventType == "PB_CONNECT" {
                            if let clientId = json["clientId"] as? String {
                                self.clientId = clientId
                                print("DEBUG: Realtime - Connected with client ID: \(clientId)")
                            } else {
                                print("DEBUG: Realtime - PB_CONNECT event missing clientId")
                                print("DEBUG: Realtime - JSON keys: \(Array(json.keys))")
                            }
                        } else {
                            // Handle record event
                            if let event = parseRealtimeEvent(from: json) {
                                handleRealtimeEvent(event)
                            } else {
                                print("DEBUG: Realtime - Failed to parse as record event")
                            }
                        }
                    }
                } catch {
                    print("DEBUG: Realtime - Failed to parse event data as JSON: \(error)")
                    print("DEBUG: Realtime - Raw data: \(eventData)")
                }
            }
        }
    }
    
    private func parseRealtimeEvent(from json: [String: Any]) -> PocketBaseRealtimeEvent? {
        guard let action = json["action"] as? String else {
            print("DEBUG: Realtime - Missing action in event")
            return nil
        }
        
        // PocketBase sends the actual record data nested under "record" field
        guard let record = json["record"] as? [String: Any] else {
            print("DEBUG: Realtime - Missing record in event")
            return nil
        }
        
        print("DEBUG: Realtime - Parsed event with action: \(action)")
        print("DEBUG: Realtime - Record keys: \(Array(record.keys))")
        
        return PocketBaseRealtimeEvent(
            action: PocketBaseRealtimeEvent.Action(rawValue: action) ?? .create,
            record: record
        )
    }
    
    private func handleRealtimeEvent(_ event: PocketBaseRealtimeEvent) {
        print("DEBUG: Realtime - Received event: \(event.action) for record")
        print("DEBUG: Realtime - Record ID: \(event.record["id"] as? String ?? "unknown")")
        print("DEBUG: Realtime - Record collection: \(event.record["collectionName"] as? String ?? "unknown")")
        print("DEBUG: Realtime - Active callbacks count: \(callbacks.count)")
        print("DEBUG: Realtime - Active callback topics: \(Array(callbacks.keys))")
        
        // Find matching subscription callbacks
        for (topic, callback) in callbacks {
            print("DEBUG: Realtime - Checking topic: \(topic)")
            // Check if this event matches any of our subscriptions
            if shouldDeliverEvent(event, to: topic) {
                print("DEBUG: Realtime - Delivering event to topic: \(topic)")
                callback(event)
            } else {
                print("DEBUG: Realtime - Event does not match topic: \(topic)")
            }
        }
    }
    
    private func shouldDeliverEvent(_ event: PocketBaseRealtimeEvent, to topic: String) -> Bool {
        // For messages collection subscription
        if topic == "messages" {
            // Check if the record is a message by looking for conversation_id field OR collectionName
            let hasConversationId = event.record["conversation_id"] != nil
            let isMessagesCollection = event.record["collectionName"] as? String == "messages"
            
            print("DEBUG: Realtime - Event delivery check for topic '\(topic)':")
            print("DEBUG: Realtime - Has conversation_id: \(hasConversationId)")
            print("DEBUG: Realtime - Is messages collection: \(isMessagesCollection)")
            
            return hasConversationId || isMessagesCollection
        }
        
        // For specific record subscriptions like "messages/record_id"
        if topic.contains("/") {
            let components = topic.split(separator: "/")
            if components.count == 2 {
                let collection = String(components[0])
                let recordId = String(components[1])
                
                if collection == "messages" && event.record["id"] as? String == recordId {
                    return true
                }
            }
        }
        
        return false
    }
}

// MARK: - URLSessionDataDelegate

extension PocketBaseRealtimeManager: URLSessionDataDelegate {
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        if let httpResponse = response as? HTTPURLResponse {
            print("DEBUG: Realtime - Received response with status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                Task { @MainActor in
                    print("DEBUG: Realtime - HTTP 200 received, marking as connected")
                    self.isConnected = true
                    self.connectionError = nil
                }
                completionHandler(.allow)
            } else {
                Task { @MainActor in
                    self.connectionError = "HTTP \(httpResponse.statusCode)"
                    self.isConnected = false
                }
                completionHandler(.cancel)
            }
        } else {
            print("DEBUG: Realtime - Non-HTTP response received")
            completionHandler(.cancel)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let dataString = String(data: data, encoding: .utf8) ?? ""
        print("DEBUG: Realtime - Received data chunk: '\(dataString.replacingOccurrences(of: "\n", with: "\\n"))'")
        
        Task { @MainActor in
            self.buffer.append(data)
            self.processBuffer()
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("DEBUG: Realtime - Stream completed with error: \(error)")
                self.connectionError = error.localizedDescription
            } else {
                print("DEBUG: Realtime - Stream completed successfully")
            }
            self.isConnected = false
            self.clientId = nil
        }
    }
}

// MARK: - Supporting Types

struct PocketBaseRealtimeEvent {
    let action: Action
    let record: [String: Any]
    
    enum Action: String {
        case create = "create"
        case update = "update"
        case delete = "delete"
    }
}

enum PocketBaseRealtimeError: LocalizedError {
    case invalidURL
    case connectionFailed
    case notConnected
    case invalidRequest
    case subscriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid realtime URL"
        case .connectionFailed:
            return "Failed to connect to realtime service"
        case .notConnected:
            return "Not connected to realtime service"
        case .invalidRequest:
            return "Invalid realtime request"
        case .subscriptionFailed:
            return "Failed to set subscriptions"
        }
    }
}