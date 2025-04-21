//
//  PKPreviewViewController.swift
//  PhotoPicker
//
//  Created by Xiang Cao on 4/9/25.
//

import AVFoundation
import Photos
import UIKit

protocol PKPreviewDelegate: AnyObject {
    func previewDidConfirm(_ preview: PKPreviewViewController)
    func previewDidRetake(_ preview: PKPreviewViewController)
}

class PKPreviewViewController: UIViewController, UIScrollViewDelegate {
    var showRetakeConfirmButton = false
    var currentIndex: Int = 0
    var items = [PKPhotoPickerItem]()
    weak var delegate: PKPreviewDelegate?
    private let pagingScrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    init(items: [PKPhotoPickerItem], currentIndex: Int = 0) {
        self.items = items
        self.currentIndex = currentIndex
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
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
            pagingScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
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
            closeButton.heightAnchor.constraint(equalToConstant: 35),
        ])

        // Configure and add pageControl
        pageControl.numberOfPages = items.count
        pageControl.currentPage = currentIndex
        pageControl.isUserInteractionEnabled = false
        pageControl.isHidden = items.count <= 1
        view.addSubview(pageControl)
        let bottomConstraint = pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        bottomConstraint.priority = .defaultLow
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomConstraint,
        ])

        if showRetakeConfirmButton {
            let toolbar = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
            toolbar.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(toolbar)

            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.distribution = .fillEqually
            stackView.spacing = 50
            stackView.translatesAutoresizingMaskIntoConstraints = false
            toolbar.contentView.addSubview(stackView)

            let retakeButton = UIButton(type: .system)
            retakeButton.setTitle("Retake", for: .normal)
            retakeButton.setTitleColor(.white, for: .normal)
            retakeButton.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)
            // retakeButton.backgroundColor = UIColor.darkGray
            stackView.addArrangedSubview(retakeButton)

            let confirmButton = UIButton(type: .system)
            confirmButton.setTitle("Confirm", for: .normal)
            confirmButton.setTitleColor(.white, for: .normal)
            confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
            // confirmButton.backgroundColor = UIColor.systemBlue
            stackView.addArrangedSubview(confirmButton)

            closeButton.isHidden = true

            NSLayoutConstraint.activate([
                toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                toolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                toolbar.heightAnchor.constraint(equalToConstant: 80),

                stackView.leadingAnchor.constraint(equalTo: toolbar.safeAreaLayoutGuide.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: toolbar.safeAreaLayoutGuide.trailingAnchor),
                stackView.topAnchor.constraint(equalTo: toolbar.topAnchor),
                stackView.bottomAnchor.constraint(equalTo: toolbar.safeAreaLayoutGuide.bottomAnchor),
                pageControl.bottomAnchor.constraint(equalTo: toolbar.topAnchor, constant: 0),
            ])
        }

        activityIndicator.color = .white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        activityIndicator.startAnimating()
        pagingScrollView.isHidden = true

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

    @objc private func retakeTapped() {
        delegate?.previewDidRetake(self)
    }

    @objc private func confirmTapped() {
        delegate?.previewDidConfirm(self)
    }

    private func loadPreview() async {
        pagingScrollView.isHidden = true
        activityIndicator.startAnimating()
        for (index, item) in items.enumerated() {
            let resolved = await item.exportAsset(manager: PHCachingImageManager())
            let frame = CGRect(x: CGFloat(index) * view.bounds.width,
                               y: 0,
                               width: view.bounds.width,
                               height: view.bounds.height)
            switch resolved {
            case let .image(image):
                let preview = PKPhotoPreviewCell(frame: frame, image: image)
                pagingScrollView.addSubview(preview)
            case let .video(url, _):
                let preview = PKVideoPreviewCell(frame: frame, videoURL: url)
                pagingScrollView.addSubview(preview)
            default:
                continue
            }
        }
        pagingScrollView.contentSize = CGSize(width: view.bounds.width * CGFloat(items.count),
                                              height: view.bounds.height)
        let offsetX = CGFloat(currentIndex) * view.bounds.width
        pagingScrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: false)
        activityIndicator.stopAnimating()
        activityIndicator.removeFromSuperview()
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
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false

        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)

        // Add double tap gesture to zoom
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if zoomScale == minimumZoomScale {
            let boundsSize = bounds.size
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
        let boundsSize = bounds.size
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

    func viewForZooming(in _: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_: UIScrollView) {
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

class PKVideoPreviewCell: UIView {
    private var videoURL: URL
    private var player: AVPlayer
    private var playerLayer: AVPlayerLayer
    private var playIcon: UIImageView
    private var playerRateObserver: NSKeyValueObservation?
    private let timeLabel = UILabel()
    private var timeObserverToken: Any?

    init(frame: CGRect, videoURL: URL) {
        self.videoURL = videoURL
        player = AVPlayer(url: videoURL)
        playerLayer = AVPlayerLayer(player: player)
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 50, weight: .regular)
        let playImage = UIImage(systemName: "play.fill", withConfiguration: symbolConfig)
        playIcon = UIImageView(image: playImage)

        super.init(frame: frame)
        backgroundColor = .black

        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)

        playIcon.tintColor = .white
        playIcon.contentMode = .center
        playIcon.backgroundColor = .black.withAlphaComponent(0.3)
        addSubview(playIcon)

        timeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        timeLabel.textColor = .white
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        timeLabel.textAlignment = .center
        timeLabel.layer.cornerRadius = 4
        timeLabel.clipsToBounds = true
        addSubview(timeLabel)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(togglePlayback))
        addGestureRecognizer(tapGesture)

        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleVideoGravity))
        doubleTapGesture.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapGesture)
        tapGesture.require(toFail: doubleTapGesture)

        playerRateObserver = player.observe(\.rate, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.playIcon.isHidden = player.rate != 0
            }
        }

        timeObserverToken = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self,
                  let duration = self.player.currentItem?.duration.seconds,
                  duration.isFinite else { return }
            let current = Int(time.seconds)
            let total = Int(duration)
            let format: (Int) -> String = { String(format: "%02d:%02d", $0 / 60, $0 % 60) }
            self.timeLabel.text = "\(format(current)) / \(format(total))"
        }

        Task {
            if let duration = try? await player.currentItem?.asset.load(.duration),
               duration.isNumeric
            {
                let total = Int(duration.seconds)
                let format: (Int) -> String = { String(format: "%02d:%02d", $0 / 60, $0 % 60) }
                self.timeLabel.text = "00:00 / \(format(total))"
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
        playIcon.frame = bounds

        let labelWidth: CGFloat = 100
        let labelHeight: CGFloat = 20
        timeLabel.frame = CGRect(x: (bounds.width - labelWidth) / 2, y: bounds.height - labelHeight - 100, width: labelWidth, height: labelHeight)
    }

    @objc private func togglePlayback() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true, options: [])
            } catch {
                print(error)
            }

            if let currentItem = player.currentItem,
               currentItem.currentTime() >= currentItem.duration
            {
                player.seek(to: .zero)
            }
            player.play()
        }
    }

    @objc private func toggleVideoGravity() {
        playerLayer.videoGravity = (playerLayer.videoGravity == .resizeAspect) ? .resizeAspectFill : .resizeAspect
    }
}
