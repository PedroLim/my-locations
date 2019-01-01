//
//  Functions.swift
//  MyLocations
//
//  Created by Pedro Henrique Pereira Lima on 01/01/19.
//  Copyright © 2019 IBM. All rights reserved.
//

import Foundation

func afterDelay(_ seconds: Double, run: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: run)
}
