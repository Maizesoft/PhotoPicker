//
//  PKCameraPreview.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/8/25.
//

import UIKit
import AVFoundation

class PKCameraPreview: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    func setSession(_ session: AVCaptureSession) {
        if let oldLayer = previewLayer {
            oldLayer.removeFromSuperlayer()
        }
        let newLayer = AVCaptureVideoPreviewLayer(session: session)
        newLayer.videoGravity = .resizeAspect
        layer.addSublayer(newLayer)
        previewLayer = newLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    func flashShutterEffect() {
        let flashView = UIView(frame: bounds)
        flashView.backgroundColor = .black
        flashView.alpha = 0
        addSubview(flashView)
        bringSubviewToFront(flashView)

        UIView.animate(withDuration: 0.1, animations: {
            flashView.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.2, animations: {
                flashView.alpha = 0
            }) { _ in
                flashView.removeFromSuperview()
            }
        }
    }
}
