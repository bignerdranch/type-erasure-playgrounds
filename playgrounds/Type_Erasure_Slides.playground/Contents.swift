//Sources:

// Intro
//https://realm.io/news/tryswift-gwendolyn-weston-type-erasure/
//http://robnapier.net/erasure
//http://www.russbishop.net/type-erasure

// Std Lib implementation technique
//https://realm.io/news/type-erased-wrappers-in-swift/
//http://robnapier.net/type-erasure-in-stdlib
//http://www.russbishop.net/inception

// Associated Types
//http://www.russbishop.net/swift-associated-types
//http://krakendev.io/blog/generic-protocols-and-their-shortcomings
// > In programming there is a concept known as a thunk (https://en.wikipedia.org/wiki/Thunk) that can help us out with this particular shortcoming! A thunk is a helper struct/class that forwards calls from one object to another object. This is useful for scenarios where those two objects can't normally talk to one another. Using this, we can effectively erase our abstract generic protocol types in favor of another concrete, more fully-fledged type. This is often referred to as type erasure.

import UIKit

protocol Row: class {
    associatedtype Model
    var sizeLabelText: String { get set }
    func configure(model: Model)
}

struct Folder {}
struct File {}

class FolderCell: Row {
    typealias Model = Folder
    var sizeLabelText: String = ""
    func configure(model: Folder) {
        print("Configured a \(type(of: self))")
    }
}
class FileCell: Row {
    typealias Model = File
    var sizeLabelText: String = ""
    func configure(model: File) {
        print("Configured a \(type(of: self))")
    }
}
class DetailFileCell: Row {
    typealias Model = File
    var sizeLabelText: String = ""
    func configure(model: File) {
        print("Configured a \(type(of: self))")
    }
}

// error: protocol 'Row' can only be used as a generic constraint because it has Self or associated type requirements

//let cells: [Row] = [FileCell(), FolderCell()]
//let randomFileCell: Row = (arc4random() % 2 == 0) ? FileCell() : DetailFileCell()
//func resize(row: Row) {
//
//}

// How Generics handle this
struct MyRow<T> {
    var sizeLabelText: String = ""
    func configure(model: T) {
        print("Configured a \(type(of: self))")
    }
}
let myRowStructs: [MyRow<File>] = [MyRow<File>(), MyRow<File>()]

// Cannot specialize non-generic type
//let cells: Row<File> = [FileCell(), DetailFileCell()]

// Protocols do not allow generic parameters
//protocol Row<Model> {
//    func configure(model: Model)
//}

// Closure example
// Type erasure to the rescue
class AnyRow<Model>: Row {
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

    init<Concrete: Row>(_ concrete: Concrete) where Model == Concrete.Model {
        _configure = concrete.configure
        _setSize = concrete.setSize
        _getSize = concrete.getSize
    }

    func configure(model: Model) {
        _configure(model)
    }
}

extension Row {
    func getSize() -> String {
        return sizeLabelText
    }
    func setSize(size: String) {
        sizeLabelText = size
    }
}

let cells: [AnyRow<File>] = [AnyRow(FileCell()), AnyRow(DetailFileCell())]
cells.map() { $0.configure(model: File()) }

if let firstCell = cells.first {
    firstCell.sizeLabelText = "200KB"
    print(firstCell.sizeLabelText)
}

// Heterogenous collection literal could only be inferred to '[Any]'; add explicit type annotation if this is intentional.
//let objectiveCDaze = [AnyRow(FileCell()), AnyRow(FolderCell())]

private class _AnyRowBase<Model>: Row {
    init() {
        guard type(of: self) != _AnyRowBase.self else {
            fatalError("_AnyRowBase<Model> instances can not be created; create a subclass instance instead")
        }
    }
    func configure(model: Model) {
        fatalError("Must override")
    }
    var sizeLabelText: String {
        get { fatalError("Must override") }
        set { fatalError("Must override") }
    }
}

private final class _AnyRowBox<Concrete: Row>: _AnyRowBase<Concrete.Model> {
    var concrete: Concrete
    init(_ concrete: Concrete) {
        self.concrete = concrete
    }
    override func configure(model: Concrete.Model) {
        concrete.configure(model: model)
    }
    override var sizeLabelText: String {
        get {
            return concrete.sizeLabelText
        }
        set {
            concrete.sizeLabelText = newValue
        }
    }
}

final class ImprovedAnyRow<Model>: Row {
    private let box: _AnyRowBase<Model>
    init<Concrete: Row>(_ concrete: Concrete) where Concrete.Model == Model {
        box = _AnyRowBox(concrete)
    }
    func configure(model: Model) {
        box.configure(model: model)
    }
    var sizeLabelText: String {
        get {
            return box.sizeLabelText
        }
        set {
            box.sizeLabelText = newValue
        }
    }
}

let improvedCells = [ImprovedAnyRow(FileCell()), ImprovedAnyRow(DetailFileCell())]
improvedCells.map() { $0.configure(model: File()) }

let randomCell = (arc4random() % 2 == 0) ? ImprovedAnyRow(DetailFileCell()) : ImprovedAnyRow(FileCell())
randomCell.sizeLabelText = "1TB"
print("\(randomCell.sizeLabelText)")

let myTest = DetailFileCell()
let wrapped = ImprovedAnyRow(myTest)
myTest.sizeLabelText = "Test"
print("\(myTest.sizeLabelText) = \(wrapped.sizeLabelText)")

