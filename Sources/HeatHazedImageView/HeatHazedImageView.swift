//
//  HeatHazedImageView.swift
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

import MetalKit

@available(iOS 10.0, *)
public class HeatHazedImageView: UIView, MTKViewDelegate {
    
    // MARK: Fields
    
    private static let noiseImage = createNoiseImage(nodes: 12, samplesPerNode: 8)
    
    private var metalView: MTKView?
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer!
    private var noiseSampler: MTLSamplerState!
    private var sourceSampler: MTLSamplerState!
    private var noiseTexture: MTLTexture!
    private var sourceTexture: MTLTexture!
    private var imageView: UIImageView?
    private var startTime: Date = .distantPast
    
    public var isAvailable: Bool {
        metalView != nil
    }
    
    public var intensity: Double = 0.5
    public var evaporates: Bool = false
    
    public var dataSource: ImageDataSource? {
        didSet {
            if let cgImage = dataSource?.cgImage {
                if metalView != nil {
                    sourceTexture = loadTexture(image: cgImage, mipmap: true)
                } else {
                    imageView?.image = UIImage(cgImage: cgImage)
                }
            } else {
                sourceTexture = nil
                imageView?.image = nil
            }
        }
    }
    
    // MARK: Initializers
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        if !setupMetalView() {
            device = nil
            commandQueue = nil
            setupImageView()
        }
        if let subView: UIView = metalView ?? imageView {
            subView.frame = bounds
            subView.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
            subView.translatesAutoresizingMaskIntoConstraints = true
            subView.isOpaque = false
            subView.backgroundColor = .clear
            addSubview(subView)
        }
        startTime = Date()
    }
    
    private func setupMetalView() -> Bool {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue(),
            let library = try? device.makeLibrary(source: shaders, options: nil) else {
            return false
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = library.makeFunction(name: "vertex_shader")
        pipelineStateDescriptor.fragmentFunction = library.makeFunction(name: "fragment_shader")
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineStateDescriptor) else {
            return false
        }
        
        let vertices: [Float] = [
            -1,  1,  0,  0,
            -1, -1,  0,  1,
             1, -1,  1,  1,
             1, -1,  1,  1,
             1,  1,  1,  0,
            -1,  1,  0,  0
        ]
        
        guard let vertexBuffer = createBuffer(vertices) else {
            return false
        }
        
        guard
            let noiseSampler = createSampler(mode: .repeat),
            let sourceSampler = createSampler(mode: .clampToEdge) else {
            return false
        }
        
        guard
            let noiseImage = Self.noiseImage.cgImage,
            let noiseTexture = loadTexture(image: noiseImage, mipmap: true) else {
            return false
        }
        
        self.pipelineState = pipelineState
        self.vertexBuffer = vertexBuffer
        self.noiseSampler = noiseSampler
        self.sourceSampler = sourceSampler
        self.noiseTexture = noiseTexture
        
        let metalView = MTKView()
        metalView.device = device
        metalView.autoResizeDrawable = true
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = false
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.delegate = self
        self.metalView = metalView
        
        return true
    }
    
    private func createBuffer(_ values: [Float]) -> MTLBuffer? {
        return device.makeBuffer(bytes: values, length: values.count * MemoryLayout.size(ofValue: values[0]), options: [])
    }
    
    private func createSampler(mode: MTLSamplerAddressMode) -> MTLSamplerState? {
        let sampler = MTLSamplerDescriptor()
        sampler.minFilter             = .linear
        sampler.magFilter             = .linear
        sampler.mipFilter             = .linear
        sampler.maxAnisotropy         = 1
        sampler.sAddressMode          = mode
        sampler.tAddressMode          = mode
        sampler.rAddressMode          = mode
        sampler.normalizedCoordinates = true
        sampler.lodMinClamp           = 0
        sampler.lodMaxClamp           = .greatestFiniteMagnitude
        return device.makeSamplerState(descriptor: sampler)
    }
    
    private func loadTexture(image: CGImage, mipmap: Bool = false) -> MTLTexture? {
        let width = image.width
        let height = image.height
        let texDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: mipmap)
        
        guard let texture = device.makeTexture(descriptor: texDescriptor) else {
            return nil
        }
        
        let bytesPerPixel = 4
        let bitsPerComponent = 8
        let bytesPerRow = width * bytesPerPixel
        
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.clear(bounds)
        context.draw(image, in: bounds)
        
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: context.data!, bytesPerRow: bytesPerRow)
        
        if mipmap,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder() {
                blitCommandEncoder.generateMipmaps(for: texture)
                blitCommandEncoder.endEncoding()
                commandBuffer.commit()
        }
        
        return texture
    }
    
    private func setupImageView() {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        self.imageView = imageView
    }
    
    // MARK: MTKViewDelegate
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // nothing to do
    }
    
    public func draw(in view: MTKView) {
        let time = Float(Date().timeIntervalSince(startTime))
        let speed: Float = 0.2
        let distortion = Float(0.1 * min(max(intensity, 0), 1))
        let evaporate: Float = evaporates ? 1 : 0
        
        guard
            let dataSource = self.dataSource,
            let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor),
            let uniforms = createBuffer([time, speed, distortion, evaporate]) else {
                return
        }
        
        if dataSource.needsDisplay {
            sourceTexture = loadTexture(image: dataSource.cgImage, mipmap: true)
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(uniforms, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(sourceTexture, index: 0)
        renderEncoder.setFragmentTexture(noiseTexture, index: 1)
        renderEncoder.setFragmentSamplerState(sourceSampler, index: 0)
        renderEncoder.setFragmentSamplerState(noiseSampler, index: 1)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { _ in  }
        commandBuffer.commit()
    }
}

@available(iOS 10.0, *)
fileprivate func createNoiseImage(nodes: Int, samplesPerNode: Int) -> UIImage {
    let xNoise = PerlinNoise2D(width: nodes, height: nodes)
    let yNoise = PerlinNoise2D(width: nodes, height: nodes)
    let zNoise = PerlinNoise2D(width: nodes, height: nodes)
    let imageLength = nodes * samplesPerNode
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(bounds: CGRect(x: 0, y: 0, width: imageLength, height: imageLength), format: format).image { ctx in
        for col in 0 ..< imageLength {
            for row in 0 ..< imageLength {
                let x = Double(col) / Double(samplesPerNode)
                let y = Double(row) / Double(samplesPerNode)
                let r = CGFloat(xNoise[x, y] / 2 + 0.5)
                let g = CGFloat(yNoise[x, y] / 2 + 0.5)
                let b = CGFloat(zNoise[x, y] / 2 + 0.5)
                UIColor(red: r, green: g, blue: b, alpha: 1).setFill()
                ctx.fill(CGRect(x: col, y: row, width: 1, height: 1))
            }
        }
    }
}

fileprivate let shaders = """
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
    float evaporate;
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
    if (uniforms.evaporate != 0) {
        offset *= in.texCoord.y;
    }
    return sourceTex.sample(sourceSampler, in.texCoord + offset);
}
"""
