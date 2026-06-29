import Foundation

// Claude  Date 06/18/2026
// The device's public identity for the shared-card backend: a random `userID`
// that doubles as the user's *friend code*. This is the only identifier that ever
// leaves the device. It is generated locally on first opt-in to Friends mode (no
// account, no email, no login) and persisted as identity.json.
//
// The matching *secret key* that authorizes writes to this id's card is NOT stored
// here — it lives in the Keychain (see KeychainStore / CardSyncService).
struct DeviceIdentity: Codable, Equatable {
    let userID: String

    init(userID: String = UUID().uuidString) {
        self.userID = userID
    }
}
