//
//  ImageDataSource.swift
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

public protocol ImageDataSource {
    var cgImage: CGImage { get }
    var needsDisplay: Bool { get }
    func setNeedsDisplay()
}

public class SingleImageDataSource: ImageDataSource {
    
    public let cgImage: CGImage
    public let needsDisplay: Bool = false
    
    public init(_ cgImage: CGImage) {
        self.cgImage = cgImage
    }
    
    public init?(_ image: UIImage?) {
        guard let cgImage = image?.cgImage else { return nil }
        self.cgImage = cgImage
    }
    
    public func setNeedsDisplay() {
        // do nothing
    }
}

@available(iOS 10.0, *)
public class CALayerImageDataSource: ImageDataSource {
    
    private let layer: CALayer
    private var size: CGSize
    private var _needsDisplay = false
    
    public init(_ layer: CALayer) {
        self.layer = layer
        size = layer.bounds.size
    }
    
    public var needsDisplay: Bool {
        _needsDisplay || layer.bounds.size != size
    }
    
    public func setNeedsDisplay() {
        DispatchQueue.main.async { [weak self] in
            self?._needsDisplay = true
        }
    }
    
    public var cgImage: CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let image = UIGraphicsImageRenderer(bounds: layer.bounds, format: format).image { ctx in
            layer.render(in: ctx.cgContext)
        }.cgImage!
        _needsDisplay = false
        size = layer.bounds.size
        return image
    }
}

@available(iOS 10.0, *)
public class UIViewImageDataSource: CALayerImageDataSource {
    
    private let view: UIView
    
    public init(_ view: UIView) {
        self.view = view
        super.init(view.layer)
    }
}
