import Cocoa
import QuickLookThumbnailing

@objc(ThumbnailProvider)
class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest,
                                   _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let image: CGImage
        do { image = try F3DPreview.cgImage(at: request.fileURL) } catch {
            handler(nil, error)
            return
        }

        // Fit the image into the requested box, keeping aspect ratio.
        let maxSize = request.maximumSize
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let scale = min(maxSize.width / w, maxSize.height / h)
        let size = CGSize(width: (w * scale).rounded(), height: (h * scale).rounded())

        handler(QLThumbnailReply(contextSize: size, currentContextDrawing: {
            NSGraphicsContext.current?.imageInterpolation = .high
            NSImage(cgImage: image, size: size).draw(in: CGRect(origin: .zero, size: size))
            return true
        }), nil)
    }
}
