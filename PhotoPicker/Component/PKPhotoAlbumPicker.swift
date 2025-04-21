//
//  PKPhotoAlbumPicker.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/7/25.
//

import Photos
import UIKit

class PKPhotoAlbumPicker: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var collections: [PHAssetCollection] = []
    var didSelectAlbum: ((PHAssetCollection, Int) -> Void)?

    private let tableView = UITableView()
    private let rowHeight = 40.0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupTableView()
        preferredContentSize = CGSizeMake(200, CGFloat(collections.count) * rowHeight)
    }

    private func setupTableView() {
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
    }

    // MARK: - UITableViewDataSource

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
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

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        return rowHeight
    }
}
