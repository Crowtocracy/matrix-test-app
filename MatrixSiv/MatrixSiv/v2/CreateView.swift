//
//  CreateView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 6/13/25.
//

import SwiftUI

struct CreateView: View {
    @Environment(\.dismiss) private var dismiss
    
    enum Mode: String {
        case directMessage = "Direct Message"
        case room = "Room"
        static var allCases: [Mode] {
            [.directMessage, .room]
        }
    }
    @Binding var newRoom: SivRoom?
    @State var username: String = ""
    @State var initialMessage: String = ""
    @State var mode: Mode = .directMessage
    @State var roomName: String = ""
    @State var roomTopic: String = ""
    @State var members: [String] = []
    @State var memberDraft: String = ""
    @State var errorMessage = ""
    @FocusState var endEditing: Bool
    var body: some View {
        VStack {
            header
            modePicker
            Text(mode.rawValue)
            if mode == .directMessage {
                dmDetails
            } else {
                roomDetails
            }
            Spacer()
        }
        .focusedHiddenTextField($endEditing)
    }
    var modePicker: some View {
        Picker("What type of chat are you trying to make?", selection: $mode) {
            ForEach(Mode.allCases, id: \.self) {
                Text($0.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
    }
    var header: some View {
        HStack {
            Spacer()
            Text("Create Chat")
                .sivTypography(.titleMedium)
            Spacer()
        }
        .frame(height: 50)
        .overlay {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .tint(.accent)
                }
                Spacer()
                
            }
            .padding(20)
        }
    }
    var dmDetails: some View {
        VStack {
            TextField("Username", text: $username)
            TextField("Enter message (Optional)", text: $initialMessage)
            Button("Create direct message") {
                Task {
                    await createDM()
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    var roomDetails: some View {
        VStack {
            TextField("Room name", text: $roomName)
            TextField("Topic (optional)", text: $roomTopic)
            ForEach(Array(zip(members.indices, members)), id: \.0) { index, member in
                HStack {
                    Text(member)
                    Spacer()
                    Button("Remove") {
                        removeMember(index: index)
                    }
                }
                
            }
            HStack {
                TextField("Add member", text: $memberDraft)
                Spacer()
                Button("Add") {
                    addMember()
                }
                .disabled(memberDraft.isEmpty)
                
            }
            
            TextField("Enter message (optional)", text: $initialMessage)
            Button("Create room") {
                Task {
                    await createRoom()
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    var errorView: some View {
        Text(errorMessage)
            .foregroundStyle(.red)
    }
    
    func createDM() async {
        print("Creating DM")
        endEditing = true
        let roomManager = await MatrixManager.shared.createDM(userId: username, initialMessage: initialMessage)
        if let roomManager {
            self.newRoom = roomManager.sivRoom
            self.dismiss()
        } else {
            errorMessage = "Failed to create DM"
        }
    }
    
    func addMember() {
        endEditing = true
        members.append(memberDraft)
        memberDraft = ""
    }
    
    func removeMember(index: Int) {
        endEditing = true
        members.remove(at: index)
    }
    func createRoom() async {
        print("Creating Room")
        endEditing = true
        if !memberDraft.isEmpty {
            addMember()
        }
        let roomManager = await MatrixManager.shared.createRoom(roomName: roomName, topic: roomTopic, userIds: members, initialMessage: initialMessage)
        if let roomManager {
            self.newRoom = roomManager.sivRoom
            self.dismiss()
        } else {
            errorMessage = "Failed to create room"
        }
    }
}


extension View {

    nonisolated public func focusedHiddenTextField(_ condition: FocusState<Bool>.Binding) -> some View {
        self.background(
            TextField("", text: .constant(""))
                .allowsHitTesting(false)
                .opacity(0)
                .focused(condition)
        )
    }

}
