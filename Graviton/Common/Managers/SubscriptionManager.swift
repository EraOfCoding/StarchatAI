//
//  SubscriptionManager.swift
//  Graviton
//
//  Created by Ben Lu on 5/12/17.
//  Copyright © 2017 Ben Lu. All rights reserved.
//

import Orbits
import SpaceTime
import UIKit

typealias SubscriptionUUID = UUID

class SubscriptionManager<T> {
    typealias SubscriptionBlock = (T) -> Void

    enum RefreshMode {
        case realtime
        case never
        case interval(TimeInterval)
    }

    class Subscription {
        let identifier: SubscriptionUUID
        let mode: RefreshMode
        var content: T?
        var lastUpdateJd: JulianDay?
        var didLoad: SubscriptionBlock?
        var didUpdate: SubscriptionBlock?

        init(identifier: SubscriptionUUID, mode: RefreshMode, content: T?, didLoad: SubscriptionBlock? = nil, didUpdate: SubscriptionBlock? = nil) {
            self.identifier = identifier
            self.mode = mode
            self.content = content
            self.didLoad = didLoad
            self.didUpdate = didUpdate
        }
    }

    var content: T?
    var subscriptions = [SubscriptionUUID: Subscription]()
    var isFetching: Bool = false

    /// Subscribe to the content update. Keep the returned unique identifier for
    /// further request or unsubscription.
    /// - Parameters:
    ///   - mode: The refresh mode.
    ///   - didLoad: The block being called when the content is loaded.
    ///   - didUpdate: The block being called when the content is updated.
    /// - Returns: A subscription unique identifier.
    func subscribe(mode: RefreshMode = .realtime, didLoad: SubscriptionBlock? = nil, didUpdate: SubscriptionBlock? = nil) -> SubscriptionUUID {
        let uuid = SubscriptionUUID()
        subscriptions[uuid] = Subscription(identifier: uuid, mode: mode, content: content, didLoad: didLoad, didUpdate: didUpdate)
        if let content = content {
            DispatchQueue.main.async {
                didLoad?(content)
            }
        }
        return uuid
    }

    /// Unsubscribe from the content update.
    ///
    /// - Parameter uuid: The subscription unique identifier.
    func unsubscribe(_ uuid: SubscriptionUUID) {
        subscriptions[uuid] = nil
    }

    /// Request the content with the state adjusted to best fit the Julian date
    /// provided. It may or may not update the content according to the refresh mode.
    /// - Parameters:
    ///   - requestedJd: The requested Julian date.
    ///   - identifier: The identifier of the subscription.
    func request(at requestedJd: JulianDay, forSubscription subscriptionId: SubscriptionUUID) {
        var changed = false
        guard let sub = subscriptions[subscriptionId] else {
            fatalError("object not subscribed")
        }
        guard let eph = sub.content else { return }
        switch sub.mode {
        case .realtime:
            update(subscription: sub, forJulianDay: requestedJd)
            sub.content = eph
            sub.lastUpdateJd = requestedJd
            changed = true
        case let .interval(interval):
            let diff = abs(requestedJd.value - (sub.lastUpdateJd?.value ?? 0.0))
            if diff >= interval / 86400 {
                update(subscription: sub, forJulianDay: requestedJd)
                sub.content = eph
                sub.lastUpdateJd = requestedJd
                changed = true
            }
        case .never:
            break
        }
        if changed {
            DispatchQueue.main.async {
                sub.didUpdate?(eph)
            }
        }
    }

    /// Load the content for the first time. This method is meant to be called
    /// when the content is first available.
    /// - Parameter content: The content for the subscribers
    func load(content: T) {
        self.content = content
        for (_, sub) in subscriptions {
            sub.content = self.content
            if let lastJd = sub.lastUpdateJd {
                update(subscription: sub, forJulianDay: lastJd)
            }
            sub.lastUpdateJd = nil
            DispatchQueue.main.async {
                sub.didLoad?(content)
                sub.didUpdate?(content)
            }
        }
    }

    // MARK: - Abstract methods

    /// Fetch the content. This usually involves a network request or database query.
    ///
    /// - Parameter mode: Fetch mode
    /// - Parameter requestedJd:  Requested Julian date to fetch the content.
    func fetch(mode _: Horizons.FetchMode?, forJulianDay _: JulianDay = JulianDay.now) {
        fatalError()
    }

    /// Force update the content to fit the requested Julian date. This method should
    /// not contain asynchronous code as it will be called frequently. It should
    /// change the internal states for the content to best represent the state at the
    /// requested Julian date.
    /// - Parameters:
    ///   - subscription: The subscription to be updated
    ///   - requestedJd: Requested Julian date to fit the content.
    func update(subscription _: SubscriptionManager<T>.Subscription, forJulianDay _: JulianDay) {
        fatalError()
    }
}
