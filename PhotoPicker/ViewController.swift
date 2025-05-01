//
//  ViewController.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/7/25.
//

import UIKit
import Photos

class ViewController: UIViewController, PKPhotoPickerDelegate {
    let scrollView = UIScrollView()
    let stackView = UIStackView()
    let photoButton = UIButton(type: .system)
    let videoButton = UIButton(type: .system)
    let allMediaButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.backgroundColor = UIColor.systemBackground

        photoButton.setTitle("Open Photo Picker", for: .normal)
        photoButton.titleLabel?.font = .boldSystemFont(ofSize: 20)
        photoButton.addTarget(self, action: #selector(presentPhotoPicker(_:)), for: .touchUpInside)
        photoButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(photoButton)

        videoButton.setTitle("Open Video Picker", for: .normal)
        videoButton.titleLabel?.font = .boldSystemFont(ofSize: 20)
        videoButton.addTarget(self, action: #selector(presentPhotoPicker(_:)), for: .touchUpInside)
        videoButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(videoButton)

        allMediaButton.setTitle("Open All Picker", for: .normal)
        allMediaButton.titleLabel?.font = .boldSystemFont(ofSize: 20)
        allMediaButton.addTarget(self, action: #selector(presentPhotoPicker(_:)), for: .touchUpInside)
        allMediaButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(allMediaButton)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: photoButton.topAnchor, constant: -20),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        NSLayoutConstraint.activate([
            allMediaButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            allMediaButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            videoButton.bottomAnchor.constraint(equalTo: allMediaButton.topAnchor, constant: -12),
            videoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            photoButton.bottomAnchor.constraint(equalTo: videoButton.topAnchor, constant: -12),
            photoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc func presentPhotoPicker(_ sender: UIButton) {
        let title = sender.title(for: .normal)
        let mode: PKPhotoPickerOptions.PKPhotoPickerMode
        if title?.contains("Video") == true {
            mode = .video
        } else if title?.contains("All") == true {
            mode = .all
        } else {
            mode = .photo
        }
        PKPhotoPicker.clearCaches()
        let picker = PKPhotoPicker(options: PKPhotoPickerOptions(
            selectionLimit: 5,
            mode: mode,
        ))
        picker.delegate = self
        let navController = UINavigationController(rootViewController: picker)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true, completion: nil)
    }
    
    func photoPicker(_ picker: PKPhotoPicker, didPick items: [PKPhotoPickerItem]) {
        for view in stackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        for item in items {
            if case .image(let image) = item {
                let imageView = UIImageView(image: image)
                imageView.contentMode = .scaleAspectFit
                imageView.clipsToBounds = true
                imageView.widthAnchor.constraint(equalToConstant: 300).isActive = true
                imageView.heightAnchor.constraint(equalToConstant: 500).isActive = true
                stackView.addArrangedSubview(imageView)
            }
        }
        picker.dismiss(animated: true)
    }
    
    func photoPickerDidCancel(_ picker: PKPhotoPicker) {
        picker.dismiss(animated: true)
    }
    
}
