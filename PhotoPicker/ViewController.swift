//
//  ViewController.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/7/25.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.backgroundColor = UIColor.systemBackground

        let button = UIButton(type: .system)
        button.setTitle("Open Photo Picker", for: .normal)
        button.addTarget(self, action: #selector(presentPhotoPicker), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc func presentPhotoPicker() {
        let picker = PhotoPicker()
        let navController = UINavigationController(rootViewController: picker)
        present(navController, animated: true, completion: nil)
    }
}
