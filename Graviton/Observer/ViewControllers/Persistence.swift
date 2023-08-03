//
//  Persistence.swift
//  Graviton
//
//  Created by Yerassyl Abilkassym on 30.07.2023.
//  Copyright © 2023 Ben Lu. All rights reserved.
//

import Foundation
import CoreData

struct PersistenceController {
    // A singleton for our entire app to use
    static let shared = PersistenceController()

    // Storage for Core Data
    let container: NSPersistentContainer

    // A test configuration for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)

        // Create 10 example programming languages.
        for _ in 0..<10 {
            let chat = Chat(context: controller.container.viewContext)
            chat.content = "Hi Satur"
        }

        return controller
    }()

    // An initializer to load Core Data, optionally able
    // to use an in-memory store.
    init(inMemory: Bool = true) {
        // If you didn't name your model Main you'll need
        // to change this name below.
        container = NSPersistentContainer(name: "ChatModel")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Show some error here
            }
        }
    }
    
    func updateLastElement(newContent: String) {
        let context = container.viewContext

        let fetchRequest: NSFetchRequest<Chat> = Chat.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = 1

        do {
            let results = try context.fetch(fetchRequest)
            if let lastChat = results.first {
                lastChat.content = newContent
                lastChat.isTyping = false
                lastChat.isUser = false
            }
            try context.save()
        } catch {
            // Handle error here
            print("Error updating last element: \(error)")
        }
    }

}
