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

/// Provides images to be used as textures for `HeatHazedImageView`.
public struct ImageDataSource {
    
    private let _render: () -> CGImage
    private let _needsDisplay: () -> Bool
    private let _setNeedsDisplay: () -> ()
    
    public init(_ _render: @escaping () -> CGImage, _ _needsDisplay: @escaping () -> Bool, _ _setNeedsDisplay: @escaping () -> ()) {
        self._render = _render
        self._needsDisplay = _needsDisplay
        self._setNeedsDisplay = _setNeedsDisplay
    }
    
    /// Renders current image and clears `needsDisplay` flag.
    public func render() -> CGImage { _render() }
    
    /// Determines whether `HeatHazedImageView` should use new image returned by `render()` method.
    public var needsDisplay: Bool { _needsDisplay() }
    
    /// Sets `needsDisplay` flag to `true`.
    /// `HeatHazedImageView` will automatically update displayed image in its next draw cycle by calling `render()`.
    public func setNeedsDisplay() { _setNeedsDisplay() }
}

public extension ImageDataSource {
    
    /// Creates `ImageDataSource` holding specified fixed image.
    /// - Parameters:
    ///   - cgImage: Source image.
    static func image(_ cgImage: CGImage) -> Self {
        ImageDataSource({ cgImage }, { false }, {})
    }
    
    /// Creates `ImageDataSource` holding specified fixed image.
    /// If given `UIImage` does not wrap a `CGImage`, it is rendered immediately.
    /// - Parameters:
    ///   - uiImage: Source image.
    static func image(_ uiImage: UIImage) -> Self {
        if let cgImage = uiImage.cgImage {
            return image(cgImage)
        } else {
            let format = UIGraphicsImageRendererFormat()
            format.scale = uiImage.scale
            let bounds = CGRect(origin: .zero, size: uiImage.size)
            let cgImage = UIGraphicsImageRenderer(bounds: bounds, format: format).image { ctx in
                uiImage.draw(in: bounds)
            }.cgImage!
            return image(cgImage)
        }
    }
}

public extension ImageDataSource {
    
    /// Creates `ImageDataSource` rendering specified `CALayer`.
    /// Owner should refresh the image by calling `setNeedsDisplay()` when contents of the layer have changed.
    /// - Parameters:
    ///   - layer: Source layer.
    static func layer(_ layer: CALayer) -> Self {
        var size = layer.bounds.size
        var needsDisplay = false
        return ImageDataSource({
            let format = UIGraphicsImageRendererFormat()
            format.scale = UIScreen.main.scale
            let bounds = layer.bounds
            let image = UIGraphicsImageRenderer(bounds: bounds, format: format).image { ctx in
                layer.render(in: ctx.cgContext)
            }.cgImage!
            size = bounds.size
            needsDisplay = false
            return image
        }, { needsDisplay || layer.bounds.size != size }, { needsDisplay = true })
    }
    
    /// Creates `ImageDataSource` rendering main `layer` of specified `UIView`.
    /// Owner should refresh the image by calling `setNeedsDisplay()` when contents of the view have changed.
    /// - Parameters:
    ///   - view: Source view.
    static func view(_ view: UIView) -> Self {
        layer(view.layer)
    }
}
