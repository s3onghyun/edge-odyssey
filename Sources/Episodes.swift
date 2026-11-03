import Foundation

/// Short encounters from Homer's Odyssey (public domain). They decorate the voyage only:
/// they never change where the traveler is at a given time, never take input, and are
/// collected in a local logbook of the poem's 24 books.
enum Episode: String, CaseIterable {
    case cyclops, aeolus, whirlpool, circe, owl, lotus, sirens, storm, calypso, ithaca

    /// Books of the Odyssey this encounter belongs to.
    var books: [Int] {
        switch self {
        case .owl: return [1]
        case .calypso, .storm: return [5]
        case .lotus, .cyclops: return [9]
        case .aeolus, .circe: return [10]
        case .sirens, .whirlpool: return [12]
        case .ithaca: return [13, 17]
        }
    }

    /// Short names for all 24 books. Only the ones an episode belongs to can be found so far.
    static func bookTitle(_ book: Int, lang: Lang? = nil) -> String {
        switch book {
        case 1: return L.t("Athena's owl", "아테나의 올빼미", "アテナのフクロウ", "雅典娜的猫头鹰", in: lang)
        case 2: return L.t("Telemachus speaks", "텔레마코스의 연설", "テレマコスの演説", "忒勒马科斯发言", in: lang)
        case 3: return L.t("Nestor at Pylos", "필로스의 네스토르", "ピュロスのネストル", "皮洛斯的涅斯托尔", in: lang)
        case 4: return L.t("Menelaus and Helen", "메넬라오스와 헬레네", "メネラオスとヘレネ", "墨涅拉俄斯与海伦", in: lang)
        case 5: return L.t("Calypso and Poseidon's storm", "칼립소와 포세이돈의 폭풍", "カリュプソとポセイドンの嵐", "卡吕普索与波塞冬的风暴", in: lang)
        case 6: return L.t("Nausicaa", "나우시카", "ナウシカア", "瑙西卡", in: lang)
        case 7: return L.t("The Phaeacian court", "파이아케스의 궁정", "パイアケスの宮廷", "费埃克斯人的宫廷", in: lang)
        case 8: return L.t("Songs of Demodocus", "데모도코스의 노래", "デモドコスの歌", "得摩多科斯之歌", in: lang)
        case 9: return L.t("The Lotus-eaters and the Cyclops", "로토스 먹는 사람들과 키클롭스", "ロートパゴスとキュクロプス", "食莲人与独眼巨人", in: lang)
        case 10: return L.t("Aeolus' winds and Circe", "아이올로스의 바람과 키르케", "アイオロスの風とキルケ", "埃俄罗斯的风与喀耳刻", in: lang)
        case 11: return L.t("The land of the dead", "저승", "冥府", "冥府", in: lang)
        case 12: return L.t("The Sirens, Scylla and Charybdis", "세이렌, 스킬라와 카리브디스", "セイレーン、スキュラとカリュブディス", "塞壬、斯库拉与卡律布狄斯", in: lang)
        case 13: return L.t("Home to Ithaca", "이타카로 돌아오다", "イタケへの帰郷", "回到伊萨卡", in: lang)
        case 14: return L.t("The swineherd Eumaeus", "돼지치기 에우마이오스", "豚飼いエウマイオス", "牧猪奴欧迈俄斯", in: lang)
        case 15: return L.t("Telemachus sails home", "텔레마코스의 귀향", "テレマコスの帰航", "忒勒马科斯返航", in: lang)
        case 16: return L.t("Father and son", "아버지와 아들", "父と子", "父与子", in: lang)
        case 17: return L.t("Old Argos", "늙은 개 아르고스", "老犬アルゴス", "老狗阿尔戈斯", in: lang)
        case 18: return L.t("The beggars' fight", "거지들의 싸움", "乞食の殴り合い", "乞丐之斗", in: lang)
        case 19: return L.t("Penelope and the scar", "페넬로페와 흉터", "ペネロペと傷跡", "珀涅罗珀与伤疤", in: lang)
        case 20: return L.t("Omens", "징조", "前兆", "征兆", in: lang)
        case 21: return L.t("The bow", "활", "弓", "弓", in: lang)
        case 22: return L.t("The suitors fall", "구혼자들의 최후", "求婚者たちの最期", "求婚者覆灭", in: lang)
        case 23: return L.t("The olive-tree bed", "올리브나무 침대", "オリーブの木の寝台", "橄榄树婚床", in: lang)
        case 24: return L.t("Peace", "평화", "和解", "和平", in: lang)
        default: return ""
        }
    }

    /// Books that some encounter can unlock today.
    static let findableBooks = Set(allCases.flatMap(\.books))
}

/// Deterministic per-session randomness, so a session's encounters can be reproduced.
struct SplitMix64 {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func chance(_ p: Double) -> Bool { Double(next() % 10_000) / 10_000 < p }
}

/// Which encounters a focus lap gets, and when (as a share of the lap).
enum EpisodePlanner {
    static func plan(seed: UInt64, journey j: Journey, focusSeconds: TimeInterval, lastFiveShare: Double,
                     forced: [Episode]?) -> [(Episode, Double)] {
        let m = j.timeMarks
        let at: [Episode: Double] = [
            .cyclops: m[0] + 0.12 * (m[1] - m[0]),          // early on the floor: eye, boulder, then the ram
            .circe: m[1] + 0.06 * (m[2] - m[1]),            // piglets follow him up the cliff
            .aeolus: m[2] + 0.35 * (m[3] - m[2]),           // a gust along the ceiling
            .whirlpool: max(m[3] - 0.5 / focusSeconds, m[2]), // spun round the top-left corner
            .owl: max(1 - lastFiveShare, 0.75),             // last minutes: Athena guides him home
        ]
        var picks: [Episode]
        if let forced { picks = forced.filter { at[$0] != nil } } else {
            var rng = SplitMix64(state: seed)
            picks = [rng.chance(0.5) ? Episode.cyclops : .circe]
            if rng.chance(0.6) { picks.append(.aeolus) }
            if rng.chance(0.5) { picks.append(.whirlpool) }
            if rng.chance(0.25) { picks.append(picks.contains(.cyclops) ? .circe : .cyclops) }
            picks.append(.owl)
        }
        return picks.compactMap { e in at[e].map { (e, $0) } }.sorted { $0.1 < $1.1 }
    }
}

/// Collected books, stored as small JSON next to the agent state (local only).
final class Logbook {
    private let url: URL
    private(set) var found: [Int: Date] = [:]
    var onNew: ((Int) -> Void)?

    init(url: URL) {
        self.url = url
        if let data = try? Data(contentsOf: url),
           let raw = try? JSONDecoder().decode([String: Double].self, from: data) {
            for (k, v) in raw { if let b = Int(k) { found[b] = Date(timeIntervalSince1970: v) } }
        }
    }

    func record(_ e: Episode) {
        var changed = false
        for b in e.books where found[b] == nil {
            found[b] = Date()
            changed = true
            onNew?(b)
        }
        guard changed else { return }
        let raw = Dictionary(uniqueKeysWithValues: found.map { (String($0.key), $0.value.timeIntervalSince1970) })
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(raw).write(to: url, options: .atomic)
    }
}
