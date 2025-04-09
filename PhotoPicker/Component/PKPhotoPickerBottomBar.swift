import UIKit
import Photos

class PKPhotoPickerBottomBar: UIView {
    var onConfirm: (() -> Void)?
    let scrollView = UIScrollView()
    let stackView = UIStackView()
    var imageCache: PHCachingImageManager?
    let cellSize = CGSizeMake(50, 50)
    let confirmButton = UIButton(type: .system)
    let contentContainer = UIView()
    
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
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        addSubview(contentContainer)
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        ])
        
        contentContainer.addSubview(scrollView)
        
        contentContainer.addSubview(confirmButton)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.filled()
        config.title = "Confirm"
        config.baseBackgroundColor = tintColor
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        confirmButton.configuration = config
        
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: confirmButton.leadingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        
        scrollView.addSubview(stackView)
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 5
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -8),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        NSLayoutConstraint.activate([
            confirmButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -12),
            confirmButton.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),
            confirmButton.heightAnchor.constraint(equalToConstant: 36),
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
    
    func update(with items: [PKPhotoPickerItem]) {
        // Remove all existing thumbnails
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        guard let imageManager = imageCache else { return }
        
        for item in items {
            let thumbImageView = UIImageView()
            thumbImageView.layer.borderColor = UIColor.systemFill.cgColor
            thumbImageView.layer.borderWidth = 1
            thumbImageView.contentMode = .scaleAspectFill
            thumbImageView.clipsToBounds = true
            thumbImageView.translatesAutoresizingMaskIntoConstraints = false
            thumbImageView.widthAnchor.constraint(equalToConstant: cellSize.width).isActive = true
            thumbImageView.heightAnchor.constraint(equalToConstant: cellSize.height).isActive = true
            stackView.addArrangedSubview(thumbImageView)
            switch item {
            case let .asset(asset):
                imageManager.requestImage(for: asset, targetSize: CGSize(width: 100, height: 100), contentMode: .aspectFill, options: nil) { image, _ in
                    thumbImageView.image = image
                }
            case let .image(image):
                thumbImageView.image = image
            case let .video(url):
                thumbImageView.contentMode = .scaleAspectFit
                thumbImageView.image = UIImage(systemName: "video")
            default:
                break
            }
        }
    }
}
