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
    private weak var session: AVCaptureSession?
    
    func setSession(_ session: AVCaptureSession) {
        if let oldLayer = previewLayer {
            oldLayer.removeFromSuperlayer()
        }
        let newLayer = AVCaptureVideoPreviewLayer(session: session)
        newLayer.videoGravity = .resizeAspect
        layer.addSublayer(newLayer)
        previewLayer = newLayer
        self.session = session
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
    
    // MARK: - Gesture Recognizers

    private func setupGestureRecognizers() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestureRecognizers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestureRecognizers()
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let session = session,
              let deviceInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        let device = deviceInput.device
        do {
            try device.lockForConfiguration()
            var zoomFactor = device.videoZoomFactor * gesture.scale
            zoomFactor = max(1.0, min(zoomFactor, device.activeFormat.videoMaxZoomFactor))
            device.videoZoomFactor = zoomFactor
            device.unlockForConfiguration()
        } catch {
            print("Error locking configuration: \(error)")
        }
        gesture.scale = 1.0
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let previewLayer = previewLayer,
              let session = session,
              let deviceInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        let device = deviceInput.device
        let point = gesture.location(in: self)
        let focusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)

        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {
            print("Error setting focus: \(error)")
        }
        
        showFocusIndicator(at: point)
    }

    private func showFocusIndicator(at point: CGPoint) {
        let indicatorSize: CGFloat = 80
        let indicator = UIView(frame: CGRect(x: point.x - indicatorSize / 2, y: point.y - indicatorSize / 2, width: indicatorSize, height: indicatorSize))
        indicator.layer.borderColor = UIColor.yellow.cgColor
        indicator.layer.borderWidth = 1
        indicator.alpha = 0
        addSubview(indicator)

        UIView.animate(withDuration: 0.15, animations: {
            indicator.alpha = 1
            indicator.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0.5, options: [], animations: {
                indicator.alpha = 0
                indicator.transform = .identity
            }) { _ in
                indicator.removeFromSuperview()
            }
        }
    }
}
