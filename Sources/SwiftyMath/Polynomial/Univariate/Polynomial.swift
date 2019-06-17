import Foundation

public protocol PolynomialType {
    static var isNormal: Bool { get }
}

public struct NormalPolynomialType : PolynomialType {
    public static let isNormal = true
}

public struct LaurentPolynomialType: PolynomialType {
    public static let isNormal = false
}

public typealias  Polynomial<x: PolynomialIndeterminate, R: Ring> = _Polynomial<NormalPolynomialType, x, R>
public typealias xPolynomial<R: Ring> = Polynomial<_x, R>
public typealias yPolynomial<R: Ring> = Polynomial<_y, R>
public typealias zPolynomial<R: Ring> = Polynomial<_z, R>
public typealias tPolynomial<R: Ring> = Polynomial<_t, R>

public typealias LaurentPolynomial<x: PolynomialIndeterminate, R: Ring> = _Polynomial<LaurentPolynomialType, x, R>

public struct _Polynomial<T: PolynomialType, x: PolynomialIndeterminate, R: Ring>: Ring, Module {
    public typealias CoeffRing = R
    
    internal let coeffs: [Int : R]
    
    public init(from n: 𝐙) {
        let a = R(from: n)
        self.init(a)
    }
    
    public init(_ a: R) {
        self.init(coeffs: [0 : a])
    }
    
    public init(coeffs: [Int : R]) {
        assert( !(T.isNormal && coeffs.contains{ (i, a) in i < 0 && a != .zero } ) )
        self.coeffs = coeffs.filter{ (_, a) in a != .zero }
    }
    
    public init(coeffs: [R], shift: Int = 0) {
        let dict = Dictionary(pairs: coeffs.enumerated().map{ (i, a) in (i + shift, a) })
        self.init(coeffs: dict)
    }
    
    public init(coeffs: R...) {
        self.init(coeffs: coeffs)
    }
    
    public static var indeterminate: _Polynomial<T, x, R> {
        return _Polynomial(coeffs: .zero, .identity)
    }
    
    public var lowestPower: Int {
        return coeffs.keys.min() ?? 0
    }
    
    public var highestPower: Int {
        return coeffs.keys.max() ?? 0
    }
    
    public var degree: Int {
        return x.degree * highestPower
    }
    
    public func coeff(_ i: Int) -> R {
        return coeffs[i, default: .zero]
    }
    
    public var leadCoeff: R {
        return coeff(highestPower)
    }
    
    public var leadTerm: _Polynomial<T, x, R> {
        return _Polynomial(coeffs: [highestPower: leadCoeff])
    }
    
    public var isMonic: Bool {
        return leadCoeff == .identity
    }
    
    public var isConst: Bool {
        return (highestPower, lowestPower) == (0, 0)
    }
    
    public var constTerm: R {
        return coeff(0)
    }
    
    public func mapCoeffs<S: Ring>(_ f: ((R) -> S)) -> _Polynomial<T, x, S> {
        return _Polynomial<T, x, S>(coeffs: coeffs.mapValues(f))
    }
    
    public func changeIndeterminate<y: PolynomialIndeterminate>(to: y.Type) -> _Polynomial<T, y, R> {
        return _Polynomial<T, y, R>(coeffs: coeffs)
    }
    
    public var normalizeUnit: _Polynomial<T, x, R> {
        if let a = leadCoeff.inverse {
            return _Polynomial(coeffs: a)
        } else {
            return _Polynomial(coeffs: .identity)
        }
    }
    
    public var inverse: _Polynomial<T, x, R>? {
        if T.isNormal, highestPower == 0, let a = constTerm.inverse {
            return _Polynomial(coeffs: a)
        } else if !T.isNormal, lowestPower == highestPower, let a = leadCoeff.inverse {
            return _Polynomial(coeffs: [-highestPower : a])
        }
        return nil
    }
    
    public var derivative: _Polynomial<T, x, R> {
        return _Polynomial(coeffs: coeffs.mapPairs { (i, a) -> (Int, R) in
            (i - 1, R(from: i) * a)
        })
    }
    
    // Horner's method
    // see: https://en.wikipedia.org/wiki/Horner%27s_method
    public func evaluate(at a: R) -> R {
        let A = a.pow(lowestPower)
        let B = (lowestPower ..< highestPower).reversed().reduce(leadCoeff) { (res, i) in
            coeff(i) + a * res
        }
        return A * B
    }

    public func evaluate<n>(at a: SquareMatrix<n, R>) -> SquareMatrix<n, R> {
        typealias M = SquareMatrix<n, R>
        let A = a.pow(lowestPower)
        let B = (lowestPower ..< highestPower).reversed().reduce(leadCoeff * M.identity) { (res, i) -> M in
            M(scalar: coeff(i)) + a * res
        }
        return A * B
    }
    
    public static func + (f: _Polynomial<T, x, R>, g: _Polynomial<T, x, R>) -> _Polynomial<T, x, R> {
        let degs = Set(f.coeffs.keys).union(g.coeffs.keys)
        let coeffs = Dictionary(keys: degs) { i in
            f.coeff(i) + g.coeff(i)
        }
        return _Polynomial(coeffs: coeffs)
    }
    
    public static prefix func - (f: _Polynomial<T, x, R>) -> _Polynomial<T, x, R> {
        return f.mapCoeffs { -$0 }
    }
    
    public static func * (f: _Polynomial<T, x, R>, g: _Polynomial<T, x, R>) -> _Polynomial<T, x, R> {
        let kRange = (f.lowestPower + g.lowestPower ... f.highestPower + g.highestPower)
        let coeffs = kRange.map { k -> (Int, R) in
            let iRange = max(f.lowestPower, k - g.highestPower) ... min(k - g.lowestPower, f.highestPower)
            let a = iRange.sum { i -> R in
                f.coeff(i) * g.coeff(k - i)
            }
            return (k, a)
        }
        return _Polynomial(coeffs: Dictionary(pairs: coeffs))
    }
    
    public static func * (r: R, f: _Polynomial<T, x, R>) -> _Polynomial<T, x, R> {
        return f.mapCoeffs { r * $0 }
    }
    
    public static func * (f: _Polynomial<T, x, R>, r: R) -> _Polynomial<T, x, R> {
        return f.mapCoeffs { $0 * r }
    }
    
    public var description: String {
        return Format.terms("+", coeffs.keys.sorted().map{ i in (coeff(i), x.symbol, i)} )
    }
    
    public static var symbol: String {
        let s = x.symbol
        return T.isNormal ? "\(R.symbol)[\(s)]" : "\(R.symbol)[\(s), \(s)⁻¹]"
    }
}

public extension _Polynomial where R: Field {
    func toMonic() -> _Polynomial<T, x, R> {
        let a = leadCoeff
        return self.mapCoeffs{ $0 / a }
    }
}

extension _Polynomial: EuclideanRing where R: Field {
    public var eucDegree: Int {
        return T.isNormal ? highestPower : highestPower - lowestPower
    }
    
    public func eucDiv(by g: _Polynomial<T, x, R>) -> (q: _Polynomial<T, x, R>, r: _Polynomial<T, x, R>) {
        guard g != .zero else {
            fatalError("divide by 0")
        }
        
        typealias P = _Polynomial<T, x, R>
        let x = P.indeterminate
        let f = self
        
        func eucDivMonomial(_ f: P, _ g: P) -> (q: P, r: P) {
            if f.eucDegree < g.eucDegree {
                return (.zero, f)
            } else {
                let a = f.leadCoeff / g.leadCoeff
                let n = T.isNormal ? f.eucDegree - g.eucDegree : (f.eucDegree - g.eucDegree) + (f.lowestPower - g.lowestPower)
                let q = a * x.pow(n)
                let r = f - q * g
                return (q, r)
            }
        }
        
        return (0 ... max(0, f.eucDegree - g.eucDegree))
            .reversed()
            .reduce( (.zero, f) ) { (result: (P, P), degree: Int) in
                let (q, r) = result
                let m = eucDivMonomial(r, g)
                return (q + m.q, m.r)
        }
    }
}

extension _Polynomial where R: RealSubset {
    public var asReal: _Polynomial<T, x, 𝐑> {
        return mapCoeffs{ $0.asReal }
    }
}

extension _Polynomial where R: ComplexSubset {
    public var asComplex: _Polynomial<T, x, 𝐂> {
        return mapCoeffs{ $0.asComplex }
    }
}