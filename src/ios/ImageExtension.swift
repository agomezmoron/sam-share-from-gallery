//
//  ImageExtension.swift
//  sam-mobile
//
//  Created by Emergya Hp on 28/4/16.
//
//

import Foundation
import UIKit

class SamImage: UIImage {
    var title: String?
    
    init?(data: NSData, title: String?) {
        self.title = title
        super.init(data: data)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    required convenience init(imageLiteral name: String) {
        fatalError("init(imageLiteral:) has not been implemented")
    }
    
    
}

extension UIImage {
    
    func jpegResized(size: CGSize) -> NSData {
        return UIImageJPEGRepresentation(self.resizeImage(size), 0.8)!
        //        return NSData()
    }
    
    func squareImageTo(size: CGSize) -> UIImage {
        return self.squareImage().resizeImage(size)
    }
    
    func squareImage() -> UIImage {
        let image = self
        let originalWidth  = image.size.width
        let originalHeight = image.size.height
        var x: CGFloat = 0.0
        var y: CGFloat = 0.0
        var edge: CGFloat = 0.0
        
        if (originalWidth > originalHeight) {
            // landscape
            edge = originalHeight
            x = (originalWidth - edge) / 2.0
            y = 0.0
            
        } else if (originalHeight > originalWidth) {
            // portrait
            edge = originalWidth
            x = 0.0
            y = (originalHeight - originalWidth) / 2.0
        } else {
            // square
            edge = originalWidth
        }
        
        let cropSquare = CGRectMake(x, y, edge, edge)
        let imageRef = CGImageCreateWithImageInRect(image.CGImage, cropSquare);
        
        return UIImage(CGImage: imageRef!, scale: UIScreen.mainScreen().scale, orientation: image.imageOrientation)
    }
    
    func resizeImage(targetSize: CGSize) -> UIImage {
        let image = self
        let size = image.size
        
        let widthRatio  = targetSize.width  / image.size.width
        let heightRatio = targetSize.height / image.size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSizeMake(size.width * heightRatio, size.height * heightRatio)
        } else {
            newSize = CGSizeMake(size.width * widthRatio,  size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRectMake(0, 0, newSize.width, newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.drawInRect(rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
}