//
//  ShareViewController.swift
//  share
//
//  Created by Emergya Hp on 15/4/16.
//
//

import UIKit
import Social
import MobileCoreServices

extension NSMutableData {
    
    /// Append string to NSMutableData
    ///
    /// Rather than littering my code with calls to `dataUsingEncoding` to convert strings to NSData, and then add that data to the NSMutableData, this wraps it in a nice convenient little extension to NSMutableData. This converts using UTF-8.
    ///
    /// - parameter string:       The string to be added to the `NSMutableData`.
    func appendString(string: String) {
        let data = string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
        appendData(data!)
    }
}

class ShareViewController: UIViewController {
    
    private var availableCollections = [SamCollection]()
    private var selectedCollections: SamCollection?
    private var token: String?
    private var baseEndpoint: String?
    let tableviewCellIdentifier = "collectionSelectionCell"
    private let reuseIdentifier = "imageCell"
    private var images: [UIImage] = [UIImage]()
    private var compressedImages: [SamImage] = [SamImage]()
    private let serviceGroup = dispatch_group_create()
    private var assets = [AnyObject]()
    
    @IBOutlet var collectionsTable: UITableView!
    @IBOutlet weak var imagesView: UICollectionView!
    
    // Buttons
    @IBOutlet weak var postButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    // Spinners
    @IBOutlet weak var generalActivityIndicator: UIActivityIndicatorView!
    
    // Toast Area variables
    //    @IBOutlet weak var toastAreaView: UIView!
    //    @IBOutlet weak var toastMessage: UILabel!
    
    @IBAction func cancelSharing(sender: AnyObject) {
        self.extensionContext!.completeRequestReturningItems([], completionHandler: nil)
    }
    
    @IBAction func postImages(sender: AnyObject) {
        
        generalActivityIndicator.startAnimating()
        postButton.enabled = false
        //        cancelButton.enabled = false
        
        for image in compressedImages {
            uploadImage(image)
        }
        
        dispatch_group_notify(serviceGroup, dispatch_get_main_queue(), {
            self.generalActivityIndicator.stopAnimating()
            self.addAssetsToCollection(self.selectedCollections!.id)
            
            // TODO show success message
            //            self.showToast(.Success, message: "Your assets are being added to your collection, you'll have them available in a moment") { _ in
            
            self.extensionContext!.completeRequestReturningItems([], completionHandler: nil)
            //            }
        })
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        let defaults = NSUserDefaults.init(suiteName: "group.com.amoron.hubmedia.share")
        
        if let endpoint = defaults!.stringForKey("baseEndpoint") {
            baseEndpoint = endpoint
        }
        
        if let tk = defaults!.stringForKey("token") {
            token = tk
        }
    }
    
    override func didReceiveMemoryWarning() {
        print("Memory warning")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let bottomBorder = UIView.init(frame: CGRectMake(0, imagesView.frame.size.height - 1, imagesView.frame.size.width, 10))
        bottomBorder.backgroundColor = UIColor(colorLiteralRed: 209, green: 211, blue: 214, alpha: 1)
        imagesView.addSubview(bottomBorder)
        
        generalActivityIndicator.startAnimating()
        initSharing()
        
        collectionsTable.registerClass(CollectionCell.classForCoder(), forCellReuseIdentifier: tableviewCellIdentifier)
        getImages() {
            image in
            if let image = image {
                
                self.images.append(image.squareImageTo(CGSize(width: 50, height: 50)))
                self.compressedImages.append(image)
                
                self.imagesView.reloadData()
            }
        }
        
    }
    
    
    private func getImages(callback: (image: SamImage?) -> Void)  {
        
        if let extensionItems = extensionContext!.inputItems as? [NSExtensionItem] {
            
            let contentType = kUTTypeImage as String
            
            for extensionItem in extensionItems {
                if let contents = extensionItem.attachments as? [NSItemProvider] {
                    for attachment in contents {
                        if attachment.hasItemConformingToTypeIdentifier(contentType) {
                            
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                                
                                attachment.loadItemForTypeIdentifier(contentType, options: nil) {
                                    (imageProvider, error) in
                                    
                                    if error == nil {
                                        
                                        guard let url = imageProvider as? NSURL,
                                            let imageData = NSData(contentsOfURL: url) else {
                                                // If the image provider is not an URL its an NSData and we don't need to retrieve the image from URL
                                                dispatch_async(dispatch_get_main_queue()) {
                                                    callback(image: SamImage(data: (imageProvider as? NSData)!, title: (NSDate(timeIntervalSinceNow: 0)).hashValue.description)!)
                                                }
                                                return
                                        }
                                        
                                        
                                        dispatch_async(dispatch_get_main_queue()) {
                                            callback(image: SamImage(data: imageData, title: url.lastPathComponent)!)
                                        }
                                        
                                        
                                    } else {
                                        let alert = UIAlertController(title: "Error", message: "Error loading image", preferredStyle: .Alert)
                                        let action = UIAlertAction(title: "Error", style: .Cancel) { _ in
                                            self.dismissViewControllerAnimated(true, completion: nil)
                                        }
                                        
                                        alert.addAction(action)
                                        self.presentViewController(alert, animated: true, completion: nil)
                                    }
                                    
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func initSharing() -> () {
        if token != nil {
            getWorkspace()
            getCollections()
        } else {
            showErrorMessage("No HubMedia account", message: "There is not any HubMedia account, please log into HubMedia before sharing content.")
        }
    }
    
    private func showErrorMessage(title: String, message: String) {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let action = UIAlertAction(title: "Ok", style: .Cancel) { _ in
            self.dismissViewControllerAnimated(true, completion: nil)
            self.extensionContext!.cancelRequestWithError(NSError(domain: message, code: 0, userInfo: nil))
        }
        
        alert.addAction(action)
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    private func getWorkspace() -> () {
        let endpoint = "\(baseEndpoint!)/workspace/"
        
        let request = createSignedRequest(endpoint, method: "GET")
        
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        
        session.dataTaskWithRequest(request, completionHandler:
            { (data, response, error) -> Void in
                
                if let error = error {
                    self.showErrorMessage("Error getting collections", message: error.localizedDescription)
                    return
                }
                
                let statusCode = (response as! NSHTTPURLResponse).statusCode
                
                if statusCode < 200 || statusCode > 299 {
                    self.showErrorMessage("Error getting collections", message: "There was an error retrieving your collections")
                    return
                }
                
                
                if let data = data {
                    do {
                        
                        let jsonResult = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers)
                        
                        let anItem = jsonResult as! Dictionary<String, AnyObject>
                        
                        let name = anItem["name"] as! String
                        let id = anItem["id"] as! Int
                        let resources = anItem["resources"] as! [[String: AnyObject]]
                        var thumbnail: String?
                        if resources.count > 0 {
                            thumbnail = resources[0]["thumbnail_url"] as? String
                        }
                        
                        let col = SamCollection(id: id, name: name, thumbnail: thumbnail)
                        self.availableCollections.insert(col, atIndex: 0)
                        
                        
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            self.collectionsTable.reloadData()
                            self.view.sendSubviewToBack(self.collectionsTable)
                            self.generalActivityIndicator.stopAnimating()
                        })
                        
                        
                        
                    } catch let error as NSError {
                        print(error)
                    }
                }
                
        }).resume()
    }
    
    private func getCollections() -> () {
        
        let endpoint = "\(baseEndpoint!)/collections/"
        
        let request = createSignedRequest(endpoint, method: "GET")
        
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        
        session.dataTaskWithRequest(request, completionHandler:
            { (data, response, error) -> Void in
                
                if let error = error {
                    self.showErrorMessage("Error getting collections", message: error.localizedDescription)
                    return
                }
                
                let statusCode = (response as! NSHTTPURLResponse).statusCode
                
                if statusCode < 200 || statusCode > 299 {
                    self.showErrorMessage("Error getting collections", message: "There was an error retrieving your collections")
                    return
                }
                
                
                if let data = data {
                    do {
                        
                        let jsonResult = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers)
                        
                        for anItem in jsonResult as! [Dictionary<String, AnyObject>] {
                            
                            let name = anItem["name"] as! String
                            let id = anItem["id"] as! Int
                            let resources = anItem["resources"] as! [[String: AnyObject]]
                            var thumbnail: String?
                            if resources.count > 0 {
                                thumbnail = resources[0]["thumbnail_url"] as? String
                            }
                            
                            let col = SamCollection(id: id, name: name, thumbnail: thumbnail)
                            self.availableCollections.append(col)
                        }
                        
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            self.collectionsTable.reloadData()
                            self.view.sendSubviewToBack(self.collectionsTable)
                            self.generalActivityIndicator.stopAnimating()
                        })
                        
                        
                        
                    } catch let error as NSError {
                        print(error)
                    }
                }
                
        }).resume()
    }
    
    private func createSignedRequest(endpoint: String, method: String) -> NSMutableURLRequest {
        let url = NSURL(string: endpoint)!
        
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = method
        request.addValue(token!, forHTTPHeaderField: "X-Auth-Token")
        
        return request
    }
    
    private func uploadImage(image: SamImage) {
        let endpoint = "\(baseEndpoint!)/assets/staging/"
        
        let request = createSignedRequest(endpoint, method: "GET")
        
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        dispatch_group_enter(serviceGroup)
        session.dataTaskWithRequest(request, completionHandler:
            { (data, response, error) -> Void in
                
                
                if error != nil {
                    // TODO manage error
                    return
                }
                
                if let data = data {
                    do {
                        
                        guard let jsonResult = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) as? NSArray,
                            let amazonSignature =  jsonResult[0] as? [String: AnyObject]
                            else {
                                self.showErrorMessage("Error getting signature", message: "Error parsing signature")
                                return
                        }
                        self.uploadToAmazon(image, amazonSignature: amazonSignature)
                        
                        dispatch_group_leave(self.serviceGroup)
                    } catch let error as NSError {
                        print(error)
                    }
                    
                    
                }
                
        }).resume()
    }
    
    private func uploadToAmazon(image: SamImage, amazonSignature: Dictionary<String, AnyObject>) {
        let request = createAmazonRequest(image, amazonSignature: amazonSignature)
        
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        dispatch_group_enter(serviceGroup)
        
        //        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
        
        session.dataTaskWithRequest(request, completionHandler:
            {
                data, response, error in
                
                if let err = error {
                    self.showErrorMessage("Error uploading", message: err.localizedDescription)
                    return
                }
                
                let statusCode = (response as! NSHTTPURLResponse).statusCode
                
                if statusCode < 200 || statusCode > 299 {
                    self.showErrorMessage("Error uploading", message: "There was an error uploading your assets to HubMedia, please try again later")
                    return
                }
                
                let asset: [String: AnyObject] = [
                    "type": "PHOTO",
                    "version": "1.0",
                    "title": image.title!,
                    "author_name": "",
                    "provider_name": NSNull(),
                    "cache_age": NSNull(),
                    "thumbnail_url": NSNull(),
                    "thumbnail_width": 0,
                    "thumbnail_height": 0,
                    "url": NSNull(),
                    "html": NSNull(),
                    "width": 240,
                    "height": 240,
                    "id": amazonSignature["sourceId"] as! String,
                    "connectorId":  amazonSignature["connectorId"] as! String,
                    "usageRights": "SHARE"
                ]
                
                self.assets.append(asset)
                
                dispatch_group_leave(self.serviceGroup)
        }).resume()
        //        }
    }
    
    
    /// Create Amazon request
    ///
    /// - parameter imageUrl: The url of the image to be uploaded
    /// - parameter amazonSignature: All data needed to perform the upload to Amazon
    /// - parameter email:    The email address to be passed to web service
    ///
    /// - returns:            The NSURLRequest that was created
    
    private func createAmazonRequest (image: SamImage, amazonSignature: Dictionary<String, AnyObject>) -> NSURLRequest {
        // TODO create params dictionary
        let param = amazonSignature["params"] as! Dictionary<String, String>
        
        let boundary = generateBoundaryString()
        
        // Set proper URL
        let url = NSURL(string: amazonSignature["stagingURL"] as! String)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        request.HTTPBody = createBodyWithParameters(param, filePathKey: "file", image: image, boundary: boundary)
        
        return request
    }
    
    /// Create body of the multipart/form-data request
    ///
    /// - parameter parameters:   The dictionary containing keys and values to be passed to web service
    /// - parameter filePathKey:  The field name to be used when uploading files. If you supply paths, you must supply filePathKey, too.
    /// - parameter imageUrl:     The file path of the file to be uploaded
    /// - parameter boundary:     The multipart/form-data boundary
    ///
    /// - returns:                The NSData of the body of the request
    
    private func createBodyWithParameters(parameters: [String: String], filePathKey: String, image: SamImage, boundary: String) -> NSData {
        let body = NSMutableData()
        
        
        for (key, value) in parameters {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendString("\(value)\r\n")
        }
        
        
        let filename = image.title
        let data = image.jpegResized(CGSize(width: 1024, height: 1024))
        let mimetype = "image/jpeg"
        
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(filePathKey)\"; filename=\"\(filename!)\"\r\n")
        body.appendString("Content-Type: \(mimetype)\r\n\r\n")
        body.appendData(data)
        body.appendString("\r\n")
        
        body.appendString("--\(boundary)--\r\n")
        
        return body
    }
    
    /// Create boundary string for multipart/form-data request
    ///
    /// - returns:            The boundary string that consists of "Boundary-" followed by a UUID string.
    
    private func generateBoundaryString() -> String {
        return "Boundary-\(NSUUID().UUIDString)"
    }
    
    /// Determine mime type on the basis of extension of a file.
    ///
    /// This requires MobileCoreServices framework.
    ///
    /// - parameter path:         The path of the file for which we are going to determine the mime type.
    ///
    /// - returns:                Returns the mime type if successful. Returns application/octet-stream if unable to determine mime type.
    
    private func mimeTypeForPath(path: String) -> String {
        let url = NSURL(fileURLWithPath: path)
        let pathExtension = url.pathExtension
        
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension! as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream";
    }
    
    private func addAssetsToCollection(selectedCollection: Int) {
        let endpoint = "\(baseEndpoint!)/collections/\(selectedCollection)/assets"
        
        let request = createSignedRequest(endpoint, method: "POST")
        let session = NSURLSession.sharedSession()
        
        do {
            request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(assets, options: .PrettyPrinted)
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            session.dataTaskWithRequest(request, completionHandler: {
                data, response, error in
                
                if error != nil {
                    // TODO Handle error
                    print(error)
                    return
                }
                
                print(response)
            }).resume()
            
        } catch let error as NSError {
            print(error)
        }
        
    }
}

extension ShareViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return availableCollections.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let collectionCell = tableView.dequeueReusableCellWithIdentifier(self.tableviewCellIdentifier, forIndexPath: indexPath) as! CollectionCell
        
        collectionCell.addCollection(availableCollections[indexPath.row])
        
        if selectedCollections == collectionCell.collection {
            collectionCell.accessoryType = .Checkmark
        } else {
            collectionCell.accessoryType = .None
        }
        
        return collectionCell
    }
}

extension ShareViewController: UICollectionViewDataSource {
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell:ImageCell = imagesView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! ImageCell
        
        cell.Image.image = images[indexPath.row]
        cell.layer.cornerRadius = 8.0
        
        
        // Configure the cell
        return cell
    }
}

extension ShareViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if !generalActivityIndicator.isAnimating() {
            let cell = tableView.cellForRowAtIndexPath(indexPath) as! CollectionCell
            
            if cell.collection == selectedCollections {
                selectedCollections = nil
                cell.accessoryType = .None
                postButton.enabled = false
            } else {
                tableView.visibleCells.forEach({ visibleCell in
                    visibleCell.accessoryType = .None
                })
                
                selectedCollections = cell.collection
                cell.accessoryType = .Checkmark
                postButton.enabled = true
            }
            
            tableView.reloadData()
            view.sendSubviewToBack(tableView)
        }
    }
}
