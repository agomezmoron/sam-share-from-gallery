//
//  collectionCell.swift
//  sam-mobile
//
//  Created by Emergya Hp on 25/4/16.
//
//

import UIKit


class CollectionCell: UITableViewCell {
    private let tableviewCellIdentifier = "collectionSelectionCell"
    //let cell: UITableViewCell
    var collection: SamCollection?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .None
        
        //        self.imageView?.contentMode = .ScaleAspectFit
        self.imageView?.image = UIImage(named: "no-image")!.resizeImage(CGSize(width: 40, height: 40))
        self.imageView?.layer.cornerRadius = 8.0
    }
    
    func addCollection(collection: SamCollection) {
        self.collection = collection
        self.textLabel!.text = self.collection?.name
        
        
        if let url = self.collection!.thumbnail {
            guard let imgURL: NSURL = NSURL(string: url),
                let request: NSURLRequest = NSURLRequest(URL: imgURL)
                else {
                    return
            }
            
            let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
            
            session.dataTaskWithRequest(request, completionHandler:
                { (data, response, error) -> Void in
                    
                    if error == nil {
                        
                        //                        self.imageView?.contentMode = .ScaleAspectFit
                        self.imageView?.image = UIImage(data: data!)!.squareImageTo(CGSize(width: 40, height: 40))
                        //                        self.imageView?.clipsToBounds = true
                        self.imageView?.layer.cornerRadius = 8.0
                        
                        self.setNeedsLayout()
                    }
            }).resume()
        }
    }
}
