//
//  PKPhotoPreviewViewController.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/9/25.
//

import UIKit
import Photos

class PKPhotoPreviewViewController: UIViewController, UIScrollViewDelegate {
    var currentIndex: Int = 0
    var items = [PKPhotoPickerItem]()
    let pagingScrollView = UIScrollView()
    let pageControl = UIPageControl() // Added UIPageControl property

    init(items: [PKPhotoPickerItem], currentIndex: Int) {
        self.items = items
        self.currentIndex = currentIndex
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        // Configure the horizontal paging scroll view
        pagingScrollView.isPagingEnabled = true
        pagingScrollView.showsHorizontalScrollIndicator = false
        pagingScrollView.showsVerticalScrollIndicator = false
        pagingScrollView.bouncesVertically = false
        pagingScrollView.bouncesZoom = false
        pagingScrollView.delegate = self
        pagingScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pagingScrollView)
        
        NSLayoutConstraint.activate([
            pagingScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pagingScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pagingScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            pagingScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 5
        closeButton.clipsToBounds = true
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            closeButton.widthAnchor.constraint(equalToConstant: 35),
            closeButton.heightAnchor.constraint(equalToConstant: 35)
        ])

        // Configure and add pageControl
        pageControl.numberOfPages = items.count
        pageControl.currentPage = currentIndex
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.pageIndicatorTintColor = .gray
        pageControl.isUserInteractionEnabled = false
        view.addSubview(pageControl)

        pageControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])

        Task {
            await loadPreview()
        }
    }

    @objc private func closeTapped() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func loadPreview() async {
        pagingScrollView.isHidden = true
        for (index, item) in items.enumerated() {
            let resolved = await item.exportAsset(manager: PHCachingImageManager())
            guard case let .image(image) = resolved else { continue }
            let frame = CGRect(x: CGFloat(index) * view.bounds.width, y: 0,
                               width: view.bounds.width, height: view.bounds.height)
            let zoomScrollView = PKPhotoPreviewCell(frame: frame, image: image)
            pagingScrollView.addSubview(zoomScrollView)
        }
        
        pagingScrollView.contentSize = CGSize(width: view.bounds.width * CGFloat(items.count),
                                              height: view.bounds.height)
        let offsetX = CGFloat(currentIndex) * view.bounds.width
        pagingScrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: false)
        pagingScrollView.isHidden = false
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { // Added method to update currentIndex and pageControl
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        currentIndex = page
        pageControl.currentPage = page
    }
}

class PKPhotoPreviewCell: UIScrollView, UIScrollViewDelegate {
    private let image: UIImage
    let imageView: UIImageView

    init(frame: CGRect, image: UIImage) {
        self.image = image
        imageView = UIImageView(image: image)
        super.init(frame: frame)
        delegate = self
        bounces = false
        minimumZoomScale = 1.0
        maximumZoomScale = 4.0
        backgroundColor = .black

        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)

        // Add double tap gesture to zoom
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if zoomScale == minimumZoomScale {
            let boundsSize = self.bounds.size
            let imageSize = image.size
            let scaleWidth = boundsSize.width / imageSize.width
            let scaleHeight = boundsSize.height / imageSize.height
            let minScale = min(scaleWidth, scaleHeight)
            let fittedWidth = imageSize.width * minScale
            let fittedHeight = imageSize.height * minScale
            imageView.frame = CGRect(x: (boundsSize.width - fittedWidth) / 2,
                                     y: (boundsSize.height - fittedHeight) / 2,
                                     width: fittedWidth,
                                     height: fittedHeight)
            contentSize = imageView.frame.size
        }
        centerImage()
    }

    func centerImage() {
        let boundsSize = self.bounds.size
        var frameToCenter = imageView.frame

        // If the image is smaller than the scroll view, center it; else stick to edges.
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }
        imageView.frame = frameToCenter
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale != minimumZoomScale {
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let newZoomScale = maximumZoomScale
            // Calculate a rect for zooming in centered on the tap point
            let width = bounds.size.width / newZoomScale
            let height = bounds.size.height / newZoomScale
            let originX = point.x - width / 2
            let originY = point.y - height / 2
            let zoomRect = CGRect(x: originX, y: originY, width: width, height: height)
            zoom(to: zoomRect, animated: true)
        }
    }
}
