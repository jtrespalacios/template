import Vapor
import HTTP

final public class AuthedMiddleware: Middleware {
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        do {
            let _ = try request.user()
            return try next.respond(to: request)
        } catch {
            try request.destroySession()
            
            if request.http.headers.firstValue(name: .contentType) == "application/json" {
                throw Abort(.unauthorized, reason: "Unauthorized user token")
            } else {
                return request.future(request.redirect(to: "/login"))
            }
        }
    }
}
