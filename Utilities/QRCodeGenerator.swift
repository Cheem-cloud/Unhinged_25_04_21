import SwiftUI
import CoreImage.CIFilterBuiltins

#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
#endif

/// Utility class for generating QR codes
class QRCodeGenerator {
    /// The shared instance of the QR code generator
    static let shared = QRCodeGenerator()
    
    /// The Core Image context used for rendering
    private let context = CIContext()
    
    /// The filter used to generate QR codes
    private let filter = CIFilter.qrCodeGenerator()
    
    /// Private initializer for singleton pattern
    private init() {}
    
    /// Generate a QR code image from a string
    /// - Parameters:
    ///   - from: The string to encode in the QR code
    ///   - color: The color of the QR code (default: black)
    ///   - backgroundColor: The background color of the QR code (default: white)
    ///   - size: The size of the QR code (default: 200)
    /// - Returns: A PlatformImage containing the QR code, or nil if generation failed
    func generateQRCode(
        from string: String,
        color: PlatformColor = PlatformColor.black,
        backgroundColor: PlatformColor = PlatformColor.white,
        size: CGFloat = 200
    ) -> PlatformImage? {
        // Set the message to encode
        let data = string.data(using: .utf8)
        filter.setValue(data, forKey: "inputMessage")

        // Set the correction level (M: Medium - up to 15% damage recovery)
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        // Get the output image
        guard let outputImage = filter.outputImage else {
            return nil
        }
        
        // Scale the image
        let scale = size / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        // Apply color filter if needed
        let coloredImage: CIImage
        
        if color != PlatformColor.black || backgroundColor != PlatformColor.white {
            coloredImage = applyColor(to: scaledImage, color: color, backgroundColor: backgroundColor)
        } else {
            coloredImage = scaledImage
        }
        
        // Create the final CGImage
        guard let cgImage = context.createCGImage(coloredImage, from: coloredImage.extent) else {
            return nil
        }
        
        // Convert to platform-specific image type
        #if canImport(UIKit)
        return UIImage(cgImage: cgImage)
        #elseif canImport(AppKit)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
        return nsImage
        #endif
    }
    
    /// Apply color to a QR code image
    /// - Parameters:
    ///   - image: The black and white QR code image
    ///   - color: The color to apply
    ///   - backgroundColor: The background color
    /// - Returns: A colored QR code image
    private func applyColor(to image: CIImage, color: PlatformColor, backgroundColor: PlatformColor) -> CIImage {
        // Convert the colors to CIColor
        let ciColor = CIColor(color: color)
        let ciBackgroundColor = CIColor(color: backgroundColor)
        
        // Create a false color filter
        let colorFilter = CIFilter.falseColor()
        colorFilter.setValue(image, forKey: kCIInputImageKey)
        colorFilter.setValue(ciColor, forKey: "inputColor1")
        colorFilter.setValue(ciBackgroundColor, forKey: "inputColor0")
        
        // Return the colored image
        return colorFilter.outputImage ?? image
    }
}

/// SwiftUI extension for generating QR code as an Image
extension Image {
    /// Initialize an Image with a QR code
    /// - Parameters:
    ///   - string: The string to encode in the QR code
    ///   - color: The color of the QR code
    ///   - backgroundColor: The background color of the QR code
    ///   - size: The size of the QR code
    /// - Returns: An Image containing the QR code
    static func qrCode(
        for string: String,
        color: Color = .black,
        backgroundColor: Color = .white,
        size: CGFloat = 200
    ) -> AnyView {
        // Convert SwiftUI colors to platform colors
        #if canImport(UIKit)
        let platformColor = UIColor(color)
        let platformBackgroundColor = UIColor(backgroundColor)
        #elseif canImport(AppKit)
        let platformColor = NSColor(color)
        let platformBackgroundColor = NSColor(backgroundColor)
        #endif
        
        if let platformImage = QRCodeGenerator.shared.generateQRCode(
            from: string,
            color: platformColor,
            backgroundColor: platformBackgroundColor,
            size: size
        ) {
            #if canImport(UIKit)
            return AnyView(Image(uiImage: platformImage)
                .interpolation(.none))
            #elseif canImport(AppKit)
            return AnyView(Image(nsImage: platformImage)
                .interpolation(.none))
            #endif
        } else {
            // Return a placeholder if QR code generation fails
            return AnyView(Image(systemName: "qrcode")
                .resizable()
                .frame(width: size, height: size))
        }
    }
} 