import Foundation

struct User: Equatable {
    let appleUserID: String
    /// nil on all sign-ins after the first — Apple only sends fullName once.
    let fullName: String?
}
