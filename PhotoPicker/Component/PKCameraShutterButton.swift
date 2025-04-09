//
//  PKCameraShutterButton.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/8/25.
//

import UIKit

class PKCameraShutterButton: UIControl {
    var softHaptics: UIImpactFeedbackGenerator?
    var rigidHaptics: UIImpactFeedbackGenerator?
    let innerCircle = UIView()
    var onTap: (() -> Void)?
    private var activityIndicator: UIActivityIndicatorView?

    init(mode: PKCameraOptions.PKCameraMode) {
        super.init(frame: .zero)
        let outerCircle = UIView()
        outerCircle.translatesAutoresizingMaskIntoConstraints = false
        outerCircle.backgroundColor = .white
        outerCircle.layer.cornerRadius = 32
        addSubview(outerCircle)

        let gapCircle = UIView()
        gapCircle.translatesAutoresizingMaskIntoConstraints = false
        gapCircle.backgroundColor = .black
        gapCircle.layer.cornerRadius = 30
        addSubview(gapCircle)

        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        innerCircle.backgroundColor = mode == .photo ? .white : .systemRed
        innerCircle.layer.cornerRadius = 28
        addSubview(innerCircle)
        
        outerCircle.isUserInteractionEnabled = false
        gapCircle.isUserInteractionEnabled = false
        innerCircle.isUserInteractionEnabled = false

        NSLayoutConstraint.activate([
            outerCircle.centerXAnchor.constraint(equalTo: centerXAnchor),
            outerCircle.centerYAnchor.constraint(equalTo: centerYAnchor),
            outerCircle.widthAnchor.constraint(equalToConstant: 64),
            outerCircle.heightAnchor.constraint(equalToConstant: 64),

            gapCircle.centerXAnchor.constraint(equalTo: centerXAnchor),
            gapCircle.centerYAnchor.constraint(equalTo: centerYAnchor),
            gapCircle.widthAnchor.constraint(equalToConstant: 60),
            gapCircle.heightAnchor.constraint(equalToConstant: 60),

            innerCircle.centerXAnchor.constraint(equalTo: centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 56),
            innerCircle.heightAnchor.constraint(equalToConstant: 56)
        ])

        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        isUserInteractionEnabled = true
        
        softHaptics = UIImpactFeedbackGenerator(style: .soft, view: self)
        rigidHaptics = UIImpactFeedbackGenerator(style: .rigid, view: self)
        softHaptics?.prepare()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func touchDown() {
        softHaptics?.impactOccurred(intensity: 0.7)
        UIView.animate(withDuration: 0.1) {
            self.innerCircle.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
    }

    @objc private func touchUp() {
        rigidHaptics?.impactOccurred(intensity: 0.9)
        UIView.animate(withDuration: 0.1) {
            self.innerCircle.transform = .identity
        }
        onTap?()
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
                    indicator.centerYAnchor.constraint(equalTo: innerCircle.centerYAnchor)
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
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 64, height: 64)
    }
}
