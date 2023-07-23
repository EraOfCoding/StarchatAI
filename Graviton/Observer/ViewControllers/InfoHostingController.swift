//
//  InfoHostingController.swift
//  Graviton
//
//  Created by Yerassyl Abilkassym on 07.07.2023.
//  Copyright © 2023 Ben Lu. All rights reserved.
//

import Foundation
import XLPagerTabStrip
import SwiftUI
import UIKit

class InfoHostingController: UIHostingController<InfoView>, IndicatorInfoProvider {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 17 / 255, green: 17 / 255, blue: 17 / 255, alpha: 1)
    }
    
    func indicatorInfo(for _: PagerTabStripViewController) -> IndicatorInfo {

        return "Info"
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

}
