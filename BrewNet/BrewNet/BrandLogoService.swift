import SwiftUI

// MARK: - Brand Logo Service(2026-08)
//
// 真实品牌 logo:公司 / 学校 / 咖啡场地,统一走 Logo.dev(publishable key 可安全内嵌)。
// 解析链:精选词典(常见公司/高校/连锁)→ 启发式猜域名 → 失败则首字母圆形兜底。
// 用法:BrandLogoView(name: "Stripe", size: 20)

enum BrandLogoService {

    private static let token = "pk_fanbtmnIS-C1PfcFZH8mlQ"

    /// 常见品牌词典(用户池高频命中;小写包含匹配)
    private static let knownDomains: [(keys: [String], domain: String)] = [
        // —— 科技公司 ——
        (["google", "alphabet"], "google.com"),
        (["meta", "facebook"], "meta.com"),
        (["apple"], "apple.com"),
        (["amazon", "aws"], "amazon.com"),
        (["microsoft"], "microsoft.com"),
        (["netflix"], "netflix.com"),
        (["nvidia"], "nvidia.com"),
        (["stripe"], "stripe.com"),
        (["tiktok"], "tiktok.com"),
        (["bytedance", "字节"], "bytedance.com"),
        (["openai"], "openai.com"),
        (["anthropic"], "anthropic.com"),
        (["uber"], "uber.com"),
        (["airbnb"], "airbnb.com"),
        (["linkedin"], "linkedin.com"),
        (["tesla"], "tesla.com"),
        (["salesforce"], "salesforce.com"),
        (["jingdong", "jd.com", "京东"], "jd.com"),
        (["sharkninja", "shark ninja", "shark ninjia"], "sharkninja.com"),
        // —— 咨询 / 金融 ——
        (["mckinsey"], "mckinsey.com"),
        (["bcg", "boston consulting"], "bcg.com"),
        (["bain"], "bain.com"),
        (["deloitte"], "deloitte.com"),
        (["goldman"], "goldmansachs.com"),
        (["jpmorgan", "jp morgan"], "jpmorganchase.com"),
        (["morgan stanley"], "morganstanley.com"),
        (["blackrock"], "blackrock.com"),
        // —— 高校 ——
        (["usc", "university of southern california"], "usc.edu"),
        (["ucla"], "ucla.edu"),
        (["stanford"], "stanford.edu"),
        (["berkeley", "uc berkeley"], "berkeley.edu"),
        (["mit", "massachusetts institute"], "mit.edu"),
        (["harvard"], "harvard.edu"),
        (["boston university"], "bu.edu"),
        (["carnegie mellon", "cmu"], "cmu.edu"),
        (["nyu", "new york university"], "nyu.edu"),
        (["columbia"], "columbia.edu"),
        (["university of michigan", "umich"], "umich.edu"),
        (["university of washington"], "washington.edu"),
        (["georgia tech"], "gatech.edu"),
        (["caltech"], "caltech.edu"),
        (["fudan", "复旦"], "fudan.edu.cn"),
        (["tsinghua", "清华"], "tsinghua.edu.cn"),
        (["peking university", "北大"], "pku.edu.cn"),
        (["shanghai jiao tong", "sjtu", "交大"], "sjtu.edu.cn"),
        (["zhejiang university", "浙大"], "zju.edu.cn"),
        // —— 咖啡场地 ——
        (["starbucks"], "starbucks.com"),
        (["blue bottle"], "bluebottlecoffee.com"),
        (["philz"], "philzcoffee.com"),
        (["verve"], "vervecoffee.com"),
        (["intelligentsia"], "intelligentsia.com"),
        (["peet"], "peets.com"),
        (["dunkin"], "dunkindonuts.com"),
        (["dulce"], "dulcela.com"),
    ]

    /// name → Logo.dev URL(找不到域名返回 nil,由视图兜底)
    static func logoURL(for name: String, size: Int = 64) -> URL? {
        guard let domain = resolveDomain(name) else { return nil }
        return URL(string: "https://img.logo.dev/\(domain)?token=\(token)&size=\(size)&format=png&retina=true")
    }

    static func resolveDomain(_ name: String) -> String? {
        let lower = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return nil }
        // 1) 词典
        for entry in knownDomains {
            if entry.keys.contains(where: { lower.contains($0) }) { return entry.domain }
        }
        // 2) 已是域名
        if lower.contains("."), !lower.contains(" ") { return lower }
        // 3) 启发式:单词 ≤2 且非泛词 → 猜 .com(Logo.dev 未命中会回 monogram,视觉可接受)
        let generic = ["startup", "stealth", "freelance", "self", "student", "university", "college", "n/a", "none"]
        if generic.contains(where: { lower.contains($0) }) { return nil }
        let words = lower.split(separator: " ")
        if words.count <= 2 {
            let guessed = words.joined().replacingOccurrences(of: "&", with: "").replacingOccurrences(of: ",", with: "")
            if guessed.count >= 3 { return "\(guessed).com" }
        }
        return nil
    }
}

// MARK: - Brand Logo View(带首字母兜底)

struct BrandLogoView: View {
    let name: String
    var size: CGFloat = 18

    private var themeColor: Color { Color(red: 0.4, green: 0.2, blue: 0.1) }

    var body: some View {
        Group {
            if let url = BrandLogoService.logoURL(for: name, size: Int(size * 3)) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22).fill(themeColor.opacity(0.12))
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundColor(themeColor.opacity(0.7))
        }
    }
}
