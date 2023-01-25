import Foundation
import FirebaseStorage

final class StorageManager {

    static let shared = StorageManager()

    private let storage = Storage.storage().reference()
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void

    /// Uploads picture to firebase storage and returns completion with url string to download
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: { metadata, error  in
            guard
                error == nil
            else {
                print("failed to upload data to firebase for picture")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self.storage.child("images/\(fileName)").downloadURL { url, error in
                guard
                    let url = url
                else {
                    print("")
                    completion(.failure(StorageErrors.failedToDownloadUrl))
                    return
                }

                let urlString = url.absoluteString
                print("dowinload url returned: \(urlString)")
                completion(.success(urlString))
            }
        })
    }
    
    public enum StorageErrors: Error {
        case failedToUpload
        case failedToDownloadUrl
    }
}
