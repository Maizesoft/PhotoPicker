import Photos
import UIKit

class PKPhotoPickerBottomBar: UIView, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    var onConfirm: (() -> Void)?
    var onTapItem: ((PKPhotoPickerItem) -> Void)?
    var onReordered: (([PKPhotoPickerItem]) -> Void)?
    var collectionView: UICollectionView!
    var imageCache: PHCachingImageManager?
    let cellSize = CGSize(width: 50, height: 50)
    let confirmButton = UIButton(type: .system)
    let contentContainer = UIView()
    private var items: [PKPhotoPickerItem] = []
    private var selectedIndex: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(blurView, at: 0)
        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        addSubview(contentContainer)
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
        ])

        contentContainer.addSubview(confirmButton)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.filled()
        config.title = "Confirm"
        config.baseBackgroundColor = tintColor
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        confirmButton.configuration = config

        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            confirmButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -12),
            confirmButton.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),
            confirmButton.heightAnchor.constraint(equalToConstant: 36),
        ])

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 5
        layout.itemSize = cellSize
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.register(PKPhotoThumbnailCell.self, forCellWithReuseIdentifier: "PKPhotoThumbnailCell")
        contentContainer.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 8),
            collectionView.trailingAnchor.constraint(equalTo: confirmButton.leadingAnchor, constant: -8),
            collectionView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
    }

    @objc private func confirmButtonTapped() {
        if var config = confirmButton.configuration {
            config.showsActivityIndicator = true
            config.title = nil
            confirmButton.configuration = config
        }
        confirmButton.isEnabled = false
        onConfirm?()
    }

    func update(with newItems: [PKPhotoPickerItem]) {
        items = newItems
        collectionView.reloadData()
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PKPhotoThumbnailCell", for: indexPath) as! PKPhotoThumbnailCell
        let item = items[indexPath.item]

        switch item {
        case let .asset(asset):
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            imageCache?.requestImage(for: asset, targetSize: CGSize(width: 100, height: 100), contentMode: .aspectFill, options: options) { image, _ in
                cell.imageView.image = image
            }
        case let .image(image):
            cell.imageView.image = image
        case let .video(_, thumbnail):
            cell.imageView.contentMode = .scaleAspectFit
            cell.imageView.image = thumbnail ?? UIImage(systemName: "video")
        default:
            break
        }

        cell.layer.borderWidth = 1
        cell.layer.borderColor = UIColor.systemFill.cgColor
        return cell
    }

    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onTapItem?(items[indexPath.item])
    }

    func collectionView(_: UICollectionView, itemsForBeginning _: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let item = items[indexPath.item]
        let dragItem = UIDragItem(itemProvider: NSItemProvider())
        dragItem.localObject = item
        return [dragItem]
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath else { return }

        for dropItem in coordinator.items {
            guard let sourceIndexPath = dropItem.sourceIndexPath,
                  let item = dropItem.dragItem.localObject as? PKPhotoPickerItem else { continue }
            collectionView.performBatchUpdates {
                items.remove(at: sourceIndexPath.item)
                items.insert(item, at: destinationIndexPath.item)
                collectionView.moveItem(at: sourceIndexPath, to: destinationIndexPath)
            } completion: { _ in
                self.onReordered?(self.items)
            }
            coordinator.drop(dropItem.dragItem, toItemAt: destinationIndexPath)
        }
    }

    func collectionView(_: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return session.localDragSession != nil
    }

    func collectionView(_: UICollectionView, dropSessionDidUpdate _: UIDropSession, withDestinationIndexPath _: IndexPath?) -> UICollectionViewDropProposal {
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
}

class PKPhotoThumbnailCell: UICollectionViewCell {
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
