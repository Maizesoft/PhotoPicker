//
//  PhotoPicker.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/7/25.
//

import UIKit
import Photos

struct PKPhotoPickerOptions {
    let selectionLimit: Int
    let mediaType: PHAssetMediaType
    let cameraEntry: Bool
}

enum PKPhotoPickerItem: Equatable {
    case asset(PHAsset)
    case image(UIImage)
    case video(URL)
    case camera
    static func == (lhs: PKPhotoPickerItem, rhs: PKPhotoPickerItem) -> Bool {
        switch (lhs, rhs) {
        case let (.asset(a1), .asset(a2)):
            return a1.localIdentifier == a2.localIdentifier
        case let (.image(i1), .image(i2)):
            return i1 === i2
        case let (.video(v1), .video(v2)):
            return v1 == v2
        case (.camera, .camera):
            return true
        default:
            return false
        }
    }
}

protocol PKPhotoPickerDelegate: AnyObject {
    func photoPicker(_ picker: PKPhotoPicker, didPick items: [PKPhotoPickerItem])
    func photoPickerDidCancel(_ picker: PKPhotoPicker)
}

class PKPhotoPicker: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDataSourcePrefetching, UIPopoverPresentationControllerDelegate, PHPhotoLibraryChangeObserver {
    let options: PKPhotoPickerOptions
    weak var delegate: PKPhotoPickerDelegate?
    private var currentItems: [PKPhotoPickerItem] = []
    private var currentFetch = PHFetchResult<PHAsset>()
    private var selectedAssets: [PKPhotoPickerItem] = []
    private var collections: [PHAssetCollection] = []
    private var currentCollectionIndex = 0
    private let albumButton = UIButton(type: .system)
    private let imageManager = PHCachingImageManager()
    private var cellImageSize: CGSize = CGSizeMake(100, 100)
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let bottomBar = PKPhotoPickerBottomBar()

    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 1
        let side = (UIScreen.main.bounds.width - 2 * spacing) / 3
        layout.itemSize = CGSize(width: side, height: side)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()
    
    init(options: PKPhotoPickerOptions) {
        self.options = options
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupNavigationBar()
        view.addSubview(collectionView)
        collectionView.register(PKPhotoPickerCell.self, forCellWithReuseIdentifier: "PhotoPickerCell")
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
        bottomBar.onConfirm = { [weak self] in
            guard let self = self else { return }
            self.delegate?.photoPicker(self, didPick: self.selectedAssets)
            dismiss(animated: true)
        }

        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            self.fetchCollection()
            PHPhotoLibrary.shared().register(self)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        imageManager.stopCachingImagesForAllAssets()
    }
    
    func fetchCollection() {
        let result = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        result.enumerateObjects { collection, _, _ in
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", self.options.mediaType.rawValue)
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
        guard self.collections.count > self.currentCollectionIndex else {
            return
        }
        activityIndicator.startAnimating()
        collectionView.isHidden = true
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", options.mediaType.rawValue)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.currentFetch = PHAsset.fetchAssets(in: self.collections[self.currentCollectionIndex], options: fetchOptions)
            var fetchedAssets: [PKPhotoPickerItem] = []
            if options.cameraEntry {
                fetchedAssets.append(.camera)
            }
            self.currentFetch.enumerateObjects { asset, _, _ in
                fetchedAssets.append(.asset(asset))
            }
            DispatchQueue.main.async {
                self.currentItems = fetchedAssets
                self.collectionView.reloadData()
                // restore selection
                for (index, item) in self.currentItems.enumerated() {
                    if self.selectedAssets.contains(item) {
                        let indexPath = IndexPath(item: index, section: 0)
                        self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                    }
                }
                self.collectionView.isHidden = false
                self.activityIndicator.stopAnimating()
            }
        }
    }
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        if changeInstance.changeDetails(for: currentFetch) != nil {
            fetchAssets()
        }
    }
    
    private func itemAtIndexPath(_ indexPath: IndexPath) -> PKPhotoPickerItem? {
        guard indexPath.item < currentItems.count else {
            return nil
        }
        return currentItems[indexPath.item]
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return currentItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoPickerCell", for: indexPath) as! PKPhotoPickerCell
        cell.imageCache = imageManager
        if let item = itemAtIndexPath(indexPath) {
            cell.configure(with: item, cellImageSize: cellImageSize)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let assetsToCache = indexPaths.compactMap { indexPath in
            if let item = itemAtIndexPath(indexPath) {
                switch item {
                case .asset(let asset):
                    return asset
                default:
                    return nil
                }
            }
            return nil
        }
        imageManager.startCachingImages(for: assetsToCache, targetSize: cellImageSize, contentMode: .aspectFill, options: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let assetsToStop = indexPaths.compactMap { indexPath in
            if let item = itemAtIndexPath(indexPath) {
                switch item {
                case .asset(let asset):
                    return asset
                default:
                    return nil
                }
            }
            return nil
        }
        imageManager.stopCachingImages(for: assetsToStop, targetSize: cellImageSize, contentMode: .aspectFill, options: nil)
    }

    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissPicker))
        albumButton.addTarget(self, action: #selector(showAlbumSelection), for: .touchUpInside)
        let config = UIImage.SymbolConfiguration(scale: .small)
        let chevron = UIImage(systemName: "chevron.down", withConfiguration: config)
        albumButton.setImage(chevron, for: .normal)
        albumButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        albumButton.semanticContentAttribute = .forceRightToLeft
        navigationItem.titleView = albumButton
    }

    @objc private func dismissPicker() {
        dismiss(animated: true) {
            self.delegate?.photoPickerDidCancel(self)
        }
    }

    @objc private func showAlbumSelection() {
        let albumPicker = PKPhotoAlbumPicker()
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
        if let item = itemAtIndexPath(indexPath) {
            if !selectedAssets.contains(item) {
                selectedAssets.append(item)
            }
            updateBottomBar()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if let item = itemAtIndexPath(indexPath) {
            if let index = selectedAssets.firstIndex(of: item) {
                selectedAssets.remove(at: index)
            }
            updateBottomBar()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if let item = itemAtIndexPath(indexPath) {
            switch item {
            case .asset, .image, .video:
                return selectedAssets.count < options.selectionLimit
            case .camera:
                self.navigationController?.pushViewController(CameraViewController(), animated: true)
                return false
            }
            
        }
        return false
    }
    
    func updateBottomBar() {
        bottomBar.update(with: selectedAssets)
        bottomBar.isHidden = selectedAssets.isEmpty
        let bottomInset = bottomBar.isHidden ? 0 : (bottomBar.bounds.height - view.safeAreaInsets.bottom)
        collectionView.contentInset.bottom = max(bottomInset, 0)
    }
}
