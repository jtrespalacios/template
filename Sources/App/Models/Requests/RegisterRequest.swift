//
// created on 7/21/18
//

import Foundation
import Vapor

struct RegisterRequest: Content {
    let email: String
    let name: String
    let password: String
    let confirmPassword: String
    let csrf: String
}
