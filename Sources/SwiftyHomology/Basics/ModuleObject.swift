//
//  ModuleObject.swift
//  Sample
//
//  Created by Taketo Sano on 2018/06/02.
//

import Foundation
import SwiftyMath

// A decomposed form of a freely & finitely presented module,
// i.e. a module with finite generators and a finite & free presentation.
//
//   M = (R/d_0 ⊕ ... ⊕ R/d_k) ⊕ R^r  ( d_i: torsion-coeffs, r: rank )
//
// See: https://en.wikipedia.org/wiki/Free_presentation
//      https://en.wikipedia.org/wiki/Structure_theorem_for_finitely_generated_modules_over_a_principal_ideal_domain#Invariant_factor_decomposition

private func extract<A, R: EuclideanRing>(_ generators: [FreeModule<A, R>]) -> ([A], Matrix<R>, Matrix<R>) {
    if generators.forAll({ z in z.isSingle }) {
        let rootBasis = generators.map{ z in z.basis[0] }
        let I = Matrix<R>.identity(size: generators.count)
        return (rootBasis, I, I)
    } else {
        let rootBasis = generators.flatMap{ $0.basis }.unique().sorted()
        let A = Matrix(rows: rootBasis.count, cols: generators.count) { (i, j) in generators[j][rootBasis[i]] }
        let T = A.elimination(form: .RowHermite).left.submatrix(rowRange: 0 ..< generators.count)
        return (rootBasis, A, T)
    }
}

public struct ModuleObject<A: BasisElementType, R: EuclideanRing>: Equatable, CustomStringConvertible {
    public let summands: [Summand]
    
    // MEMO values used for factorization where R: EuclideanRing
    internal let rootBasis: [A]
    internal let transition: Matrix<R>
    
    // root initializer
    internal init(_ summands: [Summand], _ rootBasis: [A], _ transition: Matrix<R>) {
        self.summands = summands
        self.rootBasis = rootBasis
        self.transition = transition
    }
    
    public init(basis: [A]) {
        let summands = basis.map{ z in Summand(z) }
        let I = Matrix<R>.identity(size: basis.count)
        self.init(summands, basis, I)
    }
    
    // TODO must consider when `generators` does not form a subbasis of R^n
    // e.g) generators = [(2, 0), (0, 2)]
    
    public init(basis: [FreeModule<A, R>]) {
        if basis.forAll({ $0.isSingle }) {
            self.init(basis: basis.map{ $0.basis[0] })
        } else {
            let summands = basis.map{ z in Summand(z) }
            let (rootBasis, A, T) = extract(basis)
            assert(T * A == Matrix.identity(size: basis.count))
            self.init(summands, rootBasis, T)
        }
    }
    
    public init(generators: [A], relationMatrix B: Matrix<R>) {
        let I = Matrix<R>.identity(size: generators.count)
        self.init(rootBasis: generators, generatingMatrix: I, transitionMatrix: I, relationMatrix: B)
    }
    
    public init(generators: [FreeModule<A, R>], relationMatrix B: Matrix<R>) {
        if generators.forAll({ $0.isSingle }) {
            let basis = generators.map{ $0.basis[0] }
            self.init(generators: basis, relationMatrix: B)
        } else {
            let (rootBasis, A, T) = extract(generators)
            self.init(rootBasis: rootBasis, generatingMatrix: A, transitionMatrix: T, relationMatrix: B)
        }
    }
    
    public init(generators: [FreeModule<A, R>], generatingMatrix A: Matrix<R>, transitionMatrix T: Matrix<R>, relationMatrix B: Matrix<R>) {
        if generators.forAll({ $0.isSingle }) {
            let basis = generators.map{ $0.basis[0] }
            self.init(rootBasis: basis, generatingMatrix: A, transitionMatrix: T, relationMatrix: B)
        } else {
            let (rootBasis, A0, T0) = extract(generators)
            assert(T0 * A0 == Matrix.identity(size: generators.count))
            self.init(rootBasis: rootBasis, generatingMatrix: A0 * A, transitionMatrix: T * T0, relationMatrix: B)
        }
    }
    
    /*
     *                 R^n
     *                 ^|
     *                A||T
     *             B   |v
     *  0 -> R^l >---> R^k --->> M -> 0
     *        ^        ^|
     *        |       P||
     *        |    D   |v
     *  0 -> R^l >---> R^k --->> M' -> 0
     *
     */
    public init(rootBasis: [A], generatingMatrix A: Matrix<R>, transitionMatrix T: Matrix<R>, relationMatrix B: Matrix<R>) {
        let (n, k, l) = (A.rows, A.cols, B.cols)
        
        assert(n == rootBasis.count)
        assert(k == B.rows)
        assert(n >= k)
        assert(k >= l)
        
        let elim = B.elimination(form: .Smith)
        
        let D = elim.diagonal + [.zero].repeated(k - l)
        let s = D.count{ $0 != .identity }
        
        let A2 = A * elim.leftInverse.submatrix(colRange: (k - s) ..< k)
        let T2 = (elim.left * T).submatrix(rowRange: (k - s) ..< k)
        
        // MEMO see TODO above.
//        assert(T2 * A2 == Matrix<R>.identity(size: s))
        
if T2 * A2 != Matrix<R>.identity(size: s) {
    Logger.write(.warn, "factorize() won't work properly.")
}

        let generators = rootBasis * A2
        let summands = generators.enumerated().map { (j, z) -> Summand in
            let d = D[k - s + j]
            return Summand(z, d)
        }
        
        self.init(summands, rootBasis, T2)
    }
    
    public subscript(i: Int) -> Summand {
        return summands[i]
    }
    
    public static var zeroModule: ModuleObject<A, R> {
        return ModuleObject([], [], Matrix.zero(rows: 0, cols: 0))
    }
    
    public var isZero: Bool {
        return summands.isEmpty
    }
    
    public var isFree: Bool {
        return summands.forAll { $0.isFree }
    }
    
    public var rank: Int {
        return summands.filter{ $0.isFree }.count
    }
    
    public var torsionCoeffs: [R] {
        return summands.filter{ !$0.isFree }.map{ $0.divisor }
    }
    
    public var generators: [FreeModule<A, R>] {
        return summands.map{ $0.generator }
    }
    
    public func generator(_ i: Int) -> FreeModule<A, R> {
        return summands[i].generator
    }
    
    public var freePart: ModuleObject<A, R> {
        return subSummands{ s in s.isFree }
    }
    
    public var torsionPart: ModuleObject<A, R> {
        return subSummands{ s in !s.isFree }
    }
    
    public func subSummands(_ indices: Int ...) -> ModuleObject<A, R> {
        return subSummands(indices: indices)
    }
    
    public func subSummands(indices: [Int]) -> ModuleObject<A, R> {
        let sub = indices.map{ summands[$0] }
        let T = transition.submatrix(rowsMatching: { i in indices.contains(i)}, colsMatching: { _ in true })
        return ModuleObject(sub, rootBasis, T)
    }
    
    public func subSummands(matching: (Summand) -> Bool) -> ModuleObject<A, R> {
        let indices = (0 ..< summands.count).filter{ i in matching(self[i]) }
        return subSummands(indices: indices)
    }
    
    public func merge(with M2: ModuleObject<A, R>) -> ModuleObject<A, R> {
        let M1 = self
        assert( M1.rootBasis == M2.rootBasis )

        let basis = M1.rootBasis
        let summands = M1.summands + M2.summands
        let T = M1.transition.concatRows(with: M2.transition)
        
        return ModuleObject(summands, basis, T)
    }
    
    public static func ⊕(M1: ModuleObject<A, R>, M2: ModuleObject<A, R>) -> ModuleObject<A, R> {
//        assert( M1.basis.isDisjoint(with: M2.basis) ) // commented out for performance
        let basis = M1.rootBasis + M2.rootBasis
        let summands = M1.summands + M2.summands
        let T = M1.transition ⊕ M2.transition
        return ModuleObject(summands, basis, T)
    }
    
    public func factorize(_ z: FreeModule<A, R>) -> [R] {
        let v = transition * Vector(z.factorize(by: rootBasis))
        
        return summands.enumerated().map { (i, s) in
            return s.isFree ? v[i] : v[i] % s.divisor
        }
    }
    
    public func contains(_ z: FreeModule<A, R>) -> Bool {
        let w = factorize(z).enumerated().sum { (i, r) in
            r * generator(i)
        }
        return z == w
    }
    
    public func elementIsZero(_ z: FreeModule<A, R>) -> Bool {
        return factorize(z).forAll{ $0 == .zero }
    }
    
    public func elementsAreEqual(_ z1: FreeModule<A, R>, _ z2: FreeModule<A, R>) -> Bool {
        return elementIsZero(z1 - z2)
    }
    
    public static func ==(a: ModuleObject<A, R>, b: ModuleObject<A, R>) -> Bool {
        return a.summands == b.summands
    }
    
    public func describe() {
        if !isZero {
            print("\(self) {")
            for (i, x) in generators.enumerated() {
                print("\t(\(i))\t\(x)")
            }
            print("}")
        } else {
            print("\(self)")
        }
    }
    
    public var description: String {
        if summands.isEmpty {
            return "0"
        }
        
        return summands
            .group{ $0.divisor }
            .map{ (r, list) in
                list.first!.description + (list.count > 1 ? Format.sup(list.count) : "")
            }
            .joined(separator: "⊕")
    }
    
    public struct Summand: AlgebraicStructure {
        public let generator: FreeModule<A, R>
        public let divisor: R
        
        public init(_ generator: FreeModule<A, R>, _ divisor: R = .zero) {
            self.generator = generator
            self.divisor = divisor
        }
        
        public init(_ a: A, _ divisor: R = .zero) {
            self.init(.wrap(a), divisor)
        }
        
        public var isFree: Bool {
            return divisor == .zero
        }
        
        public var degree: Int {
            return generator.degree
        }
        
        public static func ==(a: Summand, b: Summand) -> Bool {
            return (a.generator, a.divisor) == (b.generator, b.divisor)
        }
        
        public var description: String {
            switch (isFree, R.self == 𝐙.self) {
            case (true, _)    : return R.symbol
            case (false, true): return "𝐙\(Format.sub("\(divisor)"))"
            default           : return "\(R.symbol)/\(divisor)"
            }
        }
    }
}

public extension ModuleObject where R == 𝐙 {
    public var structure: [Int : Int] {
        return summands.group{ $0.divisor }.mapValues{ $0.count }
    }
    
    public var structureCode: String {
        return structure.sorted{ $0.key }.map { (d, r) in
            "\(r)\(d == 0 ? "" : Format.sub(d))"
            }.joined()
    }
    
    public func torsionPart<t: _Int>(order: t.Type) -> ModuleObject<A, IntegerQuotientRing<t>> {
        typealias Q = IntegerQuotientRing<t>
        typealias Summand = ModuleObject<A, Q>.Summand
        
        let n = t.intValue
        let sub = subSummands{ s in s.divisor == n }
        
        let summands = sub.summands.map { s -> Summand in
            Summand(s.generator.mapValues{ Q($0) }, .zero)
        }
        let transform = sub.transition.mapValues { Q($0) }
        
        return ModuleObject<A, Q>(summands, rootBasis, transform)
    }
    
    public var order2torsionPart: ModuleObject<A, 𝐙₂> {
        return torsionPart(order: _2.self)
    }
}

public extension ModuleObject where R == 𝐙₂ {
    public var asIntegerQuotients: ModuleObject<A, 𝐙> {
        typealias Summand = ModuleObject<A, 𝐙>.Summand
        let summands = self.summands.map { s -> Summand in
            Summand(s.generator.mapValues{ $0.representative }, 2)
        }
        let T = self.transition.mapValues{ a in a.representative }
        return ModuleObject<A, 𝐙>(summands, rootBasis, T)
    }
}

public extension ModuleObject where A == AbstractBasisElement, R: EuclideanRing {
    public init(rank r: Int, torsions: [R] = []) {
        let t = torsions.count
        let basis = (0 ..< r + t).map{ i in A(i) }
        let summands = (0 ..< r).map{ i in Summand(basis[i], .zero) }
            + torsions.enumerated().map{ (i, d) in Summand(basis[i + r], d) }
        let I = Matrix<R>.identity(size: r + t)
        self.init(summands, basis, I)
    }
}

public extension ModuleObject where R: EuclideanRing {
    public func asAbstract() -> ModuleObject<AbstractBasisElement, R> {
        typealias Summand = ModuleObject<AbstractBasisElement, R>.Summand
        
        let basis = self.rootBasis.enumerated().map{ (i, a) in
            AbstractBasisElement(i, label: a.description)
        }
        let summands = self.summands.map { s in
            Summand(s.generator.mapBasis { a in basis[self.rootBasis.index(of: a)!] }, s.divisor)
        }
        
        return ModuleObject<AbstractBasisElement, R>(summands, basis, transition)
    }
}

extension ModuleObject: Codable where A: Codable, R: Codable {
    enum CodingKeys: String, CodingKey {
        case summands, basis, transform // TODO rename
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let summands = try c.decode([Summand].self, forKey: .summands)
        let basis = try c.decode([A].self, forKey: .basis)
        let trans = try c.decode(Matrix<R>.self, forKey: .transform)
        self.init(summands, basis, trans)
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(summands, forKey: .summands)
        try c.encode(rootBasis, forKey: .basis)
        try c.encode(transition, forKey: .transform)
    }
}

extension ModuleObject.Summand: Codable where A: Codable, R: Codable {
    enum CodingKeys: String, CodingKey {
        case generator, divisor
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let g = try c.decode(FreeModule<A, R>.self, forKey: .generator)
        let d = try c.decode(R.self, forKey: .divisor)
        self.init(g, d)
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(generator, forKey: .generator)
        try c.encode(divisor, forKey: .divisor)
    }
}