//
// created on 7/21/18
//

import Foundation
import Vapor
import FluentMySQL
import Crypto
import Foundation
import Authentication
import JWT

struct RegisterUserRequest: Codable {
    let email: String
    let password: String
    let passwordValidation: String

    var passwordValid: Bool {
        return password == passwordValidation
    }
}

struct LoginUserRequest: Codable {
    let email: String
    let password: String
}

struct LoginResponse: Content {
    let token: String
}

internal class APIController: RouteCollection {
    let key: Data
    let signer: JWTSigner

    convenience init(key: String = "") throws {
        guard let data = key.data(using: .utf8) else {
            fatalError("Failed to get data from key \(key) for \(APIController.self)")
        }
        self.init(data: data)
    }

    init(data: Data) {
        self.key = data
        self.signer = JWTSigner.hs512(key: data)
    }

    func boot(router: Router) throws {
        router.post("api", "user") { (request) -> EventLoopFuture<LoginResponse> in
            guard let data = request.http.body.data,
                let registration = try? JSONDecoder().decode(RegisterUserRequest.self, from: data) else {
                    throw Abort(.badRequest, reason: "Unexpected content in body")
            }

            return User.query(on: request)
                .filter(\User.email, MySQLBinaryOperator.equal,
                        registration.email)
                .first()
                .flatMap(to: User.self) { user in
                    guard user == nil else {
                        throw Abort(.badRequest, reason: "User already exists")
                    }

                    guard registration.passwordValid else {
                        throw Abort(.badRequest, reason: "Passwords were not the same")
                    }

                    let hash = try BCrypt.hash(registration.password)
                    let newUser = User(email: registration.email,
                                       password: hash)

                    return newUser.save(on: request)
                }.map(to: LoginResponse.self) { [unowned self] user in
                    return try self.generateLoginResponse(for: user)
            }
        }

        router.post("api", "login") { (request) -> EventLoopFuture<LoginResponse> in
            guard let data = request.http.body.data,
                let login = try? JSONDecoder().decode(APILoginRequest.self, from: data) else {
                    throw Abort(.badRequest, reason: "Unexpected content in body")
            }

            return User.query(on: request)
                .filter(\User.email, MySQLBinaryOperator.equal,
                        login.email)
                .first()
                .map(to: User.self) { user in
                    guard let user = user else {
                        throw Abort(.unauthorized, reason: "User not found")
                    }

                    guard try BCrypt.verify(login.password, created: user.password) else {
                        throw Abort(.unauthorized, reason: "User not found")
                    }
                    return user
                }.map(to: LoginResponse.self) { [unowned self] user in
                    return try self.generateLoginResponse(for: user)
            }
        }

        let jwtmiddle = JWTAuthdMiddleware(signer: self.signer)
        let authd = router.grouped(jwtmiddle)
        authd.group("api" as PathComponentsRepresentable, configure: { r in
            r.get("hello") { (req) -> String in
                return "HELLO!"
            }
        })
    }

    private func generateLoginResponse(for user: User) throws -> LoginResponse {
        var jwt = JWT<AuthenticatedPayload>(payload: AuthenticatedPayload(sub: user.id!))
        let data = try jwt.sign(using: self.signer)
        guard let tokenString = String(data: data, encoding: .utf8) else {
            throw Abort(.internalServerError, reason: "Failed to generate token")
        }

        return LoginResponse(token: tokenString)
    }
}
