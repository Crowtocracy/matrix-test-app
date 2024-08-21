//
//  RoomView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 8/20/24.
//

import SwiftUI
import MatrixRustSDK

struct RoomView: View {
    var roomSummary: RoomSummary
    @State var message = String()
    @State var timelineItems = [TimelineItem]()
    @State var timelineListenerProxy: TimelineListenerProxy?
    @State var timelineListenerTaskHandle: TaskHandle?
    @State var timeline: Timeline?
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
            
            print(roomSummary.roomListItem.isTimelineInitialized())
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
            if roomSummary.isInvite {
                await joinRoom()
            }
            print(roomSummary.roomListItem.isTimelineInitialized())
            do {
                timeline = try await roomSummary.roomListItem.fullRoom().timeline()
                
            } catch {
                print("ERROR: cannot find timeline \(error)")
            }
            await loadOlderMessages()
            timelineListenerTaskHandle = try? await roomSummary.roomListItem.fullRoom().timeline().addListener(listener: timelineListenerProxy!)
            
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
        do {
            print(try await timeline?.paginateBackwards(numEvents: 10))
        } catch {
            print("ERROR: cannot load older messages \(error)")
        }
    }
    @ViewBuilder var header: some View {
        HStack {
            Avatar(avatarURL: roomSummary.avatarURL)
            Text(roomSummary.name)
        }
    }
    
    @ViewBuilder var messages: some View {
        ScrollView {
            LazyVStack {
                ForEach(timelineItems) { item in
                    TimelineItemCell(timelineItem: item)
                }
            }
        }
    }
    
    @ViewBuilder var footer: some View {
        HStack(spacing: 20) {
            TextField(text: $message) {
                Text("Message")
            }
            
            Button {
                print("sending message")
                Task {
                    await sendMessage()
                }
            } label: {
                Image(systemName: "paperplane")
                    .size(20)
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
            let _ = try await timeline?.send(msg: message)
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

struct TimelineItemCell: View {
    var timelineItem: TimelineItem
    var body: some View {
        if let event = timelineItem.asEvent() {
            Text(event.content().asMessage()?.body() ?? "no message body \(event.content().kind())")
        } else if let virtual = timelineItem.asVirtual() {
            switch virtual {
            case .dayDivider(let ts):
                Text(Date(timeIntervalSince1970: TimeInterval(ts / 1000)).description)
            case .readMarker:
                Text("read")
            }
        }
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

#Preview {
    RoomView(roomSummary: RoomSummary(roomListItem: RoomListItem(noPointer: .init()), id: UUID().uuidString, hasUnreadMessages: false, hasUnreadMentions: false, hasUnreadNotifications: false))
}
