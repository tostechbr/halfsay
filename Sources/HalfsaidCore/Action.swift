/// What the computer can do.
///
/// Closed actions (`openApp`, `newItem`) pick from a known list, so they may fire mid-sentence.
/// Open actions carry free text: only the pause says the text is done ("search norbert" vs "search norbert wiener").
public enum Action: String, CaseIterable, Sendable {
    case openApp = "open_app"
    case newItem = "new_item"
    case openURL = "open_url"
    case webSearch = "web_search"
    case typeText = "type_text"
    case none
}
