//
//  HistoryViewController.swift
//  Graviton
//
//  Created by Yerassyl Abilkassym on 30.07.2023.
//  Copyright © 2023 Ben Lu. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

class HistoryViewController: UIHostingController<HistoryView> {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 17 / 255, green: 17 / 255, blue: 17 / 255, alpha: 1)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

}
