import UIKit
import MessageKit
import InputBarAccessoryView

struct Message: MessageType {
    public var sender: SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind
}

extension MessageKind {
    var messageKindString: String {
        switch self {
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributedText"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "linkPreview"
        case .custom(_):
            return "custom"
        }
    }
}

struct Sender: SenderType {
    public var photoURL: String
    public var senderId: String
    public var displayName: String
}

class ChatViewController: MessagesViewController {

    public static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        return formatter
    }()

    public let otherUserEmail: String
    private let conversationId: String?
    public var isNewConversation = false;
    
    private var messages = [Message]()

    private var selfSender: Sender? = {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)

        return Sender(photoURL: "",
                      senderId: safeEmail,
                      displayName: "Me")
    }()

    init(with email: String, id: String?) {
        self.conversationId = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)

        if let conversationId = conversationId {
            listenForMessages(id: conversationId, shouldScrollToBottom: true)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .red

        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
    }
    
    private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
        print("start listening for messages: \(id)")
        DatabaseManager.shared.getAlMessagesForConnversation(with: id) { [weak self] result in
            switch result {
            case .success(let messages):
                print("received messages: \(messages)")
                guard !messages.isEmpty else {
                    return
                }

                self?.messages = messages
                
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()

                    if shouldScrollToBottom {
                        self?.messagesCollectionView.scrollToLastItem()
                    }
                    
                }
            case .failure(let error):
                print("failed to get messages: \(error)")
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
    }

}

extension ChatViewController: InputBarAccessoryViewDelegate {

    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard
            !text.replacingOccurrences(of: " ", with: "").isEmpty,
            let selfSender = self.selfSender,
            let messageId = createMessageId()
        else {
            return
        }
        
        print("Sending: \(text)")
        
        // Send Message
        if isNewConversation {
            // create convo in database
            let message = Message(sender: selfSender,
                                  messageId: messageId,
                                  sentDate: Date(),
                                  kind: .text(text))

            DatabaseManager.shared.createNewConversation(with: otherUserEmail,
                                                         otherUserName: self.title ?? "User",
                                                         firstMessage: message) { success in
                if success {
                    print("message sent")
                }
                else {
                    print("failed to send")
                }
            }
        }
        else {
            // append to an existing conversation
        }
    }
    
    private func createMessageId() -> String? {
        // date, otherUserEmail, senderEmail, randomInt
        guard
            let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String
        else {
            return nil
        }
        
        let dateString = Self.dateFormatter.string(from: Date())
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        let newIdentifier = "\(safeEmail)_\(dateString)"
        print("created message_id: \(newIdentifier)")

        return newIdentifier
    }

}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {

    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        }

        fatalError("Self Sender is nil, email should be cached")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }

}
