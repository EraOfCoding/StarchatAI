//
//  KeyboardManager.swift
//  Graviton
//
//  Created by Yerassyl Abilkassym on 05.07.2023.
//  Copyright © 2023 Ben Lu. All rights reserved.
//

import UIKit
import Combine

class KeyboardManager: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var isVisible = false
    
    var keyboardCancellable: Cancellable?
    var visibilityCancellable: AnyCancellable?
    
    init() {
        keyboardCancellable = NotificationCenter.default
            .publisher(for: NSNotification.Name.UIKeyboardWillShow)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                guard let userInfo = notification.userInfo else { return }
                guard let keyboardFrame = userInfo[UIKeyboardFrameEndUserInfoKey] as? CGRect else { return }
                
                self.isVisible = keyboardFrame.minY < UIScreen.main.bounds.height
                self.keyboardHeight = self.isVisible ? keyboardFrame.height : 0
            }
        
        visibilityCancellable = $isVisible.sink { [weak self] isVisible in
            if !isVisible {
                DispatchQueue.main.async {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.UIKeyboardWillHide,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            self.keyboardHeight = 0
            self.isVisible = false
        }
    }
}
