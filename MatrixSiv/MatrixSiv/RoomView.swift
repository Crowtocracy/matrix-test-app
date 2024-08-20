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
        }
        .task {
            print("Room task")
            timelineListenerProxy = TimelineListenerProxy({ diff in
                self.updateItemsWithDiffs(diff)
            })
            print(roomSummary.roomListItem.isTimelineInitialized())
            do {
                try await roomSummary.roomListItem.initTimeline(eventTypeFilter: nil, internalIdPrefix: nil)
            } catch {
                print("ERROR: timeline failed to init \(error)")
            }
            print(roomSummary.roomListItem.isTimelineInitialized())
            
            timelineListenerTaskHandle = try? await roomSummary.roomListItem.fullRoom().timeline().addListener(listener: timelineListenerProxy!)
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
            VStack {
                
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
            } label: {
                Image(systemName: "paperplane")
                    .size(20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
    
    private func updateItemsWithDiffs(_ diffs: [TimelineDiff]) {
        print("Received timeline diff")
        for i in diffs {
            switch i.change() {
            case .append:
                print("appended")
                print(i.append() ?? [])
            case .reset:
                print("reset")
                print(i.reset() ?? [])
                print(i.reset()?.first?.asVirtual().debugDescription)
            default:
                print(i.change())
            }
        }
        /*
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
        
        print("Finished applying diffs, current items (\(timelineItems.count)) : \(timelineItems)")
         */
    }
    
    /*private func buildDiff(from diff: TimelineDiff, on timelineItems: [TimelineItem]) -> CollectionDifference<TimelineItem>? {
        var changes = [CollectionDifference<TimelineItem>.Change]()
        
        switch diff.change() {
        case .append:
            guard let items = diff.append() else { fatalError() }

            for (index, item) in items.enumerated() {
                let timelineItem = item
                
                if timelineItem.isMembershipChange {
                    membershipChangeSubject.send(())
                }
                
                changes.append(.insert(offset: Int(timelineItems.count) + index, element: timelineItem, associatedWith: nil))
            }
        case .clear:
            MXLog.verbose("Clear all items")
            for (index, itemProxy) in timelineItems.enumerated() {
                changes.append(.remove(offset: index, element: itemProxy, associatedWith: nil))
            }
        case .insert:
            guard let update = diff.insert() else { fatalError() }

            MXLog.verbose("Insert \(update.item.debugIdentifier) at \(update.index)")
            let itemProxy = TimelineItemProxy(item: update.item)
            changes.append(.insert(offset: Int(update.index), element: itemProxy, associatedWith: nil))
        case .popBack:
            guard let itemProxy = timelineItems.last else { fatalError() }

            MXLog.verbose("Pop Back \(itemProxy.debugIdentifier)")

            changes.append(.remove(offset: timelineItems.count - 1, element: itemProxy, associatedWith: nil))
        case .popFront:
            guard let itemProxy = timelineItems.first else { fatalError() }

            MXLog.verbose("Pop Front \(itemProxy.debugIdentifier)")

            changes.append(.remove(offset: 0, element: itemProxy, associatedWith: nil))
        case .pushBack:
            guard let item = diff.pushBack() else { fatalError() }

            MXLog.verbose("Push Back \(item.debugIdentifier)")
            let itemProxy = TimelineItemProxy(item: item)
            
            if itemProxy.isMembershipChange {
                membershipChangeSubject.send(())
            }
            
            changes.append(.insert(offset: Int(timelineItems.count), element: itemProxy, associatedWith: nil))
        case .pushFront:
            guard let item = diff.pushFront() else { fatalError() }

            MXLog.verbose("Push Front: \(item.debugIdentifier)")
            let itemProxy = TimelineItemProxy(item: item)
            changes.append(.insert(offset: 0, element: itemProxy, associatedWith: nil))
        case .remove:
            guard let index = diff.remove() else { fatalError() }

            let itemProxy = timelineItems[Int(index)]

            MXLog.verbose("Remove \(itemProxy.debugIdentifier) at: \(index)")

            changes.append(.remove(offset: Int(index), element: itemProxy, associatedWith: nil))
        case .reset:
            guard let items = diff.reset() else { fatalError() }

            MXLog.verbose("Replace all items with \(items.map(\.debugIdentifier))")
            for (index, itemProxy) in timelineItems.enumerated() {
                changes.append(.remove(offset: index, element: itemProxy, associatedWith: nil))
            }

            for (index, timelineItem) in items.enumerated() {
                changes.append(.insert(offset: index, element: TimelineItemProxy(item: timelineItem), associatedWith: nil))
            }
        case .set:
            guard let update = diff.set() else { fatalError() }

            MXLog.verbose("Set \(update.item.debugIdentifier) at index \(update.index)")
            let itemProxy = TimelineItemProxy(item: update.item)
            changes.append(.remove(offset: Int(update.index), element: itemProxy, associatedWith: nil))
            changes.append(.insert(offset: Int(update.index), element: itemProxy, associatedWith: nil))
        case .truncate:
            break
        }
        
        return CollectionDifference(changes)
    }*/
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

#Preview {
    RoomView(roomSummary: RoomSummary(roomListItem: RoomListItem(noPointer: .init()), id: UUID().uuidString, hasUnreadMessages: false, hasUnreadMentions: false, hasUnreadNotifications: false))
}
