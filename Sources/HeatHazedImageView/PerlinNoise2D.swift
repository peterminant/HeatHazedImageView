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

/// Cyclical two-dimensional Perlin noise generator.
/// Values can be accessed by subscripting the generator with x and y coordinates.
/// Noise structure is repeating itself around the edges of the gradient grid.
public struct PerlinNoise2D {
    
    /// Width of the gradient table.
    public let width: Int
    
    /// Height of the gradient table.
    public let height: Int
    
    private var gradient: [[[Double]]]
    
    /// Creates cyclical two-dimensional Perlin noise generator with specified dimensions.
    /// - Parameters:
    ///   - width: Width of the gradient table.
    ///   - height: Height of the gradient table.
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
        let x0 = Int(floor(x)), x1 = x0 + 1
        let y0 = Int(floor(y)), y1 = y0 + 1
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
    
    private func dotProduct(_ ix: Int, _ iy: Int, _ x: Double, _ y: Double) -> Double {
        let dx = x - Double(ix)
        let dy = y - Double(iy)
        let gx = wrap(ix, width)
        let gy = wrap(iy, height)
        return dx * gradient[gy][gx][0] + dy * gradient[gy][gx][1]
    }
    
    private func wrap(_ index: Int, _ length: Int) -> Int {
        var i = index
        if i < 0 {
            i += (-i / length + 1) * length
        }
        return i % length
    }
    
    private func interpolate(_ a: Double, _ b: Double, _ w: Double) -> Double {
        let f = w * w * (3 - 2 * w)
        return a + (b - a) * f
    }
}

#if canImport(UIKit)
import UIKit

/// Generates image in RGB colorspace with three distinct Perlin noise maps stored in separate color components.
/// - Parameters:
///   - gridSize: Size of the gradient grid for Perlin noise generator.
///   - samplesPerNode: Number of samples / pixels for each gradient node.
/// - returns: Generated image with size equal to `gridSize * samplesPerNode`.
public func GeneratePerlinNoiseImage(gridSize: CGSize, samplesPerNode: Int) -> UIImage {
    let gridWidth = Int(ceil(gridSize.width))
    let gridHeight = Int(ceil(gridSize.height))
    let imageWidth = gridWidth * samplesPerNode
    let imageHeight = gridHeight * samplesPerNode
    
    let noise1 = PerlinNoise2D(width: gridWidth, height: gridHeight)
    let noise2 = PerlinNoise2D(width: gridWidth, height: gridHeight)
    let noise3 = PerlinNoise2D(width: gridWidth, height: gridHeight)
    let noise4 = PerlinNoise2D(width: gridWidth, height: gridHeight)
    
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let bounds = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
    
    return UIGraphicsImageRenderer(bounds: bounds, format: format).image { ctx in
        UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1).setFill()
        ctx.fill(bounds)
        for col in 0 ..< imageWidth {
            for row in 0 ..< imageHeight {
                let x = Double(col) / Double(samplesPerNode)
                let y = Double(row) / Double(samplesPerNode)
                let r = CGFloat(noise1[x, y] / 2 + 0.5)
                let g = CGFloat(noise2[x, y] / 2 + 0.5)
                let b = CGFloat(noise3[x, y] / 2 + 0.5)
                let a = CGFloat(noise4[x, y] / 2 + 0.5)
                UIColor(red: r, green: g, blue: b, alpha: a).setFill()
                ctx.fill(CGRect(x: col, y: row, width: 1, height: 1))
            }
        }
    }
}
#endif
