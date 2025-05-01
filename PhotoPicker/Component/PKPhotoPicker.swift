//
//  PKPhotoPicker.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/7/25.
//

import Photos
import UIKit

struct PKPhotoPickerOptions {
    enum PKPhotoPickerMode {
        case photo
        case video
        case all
    }

    let selectionLimit: Int
    let mode: PKPhotoPickerMode
    let cameraEntry: Bool
    let cameraSingleShot: Bool

    init(selectionLimit: Int = 5, mode: PKPhotoPickerMode, cameraEntry: Bool = true, cameraSingleShot: Bool = true) {
        self.selectionLimit = selectionLimit
        self.mode = mode
        self.cameraEntry = cameraEntry
        self.cameraSingleShot = cameraSingleShot
    }
}

enum PKPhotoPickerItem: Equatable {
    case asset(PHAsset)
    case image(UIImage)
    case video(URL, UIImage?)
    case camera
    static func == (lhs: PKPhotoPickerItem, rhs: PKPhotoPickerItem) -> Bool {
        switch (lhs, rhs) {
        case let (.asset(a1), .asset(a2)):
            return a1.localIdentifier == a2.localIdentifier
        case let (.image(i1), .image(i2)):
            return i1 === i2
        case let (.video(u1, _), .video(u2, _)):
            return u1 == u2
        case (.camera, .camera):
            return true
        default:
            return false
        }
    }

    func exportAsset(manager: PHImageManager?) async -> PKPhotoPickerItem? {
        await withCheckedContinuation { continuation in
            let cache = manager ?? PHImageManager.default()

            if case let .asset(asset) = self {
                if asset.mediaType == .video {
                    let options = PHVideoRequestOptions()
                    options.deliveryMode = .fastFormat
                    options.isNetworkAccessAllowed = true
                    print("requestExportSession")
                    cache.requestExportSession(forVideo: asset, options: options, exportPreset: AVAssetExportPresetPassthrough) { session, _ in
                        if let session = session {
                            let outputURL = PKPhotoPicker.tempFileURL(UUID().uuidString, withExtension: "mp4")
                            session.outputURL = outputURL
                            session.outputFileType = .mp4
                            print("session.exportAsynchronously")
                            session.exportAsynchronously {
                                if session.status == .completed {
                                    Task {
                                        let avAsset = AVURLAsset(url: outputURL)
                                        let imageGenerator = AVAssetImageGenerator(asset: avAsset)
                                        imageGenerator.appliesPreferredTrackTransform = true
                                        let time = CMTime(seconds: 0, preferredTimescale: 600)

                                        do {
                                            let (thumbnail, _) = try await imageGenerator.image(at: time)
                                            continuation.resume(returning: .video(outputURL, UIImage(cgImage: thumbnail)))
                                        } catch {
                                            continuation.resume(returning: .video(outputURL, nil))
                                        }
                                    }
                                } else {
                                    continuation.resume(returning: nil)
                                }
                            }
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                } else if asset.mediaType == .image {
                    let options = PHImageRequestOptions()
                    options.deliveryMode = .highQualityFormat
                    options.isSynchronous = true
                    options.isNetworkAccessAllowed = true
                    cache.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, _ in
                        if let image {
                            continuation.resume(returning: .image(image))
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            } else {
                continuation.resume(returning: self)
            }
        }
    }
}

protocol PKPhotoPickerDelegate: AnyObject {
    func photoPicker(_ picker: PKPhotoPicker, didPick items: [PKPhotoPickerItem])
    func photoPickerDidCancel(_ picker: PKPhotoPicker)
}

class PKPhotoPicker: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDataSourcePrefetching, UIPopoverPresentationControllerDelegate, PHPhotoLibraryChangeObserver, PKCameraViewControllerDelegate {
    let options: PKPhotoPickerOptions
    weak var delegate: PKPhotoPickerDelegate?
    private var currentItems: [PKPhotoPickerItem] = []
    private var selectedItems: [PKPhotoPickerItem] = []
    static private var collections: [PHAssetCollection] = []
    static private var cachedFetches = [PHAssetCollection: PHFetchResult<PHAsset>]()
    private var currentCollectionIndex = 0
    static private let fetchQueue = DispatchQueue(label: "PKPhotoPicker fetch queue")
    private let albumButton = UIButton(type: .system)
    private let imageCache = PHCachingImageManager()
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

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
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
        collectionView.allowsMultipleSelection = options.selectionLimit > 1
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let scale = UIScreen.main.scale
        if let size = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize {
            cellImageSize = CGSize(width: size.width * scale, height: size.height * scale)
        }

        view.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        view.addSubview(bottomBar)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 100),
        ])
        bottomBar.isHidden = true
        bottomBar.imageCache = imageCache
        bottomBar.onConfirm = { [weak self] in
            guard let self = self else { return }
            self.deliverSelectedItems()
        }
        bottomBar.onTapItem = { [weak self] item in
            guard let self = self else { return }
            let previewVC = PKPreviewViewController(items: self.selectedItems, currentIndex: self.selectedItems.firstIndex(of: item) ?? 0)
            previewVC.modalPresentationStyle = .fullScreen
            present(previewVC, animated: true)
        }
        bottomBar.onReordered = { [weak self] items in
            guard let self = self else { return }
            self.selectedItems = items
        }

        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            PKPhotoPicker.fetchCollection(self.options) {
                if PKPhotoPicker.collections.count > self.currentCollectionIndex, let title = PKPhotoPicker.collections[self.currentCollectionIndex].localizedTitle {
                    self.albumButton.setTitle(title, for: .normal)
                    self.albumButton.sizeToFit()
                }
                self.fetchAssets()
            }
            PHPhotoLibrary.shared().register(self)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        imageCache.stopCachingImagesForAllAssets()
    }

    private func deliverSelectedItems() {
        Task {
            setLoading(true)
            PKPhotoPicker.clearTempDirectory()
            var result = [PKPhotoPickerItem]()
            for asset in self.selectedItems {
                if let item = await asset.exportAsset(manager: imageCache) {
                    result.append(item)
                }
            }
            setLoading(false)
            self.delegate?.photoPicker(self, didPick: result)
        }
    }

    static func fetchCollection(_ options: PKPhotoPickerOptions, completion: (() -> Void)? = nil) {
        fetchQueue.async {
            if PKPhotoPicker.collections.isEmpty {
                let result = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
                PKPhotoPicker.collections.removeAll()
                result.enumerateObjects { collection, _, _ in
                    let fetchOptions = PHFetchOptions()
                    if options.mode != .all {
                        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", options.mode == .photo ? PHAssetMediaType.image.rawValue : PHAssetMediaType.video.rawValue)
                    }
                    fetchOptions.fetchLimit = 1 // we only care if it's non-empty
                    let result = PHAsset.fetchAssets(in: collection, options: fetchOptions)
                    if result.count > 0 {
                        PKPhotoPicker.collections.append(collection)
                    }
                }
                PKPhotoPicker.cachedFetches.removeAll()
            }
            
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    func fetchAssets() {
        guard PKPhotoPicker.collections.count > currentCollectionIndex else {
            return
        }
        setLoading(true)
        let currentCollection = PKPhotoPicker.collections[self.currentCollectionIndex]
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if options.mode != .all {
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", options.mode == .photo ? PHAssetMediaType.image.rawValue : PHAssetMediaType.video.rawValue)
        }
        PKPhotoPicker.fetchQueue.async { [weak self] in
            guard let self = self else { return }
            var fetch = PKPhotoPicker.cachedFetches[currentCollection]
            if fetch == nil {
                fetch = PHAsset.fetchAssets(in: currentCollection, options: fetchOptions)
                PKPhotoPicker.cachedFetches[currentCollection] = fetch
            }
            
            var fetchedAssets: [PKPhotoPickerItem] = []
            if options.cameraEntry {
                fetchedAssets.append(.camera)
            }
            fetch?.enumerateObjects { asset, _, _ in
                fetchedAssets.append(.asset(asset))
            }
            DispatchQueue.main.async {
                self.currentItems = fetchedAssets
                self.collectionView.reloadData()
                self.setLoading(false)
            }
        }
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        let currentCollection = PKPhotoPicker.collections[currentCollectionIndex]
        if let currentFetch = PKPhotoPicker.cachedFetches[currentCollection] {
            if changeInstance.changeDetails(for: currentFetch) != nil {
                PKPhotoPicker.fetchQueue.async {
                    PKPhotoPicker.cachedFetches.removeValue(forKey: currentCollection)
                    self.fetchAssets()
                }
            }
        }
    }

    private func setLoading(_ loading: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if loading {
                self.activityIndicator.startAnimating()
                collectionView.alpha = 0.5
                collectionView.isUserInteractionEnabled = false
            } else {
                collectionView.alpha = 1
                collectionView.isUserInteractionEnabled = true
                self.activityIndicator.stopAnimating()
            }
        }
    }

    private func itemAtIndexPath(_ indexPath: IndexPath) -> PKPhotoPickerItem? {
        guard indexPath.item < currentItems.count else {
            return nil
        }
        return currentItems[indexPath.item]
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        return currentItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoPickerCell", for: indexPath) as! PKPhotoPickerCell
        cell.imageCache = imageCache
        if let item = itemAtIndexPath(indexPath) {
            cell.configure(with: item, cellImageSize: cellImageSize)
            if selectedItems.contains(item) {
                collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredVertically)
            }
        }

        return cell
    }

    func collectionView(_: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let assetsToCache = indexPaths.compactMap { indexPath in
            if let item = itemAtIndexPath(indexPath) {
                switch item {
                case let .asset(asset):
                    return asset
                default:
                    return nil
                }
            }
            return nil
        }
        imageCache.startCachingImages(for: assetsToCache, targetSize: cellImageSize, contentMode: .aspectFill, options: nil)
    }

    func collectionView(_: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let assetsToStop = indexPaths.compactMap { indexPath in
            if let item = itemAtIndexPath(indexPath) {
                switch item {
                case let .asset(asset):
                    return asset
                default:
                    return nil
                }
            }
            return nil
        }
        imageCache.stopCachingImages(for: assetsToStop, targetSize: cellImageSize, contentMode: .aspectFill, options: nil)
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
        delegate?.photoPickerDidCancel(self)
    }

    @objc private func showAlbumSelection() {
        let albumPicker = PKPhotoAlbumPicker()
        albumPicker.collections = PKPhotoPicker.collections
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

    func adaptivePresentationStyle(for _: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    // Update selection delegate methods to update the bottom bar.
    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let item = itemAtIndexPath(indexPath) {
            if !selectedItems.contains(item) {
                selectedItems.append(item)
                updateBottomBar()
            }
        }
    }

    func collectionView(_: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if let item = itemAtIndexPath(indexPath) {
            if let index = selectedItems.firstIndex(of: item) {
                selectedItems.remove(at: index)
                updateBottomBar()
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if let item = itemAtIndexPath(indexPath) {
            switch item {
            case .asset, .image, .video:
                if collectionView.allowsMultipleSelection == false {
                    selectedItems.removeAll()
                    return true
                } else {
                    return selectedItems.count < options.selectionLimit
                }
            case .camera:
                let cameraVC = PKCameraViewController(
                    options: PKCameraOptions(
                        mode: options.mode == .photo ? .photo : .video,
                        position: .back
                    )
                )
                cameraVC.delegate = self
                navigationController?.pushViewController(cameraVC, animated: true)
            }
        }
        return false
    }

    func cameraViewController(_: PKCameraViewController, didFinishWith items: [PKPhotoPickerItem]) {
        if options.cameraSingleShot {
            navigationController?.popToViewController(self, animated: true)
        }
        selectedItems.append(contentsOf: items)
        updateBottomBar()
    }

    func updateBottomBar() {
        bottomBar.update(with: selectedItems)
        bottomBar.isHidden = selectedItems.isEmpty || options.selectionLimit <= 1
        let bottomInset = bottomBar.isHidden ? 0 : (bottomBar.bounds.height - view.safeAreaInsets.bottom)
        collectionView.contentInset.bottom = max(bottomInset, 0)
        if options.selectionLimit == 1 && !selectedItems.isEmpty {
            deliverSelectedItems()
        }
    }

    static var tempDirectoryURL: URL {
        let tempDir = FileManager.default.temporaryDirectory
        let exportDir = tempDir.appendingPathComponent(String(describing: PKPhotoPicker.self))
        try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        return exportDir
    }

    static func tempFileURL(_ filename: String, withExtension ext: String) -> URL {
        tempDirectoryURL.appendingPathComponent(filename + "." + ext)
    }

    static func clearTempDirectory() {
        let directory = tempDirectoryURL
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for file in files {
                do {
                    try fileManager.removeItem(at: file)
                    print("temp file removed: \(file)")
                } catch {
                    print("Failed to remove temp file at \(file): \(error)")
                }
            }
        }
    }
    
    static func warmUpFetches(_ options: PKPhotoPickerOptions) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }
        fetchCollection(options) {
            if let firstCollection = PKPhotoPicker.collections.first {
                PKPhotoPicker.fetchQueue.async {
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                    if options.mode != .all {
                        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", options.mode == .photo ? PHAssetMediaType.image.rawValue : PHAssetMediaType.video.rawValue)
                    }
                    PKPhotoPicker.cachedFetches[firstCollection] = PHAsset.fetchAssets(in: firstCollection, options: fetchOptions)
                }
            }
        }
    }
    
    static func clearCaches() {
        PKPhotoPicker.fetchQueue.async {
            PKPhotoPicker.cachedFetches.removeAll()
            PKPhotoPicker.collections.removeAll()
        }
    }
}
