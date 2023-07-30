//
//  InfoView .swift
//  Graviton
//
//  Created by Yerassyl Abilkassym on 07.07.2023.
//  Copyright © 2023 Ben Lu. All rights reserved.
//

import SwiftUI

struct BodyInfoViewControllerWrapper: UIViewControllerRepresentable {
    let target: ObserveTarget!
    let ephemerisId: SubscriptionUUID!
    typealias UIViewControllerType = BodyInfoViewController
    
    func makeUIViewController(context: Context) -> BodyInfoViewController {
        // Create and return an instance of your existing UIKit-based ViewController
        
        let bodyInfo = BodyInfoViewController(style: .plain)
                bodyInfo.target = target
                bodyInfo.ephemerisId = ephemerisId
        return bodyInfo
    }
    
    func updateUIViewController(_ uiViewController: BodyInfoViewController, context: Context) {
        // Update the UIKit-based ViewController if needed
    }
}


struct InfoView: View {
    @Environment(\.scenePhase) var scenePhase
    @State private var pageIndex = 0
    
    let persistenceController = PersistenceController.shared
    
    let target: ObserveTarget!
    let ephemerisId: SubscriptionUUID!
    let context: String
    let chatViewModel = ChatViewModel()
    
    
    var body: some View {
        VStack {
            Picker(String(describing: target!), selection: $pageIndex) {
                Text("Chat")
                    .tag(0)
                Text("Star Info")
                    .tag(1)
            }
            .pickerStyle(.segmented)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .foregroundColor(.gray)
            )
            .padding(.horizontal)
            .padding(.top, 5)
            if(pageIndex == 0) {
                ChatView(
                    viewModel: chatViewModel,
                    spaceObject: String(describing: target!).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "saturn",
                    context: context
                )
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                              
            }
            else {
                BodyInfoViewControllerWrapper(target: target, ephemerisId: ephemerisId)
            }
        }
        .onChange(of: scenePhase) { _ in
            persistenceController.save()
        }
    }
}
