import Carbon
import Foundation

struct ShortcutConfiguration: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let `default` = ShortcutConfiguration(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    var isValid: Bool {
        keyCode != UInt32(kVK_Escape) && hasSupportedModifier
    }

    var displayLabel: String {
        "\(modifierDisplay)\(keyDisplay)"
    }

    private var hasSupportedModifier: Bool {
        let requiredModifiers = UInt32(cmdKey | optionKey | controlKey | shiftKey)
        return modifiers & requiredModifiers != 0
    }

    private var modifierDisplay: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("Control") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("Option") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("Shift") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("Command") }
        return parts.isEmpty ? "" : parts.joined(separator: " + ") + " + "
    }

    private var keyDisplay: String {
        switch Int(keyCode) {
        case kVK_ANSI_A...kVK_ANSI_Z:
            return keyNameMap[Int(keyCode)] ?? "Key \(keyCode)"
        case kVK_Space:
            return "Space"
        case kVK_Return:
            return "Return"
        default:
            return keyNameMap[Int(keyCode)] ?? "Key \(keyCode)"
        }
    }
}

private let keyNameMap: [Int: String] = [
    kVK_ANSI_A: "A",
    kVK_ANSI_B: "B",
    kVK_ANSI_C: "C",
    kVK_ANSI_D: "D",
    kVK_ANSI_E: "E",
    kVK_ANSI_F: "F",
    kVK_ANSI_G: "G",
    kVK_ANSI_H: "H",
    kVK_ANSI_I: "I",
    kVK_ANSI_J: "J",
    kVK_ANSI_K: "K",
    kVK_ANSI_L: "L",
    kVK_ANSI_M: "M",
    kVK_ANSI_N: "N",
    kVK_ANSI_O: "O",
    kVK_ANSI_P: "P",
    kVK_ANSI_Q: "Q",
    kVK_ANSI_R: "R",
    kVK_ANSI_S: "S",
    kVK_ANSI_T: "T",
    kVK_ANSI_U: "U",
    kVK_ANSI_V: "V",
    kVK_ANSI_W: "W",
    kVK_ANSI_X: "X",
    kVK_ANSI_Y: "Y",
    kVK_ANSI_Z: "Z",
    kVK_ANSI_0: "0",
    kVK_ANSI_1: "1",
    kVK_ANSI_2: "2",
    kVK_ANSI_3: "3",
    kVK_ANSI_4: "4",
    kVK_ANSI_5: "5",
    kVK_ANSI_6: "6",
    kVK_ANSI_7: "7",
    kVK_ANSI_8: "8",
    kVK_ANSI_9: "9"
]
