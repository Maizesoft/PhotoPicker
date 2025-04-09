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
}

protocol PKCameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ cameraVC: PKCameraViewController, didFinishWith photo: UIImage)
    func cameraViewController(_ cameraVC: PKCameraViewController, didFinishWith videoURL: URL)
}

class PKCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    private let options: PKCameraOptions
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let preview = PKCameraPreview()
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
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.session.stopRunning()
    }

    func checkPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { DispatchQueue.main.async { self.setupCamera() } }
            }
        default:
            break
        }
    }
    
    func setupViews() {
        let bottomBar = UIView()
        bottomBar.backgroundColor = UIColor.systemGray5.withAlphaComponent(0.7)
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
            preview.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            preview.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            preview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
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
        shutterButton.onTap = {
            self.capturePhoto()
        }
        buttonContainer.addSubview(shutterButton)
        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: buttonContainer.centerXAnchor),
            shutterButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor)
        ])

        let flipButton = UIButton(type: .system)
        flipButton.translatesAutoresizingMaskIntoConstraints = false
        let flipImage = UIImage(systemName: "arrow.trianglehead.2.clockwise.rotate.90.camera.fill")
        flipButton.setImage(flipImage, for: .normal)
        flipButton.addTarget(self, action: #selector(switchCameraTapped), for: .touchUpInside)
        buttonContainer.addSubview(flipButton)
        NSLayoutConstraint.activate([
            flipButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            flipButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -20)
        ])
    }

    @objc private func switchCameraTapped() {
        DispatchQueue.global().async {
            self.switchCamera()
        }
    }

    func setupCamera() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(photoOutput),
              session.canAddOutput(movieOutput) else { return }

        session.beginConfiguration()
        session.sessionPreset = options.mode == .photo ? .photo : .high
        session.addInput(input)
        session.addOutput(photoOutput)
        session.addOutput(movieOutput)
        session.commitConfiguration()
        preview.setSession(session)
        
        DispatchQueue.global().async {
            self.session.startRunning()
        }
    }
    
    func switchCamera() {
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }

        let newPosition: AVCaptureDevice.Position = (currentInput.device.position == .back) ? .front : .back
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }

        session.beginConfiguration()
        session.removeInput(currentInput)
        if session.canAddInput(newInput) {
            session.addInput(newInput)
        }
        session.commitConfiguration()
    }

    func capturePhoto() {
        preview.flashShutterEffect()
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.global().async {
            guard let cgImage = photo.cgImageRepresentation() else { return }
            let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            DispatchQueue.main.async {
                self.delegate?.cameraViewController(self, didFinishWith: image)
            }
        }
    }

    @objc func closeTapped() {
        if let nav = self.navigationController {
            nav.popViewController(animated: true)
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        //UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
    }
}
