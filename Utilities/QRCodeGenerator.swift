import SwiftUI
import CoreImage.CIFilterBuiltins

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
    /// - Returns: A UIImage containing the QR code, or nil if generation failed
    func generateQRCode(
        from string: String,
        color: UIColor = .black,
        backgroundColor: UIColor = .white,
        size: CGFloat = 200
    ) -> UIImage? {
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
        
        if color != .black || backgroundColor != .white {
            coloredImage = applyColor(to: scaledImage, color: color, backgroundColor: backgroundColor)
        } else {
            coloredImage = scaledImage
        }
        
        // Create the final CGImage
        guard let cgImage = context.createCGImage(coloredImage, from: coloredImage.extent) else {
            return nil
        }
        
        // Convert to UIImage
        return UIImage(cgImage: cgImage)
    }
    
    /// Apply color to a QR code image
    /// - Parameters:
    ///   - image: The black and white QR code image
    ///   - color: The color to apply
    ///   - backgroundColor: The background color
    /// - Returns: A colored QR code image
    private func applyColor(to image: CIImage, color: UIColor, backgroundColor: UIColor) -> CIImage {
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
    ) -> Image {
        // Convert SwiftUI colors to UIColors
        let uiColor = UIColor(color)
        let uiBackgroundColor = UIColor(backgroundColor)
        
        if let uiImage = QRCodeGenerator.shared.generateQRCode(
            from: string,
            color: uiColor,
            backgroundColor: uiBackgroundColor,
            size: size
        ) {
            return Image(uiImage: uiImage)
                .interpolation(.none)
        } else {
            // Return a placeholder if QR code generation fails
            return Image(systemName: "qrcode")
                .resizable()
                .frame(width: size, height: size)
        }
    }
} 