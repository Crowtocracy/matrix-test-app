//
//  RoomManager.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 5/23/25.
//

import Foundation
import MatrixRustSDK

@MainActor
class RoomManager: ObservableObject {
    let sivRoom: SivRoom
    var sendHandle: SendHandle?
    var backPaginationStatusTaskHandle: TaskHandle?

    @Published var roomListItem: RoomListItem
    @Published var roomInfo: RoomInfo

    @Published var timelineItems = [TimelineItem]()
    @Published var events: [String] = []
    @Published var sivMessages: [SivMessage] = []
    @Published var reversedSivMessages: [SivMessage] = []
    @Published var requestMessage: SivMessage?
    @Published var parentMessage: SivMessage?
    @Published var timeline: Timeline?
    @Published var replyDict: [String : [SivMessage]] = [:]
    
    @Published var userAlreadySentMessage: Bool = false

    @Published var timelineListenerTaskHandle: TaskHandle?
    @Published var loadedOldest = false

    @Published var membersUUID: [String] = []

    @Published var timelineChange = false

    init(sivRoom: SivRoom, roomListItem: RoomListItem, roomInfo: RoomInfo) {
        // TODO: create a cache? in MatrixManager
        self.sivRoom = sivRoom
        self.roomListItem = roomListItem
        self.roomInfo = roomInfo
    }

    func setup() async throws {
        var timelineInitialized = false
        var retries = 0
//        if roomInfo.membership == .invited {
//            try await roomListItem.invitedRoom().join()
//        }
        while !timelineInitialized {
            if retries > 10 {
                break
            }
            retries += 1
            do {
                if !roomListItem.isTimelineInitialized() {
                    try await initializeTimeline()
                }
                timeline = try await roomListItem.fullRoom().timeline()
                timelineInitialized = true
            } catch {
                try? await Task.sleep(for: .seconds(1))
                timelineInitialized = false
            }
        }
        
        
        timelineListenerTaskHandle = try await roomListItem.fullRoom().timeline().addListener(listener: self)
    }

    func initializeTimeline() async throws {
        try await roomListItem.initTimeline(eventTypeFilter: TimelineEventTypeFilter.exclude(eventTypes: StateEventType.allcases.map { FilterTimelineEventType.state(eventType: $0) }), internalIdPrefix: nil)
        timeline = try await roomListItem.fullRoom().timeline()
    }

    func paginateBackwards() async throws {
        guard let timeline else {
            print("MERROR: no timeline")
            return
        }
        loadedOldest = try await timeline.paginateBackwards(numEvents: 10)
        backPaginationStatusTaskHandle = try await timeline.subscribeToBackPaginationStatus(listener: self)
    }

}

extension RoomManager: @preconcurrency TimelineListener {
    func onUpdate(diff: [MatrixRustSDK.TimelineDiff]) {
        Task { @MainActor in
            updateItemsWithDiffs(diff)
            var updatedMessages = [SivMessage]()
            var previousMessage: SivMessage? = nil
            var updatedReplies: [String : [SivMessage]] = [:]
            for item in self.timelineItems {
                if let sivMessage = await item.generateSivMessage(previousMessage: previousMessage) {
                    
                    if let parentId = sivMessage.parentId {
                        if updatedReplies[parentId] == nil {
                            updatedReplies[parentId] = [sivMessage]
                        } else {
                            updatedReplies[parentId]?.append(sivMessage)
                        }
                    } else {
                        previousMessage = sivMessage
                        updatedMessages.append(sivMessage)
                    }
                }
            }
            // see if user already sent something
//            userAlreadySentMessage = updatedMessages.contains(where: { $0.fromSelf })
            
            
            self.sivMessages = updatedMessages
            self.reversedSivMessages = updatedMessages.reversed()
            self.timelineChange.toggle()
            self.replyDict = updatedReplies
        }
    }

    private func updateItemsWithDiffs(_ diffs: [TimelineDiff]) {
        timelineItems = diffs.reduce(timelineItems as [TimelineItem]) { (currentItems: [TimelineItem], diff: TimelineDiff) -> [TimelineItem] in
            if let collectionDiff: CollectionDifference<TimelineItem> = buildDiff(from: diff, on: currentItems) {
                if let updatedItems: [TimelineItem] = currentItems.applying(collectionDiff) {
                    return updatedItems
                }
            }
            return currentItems
        }
    }

    private func buildDiff(from diff: TimelineDiff, on timelineItems: [TimelineItem]) -> CollectionDifference<TimelineItem>? {
        var changes = [CollectionDifference<TimelineItem>.Change]()

        switch diff.change() {
        case .append:
            guard let items = diff.append() else { fatalError() }

            for (index, item) in items.enumerated() {
                changes.append(.insert(offset: timelineItems.count + index, element: item, associatedWith: nil))
            }
        case .clear:
            for (index, item) in timelineItems.enumerated() {
                changes.append(.remove(offset: index, element: item, associatedWith: nil))
            }
        case .insert:
            guard let update = diff.insert() else { fatalError() }

            let item = update.item
            changes.append(.insert(offset: Int(update.index), element: item, associatedWith: nil))
        case .popBack:
            guard let item = timelineItems.last else { fatalError() }

            changes.append(.remove(offset: timelineItems.count - 1, element: item, associatedWith: nil))
        case .popFront:
            guard let item = timelineItems.first else { fatalError() }

            changes.append(.remove(offset: 0, element: item, associatedWith: nil))
        case .pushBack:
            guard let item = diff.pushBack() else { fatalError() }

            changes.append(.insert(offset: timelineItems.count, element: item, associatedWith: nil))
        case .pushFront:
            guard let item = diff.pushFront() else { fatalError() }

            changes.append(.insert(offset: 0, element: item, associatedWith: nil))
        case .remove:
            guard let index = diff.remove() else { fatalError() }

            let item = timelineItems[Int(index)]
            changes.append(.remove(offset: Int(index), element: item, associatedWith: nil))
        case .reset:
            guard let items = diff.reset() else { fatalError() }

            for (index, item) in timelineItems.enumerated() {
                changes.append(.remove(offset: index, element: item, associatedWith: nil))
            }

            for (index, item) in items.enumerated() {
                changes.append(.insert(offset: index, element: item, associatedWith: nil))
            }
        case .set:
            guard let update = diff.set() else { fatalError() }

            let item = update.item
            changes.append(.remove(offset: Int(update.index), element: item, associatedWith: nil))
            changes.append(.insert(offset: Int(update.index), element: item, associatedWith: nil))
        case .truncate:
            break
        }

        return CollectionDifference(changes)
    }
}

extension RoomManager: @preconcurrency PaginationStatusListener {
    func onUpdate(status: RoomPaginationStatus) {
        switch status {
        case .idle(hitTimelineStart: let hitStartOfTimeline):
            Task { @MainActor in
                loadedOldest = hitStartOfTimeline
            }
            if !hitStartOfTimeline {
                Task {
                    try? await self.paginateBackwards()
                }
            }
        case .paginating:
//            logger.debug("paginating")
            return
        }
    }
}


struct SivMessage: Identifiable {
    let id: String
    let message: String
    let timestamp: Timestamp
    let parentId: String?
}

extension StateEventType {
    static var allcases: [StateEventType] {
        return [
            .callMember,
            .policyRuleRoom,
            .policyRuleServer,
            .policyRuleUser,
            .roomAliases,
            .roomAvatar,
            .roomCanonicalAlias,
            .roomCreate,
            .roomEncryption,
            .roomGuestAccess,
            .roomHistoryVisibility,
            .roomJoinRules,
            .roomMemberEvent,
            .roomName,
            .roomPinnedEvents,
            .roomPowerLevels,
            .roomServerAcl,
            .roomThirdPartyInvite,
            .roomTombstone,
            .roomTopic,
            .spaceChild,
            .spaceParent
        ]
    }
}

extension TimelineItem {
    func generateMessageString() -> String {
        if let event = asEvent() {
            return event.sender + ":\n" + (event.getMessage() ?? "no message body")

        } else if let virtual = asVirtual() {
            switch virtual {
            case .dateDivider(let ts):
                return "---\(ts)---"

            case .readMarker:
                return "---unread---"
            case .timelineStart:
                return "---timeline start---"
            }
        }
        return ""
    }

    func generateSivMessage(previousMessage: SivMessage? = nil) async -> SivMessage? {
        guard let event = asEvent() else { return nil }
        return event.generateSivMessage(previousMessage: previousMessage)
    }
}
