//
//  HeatHazedImageViewAssets.swift
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

import UIKit

/// Generates image in RGB colorspace with three distinct Perlin noise maps stored in separate color components.
/// - Parameters:
///   - gridSize: Size of the gradient grid for Perlin noise generator.
///   - samplesPerNode: Number of samples / pixels for each gradient node.
/// - returns: Generated image with size equal to `gridSize * samplesPerNode`.
func GeneratePerlinNoiseImage(gridSize: CGSize, samplesPerNode: Int) -> UIImage {
    let gridWidth = Int(ceil(gridSize.width))
    let gridHeight = Int(ceil(gridSize.height))
    let imageWidth = gridWidth * samplesPerNode
    let imageHeight = gridHeight * samplesPerNode
    
    let noise1 = PerlinNoise2D(width: gridWidth, height: gridHeight)
    let noise2 = PerlinNoise2D(width: gridWidth, height: gridHeight)
    let noise3 = PerlinNoise2D(width: gridWidth, height: gridHeight)
    
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
                UIColor(red: r, green: g, blue: b, alpha: 1).setFill()
                ctx.fill(CGRect(x: col, y: row, width: 1, height: 1))
            }
        }
    }
}

let HeatHazeShaders = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    packed_float2 position;
    packed_float2 texCoord;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float time;
    float speed;
    float distortion;
    float evaporation;
};

vertex VertexOut vertex_shader(const device VertexIn* vertex_array [[ buffer(0) ]],
                               unsigned int vid                    [[ vertex_id ]]) {

    VertexIn in = vertex_array[vid];
    VertexOut out;
    out.position = float4(in.position, 0, 1);
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 fragment_shader(VertexOut in                [[ stage_in ]],
                                constant Uniforms& uniforms [[ buffer(0) ]],
                                texture2d<float> sourceTex  [[ texture(0) ]],
                                texture2d<float> noiseTex   [[ texture(1) ]],
                                sampler sourceSampler       [[ sampler(0) ]],
                                sampler noiseSampler        [[ sampler(1) ]]) {
    
    float2 offsetCoord = in.texCoord;
    offsetCoord.y += uniforms.time * uniforms.speed;
    float2 offset = noiseTex.sample(noiseSampler, offsetCoord).xy;
    offset -= float2(0.5, 0.5);
    offset *= 2.0;
    offset *= uniforms.distortion;
    if (uniforms.evaporation > 0) {
        offset *= clamp(1.0 - ((1.0 - in.texCoord.y) * uniforms.evaporation), 0.0, 1.0);
    }
    return sourceTex.sample(sourceSampler, in.texCoord + offset);
}
"""
