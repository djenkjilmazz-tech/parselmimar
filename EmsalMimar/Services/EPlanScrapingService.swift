import Foundation
import WebKit

// MARK: - EPlanScrapingService
// WKWebView tabanlı e-Plan / eplan.tkgm.gov.tr scraper.
// Resmi imar planı sitelerinde form doldurup TAKS/KAKS/Hmax değerlerini çeker.

@MainActor
final class EPlanScrapingService: NSObject {

    static let shared = EPlanScrapingService()

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<ImarBilgisi?, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var didInject = false
    private var currentAda = ""
    private var currentParsel = ""

    // MARK: - Public API

    func fetchImarBilgisi(il: String, ilce: String, ada: String, parsel: String) async -> ImarBilgisi? {
        guard !ada.isEmpty, !parsel.isEmpty else { return nil }

        // Deneyeceğimiz URL sıraları: e-Plan (CSB) → eplan.tkgm.gov.tr
        let candidates: [(String, String)] = [
            ("https://e-plan.gov.tr/e-plan/html/imarDurumu.html", [
                "adaNo=\(ada)", "parselNo=\(parsel)",
                "ilAd=\(il.urlEncoded)", "ilceAd=\(ilce.urlEncoded)"
            ].joined(separator: "&")),
            ("https://eplan.tkgm.gov.tr", "ada=\(ada)&parsel=\(parsel)&il=\(il.urlEncoded)"),
        ]

        for (base, query) in candidates {
            guard let url = URL(string: "\(base)?\(query)") else { continue }
            if let result = await scrape(url: url, ada: ada, parsel: parsel) {
                return result
            }
        }
        return nil
    }

    // MARK: - Scraping

    private func scrape(url: URL, ada: String, parsel: String) async -> ImarBilgisi? {
        cleanup()
        didInject = false
        currentAda = ada
        currentParsel = parsel

        return await withCheckedContinuation { cont in
            self.continuation = cont

            let handler = ScriptMessageBridge { [weak self] message in
                self?.handleImarMessage(message)
            }

            let ucc = WKUserContentController()
            ucc.add(handler, name: "imarData")

            let config = WKWebViewConfiguration()
            config.userContentController = ucc

            // Küçük ama sıfır olmayan bir frame — bazı siteler visibility kontrol eder
            let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
            wv.navigationDelegate = self
            self.webView = wv

            var req = URLRequest(url: url, timeoutInterval: 8)
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            wv.load(req)

            // Toplam 14s zaman aşımı (didFinish + 3s bekleme + JS çalışma)
            self.timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 14_000_000_000)
                guard !Task.isCancelled else { return }
                self?.injectJS(ada: ada, parsel: parsel)
            }
        }
    }

    // MARK: - JavaScript Enjeksiyonu

    func injectJS(ada: String, parsel: String) {
        guard !didInject else { return }
        didInject = true

        // JS: Önce sayfada form alanlarını bul, doldur ve gönder;
        //     bulamazsa mevcut metinden TAKS/KAKS değerlerini çek.
        let js = """
        (function() {
            var ADA = '\(ada.jsEscaped)';
            var PARSEL = '\(parsel.jsEscaped)';

            function postResult(taks, kaks, hmax, kat) {
                var r = JSON.stringify({taks:taks,kaks:kaks,hmax:hmax,kat:kat});
                window.webkit.messageHandlers.imarData.postMessage(r);
            }

            function extractFromText() {
                var t = document.body ? (document.body.innerText || '') : '';
                function find(pats) {
                    for (var i=0; i<pats.length; i++) {
                        var m = t.match(pats[i]);
                        if (m && m[1]) {
                            var v = parseFloat(m[1].replace(/\\./g,'').replace(',','.'));
                            if (v > 0) return v;
                        }
                    }
                    return 0;
                }
                var taks = find([/TAKS\\s*[:\\.=]\\s*([0-9][0-9,.]*)/i, /T\\.A\\.K\\.S\\.\\s*[:\\.=]\\s*([0-9][0-9,.]*)/i]);
                var kaks = find([/KAKS\\s*[:\\.=]\\s*([0-9][0-9,.]*)/i, /EMSAL\\s*[:\\.=]\\s*([0-9][0-9,.]*)/i, /K\\.A\\.K\\.S\\.\\s*[:\\.=]\\s*([0-9][0-9,.]*)/i]);
                var hmax = find([/H\\s*[Mm]ax\\s*[:\\.=]\\s*([0-9][0-9,.]*)/i, /Y.kseklik\\s*[:\\.=]\\s*([0-9][0-9,.]*)/i, /YUKSEKLIK\\s*[:\\.=]\\s*([0-9][0-9,.]*)/i]);
                var kat  = find([/Kat\\s+Adedi\\s*[:\\.=]\\s*([0-9]+)/i, /[Mm]aksimum\\s+[Kk]at\\s*[:\\.=]\\s*([0-9]+)/i, /MAX[\\._]KAT\\s*[:\\.=]\\s*([0-9]+)/i]);
                postResult(taks, kaks, hmax, kat);
            }

            // Form doldurma denemesi
            var inputs = document.querySelectorAll('input[type="text"], input:not([type])');
            var adaInput = null, parselInput = null;
            for (var i=0; i<inputs.length; i++) {
                var inp = inputs[i];
                var label = ((inp.name||'')+(inp.id||'')+(inp.placeholder||'')+(inp.getAttribute('aria-label')||'')).toLowerCase();
                if (!adaInput && label.indexOf('ada') >= 0 && label.indexOf('parsel') < 0 && label.indexOf('mahalle') < 0) {
                    adaInput = inp;
                } else if (!parselInput && label.indexOf('parsel') >= 0) {
                    parselInput = inp;
                }
            }

            if (adaInput && parselInput) {
                adaInput.value = ADA;
                parselInput.value = PARSEL;
                ['input','change','keyup'].forEach(function(ev) {
                    adaInput.dispatchEvent(new Event(ev, {bubbles:true}));
                    parselInput.dispatchEvent(new Event(ev, {bubbles:true}));
                });

                // Submit butonu ara
                var btns = document.querySelectorAll('button, input[type="submit"], input[type="button"]');
                var submitted = false;
                for (var j=0; j<btns.length; j++) {
                    var txt = (btns[j].textContent || btns[j].value || '').toLowerCase();
                    if (txt.match(/sorgula|ara|getir|sorgu|search/)) {
                        btns[j].click();
                        submitted = true;
                        break;
                    }
                }
                if (!submitted) {
                    var form = adaInput.closest('form');
                    if (form) form.submit();
                }
                // Form gönderdikten 4s sonra çek
                setTimeout(extractFromText, 4000);
            } else {
                // Form bulunamadı, mevcut sayfadan direkt çek
                extractFromText();
            }
        })();
        """

        webView?.evaluateJavaScript(js) { [weak self] _, err in
            if err != nil {
                Task { @MainActor [weak self] in self?.cleanup() }
            }
        }
    }

    // MARK: - Mesaj İşleme

    private func handleImarMessage(_ body: String) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { cleanup(); return }

        func d(_ k: String) -> Double {
            (json[k] as? Double) ?? (json[k] as? Int).map(Double.init) ?? 0
        }
        let taks = d("taks"), kaks = d("kaks"), hmax = d("hmax")
        let kat = Int(d("kat"))

        guard taks > 0 || kaks > 0 else { cleanup(); return }

        let result = ImarBilgisi(
            taks: taks, kaks: kaks, hmax: hmax,
            katSayisi: kat > 0 ? kat : (hmax > 0 ? max(1, Int((hmax - 3.0) / 3.0)) : 0),
            kullanim: "", kaynak: "e-Plan"
        )
        finish(result)
    }

    private func finish(_ result: ImarBilgisi?) {
        let c = continuation
        cleanup()
        c?.resume(returning: result)
    }

    private func cleanup() {
        timeoutTask?.cancel()
        timeoutTask = nil
        webView?.navigationDelegate = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "imarData")
        webView = nil
        if let c = continuation {
            continuation = nil
            c.resume(returning: nil)
        }
    }
}

// MARK: - WKNavigationDelegate

extension EPlanScrapingService: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Dinamik içeriğin yüklenmesi için 3s bekle
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !self.didInject else { return }
            self.injectJS(ada: self.currentAda, parsel: self.currentParsel)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor [weak self] in self?.cleanup() }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor [weak self] in self?.cleanup() }
    }
}

// MARK: - Script Message Bridge (retain cycle kırıcı)

private final class ScriptMessageBridge: NSObject, WKScriptMessageHandler {
    private let callback: @MainActor (String) -> Void

    init(callback: @escaping @MainActor (String) -> Void) {
        self.callback = callback
    }

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else { return }
        Task { @MainActor in self.callback(body) }
    }
}

// MARK: - String Helpers

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
    var jsEscaped: String {
        replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\\", with: "\\\\")
    }
}
