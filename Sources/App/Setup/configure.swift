import FluentMySQL
import Vapor
import Leaf
import Redis
import VaporSecurityHeaders
import URLEncodedForm
import Authentication
import SwiftyBeaver
import SwiftyBeaverVapor

public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    // MARK: -  Register providers first
    try services.register(FluentMySQLProvider())

    // MARK: - Logger Setup
    let loggingDestination = ConsoleDestination()
    try services.register(SwiftyBeaverProvider(destinations: [loggingDestination]))
    config.prefer(SwiftyBeaverVapor.self, for: Logger.self)

    // MARK: - MySQL Configuration
    let dbName = Environment.get(Constants.MySQL.database) ?? "vapor"
    let dbUsername = Environment.get(Constants.MySQL.username) ?? "vapor"
    let dbPassword = Environment.get(Constants.MySQL.password) ?? "password"
    let dbHost = Environment.get(Constants.MySQL.host) ?? "127.0.0.1"
    let rawPort = Environment.get(Constants.MySQL.port) ?? "3306"

    guard let dbPort = Int(rawPort) else {
        throw Abort(.internalServerError)
    }

    let mysqlConfig = MySQLDatabaseConfig(hostname: dbHost,
                                          port: dbPort,
                                          username: dbUsername,
                                          password: dbPassword,
                                          database: dbName)

    // MARK: - Setup Auth
    try services.register(AuthenticationProvider())

    // MARK: - Setup Redis
    let redisPassword = Environment.get(Constants.Redis.password) ?? "password"
    let redistHost = Environment.get(Constants.Redis.host) ?? "127.0.0.1"
    let rawRedisPort = Environment.get(Constants.Redis.port) ?? "6379"

    guard let redisPort = Int(rawRedisPort) else {
        throw Abort(.internalServerError)
    }

    var redisUrl = URLComponents()
    redisUrl.host = redistHost
    redisUrl.password = redisPassword
    redisUrl.port = redisPort
    redisUrl.scheme = "redis"

    guard let url = redisUrl.url else {
        throw Abort(.internalServerError)
    }

    // MARK: - Register Redis
    try services.register(RedisProvider())
    let redisConfig = try RedisDatabase(config: RedisClientConfig(url: url))


    // MARK: -  Setup Auth
    try services.register(AuthenticationProvider())

    // MARK: -  Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    // MARK: -  Register the databases
    services.register { container -> DatabasesConfig in
        var databaseConfig = DatabasesConfig()
        databaseConfig.add(database: MySQLDatabase(config: mysqlConfig), as: .mysql)
        databaseConfig.add(database: redisConfig, as: .redis)
        return databaseConfig
    }

    // MARK: -  Register and Prefer Leaf
    try services.register(LeafProvider())
    services.register(ViewRenderer.self) { container in
        return LeafRenderer(config: try container.make(), using: container)
    }

    config.prefer(LeafRenderer.self, for: ViewRenderer.self)

    // MARK: -  Register Sessions
    let secure = env == .production
    let sessionsConfig = SessionsConfig(cookieName: "vapor-session") { value in
        return HTTPCookieValue(string: value,
                               expires: Date(timeIntervalSinceNow: 60 * 60 * 24 * 7),
                               maxAge: nil,
                               domain: nil,
                               path: "/",
                               isSecure: secure,
                               isHTTPOnly: true,
                               sameSite: .strict)
    }

    services.register(sessionsConfig)

    services.register(Sessions.self) { container -> KeyedCacheSessions in
        let keyedCache = try container.keyedCache(for: .redis)
        return KeyedCacheSessions(keyedCache: keyedCache)
    }

    services.register(CSRF.self) { _ -> CSRFVerifier in
        return CSRFVerifier()
    }

    config.prefer(CSRFVerifier.self, for: CSRF.self)

    // MARK: -  Setup Security Headers
    let cspConfig = ContentSecurityPolicyConfiguration(value: CSPConfig.setupCSP().generateString())
    let xssProtectionConfig = XSSProtectionConfiguration(option: .block)
    let contentTypeConfig = ContentTypeOptionsConfiguration(option: .nosniff)
    let frameOptionsConfig = FrameOptionsConfiguration(option: .deny)
    let referrerConfig = ReferrerPolicyConfiguration(.strictOrigin)

    let securityHeadersMiddleware = SecurityHeadersFactory()
        .with(contentSecurityPolicy: cspConfig)
        .with(XSSProtection: xssProtectionConfig)
        .with(contentTypeOptions: contentTypeConfig)
        .with(frameOptions: frameOptionsConfig)
        .with(referrerPolicy: referrerConfig)
        .build()

    // MARK: -  Per-Request Security Headers
    services.register { _ in
        return CSPRequestConfiguration()
    }

    // MARK: -  Register middleware
    services.register(ErrorMiddleware())

    var middlewares = MiddlewareConfig()
    middlewares.use(securityHeadersMiddleware)
    middlewares.use(FileMiddleware.self)
    middlewares.use(ErrorMiddleware.self)
    middlewares.use(SessionsMiddleware.self)
    services.register(middlewares)

    // MARK: -  Call the migrations
    services.register { container -> MigrationConfig in
        var migrationConfig = MigrationConfig()
        try migrate(migrations: &migrationConfig)
        return migrationConfig
    }

    // MARK: -  Register CommonViewContext
    let cvc = CommonViewContext()
    services.register(cvc)

    // MARK: -  Register Content Config
    services.register { container -> ContentConfig in
        var contentConfig = ContentConfig.default()
        let formDecoder = URLEncodedFormDecoder(omitEmptyValues: true, omitFlags: false)
        contentConfig.use(decoder: formDecoder, for: .urlEncodedForm)
        return contentConfig
    }

    // MARK: -  Command Config
    var commandConfig = CommandConfig.default()
    commandConfig.useFluentCommands()
    services.register(commandConfig)

    // MARK: -  Register KeyStorage
    //    guard let apiKey = Environment.get(Constants.restMiddlewareEnvKey) else { throw Abort(.internalServerError) }
    //    services.register { container -> KeyStorage in
    //        return KeyStorage(restMiddlewareApiKey: apiKey)
    //    }

    // MARK: -  Leaf Tag Config
    let defaultTags = LeafTagConfig.default()
    services.register(defaultTags)

    // MARK: - Repository Setup
    setupRepositories(services: &services, config: &config)
}
