//
//  PKCameraViewController.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/7/25.
//
import UIKit
import AVFoundation

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    var session = AVCaptureSession()
    var photoOutput = AVCapturePhotoOutput()
    var movieOutput = AVCaptureMovieFileOutput()
    var previewLayer: AVCaptureVideoPreviewLayer!
    var isRecording = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissionAndSetup()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
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

    func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(photoOutput),
              session.canAddOutput(movieOutput) else { return }

        session.beginConfiguration()
        session.sessionPreset = .high
        session.addInput(input)
        session.addOutput(photoOutput)
        session.addOutput(movieOutput)
        session.commitConfiguration()

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        let photoButton = UIButton(frame: CGRect(x: view.bounds.midX - 30, y: view.bounds.height - 100, width: 60, height: 60))
        photoButton.layer.cornerRadius = 30
        photoButton.backgroundColor = .white
        photoButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(photoButton)
        
        session.startRunning()
    }

    @objc func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    @objc func toggleRecording() {
        if isRecording {
            movieOutput.stopRecording()
            isRecording = false
        } else {
            let outputPath = NSTemporaryDirectory() + UUID().uuidString + ".mov"
            let outputURL = URL(fileURLWithPath: outputPath)
            movieOutput.startRecording(to: outputURL, recordingDelegate: self)
            isRecording = true
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
    }
}
