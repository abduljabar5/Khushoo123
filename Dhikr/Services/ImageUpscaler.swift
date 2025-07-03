import Foundation
import Kingfisher
import CoreImage
import UIKit

struct ImageUpscaler: ImageProcessor {
    let identifier = "com.dhikr.imageupscaler"
    
    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        // First, ensure we have a valid image to work with, whether from raw data or an existing image.
        let imageToProcess: KFCrossPlatformImage?
        switch item {
        case .image(let image):
            imageToProcess = image
        case .data(let data):
            imageToProcess = KFCrossPlatformImage(data: data)
        }
        
        guard let image = imageToProcess else {
            return nil // Cannot process if we can't create an image.
        }
        
        // Now, attempt to upscale the image.
        guard let ciImage = CIImage(image: image) else { return image }
        
        let filter = CIFilter(name: "CISuperResolution")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        
        let context = CIContext()
        if let outputImage = filter?.outputImage,
           let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        
        // If upscaling fails for any reason, return the original image.
        return image
    }
} 