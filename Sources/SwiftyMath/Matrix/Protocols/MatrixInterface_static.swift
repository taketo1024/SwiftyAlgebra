//
//  MatrixIntf_static.swift
//  
//
//  Created by Taketo Sano on 2021/05/11.
//

extension MatrixInterface: AdditiveGroup, Module, ExpressibleByArrayLiteral where n: StaticSizeType, m: StaticSizeType {
    public typealias ArrayLiteralElement = BaseRing
    
    public static var size: (rows: Int, cols: Int) {
        (n.intValue, m.intValue)
    }
    
    public init(initializer: @escaping (Initializer) -> Void) {
        self.init(Impl.init(size: Self.size, initializer: initializer))
    }
    
    public init<S: Sequence>(grid: S) where S.Element == BaseRing {
        self.init(Impl.init(size: Self.size, grid: grid))
    }
    
    public init(arrayLiteral elements: ArrayLiteralElement...) {
        self.init(grid: elements)
    }

    public static var zero: Self {
        self.init(Impl.zero(size: Self.size))
    }
    
    public static func unit(_ i: Int, _ j: Int) -> Self {
        self.init(Impl.unit(size: Self.size, at: (i, j)))
    }
}

extension MatrixInterface: Multiplicative, Monoid, Ring where n == m, n: StaticSizeType {
    public init(from a : 𝐙) {
        self.init(Impl.scalar(size: Self.size, value: BaseRing.init(from: a)))
    }
    
    public static func identity(_ a: BaseRing) -> Self {
        self.init(Impl.identity(size: Self.size))
    }

    public static func scalar(_ a: BaseRing) -> Self {
        self.init(Impl.scalar(size: Self.size, value: a))
    }

    public var isInvertible: Bool {
        impl.isInvertible
    }
    
    public var inverse: Self? {
        impl.inverse.flatMap{ .init($0) }
    }
    
    public var determinant: BaseRing {
        impl.determinant
    }

    public var trace: BaseRing {
        impl.trace
    }
}

extension MatrixInterface where n == m, n == _1 {
    public var asScalar: BaseRing {
        self[0, 0]
    }
}
