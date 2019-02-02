//
//  ImageCollectionVewController.swift
//  SharedImages
//
//  Created by Christopher Prince on 3/10/18.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//
import Foundation
import UIKit
import SMCoreLib
import BadgeSwift

protocol LargeImageCellDelegate : class {
    func cellZoomed(cell: ImageCollectionVC, toZoomSize zoomSize:CGSize, withOriginalSize originalSize:CGSize)
}

class ImageCollectionVC : UICollectionViewCell {
    // For large images only, the imageView's are embedded in a scroll view to enable pinch/zoom. Because these only apply to large images, referenced as scrollView? below.
    @IBOutlet weak var scrollView: UIScrollView!
    
    // Also only applies to large scale images, because will only be used when scroll view is used.
    fileprivate var switchedToFullScaleImageForZooming = false
    
    @IBOutlet weak var imageView: UIImageView!
    
    // These are oversized to give space for padding.
    static let smallTitleHeight:CGFloat = 15
    static let largeTitleHeight:CGFloat = 25
    
    @IBOutlet weak var title: UILabel!
    
    // Only in small image VC.
    @IBOutlet weak var errorImageView: UIImageView!
    
    private(set) var image:Image!
    private(set) weak var syncController:SyncController!
    weak var imageCache:LRUCache<Image>?
    
    weak var delegate:LargeImageCellDelegate?
    var originalSize:CGSize!
    let badge = BadgeSwift()
    var tapGesture: UITapGestureRecognizer?
    var imageTapBehavior:(()->())?
    
    private var selectedImage:UIImageView!
    var userSelected:Bool = false {
        didSet {
            if userSelected {
                if selectedImage == nil {
                    let selected = UIImage(named: "Selected")
                    
                    selectedImage = UIImageView()
                    selectedImage.image = selected
                    
                    let size = min(25, imageView.frameWidth, imageView.frameHeight)
                    selectedImage.frameSize = CGSize(width: size, height: size)
                    
                    selectedImage.frameMaxX = imageView.frameMaxX
                    selectedImage.frameMaxY = imageView.frameMaxY
                    imageView.addSubview(selectedImage)
                }
            }
            else {
                selectedImage?.removeFromSuperview()
                selectedImage = nil
            }
            
            setNeedsDisplay()
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        switchedToFullScaleImageForZooming = false
        badge.removeFromSuperview()
    }
    
    func setProperties(image:Image, syncController:SyncController, cache: LRUCache<Image>, imageTapBehavior:(()->())? = nil) {
        self.image = image
        self.syncController = syncController
        title.text = image.title
        imageCache = cache
        
        if let _ = errorImageView {
            var showError = false
            if let _ = self.image.url {
                if self.image.eitherHasError {
                    showError = true
                }
            }
            else if self.image.eitherHasError {
                showError = true
                
                // No url, and thus no image contents on the image view -- it looks odd if there is no color/image on the imageView. Give it some color.
                imageView.backgroundColor = .lightGray
            }
            
            errorImageView?.isHidden = !showError
        }
        
        scrollView?.zoomScale = 1.0
        scrollView?.maximumZoomScale = 6.0
        scrollView?.delegate = self
        
        self.imageTapBehavior = imageTapBehavior
        
        if let discussion = image.discussion {
            // Color from http://www.tayloredmktg.com/rgb/
            title.textColor = UIColor(red: 30.0/255.0, green: 144.0/255.0, blue: 255.0/255.0, alpha: 1.0)
            
            if let _ = imageTapBehavior, tapGesture == nil {
                tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapGestureAction))
                
                scrollView?.addGestureRecognizer(tapGesture!)
            }
            
            if discussion.unreadCount > 0 {
                badge.format(withUnreadCount: Int(discussion.unreadCount))
                imageView.addSubview(badge)
            }
        }
        else {
            title.textColor = UIColor.black
        }
    }
    
    @objc private func tapGestureAction() {
        // Don't need to check for an error here, because this only happens with large images and we won't get that far if there is an error.
        imageTapBehavior?()
    }
    
    func cellSizeHasBeenChanged() {
        guard let imageCache = imageCache else {
            return
        }
        
        layoutIfNeeded()
        
        let minimumImageDimension:CGFloat = 15
        var size = imageView.frame.size
        size.height = max(size.height, minimumImageDimension)
        size.width = max(size.width, minimumImageDimension)
        imageView.frameSize = size
        
        scrollView?.contentSize = size
        
        // Don't use image.hasError here only because on an upload/gone case, we do have a valid URL and can render the image.
        guard let imageOriginalSize = image.originalSize else {
            originalSize = size
            return
        }
        
        let smallerSize = ImageExtras.boundingImageSizeFor(originalSize: imageOriginalSize, boundingSize: size)
        
        imageView.image = imageCache.getItem(from: image, with: smallerSize)
        
        originalSize = smallerSize
    }
}

extension ImageCollectionVC : UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        delegate?.cellZoomed(cell: self, toZoomSize: imageView.frame.size, withOriginalSize: originalSize)
        //Log.msg("imageView.frame.size: \(imageView.frame.size)")
        
        if !switchedToFullScaleImageForZooming {
            switchedToFullScaleImageForZooming = true
            
            // Load the full scale image to give the user better resolution when zooming in.
            let uiImage = ImageExtras.fullSizedImage(url: image.url! as URL)
            imageView.image = uiImage
        }
    }
}
