// Intro
// https://realm.io/news/tryswift-gwendolyn-weston-type-erasure/
// http://robnapier.net/erasure
// http://www.russbishop.net/type-erasure

// Std Lib implementation technique
// https://realm.io/news/type-erased-wrappers-in-swift/
// http://robnapier.net/type-erasure-in-stdlib

// Associated Types
// http://www.russbishop.net/swift-associated-types

// http://krakendev.io/blog/generic-protocols-and-their-shortcomings
// > In programming there is a concept known as a thunk (https://en.wikipedia.org/wiki/Thunk) that can help us out with this particular shortcoming! A thunk is a helper struct/class that forwards calls from one object to another object. This is useful for scenarios where those two objects can't normally talk to one another. Using this, we can effectively erase our abstract generic protocol types in favor of another concrete, more fully-fledged type. This is often referred to as type erasure.

import UIKit

protocol DetailRow: class {
    associatedtype Model
    var sizeLabelText: String { get set }
    func configure(model: Model)
}

struct Folder {}
struct File {}

class FolderCell: DetailRow {
    typealias Model = Folder
    var sizeLabelText: String = ""
    func configure(model: Folder) {
        print("Configured a \(type(of: self))")
    }
}
class FileCell: DetailRow {
    typealias Model = File
    var sizeLabelText: String = ""
    func configure(model: File) {
        print("Configured a \(type(of: self))")
    }
}
class DetailFileCell: DetailRow {
    typealias Model = File
    var sizeLabelText: String = ""
    func configure(model: File) {
        print("Configured a \(type(of: self))")
    }
}

// error: protocol 'DetailRow' can only be used as a generic constraint because it has Self or associated type requirements
//let cells: [DetailRow] = [FileCell(), FolderCell()]
//let randomFileCell: DetailRow = (arc4random() % 2 == 0) ? FileCell() : DetailFileCell()

// Cannot specialize non-generic type
//let cells: DetailRow<File> = [FileCell(), DetailFileCell()]

// Protocols do not allow generic parameters
//protocol DetailRow<Model> {
//    func configure(model: Model)
//}

// Closure example
// Type erasure to the rescue
class AnyDetailRow<Model>: DetailRow {
    private let _configure: (Model) -> Void

    private let _getSize: () -> String
    private var _setSize: (String) -> Void

    var sizeLabelText: String {
        get {
            return _getSize()
        }
        set {
            _setSize(newValue)
        }
    }

    init<Concrete: DetailRow>(_ concrete: Concrete) where Model == Concrete.Model {
        _configure = concrete.configure
        _setSize = concrete.setSize
        _getSize = concrete.getSize
    }

    func configure(model: Model) {
        _configure(model)
    }
}

extension DetailRow {
    func getSize() -> String {
        return sizeLabelText
    }
    func setSize(size: String) {
        sizeLabelText = size
    }
}

let cells: [AnyDetailRow<File>] = [AnyDetailRow(FileCell()), AnyDetailRow(DetailFileCell())]
cells.map() { $0.configure(model: File()) }

if let firstCell = cells.first {
    firstCell.sizeLabelText = "200KB"
    print(firstCell.sizeLabelText)
}

// Heterogenous collection literal could only be inferred to '[Any]'; add explicit type annotation if this is intentional.
//let objectiveCDaze = [AnyDetailRow(FileCell()), AnyDetailRow(FolderCell())]

fileprivate class _AnyDetailRowBase<Model>: DetailRow {
    internal var sizeLabelText: String = ""

    init() {
        guard type(of: self) != _AnyDetailRowBase.self else {
            fatalError("_AnyDetailRowBase<Model> instances can not be created; create a subclass instance instead")
        }
    }
    func configure(model: Model) {
        fatalError("Must override")
    }
}

fileprivate final class _AnyDetailRowBox<Base: DetailRow>: _AnyDetailRowBase<Base.Model> {
    var base: Base
    init(_ base: Base) {
        self.base = base
    }
    override func configure(model: Base.Model) {
        base.configure(model: model)
    }
}

final class ImprovedAnyDetailRow<Model>: DetailRow {
    private let box: _AnyDetailRowBase<Model>
    var sizeLabelText: String {
        get {
            return box.sizeLabelText
        }
        set {
            box.sizeLabelText = newValue
        }
    }

    init<Base: DetailRow>(_ base: Base) where Base.Model == Model {
        box = _AnyDetailRowBox(base)
    }
    func configure(model: Model) {
        box.configure(model: model)
    }
}

let improvedCells = [ImprovedAnyDetailRow(FileCell()), ImprovedAnyDetailRow(DetailFileCell())]
improvedCells.map() { $0.configure(model: File()) }

let randomCell = (arc4random() % 2 == 0) ? ImprovedAnyDetailRow(DetailFileCell()) : ImprovedAnyDetailRow(FileCell())
randomCell.sizeLabelText = "1TB"
print("\(randomCell.sizeLabelText)")


