//
//  PerlinNoise2D.swift
//
//  MIT License
//
//  Copyright (c) 2020 Peter Ertl
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

public struct PerlinNoise2D {
    
    public let width: Int
    public let height: Int
    
    private var gradient: [[[Double]]]
    
    public init(width: Int, height: Int) {
        self.width = max(width, 1)
        self.height = max(height, 1)
        self.gradient = Array(repeating: Array(repeating: [0.0, 0.0], count: width), count: height)
        let angleRange = 0.0 ..< (Double.pi * 2)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let angle = Double.random(in: angleRange)
                gradient[y][x][0] = cos(angle)
                gradient[y][x][1] = sin(angle)
            }
        }
    }
    
    public subscript(x: Double, y: Double) -> Double {
        let x0 = intIndex(x, width), x1 = x0 + 1
        let y0 = intIndex(y, height), y1 = y0 + 1
        let dot00 = dotProduct(x0, y0, x, y)
        let dot01 = dotProduct(x0, y1, x, y)
        let dot10 = dotProduct(x1, y0, x, y)
        let dot11 = dotProduct(x1, y1, x, y)
        return interpolate(
            interpolate(dot00, dot10, x - Double(x0)),
            interpolate(dot01, dot11, x - Double(x0)),
            y - Double(y0)
        )
    }
    
    private func intIndex(_ dblIndex: Double, _ length: Int) -> Int {
        var i = Int(floor(dblIndex))
        if i < 0 {
            i += (-i / length + 1) * length
        }
        return i
    }
    
    private func dotProduct(_ ix: Int, _ iy: Int, _ x: Double, _ y: Double) -> Double {
        let dx = x - Double(ix)
        let dy = y - Double(iy)
        let gx = ix % width
        let gy = iy % height
        return dx * gradient[gy][gx][0] + dy * gradient[gy][gx][1]
    }
    
    private func interpolate(_ a: Double, _ b: Double, _ w: Double) -> Double {
        let f = w * w * (3 - 2 * w)
        return a + (b - a) * f
    }
}
