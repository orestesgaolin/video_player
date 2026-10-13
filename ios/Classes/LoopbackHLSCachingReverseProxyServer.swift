import Foundation
import GCDWebServer
import HLSCachingReverseProxyServer
import PINCache

/// Serves the HLS cache on the loopback interface only.
///
/// `HLSCachingReverseProxyServer.start(port:)` listens on every interface. iOS treats a listener on a non-loopback
/// interface as local network access and shows the "find devices on local networks" permission prompt. The player
/// only connects to `127.0.0.1`, so loopback is sufficient.
final class LoopbackHLSCachingReverseProxyServer: HLSCachingReverseProxyServer {
    /// The query item the base class reads the origin URL from. Its own constant is internal to its module.
    private static let originURLQueryName = "__hls_origin_url"

    private let loopbackWebServer: GCDWebServer
    private var loopbackPort: Int?

    override init(webServer: GCDWebServer, urlSession: URLSession, cache: PINCaching) {
        loopbackWebServer = webServer
        super.init(webServer: webServer, urlSession: urlSession, cache: cache)
    }

    override func start(port: UInt) {
        guard !loopbackWebServer.isRunning else { return }
        do {
            try loopbackWebServer.start(options: [
                GCDWebServerOption_Port: port,
                GCDWebServerOption_BindToLocalhost: true,
            ])
            loopbackPort = Int(port)
        } catch {
            NSLog("Cache error: couldn't start the HLS cache server on port \(port): \(error)")
        }
    }

    override func stop() {
        guard loopbackWebServer.isRunning else { return }
        loopbackPort = nil
        loopbackWebServer.stop()
    }

    override func reverseProxyURL(from originURL: URL) -> URL? {
        guard let port = loopbackPort else { return nil }
        guard var components = URLComponents(url: originURL, resolvingAgainstBaseURL: false) else { return nil }
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = port
        let originURLQueryItem = URLQueryItem(name: Self.originURLQueryName, value: originURL.absoluteString)
        components.queryItems = (components.queryItems ?? []) + [originURLQueryItem]
        return components.url
    }
}
