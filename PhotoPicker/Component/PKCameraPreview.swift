//
//  PKCameraPreview.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/8/25.
//

import UIKit
import AVFoundation

class PKCameraPreview: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer!

    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspect
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
