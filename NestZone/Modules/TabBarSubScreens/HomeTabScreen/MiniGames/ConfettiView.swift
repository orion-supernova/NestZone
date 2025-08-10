import SwiftUI
import UIKit

struct ConfettiView: UIViewRepresentable {
    @Binding var isActive: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.layer.sublayers?.removeAll(where: { $0.name == "confettiLayer" })
        guard isActive else { return }
        
        let layer = CAEmitterLayer()
        layer.name = "confettiLayer"
        layer.emitterPosition = CGPoint(x: uiView.bounds.midX, y: -50)
        layer.emitterShape = .line
        layer.emitterSize = CGSize(width: uiView.bounds.width * 0.8, height: 2)
        layer.beginTime = CACurrentMediaTime()
        
        let colors: [UIColor] = [.systemPink, .systemPurple, .systemYellow, .systemGreen, .systemBlue, .systemOrange]
        var cells: [CAEmitterCell] = []
        for color in colors {
            let cell = CAEmitterCell()
            cell.birthRate = 4
            cell.lifetime = 3.0
            cell.velocity = 180
            cell.velocityRange = 60
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 6
            cell.spin = 2.0
            cell.spinRange = 0.5
            cell.scale = 0.4
            cell.scaleRange = 0.2
            cell.contents = rectangleImage(color: color).cgImage
            cells.append(cell)
        }
        layer.emitterCells = cells
        uiView.layer.addSublayer(layer)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if isActive {
                withAnimation(.easeOut(duration: 0.5)) {
                    isActive = false
                }
            }
        }
    }
    
    private func rectangleImage(color: UIColor, size: CGSize = CGSize(width: 8, height: 5)) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.setFillColor(color.cgColor)
        let rect = CGRect(origin: .zero, size: size)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 1.5)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }
}