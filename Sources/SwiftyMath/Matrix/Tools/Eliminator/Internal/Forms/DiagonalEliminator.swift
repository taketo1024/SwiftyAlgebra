//
//  DiagonalEliminator.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2017/11/08.
//  Copyright © 2017年 Taketo Sano. All rights reserved.
//

internal final class DiagonalEliminator<R: EuclideanRing>: MatrixEliminator<R> {
    override func isDone() -> Bool {
        worker.entries.allSatisfy { (i, j, a) in
            (i == j) && a.isNormalized
        }
    }
    
    override func iteration() {
        subrun(RowEchelonEliminator(worker: worker, debug: debug))
        
        if isDone() {
            return
        }
        
        subrun(ColEchelonEliminator(worker: worker, debug: debug))
    }
}