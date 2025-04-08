//
//  ViewController.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/7/25.
//

import UIKit
import Photos

class ViewController: UIViewController, PKPhotoPickerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.backgroundColor = UIColor.systemBackground

        let button = UIButton(type: .system)
        button.setTitle("Open Photo Picker", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 20)
        button.addTarget(self, action: #selector(presentPhotoPicker(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        let videoButton = UIButton(type: .system)
        videoButton.setTitle("Open Video Picker", for: .normal)
        videoButton.titleLabel?.font = .boldSystemFont(ofSize: 20)
        videoButton.addTarget(self, action: #selector(presentPhotoPicker(_:)), for: .touchUpInside)
        videoButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(videoButton)

        NSLayoutConstraint.activate([
            videoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            videoButton.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 20)
        ])
    }

    @objc func presentPhotoPicker(_ sender: UIButton) {
        let isVideo = sender.title(for: .normal)?.contains("Video") == true
        let picker = PKPhotoPicker(options: PKPhotoPickerOptions(
            selectionLimit: 3,
            mediaType: isVideo ? .video : .image,
            cameraEntry: true
        ))
        picker.delegate = self
        let navController = UINavigationController(rootViewController: picker)
        present(navController, animated: true, completion: nil)
    }
    
    func photoPicker(_ picker: PKPhotoPicker, didPick items: [PKPhotoPickerItem]) {
        
    }
    
    func photoPickerDidCancel(_ picker: PKPhotoPicker) {
        
    }
    
}
