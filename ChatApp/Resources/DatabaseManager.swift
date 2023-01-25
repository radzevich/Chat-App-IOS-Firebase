import Foundation
import FirebaseDatabase

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    
    private let database = Database.database(url: "https://chatapp-97bcf-default-rtdb.europe-west1.firebasedatabase.app").reference()
    
    
}

// MARK: Accounbt Mgmt

extension DatabaseManager {
    
    public func userExists(with email: String,
                           completion: @escaping ((Bool) -> Void)) {
        
        let safeEmail = email
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "@", with: "-")

        database.child(safeEmail).observeSingleEvent(of: .value,
                                                 with: { snapshot in

            guard snapshot.value as? String != nil else {
                completion(false)
                return
            }

            completion(true)
        })
    }

    /// Inserts new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ]) { error, _ in
            guard
                error == nil
            else {
                print("failed to write to ddatabase")
                completion(false)
                return
            }

            completion(true)
        }
    }
}

struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String

    var safeEmail: String {
        return emailAddress
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "@", with: "-")
    }

    var profilePictureFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }
}
