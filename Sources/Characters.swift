import Foundation

/// The characters the Settings window and the menu offer, saved as `character`. Others in
/// assets/ (the pixel variant, the sketches) still load for `--char`.
enum Characters {
    static let standard = "odysseus-vector"
    static let choices = [standard, "dev-voyager"]

    static func title(_ id: String, lang: Lang? = nil) -> String {
        id == "dev-voyager" ? L.t("Developer voyager", "개발자 항해자", "航海する開発者", "航海的开发者", in: lang)
                            : L.t("Odysseus", "오디세우스", "オデュッセウス", "奥德修斯", in: lang)
    }
}
