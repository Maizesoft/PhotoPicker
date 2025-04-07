//
//  PhotoPicker.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/7/25.
//

import UIKit
import Photos

class PhotoPicker: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDataSourcePrefetching, UIPopoverPresentationControllerDelegate {
    var assets: [PHAsset] = []
    var selectedAssets: [PHAsset] = []
    var collections: [PHAssetCollection] = []
    var currentCollectionIndex = 0
    let albumButton = UIButton(type: .system)
    let imageManager = PHCachingImageManager()
    var cellImageSize: CGSize = CGSizeMake(100, 100)
    var mediaType: PHAssetMediaType = .image
    let activityIndicator = UIActivityIndicatorView(style: .large)
    let bottomBar = PhotoPickerBottomBar()

    let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 1
        let side = (UIScreen.main.bounds.width - 2 * spacing) / 3
        layout.itemSize = CGSize(width: side, height: side)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        view.addSubview(collectionView)
        collectionView.register(PhotoPickerCell.self, forCellWithReuseIdentifier: "PhotoPickerCell")
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        let scale = UIScreen.main.scale
        if let size = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize {
            cellImageSize = CGSize(width: size.width * scale, height: size.height * scale)
        }
        
        view.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // 4. Setup the bottom bar.
        view.addSubview(bottomBar)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 100)
        ])
        bottomBar.isHidden = true
        bottomBar.imageManager = imageManager

        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            self.fetchCollection()
        }
    }
    
    func fetchCollection() {
        let result = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        result.enumerateObjects { collection, _, _ in
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            fetchOptions.fetchLimit = 1 // we only care if it's non-empty
            let result = PHAsset.fetchAssets(in: collection, options: fetchOptions)
            if result.count > 0 {
                self.collections.append(collection)
            }
        }
        DispatchQueue.main.async {
            if self.collections.count > self.currentCollectionIndex, let title = self.collections[self.currentCollectionIndex].localizedTitle {
                self.albumButton.setTitle(title, for: .normal)
                self.albumButton.sizeToFit()
            }
            self.fetchAssets()
        }
    }
    
    func fetchAssets() {
        activityIndicator.startAnimating()
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", mediaType.rawValue)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = PHAsset.fetchAssets(in: self.collections[self.currentCollectionIndex], options: fetchOptions)
            var fetchedAssets: [PHAsset] = []
            result.enumerateObjects { asset, _, _ in
                fetchedAssets.append(asset)
            }
            DispatchQueue.main.async {
                self.assets = fetchedAssets
                self.collectionView.reloadData()
                // restore selection
                for (index, asset) in self.assets.enumerated() {
                    if self.selectedAssets.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                        let indexPath = IndexPath(item: index, section: 0)
                        self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                    }
                }
                
                self.activityIndicator.stopAnimating()
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoPickerCell", for: indexPath) as! PhotoPickerCell
        let asset = assets[indexPath.item]
        cell.representedAssetIdentifier = asset.localIdentifier
        imageManager.requestImage(for: asset, targetSize: cellImageSize, contentMode: .aspectFill, options: nil) { image, _ in
            if cell.representedAssetIdentifier == asset.localIdentifier {
                cell.imageView.image = image
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let assetsToCache = indexPaths.compactMap { indexPath in
            indexPath.item < assets.count ? assets[indexPath.item] : nil
        }
        imageManager.startCachingImages(for: assetsToCache, targetSize: cellImageSize, contentMode: .aspectFill, options: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let assetsToStop = indexPaths.compactMap { indexPath in
            indexPath.item < assets.count ? assets[indexPath.item] : nil
        }
        imageManager.stopCachingImages(for: assetsToStop, targetSize: cellImageSize, contentMode: .aspectFill, options: nil)
    }

    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissPicker))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Confirm", style: .done, target: self, action: #selector(confirm))
        albumButton.addTarget(self, action: #selector(showAlbumSelection), for: .touchUpInside)
        let config = UIImage.SymbolConfiguration(scale: .small)
        let chevron = UIImage(systemName: "chevron.down", withConfiguration: config)
        albumButton.setImage(chevron, for: .normal)
        albumButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        albumButton.semanticContentAttribute = .forceRightToLeft
        navigationItem.titleView = albumButton
    }

    @objc private func dismissPicker() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func confirm() {
        // Implement confirmation logic here
    }

    @objc private func showAlbumSelection() {
        let albumPicker = PhotoAlbumPicker()
        albumPicker.collections = self.collections
        albumPicker.didSelectAlbum = { [weak self] selectedCollection, index in
            guard let self = self else { return }
            self.currentCollectionIndex = index
            if let title = selectedCollection.localizedTitle {
                self.albumButton.setTitle(title, for: .normal)
                self.albumButton.sizeToFit()
            }
            self.fetchAssets()
        }
        albumPicker.modalPresentationStyle = .popover
        if let popover = albumPicker.popoverPresentationController {
            popover.sourceView = albumButton
            popover.sourceRect = albumButton.bounds
            popover.permittedArrowDirections = .up
            popover.delegate = self
        }
        present(albumPicker, animated: true, completion: nil)
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    // Update selection delegate methods to update the bottom bar.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < assets.count else { return }
        let asset = assets[indexPath.item]
        if !selectedAssets.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
            selectedAssets.append(asset)
        }
        bottomBar.update(with: selectedAssets)
        bottomBar.isHidden = selectedAssets.isEmpty
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard indexPath.item < assets.count else { return }
        let asset = assets[indexPath.item]
        if let index = selectedAssets.firstIndex(of: asset) {
            selectedAssets.remove(at: index)
        }
        bottomBar.update(with: selectedAssets)
        bottomBar.isHidden = selectedAssets.isEmpty
    }
}
