//
//  PKCameraViewController.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/7/25.
//
import UIKit
import AVFoundation
import Photos

struct PKCameraOptions {
    enum PKCameraMode {
        case photo
        case video
    }
    let mode: PKCameraMode
    let position: AVCaptureDevice.Position
    let showPreview: Bool
    
    init(mode: PKCameraMode, position: AVCaptureDevice.Position = .back, showPreview: Bool = true) {
        self.mode = mode
        self.position = position
        self.showPreview = showPreview
    }
}

protocol PKCameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ cameraVC: PKCameraViewController, didFinishWith items: [PKPhotoPickerItem])
}

class PKCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate, PKPreviewDelegate {
    let options: PKCameraOptions
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "PKCameraViewController session queue")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let preview = PKCameraPreview()
    private var shutterButton: PKCameraShutterButton?
    private var recordingTimeLabel: UILabel?
    private var recordingTimer: Timer?
    private var permissionLabel: UILabel?
    weak var delegate: PKCameraViewControllerDelegate?
    
    var isRecording = false
    
    init(options: PKCameraOptions) {
        self.options = options
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let closeImage = UIImage(systemName: "xmark")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 17, weight: .regular))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: closeImage, style: .plain, target: self, action: #selector(closeTapped))
        self.navigationItem.hidesBackButton = true
        
        checkPermissionAndSetup()
        setupViews()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func checkPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { self.setupCamera() }
            }
        default:
            DispatchQueue.main.async {
                self.permissionLabel?.isHidden = false
            }
            break
        }
    }
    
    var isVideoMode: Bool {
        return options.mode == .video
    }
    var isPhotoMode: Bool {
        return options.mode == .photo
    }
    
    func setupViews() {
        let bottomBar = UIView()
        bottomBar.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 150)
        ])
        
        preview.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(preview, at: 0)
        NSLayoutConstraint.activate([
            preview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        if isVideoMode {
            NSLayoutConstraint.activate([
                preview.topAnchor.constraint(equalTo: view.topAnchor),
                preview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                preview.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                preview.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            ])
        }
        
        let buttonContainer = UIView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(buttonContainer)
        NSLayoutConstraint.activate([
            buttonContainer.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            buttonContainer.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            buttonContainer.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            buttonContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        let shutterButton = PKCameraShutterButton(mode: options.mode)
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.innerCircle.backgroundColor = isVideoMode ? .systemRed : .white
        shutterButton.onTap = {
            if self.isPhotoMode {
                self.capturePhoto()
            } else {
                self.toggleRecording()
            }
        }
        buttonContainer.addSubview(shutterButton)
        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: buttonContainer.centerXAnchor),
            shutterButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor)
        ])
        self.shutterButton = shutterButton

        let flipButton = UIButton(type: .system)
        flipButton.translatesAutoresizingMaskIntoConstraints = false
        let flipImage = UIImage(systemName: "arrow.trianglehead.2.clockwise.rotate.90.camera.fill")
        flipButton.setImage(flipImage, for: .normal)
        flipButton.tintColor = .white
        flipButton.addTarget(self, action: #selector(switchCameraTapped), for: .touchUpInside)
        buttonContainer.addSubview(flipButton)
        NSLayoutConstraint.activate([
            flipButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            flipButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -20)
        ])

        let timeLabel = UILabel()
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.textColor = .white
        timeLabel.backgroundColor = .systemRed
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        timeLabel.textAlignment = .center
        timeLabel.layer.cornerRadius = 4
        timeLabel.layer.masksToBounds = true
        timeLabel.isHidden = true
        view.addSubview(timeLabel)
        NSLayoutConstraint.activate([
            timeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timeLabel.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -12),
            timeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            timeLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
        recordingTimeLabel = timeLabel
        
        let label = UILabel()
        label.text = "No permission to camera"
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        permissionLabel = label
    }

    @objc private func switchCameraTapped() {
        DispatchQueue.global().async {
            self.switchCamera()
        }
    }

    private func findBestCameraDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )
        return discoverySession.devices.first
    }

    func setupCamera() {
        guard let device = findBestCameraDevice(for: options.position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(photoOutput),
              session.canAddOutput(movieOutput) else { return }

        session.beginConfiguration()
        session.sessionPreset = isPhotoMode ? .photo : .high
        session.addInput(input)
        if isVideoMode {
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let micInput = try? AVCaptureDeviceInput(device: audioDevice),
               session.canAddInput(micInput) {
                session.addInput(micInput)
            }
        }
        session.addOutput(photoOutput)
        session.addOutput(movieOutput)
        session.commitConfiguration()
        preview.setSession(session)
        
        setInitialZoom(for: device)
        
        sessionQueue.async {
            self.session.startRunning()
        }
    }
    
    func switchCamera() {
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }

        let newPosition: AVCaptureDevice.Position = (currentInput.device.position == .back) ? .front : .back
        guard let newDevice = findBestCameraDevice(for: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }

        session.beginConfiguration()
        session.removeInput(currentInput)
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            setInitialZoom(for: newDevice)
        }
        session.commitConfiguration()
    }

    private func setInitialZoom(for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = device.maxAvailableVideoZoomFactor
            let zoomForWideLens: CGFloat
            
            if let first = switchOvers.first {
                zoomForWideLens = CGFloat(truncating: first)
            } else {
                zoomForWideLens = 1.0
            }

            let clamped = min(max(zoomForWideLens, minZoom), maxZoom)
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        } catch {
            print("Error setting initial zoom: \(error)")
        }
    }

    func capturePhoto() {
        shutterButton?.setLoading(true)
        preview.flashShutterEffect()
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func toggleRecording() {
        if isRecording {
            shutterButton?.setLoading(true)
            recordingTimer?.invalidate()
            recordingTimeLabel?.isHidden = true
            movieOutput.stopRecording()
            isRecording = false
        } else {
            if let movieConnection = movieOutput.connection(with: .video) {
                if movieConnection.isVideoMirroringSupported {
                    movieConnection.isVideoMirrored = previewIsMirrored
                }
            }
            let outputURL = PKPhotoPicker.tempFileURL(UUID().uuidString, withExtension: "mp4")
            movieOutput.startRecording(to: outputURL, recordingDelegate: self)
            recordingTimeLabel?.text = "00:00:00"
            recordingTimeLabel?.isHidden = false
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                let totalSeconds = Int(self.movieOutput.recordedDuration.seconds)
                let hours = totalSeconds / 3600
                let minutes = (totalSeconds % 3600) / 60
                let seconds = totalSeconds % 60
                self.recordingTimeLabel?.text = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            }
            isRecording = true
        }
        shutterButton?.setRecording(isRecording)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.global().async {
            guard let cgImage = photo.cgImageRepresentation() else { return }
            let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: self.previewIsMirrored ? .leftMirrored : .right)
            DispatchQueue.main.async {
                self.shutterButton?.setLoading(false)
                if self.options.showPreview {
                    let preview = PKPreviewViewController(items: [.image(image)])
                    preview.delegate = self
                    preview.showRetakeConfirmButton = true
                    self.present(preview, animated: true)
                } else {
                    self.delegate?.cameraViewController(self, didFinishWith: [.image(image)])
                }
            }
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        recordingTimer?.invalidate()
        guard error == nil else { return }
        Task {
            let asset = AVURLAsset(url: outputFileURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0, preferredTimescale: 600)
            do {
                let (thumbnail, _) = try await imageGenerator.image(at: time)
                shutterButton?.setLoading(false)
                let item = PKPhotoPickerItem.video(outputFileURL, UIImage(cgImage: thumbnail))
                if options.showPreview {
                    let preview = PKPreviewViewController(items: [item])
                    preview.delegate = self
                    preview.showRetakeConfirmButton = true
                    self.present(preview, animated: true)
                } else {
                    delegate?.cameraViewController(self,  didFinishWith: [item])
                }
            } catch {
                shutterButton?.setLoading(false)
            }
        }
    }
    
    private var previewIsMirrored: Bool {
        if let previewLayer = self.preview.previewLayer,
           let connection = previewLayer.connection,
           connection.isVideoMirrored {
            return true
        }
        return false
    }

    @objc func closeTapped() {
        if let nav = self.navigationController {
            nav.popViewController(animated: true)
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func previewDidConfirm(_ preview: PKPreviewViewController) {
        preview.dismiss(animated: false)
        self.delegate?.cameraViewController(self, didFinishWith: preview.items)
    }
    
    func previewDidRetake(_ preview: PKPreviewViewController) {
        preview.dismiss(animated: true)
    }
}
