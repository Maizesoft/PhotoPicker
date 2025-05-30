//
//  PKCameraPreview.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/8/25.
//

import AVFoundation
import UIKit
import OSLog

class PKCameraPreview: UIView {
    var previewLayer = AVCaptureVideoPreviewLayer()
    var onDoubleTap: (() -> Void)?

    func setSession(_ session: AVCaptureSession) {
        let logger = Logger(subsystem: "PKCameraPreview", category: "Camera")
        logger.log(level: .debug, "Setting camera preview session")
        previewLayer.session = session
        logger.log(level: .debug, "all done")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
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

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        tap.require(toFail: doubleTap)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(previewLayer)
        setupGestureRecognizers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.addSublayer(previewLayer)
        setupGestureRecognizers()
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let session = previewLayer.session,
              let deviceInput = session.inputs
              .compactMap({ $0 as? AVCaptureDeviceInput })
              .first(where: { $0.device.hasMediaType(.video) }) else { return }
        let device = deviceInput.device
        do {
            try device.lockForConfiguration()
            var zoomFactor = device.videoZoomFactor * gesture.scale
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = device.maxAvailableVideoZoomFactor
            zoomFactor = min(max(zoomFactor, minZoom), maxZoom)
            device.videoZoomFactor = zoomFactor
            device.unlockForConfiguration()
        } catch {
            print("Error locking configuration: \(error)")
        }
        gesture.scale = 1.0
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let session = previewLayer.session,
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

    @objc private func handleDoubleTap(_: UITapGestureRecognizer) {
        onDoubleTap?()
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
