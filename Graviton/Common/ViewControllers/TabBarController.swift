//
//  TabBarController.swift
//  Graviton
//
//  Created by Sihao Lu on 7/30/17.
//  Copyright © 2017 Ben Lu. All rights reserved.
//

import UIKit

class TabBarController: UITabBarController, UITabBarControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if UserDefaults.standard.bool(forKey: "isFirstTime") == false {
            UserDefaults.standard.set(false, forKey: "isFirstTime")
            print("HEY")
            delegate = self
            Style.setTabBarTransparent(tabBar: tabBar)
            if let navigationController = selectedViewController as? UINavigationController {
                applyTabBarStyle(toViewController: navigationController.topViewController)
            }
        } else {
            print("Standart")

            let infoView = HistoryView()
                    
            let infoController = HistoryViewController(rootView: infoView)

            infoController.navigationItem.title = String(describing: "Welcome!")

            let navigationController = UINavigationController(rootViewController: infoController)
            navigationController.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
            navigationController.modalPresentationStyle = .fullScreen

            tabBarController?.present(navigationController, animated: true, completion: nil)

        }
    }

    // MARK: - Tab bar controller delegate

    func tabBarController(_: UITabBarController, didSelect viewController: UIViewController) {
        guard let navigationController = viewController as? UINavigationController else {
            return
        }
        applyTabBarStyle(toViewController: navigationController.topViewController)
    }

    private func applyTabBarStyle(toViewController viewController: UIViewController?) {
        if viewController is SceneController {
            Style.setTabBarTransparent(tabBar: tabBar)
        } else {
            Style.setTabBarNormal(tabBar: tabBar)
            if viewController is InformationViewController {
                tabBar.barStyle = .black
            }
        }
    }
}
