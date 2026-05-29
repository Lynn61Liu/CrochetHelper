import Foundation

struct CrochetToken: Equatable, Sendable {
    var text: String
}

struct CrochetTokenizer: Sendable {
    func tokenize(_ line: String) -> [CrochetToken] {
        let normalized = normalize(line)
        var tokenTexts: [String] = []

        if let roundLabel = extractRoundLabel(from: normalized) {
            tokenTexts.append(roundLabel)
        }

        tokenTexts.append(contentsOf: extractInstructionTokens(from: normalized))
        return tokenTexts.map { CrochetToken(text: $0) }
    }

    private func normalize(_ line: String) -> String {
        line
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: "重复", with: "x")
            .replacingOccurrences(of: "次", with: "")
    }

    private func extractRoundLabel(from line: String) -> String? {
        guard let match = line.matches(of: try! Regex(#"^\s*(R\d+|第\d+圈)"#)).first else {
            return nil
        }
        return String(line[match.range]).trimmingCharacters(in: .whitespaces)
    }

    private func extractInstructionTokens(from line: String) -> [String] {
        let body = line
            .replacingOccurrences(of: #"^\s*(R\d+|第\d+圈)\s*:?\s*"#, with: "", options: .regularExpression)

        var tokens: [String] = []
        var index = body.startIndex

        while index < body.endIndex {
            let character = body[index]

            if character == "(" {
                let groupStart = index
                guard let close = matchingCloseParenthesis(in: body, from: groupStart) else {
                    body.formIndex(after: &index)
                    continue
                }

                let afterClose = body.index(after: close)
                let trailingRepeat = repeatRange(in: body, startingAt: afterClose)
                if let trailingRepeat {
                    tokens.append(String(body[groupStart..<trailingRepeat.upperBound]).trimmingCharacters(in: .whitespaces))
                    index = trailingRepeat.upperBound
                } else {
                    let inner = String(body[body.index(after: groupStart)..<close]).trimmingCharacters(in: .whitespaces)
                    if inner.range(of: #"^\d+$"#, options: .regularExpression) != nil {
                        tokens.append(inner)
                    }
                    index = afterClose
                }
                continue
            }

            if character.isNumber || character.isLetter {
                let start = index
                repeat {
                    body.formIndex(after: &index)
                } while index < body.endIndex && (body[index].isNumber || body[index].isLetter)

                let text = String(body[start..<index]).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty, text.range(of: #"^\d+$"#, options: .regularExpression) == nil {
                    tokens.append(text)
                }
                continue
            }

            body.formIndex(after: &index)
        }

        return tokens
    }

    private func matchingCloseParenthesis(in text: String, from open: String.Index) -> String.Index? {
        var depth = 0
        var index = open

        while index < text.endIndex {
            if text[index] == "(" {
                depth += 1
            } else if text[index] == ")" {
                depth -= 1
                if depth == 0 {
                    return index
                }
            }
            text.formIndex(after: &index)
        }

        return nil
    }

    private func repeatRange(in text: String, startingAt start: String.Index) -> Range<String.Index>? {
        var index = start
        while index < text.endIndex && text[index].isWhitespace {
            text.formIndex(after: &index)
        }

        guard index < text.endIndex, text[index] == "x" else {
            return nil
        }

        var end = text.index(after: index)
        while end < text.endIndex && text[end].isWhitespace {
            text.formIndex(after: &end)
        }

        let numberStart = end
        while end < text.endIndex && text[end].isNumber {
            text.formIndex(after: &end)
        }

        return numberStart == end ? nil : start..<end
    }
}
