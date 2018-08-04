import Vapor

public func routes(_ router: Router) throws {
    let jwtKey = "BlahBlahBlah"
    try router.register(collection: LoginViewController())
    try router.register(collection: MarketingViewController())
    try router.register(collection: RegisterViewController())
    try router.register(collection: try APIController(key: jwtKey))
}
