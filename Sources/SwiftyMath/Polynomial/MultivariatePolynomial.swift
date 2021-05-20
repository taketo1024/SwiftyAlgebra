//
//  MultivariatePolynomial.swift
//  
//
//  Created by Taketo Sano on 2021/05/19.
//

public protocol MultivariatePolynomialIndeterminates {
    associatedtype NumberOfIndeterminates: SizeType
    static var isFinite: Bool { get }
    static var numberOfIndeterminates: Int { get }
    static func symbol(_ i: Int) -> String
    static func degree(_ i: Int) -> Int
}

extension MultivariatePolynomialIndeterminates {
    public static var isFinite: Bool {
        !NumberOfIndeterminates.isDynamic
    }
    
    public static var numberOfIndeterminates: Int {
        NumberOfIndeterminates.intValue
    }
    
    public static func degree(_ i: Int) -> Int {
        1
    }
    
    public static func totalDegree(exponents: MultiIndex<NumberOfIndeterminates>) -> Int {
        assert(!isFinite || exponents.length <= numberOfIndeterminates)
        return exponents.indices.enumerated().sum { (i, k) in
            k * degree(i)
        }
    }
}

public protocol MultivariatePolynomialType: PolynomialType where Indeterminate: MultivariatePolynomialIndeterminates, Exponent == MultiIndex<Indeterminate.NumberOfIndeterminates> {
    typealias NumberOfIndeterminates = Indeterminate.NumberOfIndeterminates
}

extension MultivariatePolynomialType {
    public static func indeterminate(_ i: Int) -> Self {
        let l = Indeterminate.isFinite ? Indeterminate.numberOfIndeterminates : i + 1
        let indices = (0 ..< l).map{ $0 == i ? 1 : 0 }
        let I = MultiIndex<NumberOfIndeterminates>(indices)
        return .init(coeffs: [I : .identity] )
    }
    
    public static var numberOfIndeterminates: Int {
        NumberOfIndeterminates.intValue
    }
    
    public static func monomial(withExponents I: Exponent) -> Self {
        .init(coeffs: [I: .identity])
    }
    
//    public static func monomials(ofTotalExponent e: Int) -> [Self] {
//        monomials(ofTotalExponent: e, usingIndeterminates: (0 ..< Indeterminates.numberOfIndeterminates).toArray())
//    }
//
//    public static func monomials(ofTotalExponent e: Int, usingIndeterminates indices: [Int]) -> [Self] {
//        Generator.monomials(ofTotalExponent: e, usingIndeterminates: indices).map { .init(elements: [$0: .identity] )}
//    }
    
//    typealias xn = Indeterminates
//    guard !indices.isEmpty else {
//        return (total == 0) ? [.identity] : []
//    }
//    
//    func generate(_ total: Int, _ i: Int) -> [[Int : Int]] {
//        if i == 0 {
//            return [[indices[i] : total]]
//        } else {
//            return (0 ... total).flatMap { e_i -> [[Int : Int]] in
//                generate(total - e_i, i - 1).map { exponents in
//                    exponents.merging([indices[i] : e_i])
//                }
//            }
//        }
//    }
//    
//    return generate(total, indices.count - 1).map { .init($0) }

    
    public func coeff(_ exponent: Int...) -> BaseRing {
        self.coeff(Exponent(exponent))
    }
    
    public func evaluate(by values: [BaseRing]) -> BaseRing {
        assert(!Indeterminate.isFinite || values.count <= Self.numberOfIndeterminates)
        return coeffs.sum { (I, a) in
            a * I.indices.enumerated().multiply{ (i, e) in values.count < i ? .zero : values[i].pow(e) }
        }
    }
    
    public func evaluate(by values: BaseRing...) -> BaseRing {
        evaluate(by: values)
    }
    
//    public static func elementarySymmetric(_ i: Int) -> Self {
//        assert(xn.isFinite)
//        assert(i >= 0)
//
//        let n = xn.numberOfIndeterminates
//        if i > n {
//            return .zero
//        }
//
//        let exponents = (0 ..< n).choose(i).map { combi -> [Int] in
//            // e.g.  [0, 1, 3] -> (1, 1, 0, 1)
//            let l = combi.last ?? 0
//            return (0 ... l).map { combi.contains($0) ? 1 : 0 }
//        }
//
//        let coeffs = Dictionary(pairs: exponents.map{ ($0, R.identity) } )
//        return .init(coeffs: coeffs)
//    }
    
    public var description: String {
        if coeffs.isEmpty {
            return "0"
        }
        
        let elements = coeffs.sorted{ $0.key.total }
            .map { (I, a) -> (String, BaseRing) in
                if I.isZero {
                    return (a.description, .identity)
                } else {
                    let m = I.indices.enumerated().map{ (i, d) in
                        (d > 0) ? Format.power(Indeterminate.symbol(i), d) : ""
                    }.joined()
                    return (m, a)
                }
            }
        
        return Format.linearCombination(elements)
    }
    
//    public static var symbol: String {
//        typealias xn = Indeterminates
//        if xn.isFinite {
//            let n = xn.numberOfIndeterminates
//            return "\(BaseRing.symbol)[\( (0 ..< n).map{ i in xn.symbol(i) }.joined(separator: ", "))]"
//        } else {
//            return "\(BaseRing.symbol)[\( (0 ..< 3).map{ i in xn.symbol(i) }.appended("…").joined(separator: ", "))]"
//        }
//    }
}

public struct MultivariatePolynomial<R: Ring, xn: MultivariatePolynomialIndeterminates>: MultivariatePolynomialType {
    public typealias BaseRing = R
    public typealias Indeterminate = xn
    public typealias Exponent = MultiIndex<xn.NumberOfIndeterminates>

    public let coeffs: [Exponent : R]
    public init(coeffs: [Exponent : R]) {
        self.coeffs = coeffs.exclude{ $0.value.isZero }
    }
    
    public var leadExponent: Exponent {
        coeffs.keys.max(by: { $0.total < $1.total }) ?? .zero
    }
    
    public var inverse: Self? {
        (isConst && constCoeff.isInvertible)
            ? .init(constCoeff.inverse!)
            : nil
    }
}

extension MultivariatePolynomial: ExpressibleByIntegerLiteral where R: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: R.IntegerLiteralType) {
        self.init(BaseRing(integerLiteral: value))
    }
}

//// MEMO: Waiting for parameterized extension.
//public func splitPolynomials<xn, A, R>(_ z: LinearCombination<A, MultivariatePolynomial<xn, R>>) -> LinearCombination<TensorGenerator<MultivariatePolynomialGenerator<xn>, A>, R> {
//    return z.elements.sum { (a, p) in
//        p.elements.sum { (m, r) in
//            LinearCombination(elements: [ m ⊗ a : r])
//        }
//    }
//}
//
//// MEMO: Waiting for parameterized extension.
//public func combineMonomials<xn, A, R>(_ z: LinearCombination<TensorGenerator<MultivariatePolynomialGenerator<xn>, A>, R>) -> LinearCombination<A, MultivariatePolynomial<xn, R>> {
//    return z.elements.sum { (x, r) in
//        let (m, a) = x.factors
//        let p = r * MultivariatePolynomial<xn, R>.wrap(m)
//        return LinearCombination(elements: [a : p])
//    }
//}