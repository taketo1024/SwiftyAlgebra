//
//  File.swift
//  
//
//  Created by Taketo Sano on 2021/05/18.
//

public struct MultiIndex<n: SizeType>: AdditiveGroup, ExpressibleByArrayLiteral, Comparable, Hashable {
    public typealias ArrayLiteralElement = Int
    
    public let indices: [Int]
    
    public init(_ indices: [Int]) {
        if n.isFixed {
            assert(indices.count == n.intValue)
            self.indices = indices
        } else {
            self.indices = indices.dropLast{ $0 == 0 }
        }
    }
    
    public init(_ indices: Int...) {
        self.init(indices)
    }
    
    public init(arrayLiteral elements: Int...) {
        self.init(elements)
    }
    
    public static var isFixed: Bool {
        n.isFixed
    }
    
    public static var length: Int {
        n.intValue
    }
    
    public var total: Int {
        indices.sum()
    }
    
    public subscript(_ i: Int) -> Int {
        if n.isFixed {
            return indices[i]
        } else {
            return indices.indices.contains(i) ? indices[i] : 0
        }
    }
    
    public static var zero: MultiIndex<n> {
        n.isFixed ? .init([0] * n.intValue) : .init([])
    }
    
    public static func ==(c1: Self, c2: Self) -> Bool {
        c1.indices == c2.indices
    }

    public static func +(c1: Self, c2: Self) -> Self {
        if n.isFixed {
            return .init( c1.indices.merging(c2.indices, mergedBy: +) )
        } else {
            return .init( c1.indices.merging(c2.indices, filledWith: 0, mergedBy: +) )
        }
    }
    
    public static prefix func -(_ c: Self) -> Self {
        .init( c.indices.map{ -$0 } )
    }

    public static func < (c1: Self, c2: Self) -> Bool {
        (c1 != c2) && (c2 - c1).indices.allSatisfy{ $0 >= 0 }
    }
    
    public var description: String {
        "(\( indices.map{ $0.description }.joined(separator: ", ") ))"
    }
}

extension MultiIndex where n == _2 {
    public init(_ indices: (Int, Int)) {
        self.init([indices.0, indices.1])
    }
    
    public var tuple: (Int, Int) {
        (self[0], self[1])
    }
}

extension MultiIndex where n == _3 {
    public init(_ indices: (Int, Int, Int)) {
        self.init([indices.0, indices.1, indices.2])
    }
    
    public var triple: (Int, Int, Int) {
        (self[0], self[1], self[2])
    }
}
