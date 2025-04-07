import UIKit
import Photos

class PhotoPickerBottomBar: UIView {
    let scrollView = UIScrollView()
    let stackView = UIStackView()
    var imageManager: PHCachingImageManager?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: self.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        
        scrollView.addSubview(stackView)
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -8),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }
    
    func update(with assets: [PHAsset]) {
        // Remove all existing thumbnails
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        guard let imageManager = imageManager else { return }
        
        for asset in assets {
            let thumbImageView = UIImageView()
            thumbImageView.contentMode = .scaleAspectFill
            thumbImageView.clipsToBounds = true
            thumbImageView.translatesAutoresizingMaskIntoConstraints = false
            thumbImageView.widthAnchor.constraint(equalToConstant: 60).isActive = true
            thumbImageView.heightAnchor.constraint(equalToConstant: 60).isActive = true
            stackView.addArrangedSubview(thumbImageView)
            
            imageManager.requestImage(for: asset, targetSize: CGSize(width: 60, height: 60), contentMode: .aspectFill, options: nil) { image, _ in
                thumbImageView.image = image
            }
        }
    }
}
