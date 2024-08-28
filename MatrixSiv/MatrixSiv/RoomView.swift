//
//  RoomView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 8/20/24.
//

import SwiftUI
import MatrixRustSDK

struct RoomView: View {
    @Binding var roomSummary: RoomSummary
    @State var message = String()
    @State var timelineItems = [TimelineItem]()
    @State var timelineListenerProxy: TimelineListenerProxy?
    @State var timelineListenerTaskHandle: TaskHandle?
    @State var timeline: Timeline?
    @State var parentMessage: TimelineItem?
    var body: some View {
        VStack {
            header
            messages
            footer
        }
        .task {
            print("Room task")
            timelineListenerProxy = TimelineListenerProxy({ diff in
                self.updateItemsWithDiffs(diff)
            })
            
            
            if !roomSummary.roomListItem.isTimelineInitialized() {
                await initializeTimeline()
            }
            
            if roomSummary.isInvite {
                await joinRoom()
            }
            print(roomSummary.roomListItem.isTimelineInitialized())
            do {
                timeline = try await roomSummary.roomListItem.fullRoom().timeline()
                
            } catch {
                print("ERROR: cannot find timeline \(error)")
            }
            timelineListenerTaskHandle = try? await roomSummary.roomListItem.fullRoom().timeline().addListener(listener: timelineListenerProxy!)
            
        }
    }
    func initializeTimeline() async {
        do {
            
            let stateEventFilters: [StateEventType] = [.roomAliases,
                                                       .roomCanonicalAlias,
                                                       .roomGuestAccess,
                                                       .roomHistoryVisibility,
                                                       .roomJoinRules,
                                                       .roomPinnedEvents,
                                                       .roomPowerLevels,
                                                       .roomServerAcl,
                                                       .roomTombstone,
                                                       .spaceChild,
                                                       .spaceParent,
                                                       .policyRuleRoom,
                                                       .policyRuleServer,
                                                       .policyRuleUser,
                                                       .roomCreate,
                                                       .roomMemberEvent,
                                                       .roomName
            ]
            try await roomSummary.roomListItem.initTimeline(eventTypeFilter: TimelineEventTypeFilter.exclude(eventTypes: stateEventFilters.map({ FilterTimelineEventType.state(eventType: $0) })), internalIdPrefix: nil)
        } catch {
            print("ERROR: timeline failed to init \(error)")
        }
    }
    func joinRoom() async {
        do {
            try await roomSummary.roomListItem.fullRoom().join()
        } catch {
            print("ERROR: unable to join room \(error)")
        }
    }
    func loadOlderMessages() async {
        print("loading older messages")
        do {
            let _ = try await timeline?.paginateBackwards(numEvents: 10)
//            print(try await timeline?.paginateBackwards(numEvents: 10))
        } catch {
            print("ERROR: cannot load older messages \(error)")
        }
    }
    @ViewBuilder var header: some View {
        HStack {
            Avatar(avatarURL: roomSummary.avatarURL)
            Text(roomSummary.name)
            Circle()
                .fill(roomSummary.hasUnreadMessages ? .green : .clear)
                .size(15)
        }
    }
    
    @ViewBuilder var messages: some View {
        ScrollView {
            LazyVStack {
                Button {
                    Task {
                        await loadOlderMessages()
                    }
                } label: {
                    Text("Load older messages")
                }
                .padding(10)
                .background(.gray)
                .clipShape(Capsule())
                .rotationEffect(Angle(degrees: 180)).scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                ForEach(timelineItems.reversed()) { item in
                    TimelineItemCell(timelineItem: item, timeline: $timeline, addReaction: toggleReaction)
                        .rotationEffect(Angle(degrees: 180)).scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                        .onLongPressGesture(perform: {
                            setReplyMessage(message: item)
                        })
                        .task {
                            if roomSummary.hasUnreadMessages {
//                                try? await Task.sleep(for: .seconds(10))
                                if let eventId = item.asEvent()?.eventId() {
                                    await markAsRead(eventID: eventId)
                                }
                                
                               
                            }
                        }
                }
                Spacer()
                
            }
        }
        .rotationEffect(Angle(degrees: 180)).scaleEffect(x: -1.0, y: 1.0, anchor: .center)
    }
    
    func setReplyMessage(message: TimelineItem) {
        guard let _ = message.asEvent()?.content().asMessage()?.body() else {
            print("Invalid parent message")
            return
        }
        parentMessage = message
    }
    
    func toggleReaction(eventID: String, reaction: String) async throws {
        try await timeline?.toggleReaction(eventId: eventID, key: reaction)
    }
    
    func markAsRead(eventID: String) async {
        print(":marking as read")
        do {
            guard let timeline else {
                fatalError("no timeline")
            }
            try await timeline.sendReadReceipt(receiptType: .read, eventId: eventID)
            try await roomSummary.roomListItem.fullRoom().markAsRead(receiptType: .read)
            print("marked as read")
        } catch {
            print("ERROR: cannot mark as read \(error)")
        }
        
    }
    
    @ViewBuilder var footer: some View {
        VStack {
            if let parent = parentMessage?.asEvent()?.content().asMessage()?.body() {
                HStack {
                    Text("Replying to: \(parent)")
                    Spacer()
                    Button {
                        parentMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .size(20)
                    }
                }
                
            }
            
            HStack(spacing: 20) {
                TextField(text: $message) {
                    Text("Message")
                }
                
                Button {
                    print("sending message")
                    Task {
                        await sendMessage()
                        // await sendObjectMessage()
                    }
                } label: {
                    Image(systemName: "paperplane")
                        .size(20)
                }
            }
        }
        
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
    
    
    private func sendMessage() async {
        guard !message.isEmpty else {
            print("empty message")
            return
        }
        let message = messageEventContentFromMarkdown(md: message)
        do {
            if let eventID = parentMessage?.asEvent()?.eventId() {
                let _ = try await timeline?.sendReply(msg: message, eventId: eventID)
                parentMessage = nil
            } else {
                let _ = try await timeline?.send(msg: message)
            }
            print("message sent")
            self.message = ""
        } catch {
            print("ERROR: Message not sent \(error)")
        }
        
    }
    
    private func sendObjectMessage() async {
        guard !message.isEmpty else {
            print("empty message")
            return
        }
        let messageObject = MessageContent(sivElementUUID: UUID().uuidString, message: self.message, url: "https://www.trysiv.com/shares/detail/1b48398c-b16e-4e2c-ba9c-cac5932bc19c/981e9148-2af1-4b67-a5f0-e58777795d1e")
        do {
            let json = try JSONEncoder().encode(messageObject)
            guard let htmlString = String(data: json, encoding: String.Encoding.utf8) else {
                print("ERROR: can't convert json to html")
                return
            }
            let messageHTML = messageEventContentFromHtml(body: message, htmlBody: htmlString)
            let _ = try await timeline?.send(msg: messageHTML)
            print("message sent")
            self.message = ""
        } catch {
            print("ERROR: Message not sent \(error)")
        }
        
    }
    private func updateItemsWithDiffs(_ diffs: [TimelineDiff]) {
        
        let items = diffs
            .reduce(timelineItems) { currentItems, diff in
                guard let collectionDiff = buildDiff(from: diff, on: currentItems) else {
                    print("Failed building CollectionDifference from \(diff)")
                    return currentItems
                }
                
                guard let updatedItems = currentItems.applying(collectionDiff) else {
                    print("Failed applying diff: \(collectionDiff)")
                    return currentItems
                }
                
                return updatedItems
            }

//        itemProxiesSubject.send(items)
        self.timelineItems = items
        if timelineItems.count < 10 {
            Task {
                await loadOlderMessages()
            }
        }
        print("Finished applying diffs, current items (\(timelineItems.count)) : \(timelineItems)")
        
    }
    
    private func buildDiff(from diff: TimelineDiff, on timelineItems: [TimelineItem]) -> CollectionDifference<TimelineItem>? {
        var changes = [CollectionDifference<TimelineItem>.Change]()
        
        switch diff.change() {
        case .append:
            guard let items = diff.append() else { fatalError() }

            for (index, item) in items.enumerated() {
                let timelineItem = item
                
                changes.append(.insert(offset: Int(timelineItems.count) + index, element: timelineItem, associatedWith: nil))
            }
        case .clear:
            for (index, itemProxy) in timelineItems.enumerated() {
                changes.append(.remove(offset: index, element: itemProxy, associatedWith: nil))
            }
        case .insert:
            guard let update = diff.insert() else { fatalError() }

            changes.append(.insert(offset: Int(update.index), element: update.item, associatedWith: nil))
        case .popBack:
            guard let itemProxy = timelineItems.last else { fatalError() }


            changes.append(.remove(offset: timelineItems.count - 1, element: itemProxy, associatedWith: nil))
        case .popFront:
            guard let itemProxy = timelineItems.first else { fatalError() }


            changes.append(.remove(offset: 0, element: itemProxy, associatedWith: nil))
        case .pushBack:
            guard let item = diff.pushBack() else { fatalError() }
            
            changes.append(.insert(offset: Int(timelineItems.count), element: item, associatedWith: nil))
        case .pushFront:
            guard let item = diff.pushFront() else { fatalError() }

            changes.append(.insert(offset: 0, element: item, associatedWith: nil))
        case .remove:
            guard let index = diff.remove() else { fatalError() }
            let itemProxy = timelineItems[Int(index)]
            changes.append(.remove(offset: Int(index), element: itemProxy, associatedWith: nil))
        case .reset:
            guard let items = diff.reset() else { fatalError() }
            for (index, itemProxy) in timelineItems.enumerated() {
                changes.append(.remove(offset: index, element: itemProxy, associatedWith: nil))
            }

            for (index, timelineItem) in items.enumerated() {
                changes.append(.insert(offset: index, element: timelineItem, associatedWith: nil))
            }
        case .set:
            guard let update = diff.set() else { fatalError() }
            changes.append(.remove(offset: Int(update.index), element: update.item, associatedWith: nil))
            changes.append(.insert(offset: Int(update.index), element: update.item, associatedWith: nil))
        case .truncate:
            break
        }
        return CollectionDifference(changes)
    }
}

class TimelineListenerProxy: TimelineListener {
    private let onUpdateClosure: ([MatrixRustSDK.TimelineDiff]) -> Void
    init(_ onUpdateClosure: @escaping ([MatrixRustSDK.TimelineDiff]) -> Void) {
        self.onUpdateClosure = onUpdateClosure
    }
    func onUpdate(diff: [MatrixRustSDK.TimelineDiff]) {
        onUpdateClosure(diff)
    }
    
}

extension TimelineItem: Identifiable {
    public var id: String {
        self.uniqueId()
    }
}

struct MessageContent: Codable {
    let sivElementUUID: String
    let message: String
    let url: String
    
    static func messageFromString(_ str: String) throws -> MessageContent? {
        let messageContent = try JSONDecoder().decode(MessageContent.self, from: str.data(using: .utf8)!)
        return messageContent
    }
}

#Preview {
    RoomView(roomSummary: .constant(RoomSummary(roomListItem: RoomListItem(noPointer: .init()), id: UUID().uuidString, hasUnreadMessages: false, hasUnreadMentions: false, hasUnreadNotifications: false)))
}
