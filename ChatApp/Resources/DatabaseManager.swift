import Foundation
import FirebaseDatabase
import RealmSwift

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    
    private let database = Database.database(url: "https://chatapp-97bcf-default-rtdb.europe-west1.firebasedatabase.app").reference()
    
    static func safeEmail(emailAddress: String) -> String {
        return emailAddress
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "@", with: "-")
    }
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
            guard error == nil else {
                print("failed to write to ddatabase")
                completion(false)
                return
            }
            
            self.database.child("users").observeSingleEvent(of: .value) { snapshot in
                if var usersCollection = snapshot.value as? [[String: String]] {
                    // append to user dictionary
                    let newElement = [
                        "name": user.firstName + " " + user.lastName,
                        "email": user.safeEmail
                    ]

                    usersCollection.append(newElement)
                    
                    self.database.child("users").setValue(usersCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }

                        completion(true)
                    }
                    
                } else {
                    // create that array
                    let newCollection: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]

                    self.database.child("users").setValue(newCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }

                        completion(true)
                    }
                }
            }

            completion(true)
        }
    }
    
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            completion(.success(value))
        }
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
    }
}

// MARK: - Sending messages/conversations

extension DatabaseManager {
    
    /*
     "root": {
        "messages": [
            {
                "id": String,
                "type": text, photo, video,
                "content": String,
                "date": Date,
                "sender_email": Date,
                "is_read": Bool,
            }
        ]
     }
     
     conversation => [
        [
            "conversation_id": String,
            "other_user_email": String,
            "latest_message": => {
                "date": Date,
                "message": String,
                "is_read": Bool,
            },
        ],
     ]
     */
    
    /// Create a new conversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, otherUserName: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard
            let currentEmail = UserDefaults.standard.value(forKey: "email") as? String
        else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child(safeEmail)

        ref.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("user not found")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""

            switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationID = "conversation_\(firstMessage.messageId)"

            let newConversationData: [String: Any] = [
                "id": conversationID,
                "other_user_email": otherUserEmail,
                "other_user_name": otherUserName,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false,
                ]
            ]

            let recepient_newConversationData: [String: Any] = [
                "id": conversationID,
                "other_user_email": safeEmail,
                "other_user_name": "Self",
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false,
                ]
            ]
            
            // Update recepient user conversation entry
            
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    // append
                    conversations.append(recepient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                }
                else {
                    // creation
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recepient_newConversationData])
                }
            }

            // Update current user conversation entry
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                // conversation array exists for current user
                // you should append new message
                conversations.append(newConversationData)
                userNode["conversations"] = conversations

                ref.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }

                    self?.finishCreatingConversation(name: otherUserName,
                                                     conversationID: conversationID,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                }
            } else {
                // conversation array does not exist
                // create it
                userNode["conversations"] = [
                    newConversationData
                ]

                ref.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }

                    self?.finishCreatingConversation(name: otherUserName,
                                                     conversationID: conversationID,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                }
            }
        }
    }
    
    private func finishCreatingConversation(name: String, conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        
        var message = ""

        switch firstMessage.kind {
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)

        guard
            let myEmail = UserDefaults.standard.value(forKey: "email") as? String
        else {
            completion(false)
            return
        }

        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)

        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name": name
        ]

        let value: [String: Any] = [
            "messages": [
                collectionMessage
            ]
        ]

        database.child("\(conversationID)").setValue(value) { error, _ in
            guard error == nil else {
                completion(false)
                return
            }

            completion(true)
        }
    }
    
    /// Fetched and returns all conversations for the user with passed in email
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        print("try to fetch conversations for: \(email)")
        database.child("\(email)/conversations").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }

            let conversations: [Conversation] = value.compactMap { dictionary in
                guard
                    let conversationId = dictionary["id"] as? String,
                    let otherUserEmail = dictionary["other_user_email"] as? String,
                    let otherUserName = dictionary["other_user_name"] as? String,
                    let latestMessage = dictionary["latest_message"] as? [String: Any],
                    let date = latestMessage["date"] as? String,
                    let message = latestMessage["message"] as? String,
                    let isRead = latestMessage["is_read"] as? Bool
                else {
                    return nil
                }

                let latestMessageObject = LatestMessage(date: date,
                                                        text: message,
                                                        isRead: isRead)

                return Conversation(id: conversationId,
                                    otherUserName: otherUserName,
                                    otherUserEmail: otherUserEmail,
                                    latestMessage: latestMessageObject)
            }

            completion(.success(conversations))
        }
    }
    
    /// Gets all messages for a given coversation
    public func getAlMessagesForConnversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }

            let messages: [Message] = value.compactMap { dictionary in
                guard
                    let name = dictionary["name"] as? String,
                    let isRead = dictionary["is_read"] as? Bool,
                    let messageID = dictionary["id"] as? String,
                    let content = dictionary["content"] as? String,
                    let senderEmail = dictionary["sender_email"] as? String,
                    let type = dictionary["type"] as? String,
                    let dateString = dictionary["date"] as? String,
                    let date = ChatViewController.dateFormatter.date(from: dateString)
                else {
                    return nil
                }

                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageID,
                               sentDate: date,
                               kind: .text(content))
            }

            completion(.success(messages))
        }
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversation: String, message: Message, completion: @escaping (Bool) -> Void) {
        
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
