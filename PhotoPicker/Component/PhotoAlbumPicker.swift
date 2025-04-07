//
//  PhotoAlbumPicker.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/7/25.
//

import UIKit
import Photos

class PhotoAlbumPicker: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var collections: [PHAssetCollection] = []
    var didSelectAlbum: ((PHAssetCollection, Int) -> Void)?

    private let tableView = UITableView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupTableView()
        preferredContentSize = CGSizeMake(200, CGFloat(collections.count) * 40.0)
    }

    private func setupTableView() {
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return collections.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "AlbumCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) ??
                   UITableViewCell(style: .default, reuseIdentifier: cellIdentifier)
        let collection = collections[indexPath.row]
        cell.textLabel?.text = collection.localizedTitle
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedCollection = collections[indexPath.row]
        didSelectAlbum?(selectedCollection, indexPath.row)
        dismiss(animated: true, completion: nil)
    }
}
