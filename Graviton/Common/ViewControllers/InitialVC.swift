//
//  InitialVC.swift
//  Graviton
//
//  Created by Yerassyl Abilkassym on 31.07.2023.
//  Copyright © 2023 Ben Lu. All rights reserved.
//

import UIKit

class InitialVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        if UserDefaults.standard.bool(forKey: "isFirstTime") == false {
            let vc = self.storyboard?.instantiateViewController(withIdentifier: "TabBarVC")
            if let vc = vc {
                self.navigationController?.pushViewController(vc, animated: true)
            }
            
        } else {
            UserDefaults.standard.set(false, forKey: "isFirstTime")
            let vc = self.storyboard?.instantiateViewController(withIdentifier: "OnboardingVC")
            if let vc = vc {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
