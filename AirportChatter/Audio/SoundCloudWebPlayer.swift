import Foundation
import SwiftUI
import WebKit

@MainActor
final class SoundCloudWebPlayer {
    private weak var webView: WKWebView?
    private var wantsPlayback = false
    private var volume = 0.5
    private(set) var isReady = false {
        didSet { onReadyChanged?(isReady) }
    }

    var onReadyChanged: ((Bool) -> Void)?
    var onPlayingChanged: ((Bool) -> Void)?
    var onFailure: ((String) -> Void)?
    var onRemoteCommand: ((PlaybackCommand) -> Void)?

    func attach(webView: WKWebView) {
        guard self.webView !== webView else { return }
        self.webView = webView
        loading()
    }

    func loading() {
        isReady = false
        onPlayingChanged?(false)
    }

    func receive(_ message: String) {
        switch message {
        case "ready":
            isReady = true
            send("setVolume", value: Int(volume * 100))
            send(wantsPlayback ? "play" : "pause")
        case "playing": onPlayingChanged?(true)
        case "paused", "finished": onPlayingChanged?(false)
        case "error":
            onPlayingChanged?(false)
            onFailure?("SoundCloud could not play this track. Try another track or use its embedded player.")
        default: break
        }
    }

    func setVolume(_ value: Double) {
        volume = max(0, min(1, value))
        send("setVolume", value: Int(volume * 100))
    }

    func play() { wantsPlayback = true; send("play") }
    func pause() { wantsPlayback = false; send("pause") }
    func next() { send("next") }
    func previous() { send("prev") }

    private func send(_ command: String, value: Int? = nil) {
        guard isReady, let webView else { return }
        let argument = value.map { ", \($0)" } ?? ""
        webView.evaluateJavaScript("window.nativeSoundCloudControl('\(command)'\(argument))") { [weak self] _, error in
            if error != nil {
                self?.isReady = false
                self?.onPlayingChanged?(false)
                self?.onFailure?("Could not communicate with the SoundCloud player.")
            }
        }
    }
}

@MainActor
final class SoundCloudCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let bridge: SoundCloudWebPlayer

    init(bridge: SoundCloudWebPlayer) { self.bridge = bridge }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let event = message.body as? String else { return }
        if message.name == "soundCloudRemote" {
            guard message.frameInfo.securityOrigin.host == "w.soundcloud.com",
                  let command = PlaybackCommand(rawValue: event) else { return }
            bridge.onRemoteCommand?(command)
        } else if message.frameInfo.isMainFrame {
            bridge.receive(event)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        bridge.loading()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        bridge.receive("error")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        bridge.loading()
        webView.reload()
    }
}

#if os(iOS)
struct SoundCloudWebView: UIViewRepresentable {
    let bridge: SoundCloudWebPlayer

    func makeCoordinator() -> SoundCloudCoordinator {
        SoundCloudCoordinator(bridge: bridge)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = buildWebView(context: context)
        bridge.attach(webView: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Keep SwiftUI update cycles side-effect free to avoid layout loops.
    }

}
#elseif os(macOS)
struct SoundCloudWebView: NSViewRepresentable {
    let bridge: SoundCloudWebPlayer

    func makeCoordinator() -> SoundCloudCoordinator {
        SoundCloudCoordinator(bridge: bridge)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = buildWebView(context: context)
        bridge.attach(webView: webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Keep SwiftUI update cycles side-effect free to avoid layout loops.
    }

}
#endif

extension SoundCloudWebView {
    func buildWebView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.userContentController.add(context.coordinator, name: "soundCloud")
        config.userContentController.add(context.coordinator, name: "soundCloudRemote")
        config.userContentController.addUserScript(WKUserScript(source: Self.remoteControlScript,
            injectionTime: .atDocumentStart, forMainFrameOnly: false))
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
#if os(iOS)
        config.allowsInlineMediaPlayback = true
#endif
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
#if os(iOS)
        webView.isOpaque = false
        webView.backgroundColor = .clear
#endif
        webView.loadHTMLString(Self.embeddedHTML, baseURL: nil)
        return webView
    }

    // WebKit may own Now Playing while the widget is audible. Forward its system
    // media-session actions to the same coordinator as the app's native controls.
    static let remoteControlScript = """
    (() => {
      if (location.hostname !== 'w.soundcloud.com' || !('mediaSession' in navigator)) return;
      const actions = {play: 'play', pause: 'pause', stop: 'pause', nexttrack: 'next', previoustrack: 'previous'};
      const session = navigator.mediaSession;
      const setActionHandler = session.setActionHandler.bind(session);
      const forward = command => () => window.webkit.messageHandlers.soundCloudRemote.postMessage(command);
      // The widget installs (and replaces) its own handlers asynchronously.
      // Keep shared transport actions routed to native even after those updates.
      session.setActionHandler = (action, handler) => {
        const command = Object.prototype.hasOwnProperty.call(actions, action) ? actions[action] : null;
        setActionHandler(action, command ? forward(command) : handler);
      };
      function install() {
        for (const [action, command] of Object.entries(actions)) {
          try {
            setActionHandler(action, forward(command));
          } catch (_) { /* Some OS versions do not support every action. */ }
        }
      }
      install();
      document.addEventListener('play', install, true);
    })();
    """

    // show_teaser=false removes the mobile app-promotion overlay without synthetic clicks.
    static let embeddedHTML = """
    <!DOCTYPE html>
    <html>
      <head>
        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />
        <style>
          html, body {
            margin: 0;
            padding: 0;
            background: #0e1620;
            height: 100%;
          }
          #wrap {
            height: 100%;
            width: 100%;
          }
          iframe {
            width: 100%;
            height: 100%;
            border: 0;
          }
        </style>
      </head>
      <body>
        <div id=\"wrap\">
          <iframe
            id=\"sc-widget\"
            scrolling=\"no\"
            allow=\"autoplay\"
            src=\"https://w.soundcloud.com/player/?url=https%3A//api.soundcloud.com/playlists/5281179&color=00aabb&auto_play=false&hide_related=false&show_comments=false&show_user=true&show_reposts=false&show_teaser=false\"
          ></iframe>
        </div>

        <script src=\"https://w.soundcloud.com/player/api.js\"></script>
        <script>
          const notify = event => window.webkit.messageHandlers.soundCloud.postMessage(event);

          const iframe = document.getElementById('sc-widget');
          const widget = SC.Widget(iframe);

          widget.bind(SC.Widget.Events.READY, function() {
            notify("ready");
          });

          widget.bind(SC.Widget.Events.PLAY, () => notify("playing"));
          widget.bind(SC.Widget.Events.PAUSE, () => notify("paused"));
          widget.bind(SC.Widget.Events.FINISH, () => notify("finished"));
          widget.bind(SC.Widget.Events.ERROR, () => notify("error"));

          let transportRevision = 0;
          window.nativeSoundCloudControl = function(action, value) {
            if (!widget) return;
            const revision = action === 'setVolume' ? transportRevision : ++transportRevision;
            switch (action) {
              case 'play':
                widget.play();
                break;
              case 'pause':
                widget.pause();
                break;
              case 'next':
              case 'prev':
                widget.isPaused(function(paused) {
                  if (revision !== transportRevision) return;
                  if (action === 'next') widget.next(); else widget.prev();
                  if (paused) widget.pause(); else widget.play();
                });
                break;
              case 'setVolume':
                widget.setVolume(Number(value));
                break;
            }
          }
        </script>
      </body>
    </html>
    """
}
