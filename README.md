# HeatHazedImageView

Image view simulating refraction of light passing through heated air, i.e. heat haze or burning effect.

<img src="./example.gif" width="300">

### Usage

1. Create view programatically or via Interface Builder
```swift
let imageView: HeatHazedImageView!
```

2. Set animation parameters
```swift
imageView.speed = 200 // speed of rising air: min = 0, max = 1000
imageView.distortion = 500 // intensity of distortion effect: min = 0, max = 1000
imageView.isEvaporating = false // determines whether effect diminishes as the air rises to the top
```

3. Set source image
```swift
imageView.dataSource = .image(cgImage) // fixed image
imageView.dataSource = .image(uiImage) // fixed image and scale
imageView.dataSource = .layer(caLayer) // render layer (e.g. CAGradientLayer) using screen scale
imageView.dataSource = .view(uiView) // render view (e.g. UILabel) using screen scale
```

4. Start / stop the animation
```swift
imageView.isPaused = false // false by default
```

5. Refresh source image if needed
```swift
label.text = "1"
imageView.dataSource = .view(label)
...
label.text = "2"
imageView.dataSource?.setNeedsDisplay()
```
