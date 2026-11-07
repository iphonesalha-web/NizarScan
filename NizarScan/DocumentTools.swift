import UIKit
import Vision
import PDFKit
import CoreImage

struct DocumentTools {
    static func recognizeText(in images: [UIImage], completion: @escaping (String) -> Void) {
        let group = DispatchGroup(); let lock = NSLock(); var chunks: [(Int, String)] = []
        for (index, image) in images.enumerated() {
            guard let cg = image.cgImage else { continue }; group.enter()
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation] ?? []).compactMap { $0.topCandidates(1).first?.string }
                lock.lock(); chunks.append((index, lines.joined(separator: "\n"))); lock.unlock(); group.leave()
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["ar", "de-DE", "en-US"]
            DispatchQueue.global(qos: .userInitiated).async {
                do { try VNImageRequestHandler(cgImage: cg).perform([request]) } catch { group.leave() }
            }
        }
        group.notify(queue: .main) { completion(chunks.sorted { $0.0 < $1.0 }.map(\.1).joined(separator: "\n\n--- Page ---\n\n")) }
    }

    static func makePDF(images: [UIImage], title: String) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { ctx in
            for image in images {
                ctx.beginPage(); let inset: CGFloat = 24
                let target = page.insetBy(dx: inset, dy: inset)
                let ratio = min(target.width / image.size.width, target.height / image.size.height)
                let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                image.draw(in: CGRect(x: (page.width-size.width)/2, y: (page.height-size.height)/2, width: size.width, height: size.height))
            }
        }
    }

    static func enhanced(_ image: UIImage, monochrome: Bool) -> UIImage {
        guard let ci = CIImage(image: image) else { return image }
        let filter = monochrome ? CIFilter(name: "CIPhotoEffectNoir") : CIFilter(name: "CIColorControls")
        filter?.setValue(ci, forKey: kCIInputImageKey)
        if !monochrome { filter?.setValue(0, forKey: kCIInputSaturationKey); filter?.setValue(1.25, forKey: kCIInputContrastKey) }
        guard let output = filter?.outputImage, let cg = CIContext().createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: cg)
    }
}
