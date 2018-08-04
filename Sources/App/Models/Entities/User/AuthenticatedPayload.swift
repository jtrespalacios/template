// AuthenticatedPayload.swift
// Created on 8/2/18

import Foundation
import JWT
import Vapor

struct AuthenticatedPayload: JWTPayload {
    let exp: ExpirationClaim
    let iss: IssuerClaim
    let sub: SubjectClaim

    init(offset: TimeInterval = 3600, sub: UUID, host: String = "") {
        self.exp = ExpirationClaim(value: Date(timeIntervalSinceNow: offset))
        self.iss = IssuerClaim(value: host)
        self.sub = SubjectClaim(value: sub.uuidString)
    }

    func verify() throws {
        try exp.verify()
    }
}
