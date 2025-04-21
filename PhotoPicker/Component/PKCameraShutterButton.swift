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
    let innerCircle = UIView()
    var onTap: ((_ longPress: Bool) -> Void)?
    private var activityIndicator: UIActivityIndicatorView?
    private var longPressTimer: Timer?

    init(mode: PKCameraOptions.PKCameraMode) {
        super.init(frame: .zero)
        let outerCircle = UIView()
        outerCircle.translatesAutoresizingMaskIntoConstraints = false
        outerCircle.backgroundColor = .clear
        outerCircle.layer.cornerRadius = 32
        outerCircle.layer.borderColor = UIColor.white.cgColor
        outerCircle.layer.borderWidth = 2
        addSubview(outerCircle)

        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        innerCircle.backgroundColor = (mode == .video ? .systemRed : .white)
        innerCircle.layer.cornerRadius = 28
        addSubview(innerCircle)

        outerCircle.isUserInteractionEnabled = false
        innerCircle.isUserInteractionEnabled = false

        NSLayoutConstraint.activate([
            outerCircle.centerXAnchor.constraint(equalTo: centerXAnchor),
            outerCircle.centerYAnchor.constraint(equalTo: centerYAnchor),
            outerCircle.widthAnchor.constraint(equalToConstant: 64),
            outerCircle.heightAnchor.constraint(equalToConstant: 64),

            innerCircle.centerXAnchor.constraint(equalTo: centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 56),
            innerCircle.heightAnchor.constraint(equalToConstant: 56),
        ])

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
            self.innerCircle.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
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
            self.innerCircle.transform = .identity
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
        if loading {
            innerCircle.isHidden = true
            if activityIndicator == nil {
                let indicator = UIActivityIndicatorView(style: .large)
                indicator.overrideUserInterfaceStyle = .dark
                indicator.translatesAutoresizingMaskIntoConstraints = false
                indicator.startAnimating()
                addSubview(indicator)
                NSLayoutConstraint.activate([
                    indicator.centerXAnchor.constraint(equalTo: innerCircle.centerXAnchor),
                    indicator.centerYAnchor.constraint(equalTo: innerCircle.centerYAnchor),
                ])
                activityIndicator = indicator
            }
        } else {
            innerCircle.isHidden = false
            activityIndicator?.removeFromSuperview()
            activityIndicator = nil
        }
    }

    func setRecording(_ recording: Bool) {
        let cornerRadius: CGFloat = recording ? 8 : 28
        let scale: CGFloat = recording ? 0.6 : 1.0
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
            self.innerCircle.layer.cornerRadius = cornerRadius
            self.innerCircle.transform = CGAffineTransform(scaleX: scale, y: scale)
        }, completion: nil)
        innerCircle.backgroundColor = recording ? .systemRed : .white
        if recording {
            try? AVAudioSession.sharedInstance().setAllowHapticsAndSystemSoundsDuringRecording(true)
        }
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: 64, height: 64)
    }
}
