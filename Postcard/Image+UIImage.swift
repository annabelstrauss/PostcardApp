import SwiftUI

extension View {
    func asUIImage() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        return renderer.uiImage
    }
}

extension Image {
    func asUIImage() -> UIImage? {
        self
            .resizable()
            .scaledToFit()
            .asUIImage()
    }
} 