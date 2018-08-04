// JWTAuthedMiddleware.swift
// Created on 8/2/18

import Authentication
import Vapor
import JWT

extension JWT: Authenticatable {}

final public class JWTAuthdMiddleware: Middleware {
    let signer: JWTSigner
    let shouldFetchUser: Bool

    init(signer: JWTSigner, fetchUser: Bool = true) {
        self.signer = signer
        self.shouldFetchUser = fetchUser
    }

    public func respond(to request: Request,
                        chainingTo next: Responder) throws -> EventLoopFuture<Response> {
        if try request.isAuthenticated(User.self) {
            return try next.respond(to: request)
        }

        if try request.isAuthenticated(JWT<AuthenticatedPayload>.self) {
            return try next.respond(to: request)
        }

        guard let authHeader = request.http.headers.firstValue(name: .authorization) else {
            throw Abort(.unauthorized,
                        reason: "Unauthroized user token")
        }

        let components = authHeader.split(separator: " ")
        guard components.count == 2, components[0] == "Bearer",
            let keyData = components[1].data(using: .utf8) else {
            throw Abort(.unauthorized,
                        reason: "Unauthroized user token")
        }

        let jwt: JWT<AuthenticatedPayload>;
        do {
            jwt = try JWT<AuthenticatedPayload>(from: keyData,
                                                verifiedUsing: signer)
        } catch {
            guard let jwtError = error as? JWTError else {
                throw Abort(.unauthorized,
                            reason: "Unauthorized user token")
            }

            if jwtError.identifier == "exp" {
                throw Abort(.unauthorized,
                            reason: "Token has expired")
            } else {
                throw Abort(.unauthorized,
                            reason: "Unauthorized user token")
            }
        }

        try request.authenticate(jwt)

        guard shouldFetchUser else {
            return try next.respond(to: request)
        }

        let userId = jwt.payload.sub.value
        guard let uuid = UUID(userId) else {
            throw Abort(.unauthorized,
                        reason: "Unauthorized user token")
        }

        return User.find(uuid, on: request).flatMap(to: Response.self) { user in
            guard let user = user else {
                throw Abort(.unauthorized,
                            reason: "Unauthorized user token")
            }
            try request.authenticate(user)
            return try next.respond(to: request)
        }
    }
}

