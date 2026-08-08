import SwiftUI

// MARK: - Founding Member 邀请制(自包含模块)
//
// 兑换邀请码 → 服务端 redeem_invite_code RPC 授予永久免费 Pro + is_founding。
// 客户端只缓存 founding 布尔(UserDefaults 按 userId),徽章/入口据此显示;
// 首开异步从 users.is_founding 刷新一次。不触碰 AppUser/SupabaseUser 解码链。

enum FoundingStore {
    private static func key(_ userId: String) -> String { "brew_founding_\(userId)" }

    static func isFounding(userId: String) -> Bool {
        UserDefaults.standard.bool(forKey: key(userId))
    }
    static func set(_ value: Bool, userId: String) {
        UserDefaults.standard.set(value, forKey: key(userId))
    }
}

@MainActor
final class FoundingService: ObservableObject {
    static let shared = FoundingService()
    private init() {}

    /// 兑换邀请码。成功且为 founding → 返回 true 并缓存。
    func redeem(code: String, userId: String) async throws -> Bool {
        struct Params: Encodable { let p_code: String }
        struct Result: Decodable { let ok: Bool?; let is_founding: Bool?; let already: Bool? }
        let resp = try await SupabaseConfig.shared.client
            .rpc("redeem_invite_code", params: Params(p_code: code.trimmingCharacters(in: .whitespaces)))
            .execute()
        let result = try JSONDecoder().decode(Result.self, from: resp.data)
        let founding = result.is_founding ?? false
        if founding { FoundingStore.set(true, userId: userId) }
        return founding
    }

    /// 首开静默刷新(注册后 founding 可能是别处授予的)
    func refresh(userId: String) async {
        struct Row: Decodable { let is_founding: Bool? }
        guard let resp = try? await SupabaseConfig.shared.client
            .from("users").select("is_founding").eq("id", value: userId).single().execute(),
            let row = try? JSONDecoder().decode(Row.self, from: resp.data) else { return }
        FoundingStore.set(row.is_founding ?? false, userId: userId)
    }
}

// MARK: - Founding Member 徽章

struct FoundingBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 11, weight: .bold))
            Text("Founding")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(
            LinearGradient(colors: [Brew.goldFill, Brew.goldFillDeep],
                           startPoint: .leading, endPoint: .trailing)))
    }
}

// MARK: - 邀请码兑换 sheet

struct InviteCodeRedeemView: View {
    let userId: String
    var onFounding: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var isRedeeming = false
    @State private var errorText: String?
    @State private var success = false

    private var themeColor: Color { Brew.brand }

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 8)

            if success {
                VStack(spacing: 12) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(Brew.goldFill)
                    Text("You're a Founding Member ☕️")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Free Pro, forever. Thank you for being here early — you're the kind of person BrewNet is built around.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Button {
                        onFounding(); dismiss()
                    } label: {
                        Text("Let's go")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Brew.brandFill))
                    }
                }
                .padding(24)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Have an invite code?")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Founding members get BrewNet Pro free, for good.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    TextField("Enter code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 14).padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Brew.surfaceRaised))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(themeColor.opacity(0.15), lineWidth: 1))

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }

                    Button {
                        redeem()
                    } label: {
                        Text(isRedeeming ? "Checking…" : "Redeem")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(
                                code.trimmingCharacters(in: .whitespaces).isEmpty || isRedeeming
                                ? Color.gray.opacity(0.4) : Brew.brandFill))
                    }
                    .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || isRedeeming)
                }
                .padding(24)
            }
            Spacer()
        }
        .presentationDetents([.height(success ? 360 : 320)])
        .background(Brew.bg.ignoresSafeArea())
    }

    private func redeem() {
        isRedeeming = true
        errorText = nil
        Task {
            do {
                let founding = try await FoundingService.shared.redeem(code: code, userId: userId)
                await MainActor.run {
                    isRedeeming = false
                    if founding {
                        success = true
                    } else {
                        errorText = "That code isn't a founding invite."
                    }
                }
            } catch {
                await MainActor.run {
                    isRedeeming = false
                    errorText = "That code didn't work. Double-check and try again."
                }
            }
        }
    }
}
