import Foundation
import FirebaseStorage

final class StorageManager {

    static let shared = StorageManager()

    private let storage = Storage.storage().reference()
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void

    /// Uploads picture to firebase storage and returns completion with url string to download
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("images/\(fileName)").putData(data, metadata: nil) {  [weak self] metadata, error  in
            guard
                error == nil
            else {
                print("failed to upload data to firebase for picture")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("images/\(fileName)").downloadURL { url, error in
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
        }
    }
    
    /// Uploads image that will be sent in a conversation message
    public func uploadMessagePhoto(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("message_images/\(fileName)").putData(data, metadata: nil) { [weak self] metadata, error  in
            guard
                error == nil
            else {
                print("failed to upload data to firebase for picture")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("message_images/\(fileName)").downloadURL { url, error in
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
        }
    }
    
    /// Uploads video that will be sent in a conversation message
    public func uploadMessageVideo(with fileUrl: URL, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("message_videos/\(fileName)").putFile(from: fileUrl) { [weak self] metadata, error  in
            guard
                error == nil
            else {
                print("failed to video file to firebase for video")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("message_videos/\(fileName)").downloadURL { url, error in
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
        }
    }
    
    public enum StorageErrors: Error {
        case failedToUpload
        case failedToDownloadUrl
    }
    
    public func downoadURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let reference = storage.child(path)

        reference.downloadURL(completion: { url, error in
            guard let url = url, error == nil else {
                completion(.failure(StorageErrors.failedToDownloadUrl))
                return
            }

            completion(.success(url))
        })
    }
}
