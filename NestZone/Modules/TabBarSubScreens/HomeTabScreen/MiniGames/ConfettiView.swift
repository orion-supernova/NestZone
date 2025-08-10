import SwiftUI
import UIKit

struct ConfettiView: UIViewRepresentable {
    @Binding var isActive: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.layer.sublayers?.removeAll(where: { $0.name == "confettiLayer" })
        guard isActive else { return }
        
        let layer = CAEmitterLayer()
        layer.name = "confettiLayer"
        layer.emitterPosition = CGPoint(x: uiView.bounds.midX, y: -10)
        layer.emitterShape = .line
        layer.emitterSize = CGSize(width: uiView.bounds.width, height: 2)
        layer.beginTime = CACurrentMediaTime()
        
        let colors: [UIColor] = [.systemPink, .systemPurple, .systemYellow, .systemGreen, .systemBlue, .systemOrange]
        var cells: [CAEmitterCell] = []
        for color in colors {
            let cell = CAEmitterCell()
            cell.birthRate = 6
            cell.lifetime = 4.0
            cell.velocity = 220
            cell.velocityRange = 80
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 8
            cell.spin = 3.5
            cell.spinRange = 1.0
            cell.scale = 0.6
            cell.scaleRange = 0.3
            cell.contents = rectangleImage(color: color).cgImage
            cells.append(cell)
        }
        layer.emitterCells = cells
        uiView.layer.addSublayer(layer)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isActive = false
        }
    }
    
    private func rectangleImage(color: UIColor, size: CGSize = CGSize(width: 10, height: 6)) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.setFillColor(color.cgColor)
        let rect = CGRect(origin: .zero, size: size)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 2)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }
}