import CryptoKit
import Foundation

func sha256Hash(_ input: String) -> String {
    let normalizedInput = input
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
    let digest = SHA256.hash(data: Data(normalizedInput.utf8))

    return digest.map { String(format: "%02x", $0) }.joined()
}
