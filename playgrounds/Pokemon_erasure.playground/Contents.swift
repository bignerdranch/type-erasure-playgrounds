//: Pokemon Erasure

import Foundation

protocol Pokemon {
    associatedtype Power
    func attack() -> Power
}

struct Pikachu: Pokemon {
    func attack() -> 🌩 {
        return 🌩()
    }
}

struct Charmander: Pokemon {
    func attack() -> 🔥 {
        return 🔥()
    }
}

// power types
struct 🔥 { }
struct 🌩 { }

// MARK: - Abstract base class
class _AnyPokemonBase<Power>: Pokemon {
    init() {
        guard type(of: self) != _AnyPokemonBase.self else {
            fatalError("_AnyPokemonBase<Power> instances can not be created; create a subclass instance instead")
        }
    }
    func attack() -> Power {
        fatalError("Must override")
    }
}
// MARK: - Box container class
fileprivate final class _AnyPokemonBox<Base: Pokemon>: _AnyPokemonBase<Base.Power> {
    var base: Base
    init(_ base: Base) { self.base = base }
    fileprivate override func attack() -> Base.Power {
        return base.attack()
    }
}
// MARK: - AnyPokemon Wrapper
final class AnyPokemon<Power>: Pokemon {
    private let box: _AnyPokemonBase<Power>
    init<Base: Pokemon>(_ base: Base) where Base.Power == Power {
        box = _AnyPokemonBox(base)
    }
    func attack() -> Power {
        return box.attack()
    }
}

// Use AnyPokemon type directly
let pokemon: AnyPokemon = AnyPokemon(Pikachu())
pokemon.attack()

// Add a new electric Pokemon
class Jolteon: Eevee, Pokemon {
    func attack() -> 🌩 {
        return 🌩()
    }
}
class Eevee {}

// Iterate over a collection of Electric Pokemon
let electricPokemon = [AnyPokemon(Pikachu()), AnyPokemon(Jolteon())]
electricPokemon.map() { $0.attack() }

