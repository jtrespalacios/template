//
// created on 7/21/18
//

import Foundation

struct Constants {
    static let databaseURL = "DATABASE_URL"
    static let redisURL = "REDIS_URL"
    static let restMiddlewareEnvKey = "REST_API_KEY"

    enum MySQL {
        static let username = "MYSQL_USER"
        static let password = "MYSQL_PASSWORD"
        static let host = "MYSQL_HOST"
        static let port = "MYSQL_PORT"
        static let database = "MYSQL_DATABASE"
    }
    enum Redis {
        static let password = "REDIS_PASSWORD"
        static let host = "REDIS_HOST"
        static let port = "REDIS_PORT"
    }

    struct SessionKeys {
        static let userId = "userId"
        static let userEmail = "userEmail"
    }
}
