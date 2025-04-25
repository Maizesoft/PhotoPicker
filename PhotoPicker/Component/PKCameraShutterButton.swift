//
//  PKCameraShutterButton.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/8/25.
//

import AVFAudio
import UIKit

class PKCameraShutterButton: UIControl {
    var softHaptics: UIImpactFeedbackGenerator?
    var rigidHaptics: UIImpactFeedbackGenerator?
    let outerCircle = CAShapeLayer()
    let innerCircle = CAShapeLayer()
    var onTap: ((_ longPress: Bool) -> Void)?
    private var activityIndicator: UIActivityIndicatorView?
    private var longPressTimer: Timer?

    init(mode: PKCameraOptions.PKCameraMode) {
        super.init(frame: .zero)
        
        layer.addSublayer(outerCircle)
        layer.addSublayer(innerCircle)

        outerCircle.bounds = CGRect(x: 0, y: 0, width: 64, height: 64)
        outerCircle.position = CGPoint(x: 32, y: 32)
        outerCircle.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 64, height: 64)).cgPath
        // Rotate the progress ring so it starts at the top (12 o'clock)
        outerCircle.setAffineTransform(CGAffineTransform(rotationAngle: -.pi / 2))
        outerCircle.fillColor = UIColor.clear.cgColor
        outerCircle.strokeColor = UIColor.white.cgColor
        outerCircle.lineWidth = 2
        outerCircle.lineCap = .round

        innerCircle.bounds = CGRect(x: 0, y: 0, width: 56, height: 56)
        innerCircle.position = CGPoint(x: 32, y: 32)
        innerCircle.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 56, height: 56)).cgPath
        innerCircle.fillColor = (mode == .video ? UIColor.systemRed.cgColor : UIColor.white.cgColor)

        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        isUserInteractionEnabled = true

        softHaptics = UIImpactFeedbackGenerator(style: .soft, view: self)
        rigidHaptics = UIImpactFeedbackGenerator(style: .rigid, view: self)
        softHaptics?.prepare()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func touchDown() {
        softHaptics?.impactOccurred(intensity: 0.7)
        UIView.animate(withDuration: 0.1) {
            self.innerCircle.setAffineTransform(CGAffineTransform(scaleX: 0.9, y: 0.9))
        }
        if let longPressTimer {
            longPressTimer.invalidate()
        }
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { _ in
            self.longPressTimer = nil
            self.rigidHaptics?.impactOccurred(intensity: 0.9)
            self.onTap?(true)
        })
    }

    @objc private func touchUp() {
        rigidHaptics?.impactOccurred(intensity: 0.9)
        UIView.animate(withDuration: 0.1) {
            self.innerCircle.setAffineTransform(.identity)
        }
        if let longPressTimer {
            longPressTimer.invalidate()
            self.longPressTimer = nil
            onTap?(false)
        } else {
            onTap?(true)
        }
    }

    func setLoading(_ loading: Bool) {
        innerCircle.isHidden = loading
        if loading {
            if activityIndicator == nil {
                let indicator = UIActivityIndicatorView(style: .large)
                indicator.overrideUserInterfaceStyle = .dark
                indicator.translatesAutoresizingMaskIntoConstraints = false
                indicator.startAnimating()
                addSubview(indicator)
                NSLayoutConstraint.activate([
                    indicator.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                    indicator.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                ])
                activityIndicator = indicator
            }
        } else {
            activityIndicator?.removeFromSuperview()
            activityIndicator = nil
        }
    }

    func setRecording(_ recording: Bool) {
        let cornerRadius: CGFloat = recording ? 8 : 28
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
            let newPath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 56, height: 56), cornerRadius: cornerRadius)
            self.innerCircle.path = newPath.cgPath
            self.innerCircle.fillColor = recording ? UIColor.systemRed.cgColor : UIColor.white.cgColor
            
            let innerscale: CGFloat = recording ? 0.6 : 1.0
            self.innerCircle.setAffineTransform(CGAffineTransform(scaleX: innerscale, y: innerscale))
            let outerscale: CGFloat = recording ? 1.5 : 1.0
            let scaleTransform = CGAffineTransform(scaleX: outerscale, y: outerscale)
            let rotationTransform = CGAffineTransform(rotationAngle: -.pi / 2)
            self.outerCircle.setAffineTransform(scaleTransform.concatenating(rotationTransform))
            self.outerCircle.fillColor = recording ? UIColor.white.withAlphaComponent(0.5).cgColor : UIColor.clear.cgColor
            self.outerCircle.strokeColor = recording ? UIColor.systemRed.cgColor : UIColor.white.cgColor
            self.outerCircle.lineWidth = recording ? 5 : 2
        }, completion: nil)
        self.outerCircle.strokeEnd = recording ? 0 : 1
        if recording {
            try? AVAudioSession.sharedInstance().setAllowHapticsAndSystemSoundsDuringRecording(true)
        }
    }

    func setProgress(_ progress: CGFloat) {
        let clampedProgress = max(0, min(progress, 1))
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        outerCircle.strokeStart = 0
        outerCircle.strokeEnd = clampedProgress
        CATransaction.commit()
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: 64, height: 64)
    }
}
