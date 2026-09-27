import Foundation

public struct RankedItem: Hashable, Sendable {
    public let id: UUID
    public let rank: Int64

    public init(id: UUID, rank: Int64) {
        self.id = id
        self.rank = rank
    }
}

/// Sparse integer ranks within one container, with the UUID as a
/// deterministic tie-breaker (FR-04). A move normally rewrites only the moved
/// item; the siblings are rebalanced only when the gap is exhausted.
public enum Ranking {
    public static let spacing: Int64 = 1 << 20

    public static func precedes(_ lhs: RankedItem, _ rhs: RankedItem) -> Bool {
        lhs.rank != rhs.rank ? lhs.rank < rhs.rank : lhs.id.uuidString < rhs.id.uuidString
    }

    public static func sorted(_ items: [RankedItem]) -> [RankedItem] {
        items.sorted(by: precedes)
    }

    /// Returns the rank updates needed to place `id` at `destination` among
    /// `siblings`. `siblings` may or may not already contain `id`.
    public static func changes(placing id: UUID, at destination: Int, among siblings: [RankedItem]) -> [UUID: Int64] {
        let others = sorted(siblings).filter { $0.id != id }
        let index = min(max(destination, 0), others.count)
        let lower = index > 0 ? others[index - 1].rank : nil
        let upper = index < others.count ? others[index].rank : nil

        if let rank = rank(between: lower, and: upper) {
            return [id: rank]
        }

        var ordered = others.map(\.id)
        ordered.insert(id, at: index)
        var result: [UUID: Int64] = [:]
        let current = Dictionary(siblings.map { ($0.id, $0.rank) }, uniquingKeysWith: { first, _ in first })
        for (offset, itemID) in ordered.enumerated() {
            let rank = Int64(offset + 1) * spacing
            if current[itemID] != rank { result[itemID] = rank }
        }
        return result
    }

    /// A rank strictly between the bounds, or `nil` when a rebalance is needed.
    static func rank(between lower: Int64?, and upper: Int64?) -> Int64? {
        switch (lower, upper) {
        case (nil, nil):
            return spacing
        case let (lower?, nil):
            let (next, overflow) = lower.addingReportingOverflow(spacing)
            return overflow ? nil : next
        case let (lower, upper?):
            let floor = lower ?? 0
            guard upper > floor else { return nil }
            let middle = floor + (upper - floor) / 2
            return middle > floor && middle < upper ? middle : nil
        }
    }
}
