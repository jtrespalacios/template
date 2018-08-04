import Vapor

struct LoginRequest: Content {
    let email: String
    let password: String
    let csrf: String
}

struct APILoginRequest: Content {
    let email: String
    let password: String
}
