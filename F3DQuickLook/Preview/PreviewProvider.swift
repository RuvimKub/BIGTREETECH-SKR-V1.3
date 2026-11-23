import Cocoa
import Quartz
import UniformTypeIdentifiers

@objc(PreviewProvider)
class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let image = try F3DPreview.cgImage(at: request.fileURL)

        // Show the preview at up to 720 pt, keeping aspect ratio.
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let scale = 720 / max(w, h)
        let size = CGSize(width: (w * scale).rounded(), height: (h * scale).rounded())

        let reply = QLPreviewReply(contextSize: size, isBordered: false) { context, _ in
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(origin: .zero, size: size))
        }
        reply.title = request.fileURL.lastPathComponent
        return reply
    }
}
