//  s
//  ChatView.swift
//  Graviton
//
//  Created by Yerassyl Abilkassym on 05.07.2023.
//  Copyright © 2023 Ben Lu. All rights reserved.
//

import SwiftUI
import Combine
import CoreData

struct ChatMessage: Identifiable {
    let id = UUID()
    var content: String
    let isUser: Bool
    let isTyping: Bool
    let date = Date()
}

struct ChatRersponse: Decodable {
    let answer: String
    
    private enum CodingKeys: String, CodingKey {
        case answer
    }
}


class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Environment(\.managedObjectContext) var moc

    
    var history: String = ""
    
    func sendMessage(with prompt: String, context: String, spaceObject: String) {
            
        let urlString = "https://nebula-qzob.onrender.com/chat/\(spaceObject)?context=\(context)&history=\(history.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&prompt=\(prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let requestBody = "prompt=\(prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = requestBody.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, urlResponse, error in
            // Handle the response asynchronously
            DispatchQueue.main.async {
                if let error = error {
                    print("Error: \(error)")
                    return
                }
                
                if let response = urlResponse as? HTTPURLResponse {
                    print("Response Status Code: \(response.statusCode)")
                }
                
                if let data = data {
                    do {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Response: \(responseString)")
                    }
                    
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    if let responseDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if let answer = responseDict["answer"] as? String {
                            let chatMessage = ChatMessage(content: answer, isUser: false, isTyping: false)
                            self.messages[self.messages.endIndex - 1] = chatMessage
                            self.history = "\(prompt) \n \(chatMessage.content)"
                        } else {
                            print("Invalid JSON format: Missing 'answer' key")
                        }
                    } else {
                        print("Invalid JSON format: Unable to parse response as dictionary")
                    }
                    } catch {
                        print("Error decoding response: \(error)")
                        let error = "Sorry, could you please rephrase the question. I am confused..."
                        let chatMessage = ChatMessage(content: error, isUser: false, isTyping: false)
                        self.messages[self.messages.endIndex - 1] = chatMessage
                        self.history = "\(prompt) \n \(error) "
                    }
                }
            }
        }.resume()
        
        let userMessage = ChatMessage(content: prompt, isUser: true, isTyping: false)
        let typingMessage = ChatMessage(content: "Typing...", isUser: false, isTyping: true)
        
        // Update UI-related code
        DispatchQueue.main.async {
            self.messages.append(userMessage)
            self.messages.append(typingMessage)
            

        }
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
            
            ZStack(alignment: alignment) {
                placeholder().opacity(shouldShow ? 1 : 0)
                self
            }
        }
}


struct ChatView: View {
    @Environment(\.managedObjectContext) var moc
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var keyboardManager = KeyboardManager()
    let spaceObject: String
    let context: String
    let randomPrompts = ["Hi! Tell me the story of your creation!", "What is your radius", "What would your g value be if your radius was twice as small?", "What does your name mean?", "What are some astronomical events occurring soon?", "How does the universe expansion affect you?", "Top 5 facts about you.", "What is your age?", "How AI could revolutionize the space exploration.", "What are some astronomical news recently?"]
    
    @State private var promptInput = ""
    
    @State private var glowRadius = 10.0
    
    enum FocusedField {
        case promptInput
    }
    
    @FocusState var focusedField: FocusedField?
    
    
    var body: some View {
        VStack {
            MessageScrollView(viewModel: viewModel, keyboardManager: keyboardManager, spaceObject: spaceObject)
            HStack {
                Button(action: {
                    promptInput = randomPrompts.randomElement() ?? "HI"
                }
                ) {
                    Image("generate prompt")
                        .resizable()
                        .frame(width: 17, height: 17)
                        .padding(.trailing, 10)
                }
                .padding(.leading, 10)
                TextField("", text: $promptInput)
                    .padding(.leading, 10)
                    .padding(.top, 5)
                    .padding(.bottom, 5)
                    .padding(.trailing, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color(red: 7 / 255, green: 7 / 255, blue: 7 / 255))
                        
                    )
                    .padding(1)
                    .foregroundColor(.white)
                    .focused($focusedField, equals: .promptInput)
                    .placeholder(when: promptInput.isEmpty) {
                        Text("Message...")
                            .foregroundColor(.white.opacity(0.3))
                            .zIndex(3)
                            .padding(.leading, 10)
                            .onTapGesture {
                                focusedField = .promptInput
                            }
                    }
                Button(action: {
                    if viewModel.messages.count < 1 || viewModel.messages[viewModel.messages.endIndex - 1].content != "Typing..."{
                        if !promptInput.isEmpty {
                            viewModel.sendMessage(with: promptInput, context: context, spaceObject: spaceObject)
                            let chat = Chat(context: moc)
                            chat.content = promptInput
                            chat.isTyping = false
                            chat.id = UUID()
                            chat.isUser = true
                            chat.date = Date()
                            chat.spaceObject = spaceObject
                            
                            try? moc.save()
                            
                            promptInput = ""
                            
                            let typing = Chat(context: moc)
                            typing.content = "Typing..."
                            typing.isTyping = true
                            typing.id = UUID()
                            typing.isUser = false
                            typing.date = Date()
                            typing.spaceObject = spaceObject
                            
                            try? moc.save()
                            
                        }
                    }
                }
                ) {
                    Text("Send")
                }
                .padding(.leading, 10)
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .padding(.bottom, 9)
            .padding(.top, 3)
            .background(Color(red: 28 / 255, green: 28 / 255, blue: 28 / 255))
            .onChange(of: viewModel.messages.count > 0 ? viewModel.messages[viewModel.messages.endIndex - 1].isTyping : true) {typing in
                let lastIndex = viewModel.messages.endIndex - 1
                if !viewModel.messages[lastIndex].isTyping {
                    print("IT WORKS!!!")
                    changeLastElementOfCoreData(answer: viewModel.messages[lastIndex].content)
                }
            }
        }
        
        .preferredColorScheme(.dark)
        
    }
    
    private func changeLastElementOfCoreData(answer: String) {
        let fetchRequest: NSFetchRequest<Chat> = Chat.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Chat.date, ascending: true)] // Change "timestamp" to your sorting key

        do {
            // Fetch the entities from Core Data
            let entities = try moc.fetch(fetchRequest)

            // Check if there are any elements in the array
            guard entities.count > 0 else {
                print("No elements found in Core Data.")
                return
            }

            // Get the last element
            let lastEntity = entities.last!

            // Perform the desired change on the last element
            // For example, if "YourAttribute" is an attribute of the entity, and you want to change it:
            lastEntity.content = answer
            lastEntity.isTyping = false
            lastEntity.isUser = false

            // Save the context to persist the changes
            try moc.save()
            print("Last element in Core Data has been updated.")
        } catch let error as NSError {
            print("Error fetching or updating Core Data: \(error), \(error.userInfo)")
        }
    }
}

func RemoveLinkMarks(content: String) -> String {
    let parsed = content.replacingOccurrences(of: "![", with: "[")
    
    return parsed
}

struct MessageScrollView: View {
    @FetchRequest(sortDescriptors: [
        SortDescriptor(\.date)
    ]) var chat: FetchedResults<Chat>
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var keyboardManager = KeyboardManager()
    let spaceObject: String
    
    var body: some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(chat) { message in
                        if message.spaceObject == spaceObject {
                            if message.isTyping {
                                LoadingBubbleView(viewModel: viewModel)
                                
                            } else {
                                Text(LocalizedStringKey(RemoveLinkMarks(content: message.content ?? "")))
                                    .padding(10)
                                    .background(message.isUser ? Color.blue : Color(red: 70 / 255, green: 70 / 255, blue: 70 / 255))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .padding(5)
                                    .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
                                    .font(.system(size: 17))
                                    .id(message.id)
                            }
                        }
                        
                    }
                }
                .onChange(of: viewModel.messages.count > 0 ? viewModel.messages[viewModel.messages.endIndex - 1].content.count : 1) { _ in
                    withAnimation {
                        scrollViewProxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                        
                    }
                
                }
                .onChange(of: keyboardManager.isVisible) { _ in
                    withAnimation {
                        scrollViewProxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                    }
                }
                
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation {
                    scrollViewProxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                }
            }
            .onTapGesture(count: 1) {
                keyboardManager.isVisible = false
            }
        }
    }
}


struct LoadingBubbleView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    @State private var dotScale: CGFloat = 0.1
    @State private var dotOpacity: Double = 0.0
    
    private let dotSize: CGFloat = 5.0
    private let dotSpacing: CGFloat = 1.0
    private let animationDuration: TimeInterval = 0.8
    
    var body: some View {
        HStack(spacing: dotSpacing) {
            ForEach(0..<3) { index in
                Circle()
                    .foregroundColor(.gray)
                    .frame(width: dotSize, height: dotSize)
                    .opacity(dotOpacity)
                    .scaleEffect(dotScale)
                    .animation(
                        Animation.easeInOut(duration: animationDuration)
                            .repeatForever(autoreverses: true)
                            .delay(animationDuration / 3.0 * Double(index))
                    )
            }
        }
        .onAppear {
            startAnimating()
        }
        .onDisappear {
            stopAnimating()
        }
        .padding(10)
        .background(Color(red: 70 / 255, green: 70 / 255, blue: 70 / 255))
        .cornerRadius(10)
        .padding(5)
        .frame(alignment: .leading)
    }
    
    private func startAnimating() {
        dotOpacity = 1.0
        dotScale = 1.0
    }
    
    private func stopAnimating() {
        dotOpacity = 0.0
        dotScale = 0.1
    }
}
