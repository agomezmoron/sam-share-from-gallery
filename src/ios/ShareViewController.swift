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

let baseEndpoint = "http://dev.hubmedia.hpengage.com/hubmedia/api/rest"

class ShareViewController: SLComposeServiceViewController, CollectionsViewControllerDelegate {
    
    var availableCollections = [SamCollection](count: 1, repeatedValue: SamCollection(id: nil, name: "Workspace"))
    var selectedCollection = SamCollection(id: nil, name: "Workspace")
    var token: String?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        initSharing()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func initSharing() -> () {
        let fileManager = NSFileManager.defaultManager()
        
        let appGroupDirectoryPath = fileManager.containerURLForSecurityApplicationGroupIdentifier("group.com.amoron.hubmedia.share")
        let keyFilePath = appGroupDirectoryPath!.URLByAppendingPathComponent("key.txt").path
        
        
        //////// Mocked area
        let text = "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJpZ29uemFsZXpAZW1lcmd5YS5jb20iLCJleHAiOjE0NjEyNDk2NTl9.4Zdh8UklqcomGkcdhe7gOwiBK-VuKjCD1MGm-5z0FbDrfTLGsdwuxUrbIdInxgQcpMeK2a7xuQ2GkACFVBhFRg"
        
        //writing
        do {
            try text.writeToFile(keyFilePath!, atomically: false, encoding: NSUTF8StringEncoding)
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        ///// End of mocked area
        
        //reading
        do {
            token = try String(contentsOfFile: keyFilePath!, encoding: NSUTF8StringEncoding)
            selectedCollection = availableCollections[0]
            getCollections()
            
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
    
    func getCollections() -> () {
        
        let endpoint = baseEndpoint + "/collections/"
        let url = NSURL(string: endpoint)!
        
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "GET"
        request.addValue(token!, forHTTPHeaderField: "X-Auth-Token")
        
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: config)
        
        session.dataTaskWithRequest(request, completionHandler:
            { (data, response, error) -> Void in
                
                if let data = data {
                    do {
                        
                        let jsonResult = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers)
                        
                        for anItem in jsonResult as! [Dictionary<String, AnyObject>] {
                            
                            let name = anItem["name"] as! String
                            let id = anItem["id"] as! Int
                            
                            let col = SamCollection(id: id, name: name)
                            self.availableCollections.append(col)
                        }
                    } catch let error as NSError {
                        print(error)
                    }
                }
                
        }).resume()
    }
    
    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }
    
    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        if let content = extensionContext!.inputItems[0] as? NSExtensionItem {
            let contentType = kUTTypeImage as String
            
            if let contents = content.attachments as? [NSItemProvider] {
                for attachment in contents {
                    if attachment.hasItemConformingToTypeIdentifier(contentType) {
                        attachment.loadItemForTypeIdentifier(contentType, options: nil) {
                            data, error in
                            
                            let imageUrl = data as! NSURL
                            
                            self.uploadImage(imageUrl)
                            
                            // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
                            self.extensionContext!.completeRequestReturningItems([], completionHandler: nil)
                        }
                    }
                }
            }
        }
    }
    
    func uploadImage(imageUrl: NSURL) {
        let endpoint = "\(baseEndpoint)/assets/staging/"
        let url = NSURL(string: endpoint)!
        
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "GET"
        request.addValue(token!, forHTTPHeaderField: "X-Auth-Token")
        
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: config)
        
        session.dataTaskWithRequest(request, completionHandler:
            { (data, response, error) -> Void in
                
                
                if error != nil {
                    // TODO manage error
                    return
                }
                
                if let data = data {
                    do {
                        
                        let jsonResult = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers)
                        
                        let amazonSignature = jsonResult[0] as! Dictionary<String, AnyObject>
                        
                        self.uploadToAmazon(imageUrl, amazonSignature: amazonSignature)
                    } catch let error as NSError {
                        print(error)
                    }
                }
                
        }).resume()
    }
    
    func uploadToAmazon(imageUrl: NSURL, amazonSignature: Dictionary<String, AnyObject>) {
        let request = createAmazonRequest(imageUrl, amazonSignature: amazonSignature)
        
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: config)
        
        session.dataTaskWithRequest(request, completionHandler:
            {
                data, response, error in
                
                if error != nil {
                    // TODO manage error 
                    return
                }
                
                self.addAssetToCollection(imageUrl.lastPathComponent!, sourceId: amazonSignature["sourceId"] as! String, connectorId: amazonSignature["connectorId"] as! String)
                
                
                
        }).resume()
    }
    
    ///////
    
    
    // TODO Perform request
    
    /// Create request
    ///
    /// - parameter userid:   The userid to be passed to web service
    /// - parameter password: The password to be passed to web service
    /// - parameter email:    The email address to be passed to web service
    ///
    /// - returns:            The NSURLRequest that was created
    
    func createAmazonRequest (imageUrl: NSURL, amazonSignature: Dictionary<String, AnyObject>) -> NSURLRequest {
        // TODO create params dictionary
        let param = amazonSignature["params"] as! Dictionary<String, String>
        
        let boundary = generateBoundaryString()
        
        // Set proper URL
        let url = NSURL(string: amazonSignature["stagingURL"] as! String)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
//        let path1 = NSBundle.mainBundle().pathForResource("image1", ofType: "png") as String!
//        let path1 = imageUrl.path
        request.HTTPBody = createBodyWithParameters(param, filePathKey: "file", imageUrl: imageUrl, boundary: boundary)
        
        return request
    }
    
    /// Create body of the multipart/form-data request
    ///
    /// - parameter parameters:   The optional dictionary containing keys and values to be passed to web service
    /// - parameter filePathKey:  The optional field name to be used when uploading files. If you supply paths, you must supply filePathKey, too.
    /// - parameter paths:        The optional array of file paths of the files to be uploaded
    /// - parameter boundary:     The multipart/form-data boundary
    ///
    /// - returns:                The NSData of the body of the request
    
    func createBodyWithParameters(parameters: [String: String]?, filePathKey: String?, imageUrl: NSURL, boundary: String) -> NSData {
        let body = NSMutableData()
        
        if parameters != nil {
            for (key, value) in parameters! {
                body.appendString("--\(boundary)\r\n")
                body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.appendString("\(value)\r\n")
            }
        }
        
        let filename = imageUrl.lastPathComponent
        let data = NSData(contentsOfURL: imageUrl)!
        let mimetype = mimeTypeForPath(imageUrl.path!)
        
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(filePathKey!)\"; filename=\"\(filename!)\"\r\n")
        body.appendString("Content-Type: \(mimetype)\r\n\r\n")
        body.appendData(data)
        body.appendString("\r\n")
        
        
//        if paths != nil {
//            for path in paths! {
//                let url = NSURL(fileURLWithPath: path)
//                let filename = url.lastPathComponent
//                let data = NSData(contentsOfURL: url)!
//                let mimetype = mimeTypeForPath(path)
//                
//                body.appendString("--\(boundary)\r\n")
//                body.appendString("Content-Disposition: form-data; name=\"\(filePathKey!)\"; filename=\"\(filename!)\"\r\n")
//                body.appendString("Content-Type: \(mimetype)\r\n\r\n")
//                body.appendData(data)
//                body.appendString("\r\n")
//            }
//        }
        
        body.appendString("--\(boundary)--\r\n")
        return body
    }
    
    /// Create boundary string for multipart/form-data request
    ///
    /// - returns:            The boundary string that consists of "Boundary-" followed by a UUID string.
    
    func generateBoundaryString() -> String {
        return "Boundary-\(NSUUID().UUIDString)"
    }
    
    /// Determine mime type on the basis of extension of a file.
    ///
    /// This requires MobileCoreServices framework.
    ///
    /// - parameter path:         The path of the file for which we are going to determine the mime type.
    ///
    /// - returns:                Returns the mime type if successful. Returns application/octet-stream if unable to determine mime type.
    
    func mimeTypeForPath(path: String) -> String {
        let url = NSURL(fileURLWithPath: path)
        let pathExtension = url.pathExtension
        
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension! as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream";
    }
    
    func addAssetToCollection(filename: String, sourceId: String, connectorId: String) {
        let endpoint = "\(baseEndpoint)/collections/\(selectedCollection.id!)/assets"
        
        let asset: [String: AnyObject] = [
            "type": "PHOTO",
            "version": "1.0",
            "title": filename,
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
            "id": sourceId,
            "connectorId": connectorId
        ]
        
        let assetsList = [asset]
        
        let request = NSMutableURLRequest(URL: NSURL(string: endpoint)!)
        let session = NSURLSession.sharedSession()
        
        request.HTTPMethod = "POST"
        
        
        do {
            request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(assetsList, options: NSJSONWritingOptions.PrettyPrinted)
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue(token!, forHTTPHeaderField: "X-Auth-Token")
            
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

    
    override func configurationItems() -> [AnyObject]! {
        
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return [collectionsConfigurationItem]
    }
    
    lazy var collectionsConfigurationItem: SLComposeSheetConfigurationItem = {
        let item = SLComposeSheetConfigurationItem()
        
        item.title = "Collection"
        item.value = self.selectedCollection.name
        item.tapHandler = self.showCollectionSelection
        
        return item
    }()
    
    // Shows the collection selection view
    func showCollectionSelection() {
        let controller = CollectionsViewController(style: .Plain)
        controller.availableCollections = availableCollections
        controller.selectedCollection = selectedCollection
        controller.delegate = self
        pushConfigurationViewController(controller)
    }
    
    // One the user selects a configuration item (color), we remember the value and pop
    // the color selection view controller
    func collectionSelection(sender: CollectionsViewController, selectedValue: SamCollection) {
        collectionsConfigurationItem.value = selectedValue.name
        selectedCollection = selectedValue
        popConfigurationViewController()
    }    
}