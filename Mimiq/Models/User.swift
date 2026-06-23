import Foundation

enum AuthProvider: String, Codable {
    case apple, google, email
}

struct User: Equatable {
    let id: String
    let provider: AuthProvider
    let email: String?
    let fullName: String?
    let accessToken: String?    // Supabase session token; nil for Apple native

    // Backward-compat Apple init
    init(appleUserID: String, fullName: String?) {
        self.id = appleUserID
        self.provider = .apple
        self.email = nil
        self.fullName = fullName
        self.accessToken = nil
    }

    init(id: String, provider: AuthProvider, email: String?, fullName: String? = nil, accessToken: String?) {
        self.id = id
        self.provider = provider
        self.email = email
        self.fullName = fullName
        self.accessToken = accessToken
    }
}
