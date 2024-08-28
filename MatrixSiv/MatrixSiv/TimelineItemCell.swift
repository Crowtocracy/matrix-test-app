//
//  TimelineItemCell.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 8/28/24.
//

import SwiftUI
import MatrixRustSDK

struct TimelineItemCell: View {
    var timelineItem: TimelineItem
    @State var senderName = String()
    @State var messageContent: MessageContent?
    @State var reactions: [Reaction] = []
    @State var toogleToReload = false
    @Binding var timeline: Timeline?
    @State var parentMessage: String?
    let addReaction: (_ eventID: String, _ reaction: String) async throws -> Void
    var body: some View {
        if let event = timelineItem.asEvent() {
            VStack(alignment: .leading) {
                Text(senderName)
                    .bold()
                    .foregroundStyle(timelineItem.asEvent()?.sender() == "@trysiv-test1:matrix.org" ? .blue : .pink)
                if let parentMessage {
                    Text(parentMessage)
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 20)
                        .overlay(
                            Rectangle()
                                .fill(.gray)
                                .frame(width: 2),
                            alignment: .leading
                        )
                }
                
                Text(event.content().asMessage()?.body() ?? "no message body \(event.content().kind())")
                if let messageContent {
                    Text("This message has additional data").font(.footnote)
//                        Text("\(messageContent)")
                }
                reactionsView
                
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 5)
            .task {
                switch event.senderProfile() {
                case .ready(let displayName, let displayNameAmbiguous, let avatarUrl):
                    senderName = event.sender() == "@trysiv-test1:matrix.org" ? "Me" : displayName ?? ""
                case .error(let message):
                    print("ERROR: unable to load sender profile: \(message)")
                default:
                    senderName = "Unknown"
                }
                senderName = event.sender()
                switch event.content().asMessage()?.msgtype() {
                case .text(let content):
                    if let html = content.formatted?.body {
                        do {
                            messageContent = try MessageContent.messageFromString(html)
                        } catch {
                            messageContent = nil
                            // print("ERROR: Cannot parse html to MessageContent \(error)")
                        }
                    }
                default:
                    print("message type not supported")
                }
                if let parentId = event.content().asMessage()?.inReplyTo()?.eventId {
                    do {
                        let details = try await timeline?.loadReplyDetails(eventIdStr: parentId)
                        let parent = try await timeline?.getEventTimelineItemByEventId(eventId: details?.eventId ?? parentId)
                        parentMessage = parent?.content().asMessage()?.body()
                    } catch {
                        print("ERROR: Cannot get parent \(error)")
                    }
                    
                }
                reactions = timelineItem.asEvent()?.reactions() ?? []
                
            }
            
        } else if let virtual = timelineItem.asVirtual() {
            switch virtual {
            case .dayDivider(let ts):
                Text(Date(timeIntervalSince1970: TimeInterval(ts / 1000)).description)
                    .font(.footnote)
                    .foregroundStyle(.gray)
            case .readMarker:
                Text("read")
            }
        }
    }
    
    @ViewBuilder
    var reactionsView: some View {
        HStack {
            ForEach(timelineItem.asEvent()?.reactions() ?? [], id: \.key) { reaction in
                HStack {
                    Text("\(reaction.key) \(reaction.count)")
                        .onTapGesture {
                            toggleReaction(key: reaction.key)
                        }
                }
                .padding(4)
                .background(
                    Capsule().fill(.white).stroke(.gray, lineWidth: 1)
                )
                
            }
            Button {
                toggleReaction()
            } label: {
                Image(systemName: "face.smiling")
                    .resizable()
                    .scaledToFit()
                    .size(20)
                    .overlay {
                        Image(systemName: "plus")
                            .resizable()
                            .scaledToFit()
                            .size(8)
                            .offset(x: 8, y: -10)
                        
                    }
            }
            Spacer()
        }
    }
    func toggleReaction(key: String = "🌱") {
        print("send a reaction")
        guard let eventID = timelineItem.asEvent()?.eventId() else {
            print("no eventID")
            return
        }
        Task {
            do {
                try await addReaction(eventID, key)
                print("reaction sent")
                reactions = timelineItem.asEvent()?.reactions() ?? []
                toogleToReload.toggle()
            } catch {
                print("Error: cannot send reaction \(error)")
            }
            
        }
    }
}

#Preview {
    func placeholder(a: String, b: String ) async throws {}
    return TimelineItemCell(timelineItem: TimelineItem(noPointer: .init()), timeline: .constant(Timeline(noPointer: .init())), addReaction: placeholder)
}
