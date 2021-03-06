//
//  ImageExtras.swift
//  SharedImages
//
//  Created by Christopher Prince on 6/6/18.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//
import Foundation
import SMCoreLib

enum SortingOrder : String {
    case newerAtTop
    case newerAtBottom
}

class ImageExtras {
    static let discussionsDirectoryPath = "Discussions"
    
    static let iconDirectory = "SmallImages"
    static let iconDirectoryURL = FileStorage.url(ofItem: iconDirectory)
    static let largeImageDirectoryURL = FileStorage.url(ofItem: FileExtras.defaultDirectoryPath)
    

    static var minCostCache:UInt64 = 1000000
    static var maxCostCache:UInt64 = 10000000
    static var imageCache = LRUCache<Image>(maxItems: 500, maxCost:maxCostCache)!
    
    // Resets to smaller if not already at smaller size; only if reset is done will callback be called.
    static func resetToSmallerImageCache(didTheReset:()->()) {
        if imageCache.maxCost == maxCostCache {
            imageCache = LRUCache<Image>(maxItems: 500, maxCost:minCostCache)!
            didTheReset()
        }
    }
    
    static let appMetaDataTitleKey = "title"
    static let appMetaDataDiscussionUUIDKey = "discussionUUID"
    static let appMetaDataFileTypeKey = "fileType"
    
    enum FileType : String {
        case image
        case discussion
    }
    
    static func imageFileName(url:URL) -> String {
        return url.lastPathComponent
    }
    
    static func sizeFromFile(url:URL) -> CGSize {
        return ImageStorage.size(ofImage: imageFileName(url:url), withPath: largeImageDirectoryURL)
    }
    
    static func fullSizedImage(url:URL) -> UIImage {
        return ImageStorage.image(fromFile:imageFileName(url:url), withPath:largeImageDirectoryURL)
    }
    
    // Get the size of the icon without distorting the aspect ratio. Adapted from 
    static func boundingImageSizeFor(originalSize:CGSize, boundingSize:CGSize) -> CGSize {
        let aspectWidth = boundingSize.width / originalSize.width
        let aspectHeight = boundingSize.height / originalSize.height
        let aspectRatio = min(aspectWidth, aspectHeight)
        
        return CGSize(width: originalSize.width * aspectRatio, height: originalSize.height * aspectRatio)
    }
    
    // Also removes associated discussions.
    static func removeLocalImages(uuids:[String]) {
        for uuid in uuids {
            guard let image = Image.fetchObjectWithUUID(uuid) else {
                Log.error("Cannot find image with UUID: \(uuid)")
                return
            }
            
            Log.msg("Deleting image with uuid: \(uuid)")
            
          
            do {
                // This also removes the associated discussion.
                try image.remove()
            }
            catch (let error) {
                Log.error("Error removing image: \(error)")
            }
            
            CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        }
    }
    
    static func newJSONFile() -> SMRelativeLocalURL {
        let directoryURL = FileStorage.url(ofItem: ImageExtras.discussionsDirectoryPath)
        FileStorage.createDirectoryIfNeeded(directoryURL)
        let newFileName = FileStorage.createTempFileName(inDirectory: directoryURL?.path, withPrefix: "FileObjects", andExtension: "json")
        return SMRelativeLocalURL(withRelativePath: ImageExtras.discussionsDirectoryPath + "/" + newFileName!, toBaseURLType: .documentsDirectory)!
}
}
