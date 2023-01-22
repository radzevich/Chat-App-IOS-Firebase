import UIKit
import FirebaseAuth

class ConversationsViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        vaidateAuth()
    }

    private func vaidateAuth() {
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let loginController = LoginViewController()
            let navigationController = UINavigationController(rootViewController: loginController)
            navigationController.modalPresentationStyle = .fullScreen

            present(navigationController, animated: true)
        }
    }
}

