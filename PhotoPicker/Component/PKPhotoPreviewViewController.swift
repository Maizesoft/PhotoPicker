//
//  PKPhotoPreviewViewController.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/9/25.
//

import UIKit
import Photos

class PKPhotoPreviewViewController: UIViewController, UIScrollViewDelegate {
    var item: PKPhotoPickerItem?
    private var imageView: UIImageView!
    private var scrollView: UIScrollView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        Task { await loadPreview() }
    }

    private func loadPreview() async {
        let resolved = await item?.exportAsset(manager: PHCachingImageManager())
        guard case let .image(image) = resolved else { return }
     
        scrollView = UIScrollView(frame: view.bounds)
        scrollView.delegate = self
        scrollView.maximumZoomScale = 5
        view.addSubview(scrollView)
     
        imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.addSubview(imageView)

        scrollView.contentSize = image.size
        
        let scaleWidth = scrollView.bounds.width / image.size.width
        let scaleHeight = scrollView.bounds.height / image.size.height
        let minScale = min(scaleWidth, scaleHeight)
        scrollView.minimumZoomScale = minScale
        scrollView.zoomScale = minScale

        view.setNeedsLayout()
        view.layoutIfNeeded()
        centerImage(in: scrollView)
    }

    private func centerImage(in scrollView: UIScrollView) {
        let offsetX = max((scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5, 0)
        imageView?.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX, y: scrollView.contentSize.height * 0.5 + offsetY)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}
