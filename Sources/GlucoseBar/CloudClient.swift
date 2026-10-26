import Foundation
import GlucoseCore

enum CloudError: LocalizedError {
    case authentication, rateLimited, unavailable, badResponse, network
    var errorDescription: String? {
        switch self {
        case .authentication: return "登录凭证已失效。请在设置中更新凭证。"
        case .rateLimited: return "云端请求过于频繁，稍后自动重试。"
        case .unavailable: return "硅基云端暂时不可用，稍后自动重试。"
        case .badResponse: return "云端返回格式发生变化，暂时无法读取。"
        case .network: return "网络连接失败，稍后自动重试。"
        }
    }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

struct CloudClient: Sendable {
    static let endpoint = URL(string: "https://api.sisensing.com/follow/app/follow/myself/glucose/details/devices")!

    func fetch(token: String) async throws -> [SensorSeries] {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        config.httpShouldSetCookies = false
        config.urlCache = nil
        let session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        request.setValue("GlucoseBar/\(version) macOS", forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch { throw CloudError.network }
        guard let http = response as? HTTPURLResponse else { throw CloudError.badResponse }
        switch http.statusCode {
        case 200: break
        case 401, 403: throw CloudError.authentication
        case 429: throw CloudError.rateLimited
        case 500...599: throw CloudError.unavailable
        default: throw CloudError.badResponse
        }
        // Only static local error messages reach the UI. Never log response bodies or credentials.
        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = root["code"] {
            let number = (code as? NSNumber)?.intValue ?? Int(code as? String ?? "")
            if number == 401 || number == 403 { throw CloudError.authentication }
        }
        return try SisensingParser.parse(data)
    }
}
