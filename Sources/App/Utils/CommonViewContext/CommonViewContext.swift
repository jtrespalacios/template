import Foundation
import Vapor

struct CommonViewContext: Service, Content {
    var userObject: CommonUserObject?
    
    struct CommonUserObject: Content {
        var email: String?
        var id: Int?
    }
}
