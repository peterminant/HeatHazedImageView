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

/// Image view simulating refraction of light passing through heated air, i.e. burning effect.
/// Images provided by `dataSource` are scaled to fit the size of this view.
/// If Metal is not supported on current device, this view displays the image without animation as a fallback behavior.
@IBDesignable
public class HeatHazedImageView: UIView {
    
    private static let library = HeatHazeShaders
    private static let noiseImage = GeneratePerlinNoiseImage(gridSize: CGSize(width: 12, height: 12), samplesPerNode: 8)
    
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
    private var startTime: Date = .distantFuture
    
    /// `true` if Metal is supported on current device, otherwise `false`.
    public var isSupported: Bool {
        metalView != nil
    }
    
    /// Provides an image to be used as a texture for heat haze effect.
    /// The image is scaled to fit this view.
    public var dataSource: ImageDataSource? {
        didSet {
            if let cgImage = dataSource?.render() {
                if metalView != nil {
                    sourceTexture = loadTexture(image: cgImage, mipmap: true)
                } else {
                    imageView?.image = UIImage(cgImage: cgImage)
                }
            } else {
                sourceTexture = nil
                imageView?.image = nil
            }
            setNeedsDisplay()
        }
    }
    
    /// Determines whether animation is paused, `false` by default.
    @IBInspectable
    public var isPaused: Bool = false {
        didSet {
            metalView?.isPaused = isPaused
            metalView?.enableSetNeedsDisplay = isPaused
        }
    }
    
    /// Controls the speed of rising air: minimum = 0, maximum = 1000, default = 200.
    @IBInspectable
    public var speed: CGFloat = 200 {
        didSet { setNeedsDisplay() }
    }
    
    /// Controls the intensity of distortion effect: minimum = 0, maximum = 1000, default = 500.
    @IBInspectable
    public var distortion: CGFloat = 500 {
        didSet { setNeedsDisplay() }
    }
    
    /// Determines whether distortion effect diminishes as the air rises to the top of the view.
    @IBInspectable
    public var isEvaporating: Bool = false {
        didSet { setNeedsDisplay() }
    }
    
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
            let library = try? device.makeLibrary(source: Self.library, options: nil) else {
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
        
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout.size(ofValue: vertices[0]), options: []) else {
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
        metalView.isPaused = self.isPaused
        metalView.enableSetNeedsDisplay = self.isPaused
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.delegate = self
        self.metalView = metalView
        
        return true
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
    
    public override func setNeedsDisplay() {
        super.setNeedsDisplay()
        metalView?.setNeedsDisplay()
        imageView?.setNeedsDisplay()
    }
}

extension HeatHazedImageView: MTKViewDelegate {
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // nothing to do
    }
    
    public func draw(in view: MTKView) {
        guard
            let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
        }
        
        if let dataSource = self.dataSource {
            let time = Float(Date().timeIntervalSince(startTime))
            let speed = Float(1.0 * min(max(self.speed, 0), 1000) / 1000)
            let distortion = Float(0.1 * min(max(self.distortion, 0), 1000) / 1000)
            let evaporate: Float = isEvaporating ? 1 : 0
            let uniforms = [time, speed, distortion, evaporate]
            
            if dataSource.needsDisplay {
                sourceTexture = loadTexture(image: dataSource.render(), mipmap: true)
            }
            
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(uniforms, length: uniforms.count * MemoryLayout.size(ofValue: uniforms[0]), index: 0)
            renderEncoder.setFragmentTexture(sourceTexture, index: 0)
            renderEncoder.setFragmentTexture(noiseTexture, index: 1)
            renderEncoder.setFragmentSamplerState(sourceSampler, index: 0)
            renderEncoder.setFragmentSamplerState(noiseSampler, index: 1)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
