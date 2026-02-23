import Foundation

class ConnectivityChecker {

    static let monitoringURLString = "http://captive.apple.com"

    func checkOutboundConnection(completion: @escaping (Bool) -> Void) {

        print("Attempting outbound connection to:", Self.monitoringURLString)

        guard let url = URL(string: Self.monitoringURLString) else {
            completion(false)
            return
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 5
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.httpAdditionalHeaders = ["Connection": "close"]

        let session = URLSession(configuration: configuration)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        let task = session.dataTask(with: request) { _, response, error in

            defer { session.finishTasksAndInvalidate() }

            if let error = error {
                print("Outbound Error:", error.localizedDescription)
                completion(false)
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               (200...399).contains(httpResponse.statusCode) {
                completion(true)
            } else {
                completion(false)
            }
        }

        task.resume()
    }
}
