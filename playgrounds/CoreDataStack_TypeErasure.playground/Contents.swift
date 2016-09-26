//: Playground - noun: a place where people can play

import Foundation
import CoreData

@objc public protocol CoreDataModelable {
    static var entityName: String { get }
}
extension CoreDataModelable {
    static public func entityDescriptionInContext(context: NSManagedObjectContext) -> NSEntityDescription! {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            assertionFailure("Entity named \(entityName) doesn't exist. Fix the entity description or naming of \(Self.self).")
            return nil
        }
        return entity
    }
}

public enum FireFrequency {
    case onChange
    case onSave
}

public protocol EntityMonitorDelegate: class {
    associatedtype T: NSManagedObject, CoreDataModelable, Hashable

    func entityMonitorObservedInserts(_ monitor: EntityMonitor<T>, entities: Set<T>)
    func entityMonitorObservedDeletions(_ monitor: EntityMonitor<T>, entities: Set<T>)
    func entityMonitorObservedModifications(_ monitor: EntityMonitor<T>, entities: Set<T>)
}

public class EntityMonitor<T: NSManagedObject> where T: CoreDataModelable, T: Hashable {

    public func setDelegate<U: EntityMonitorDelegate>(_ delegate: U) where U.T == T {
        self.delegateHost = ForwardingEntityMonitorDelegate(owner: self, delegate: delegate)
    }

    // MARK: - Private Properties

    private var delegateHost: BaseEntityMonitorDelegate<T>? {
        willSet {
            delegateHost?.removeObservers()
        }
        didSet {
            delegateHost?.setupObservers()
        }
    }

    fileprivate typealias EntitySet = Set<T>
    fileprivate let context: NSManagedObjectContext
    fileprivate let frequency: FireFrequency
    fileprivate let entityPredicate: NSPredicate
    fileprivate let filterPredicate: NSPredicate?
    fileprivate lazy var combinedPredicate: NSPredicate = {
        if let filterPredicate = self.filterPredicate {
            return NSCompoundPredicate(andPredicateWithSubpredicates:
                [self.entityPredicate, filterPredicate])
        } else {
            return self.entityPredicate
        }
    }()

    public init(context: NSManagedObjectContext, frequency: FireFrequency = .onSave, filterPredicate: NSPredicate? = nil) {
        self.context = context
        self.frequency = frequency
        self.filterPredicate = filterPredicate
        self.entityPredicate = NSPredicate(format: "entity == %@", T.entityDescriptionInContext(context: context))
    }

    deinit {
        delegateHost?.removeObservers()
    }
}

private class BaseEntityMonitorDelegate<T: NSManagedObject>: NSObject where T: CoreDataModelable, T: Hashable {

    private let ChangeObserverSelectorName = #selector(BaseEntityMonitorDelegate<T>.evaluateChangeNotification(_:))

    typealias Owner = EntityMonitor<T>
    typealias EntitySet = Owner.EntitySet

    unowned let owner: Owner

    init(owner: Owner) {
        self.owner = owner
    }

    final func setupObservers() {
        let notificationName: NSNotification.Name
        switch owner.frequency {
        case .onChange:
            notificationName = NSNotification.Name.NSManagedObjectContextObjectsDidChange
        case .onSave:
            notificationName = NSNotification.Name.NSManagedObjectContextDidSave
        }

        NotificationCenter.default.addObserver(self,
                                               selector: ChangeObserverSelectorName,
                                               name: notificationName,
                                               object: owner.context)
    }

    final func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc final func evaluateChangeNotification(_ notification: Notification) {
        guard let changeSet = (notification as NSNotification).userInfo else {
            return
        }

        owner.context.performAndWait { [predicate = owner.combinedPredicate] in
            func process(_ value: Any?) -> EntitySet {
                return (value as? NSSet)?.filtered(using: predicate) as? EntitySet ?? []
            }

            let inserted = process(changeSet[NSInsertedObjectsKey])
            let deleted = process(changeSet[NSDeletedObjectsKey])
            let updated = process(changeSet[NSUpdatedObjectsKey])
            self.handleChanges(inserted: inserted, deleted: deleted, updated: updated)
        }
    }

    func handleChanges(inserted: EntitySet, deleted: EntitySet, updated: EntitySet) {
        fatalError("Must be overridden")
    }
}

private final class ForwardingEntityMonitorDelegate<Delegate: EntityMonitorDelegate>: BaseEntityMonitorDelegate<Delegate.T> {

    weak var delegate: Delegate?

    init(owner: Owner, delegate: Delegate) {
        super.init(owner: owner)
        self.delegate = delegate
    }

    override func handleChanges(inserted: EntitySet, deleted: EntitySet, updated: EntitySet) {
        guard let delegate = delegate else { return }

        if !inserted.isEmpty {
            delegate.entityMonitorObservedInserts(owner, entities: inserted)
        }

        if !deleted.isEmpty {
            delegate.entityMonitorObservedDeletions(owner, entities: deleted)
        }

        if !updated.isEmpty {
            delegate.entityMonitorObservedModifications(owner, entities: updated)
        }
    }
}

class Job: NSManagedObject, CoreDataModelable {
    static let entityName = "Job"
}

class MyJobObserver: EntityMonitorDelegate {
    let entityMonitor: EntityMonitor<Job>

    init(context: NSManagedObjectContext) {
        entityMonitor = EntityMonitor<Job>(context: context)
        entityMonitor.setDelegate(self)
    }

    func entityMonitorObservedInserts(_ monitor: EntityMonitor<Job>, entities: Set<Job>) {
        print("jobs created: \(entities)")
    }

    func entityMonitorObservedDeletions(_ monitor: EntityMonitor<Job>, entities: Set<Job>) {
        print("jobs deleted: \(entities)")
    }

    func entityMonitorObservedModifications(_ monitor: EntityMonitor<Job>, entities: Set<Job>) {
        print("jobs changed: \(entities)")
    }
}



