//
//  ChatHostingController .swift
//  Graviton
//
//  Created by Yerassyl Abilkassym on 05.07.2023.
//  Copyright © 2023 Ben Lu. All rights reserved.
//

import Foundation
import XLPagerTabStrip
import SwiftUI
import UIKit

class ChatHostingController: UIHostingController<ChatView>, IndicatorInfoProvider {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 17 / 255, green: 17 / 255, blue: 17 / 255, alpha: 1)
        
    }
    
    func indicatorInfo(for _: PagerTabStripViewController) -> IndicatorInfo {

        return "Chat"
    }
}
