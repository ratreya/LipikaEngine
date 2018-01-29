/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

extension Collection {
    subscript(position: Self.Index, default defaultValue: Self.Element) -> Self.Element {
        get {
            return position < self.endIndex ? self[position] : defaultValue
        }
    }
}

class RuleOutput: CustomStringConvertible {
    private var ouputRule: String
    private let kOutputPattern: RegEx

    var description: String {
        return self.ouputRule
    }
    
    init(rule: String) throws {
        self.ouputRule = rule
        self.kOutputPattern = try RegEx(pattern: "\\[\\$([0-9]+)\\]")
    }
    
    func generate(intermediates: [String]) -> String {
        var result = ouputRule
        while (kOutputPattern =~ result) {
            let index = Int(kOutputPattern.captured()!)! - 1
            result = kOutputPattern.replacing(with: intermediates[index, default: ""])!
        }
        return result
    }
}

class RuleInput: Hashable, CustomStringConvertible {
    var type: String
    var key: String?

    var description: String {
        return key == nil ? type : "\(type)/\(key!)"
    }

    init(type: String) {
        self.type = type
    }
    
    init(type: String, key: String) {
        self.type = type
        self.key = key
    }
    
    var hashValue: Int {
        if let key = key {
            return (type.hashValue << 5) &+ type.hashValue &+ key.hashValue /* djb2 */
        }
        return type.hashValue
    }

    static func == (lhs: RuleInput, rhs: RuleInput) -> Bool {
        return lhs.type == rhs.type && lhs.key == rhs.key
    }
}

struct ReverseTrieValue: CustomStringConvertible {
    var scheme: [String]
    var type: String
    var key: String
    var description: String {
        return "\(scheme)/\(type):\(key)"
    }
}

typealias MappingValue = OrderedMap<String, (scheme: [String], script: String?)>
typealias ReverseTrie = Trie<String, ReverseTrieValue>
typealias ForwardTrieValue = [(script: String?, type: String, key: String)]
typealias ForwardTrie = Trie<String, ForwardTrieValue>
typealias RulesTrie = Trie<[RuleInput], RuleOutput>

class Rules {
    private let kSpecificValuePattern: RegEx
    private let kMapStringSubPattern: RegEx
    /// Type->Key->([Scheme], Script)
    private let mappings: [String: MappingValue]

    private (set) var rulesTrie = RulesTrie()
    /// Script->([Scheme], Type, Key)
    private (set) var reverseTrie = ReverseTrie()
    /// Scheme->[(Script, Type, Key)]
    private (set) var forwardTrie = ForwardTrie()

    init(imeRules: [String], mappings: [String: MappingValue]) throws {
        kSpecificValuePattern = try RegEx(pattern: "[\\{\\[]([^\\{\\[]+/[^\\{\\[]+)[\\}\\]]")
        kMapStringSubPattern = try RegEx(pattern: "(\\[[^\\]]+?\\]|\\{[^\\}]+?\\})")

        self.mappings = mappings
        for type in mappings.keys {
            for key in mappings[type]!.keys {
                let script = mappings[type]![key]!.script
                let scheme = mappings[type]![key]!.scheme
                for input in scheme {
                    forwardTrie[input, default: ForwardTrieValue()]?.append((script, type, key))
                }
                if let script = script {
                    reverseTrie[script] = ReverseTrieValue(scheme: scheme, type: type, key: key)
                }
            }
        }

        for imeRule in imeRules {
            if imeRule.isEmpty { continue }
            let components = imeRule.components(separatedBy: "\t")
            guard components.count == 2 else {
                throw EngineError.parseError("IME Rule not two column TSV: \(imeRule)")
            }
            if kMapStringSubPattern =~ components[0] {
                let inputStrings = kMapStringSubPattern.allMatching()!.map() { $0.trimmingCharacters(in: CharacterSet(charactersIn: "{}")) }
                let inputs = inputStrings.flatMap(){ (inputString) -> RuleInput in
                    let parts = inputString.components(separatedBy: "/")
                    return parts.count > 1 ? RuleInput(type: parts[0], key: parts[1]): RuleInput(type: parts[0])
                }
                let output = try expandMappingRefs(components[1])
                rulesTrie[inputs] = try RuleOutput(rule: output)
            }
            else {
                throw EngineError.parseError("Input part: \(components[0]) of IME Rule: \(imeRule) cannot be parsed")
            }
        }
    }
    
    private func expandMappingRefs(_ input: String) throws -> String {
        var result = input
        while (kSpecificValuePattern =~ result) {
            let match = kSpecificValuePattern.matching()!
            let components = kSpecificValuePattern.captured()!.components(separatedBy: "/")
            if let map = mappings[components[0]]?[components[1]] {
                let replacement = match.hasPrefix("{") ? map.scheme[0] : map.script
                result = kSpecificValuePattern.replacing(with: replacement ?? "")!
            }
            else {
                throw EngineError.parseError("Cannot find mapping for \(match)")
            }
        }
        return result
    }
}
