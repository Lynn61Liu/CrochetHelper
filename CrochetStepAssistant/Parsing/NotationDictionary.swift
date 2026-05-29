import Foundation

struct NotationEntry: Equatable, Sendable {
    let symbol: String
    let action: StitchAction
    let chineseTerm: String
    let englishTerm: String
}

struct NotationDictionary: Sendable {
    let entries: [NotationEntry] = [
        .init(symbol: "CH", action: .chain, chineseTerm: "锁针", englishTerm: "chain"),
        .init(symbol: "X", action: .singleCrochet, chineseTerm: "短针", englishTerm: "single crochet"),
        .init(symbol: "V", action: .singleCrochetIncrease, chineseTerm: "加针", englishTerm: "increase"),
        .init(symbol: "A", action: .singleCrochetDecrease, chineseTerm: "减针", englishTerm: "decrease"),
        .init(symbol: "W", action: .threeSingleCrochetInOne, chineseTerm: "一针里钩三短针", englishTerm: "3 sc in one stitch"),
        .init(symbol: "M", action: .threeSingleCrochetMerged, chineseTerm: "三针并一针", englishTerm: "3 sc merged"),
        .init(symbol: "T", action: .halfDoubleCrochet, chineseTerm: "中长针", englishTerm: "half double crochet"),
        .init(symbol: "TV", action: .halfDoubleCrochetIncrease, chineseTerm: "中长针加针", englishTerm: "hdc increase"),
        .init(symbol: "TA", action: .halfDoubleCrochetDecrease, chineseTerm: "中长针减针", englishTerm: "hdc decrease"),
        .init(symbol: "SL", action: .slipStitch, chineseTerm: "引拔针", englishTerm: "slip stitch"),
        .init(symbol: "K", action: .chainSpace, chineseTerm: "空针位", englishTerm: "chain space"),
        .init(symbol: "F", action: .doubleCrochet, chineseTerm: "长针", englishTerm: "double crochet"),
        .init(symbol: "FV", action: .doubleCrochetIncrease, chineseTerm: "长针加针", englishTerm: "dc increase"),
        .init(symbol: "FA", action: .doubleCrochetDecrease, chineseTerm: "长针减针", englishTerm: "dc decrease"),
        .init(symbol: "BLO", action: .backLoopOnly, chineseTerm: "后半针", englishTerm: "back loop only"),
        .init(symbol: "FLO", action: .frontLoopOnly, chineseTerm: "前半针", englishTerm: "front loop only")
    ]

    func action(for symbol: String) -> StitchAction {
        entries.first { $0.symbol == symbol }?.action ?? .unknown
    }
}
