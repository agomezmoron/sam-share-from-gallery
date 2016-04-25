//
//  CollectionsViewController.swift
//  sam-mobile
//
//  Created by Emergya Hp on 19/4/16.
//
//

import UIKit

//@objc(CollectionsViewControllerDelegate)
protocol CollectionsViewControllerDelegate {
    func collectionSelection(
        sender: CollectionsViewController,
        selectedValue: SamCollection)
}


class CollectionsViewController: UITableViewController {
    var availableCollections = [SamCollection](count: 1, repeatedValue: SamCollection(id: nil, name: "Workspace"))
    let tableviewCellIdentifier = "collectionSelectionCell"
    var selectedCollection: SamCollection?
    var delegate: CollectionsViewControllerDelegate?
    var token: String = ""
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // Initialize the tableview
    override init(style: UITableViewStyle) {
        super.init(style: style)
        tableView.registerClass(UITableViewCell.classForCoder(),
                                forCellReuseIdentifier: tableviewCellIdentifier)
        title = "Choose Collection"
    }
    
//    init(style: UITableViewStyle, token: String) {
//        super.init(style: style)
//        tableView.registerClass(UITableViewCell.classForCoder(),
//                                forCellReuseIdentifier: tableviewCellIdentifier)
//        title = "Choose Collection"
//        self.token = token
//        selectedCollection = availableCollections[0]
//        getCollections()
//    }
//    
//    func getCollections() -> () {
//        
//        let endpoint = "http://dev.hubmedia.hpengage.com/hubmedia/api/rest/collections/"
//        let url = NSURL(string: endpoint)!
//        
//        let request = NSMutableURLRequest(URL: url)
//        request.HTTPMethod = "GET"
//        request.addValue(token, forHTTPHeaderField: "X-Auth-Token")
//        
//        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
//        let session = NSURLSession(configuration: config)
//        
//        session.dataTaskWithRequest(request, completionHandler:
//            { (data, response, error) -> Void in
//                
//                if let data = data {
//                    do {
//                        
//                        let jsonResult = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers)
//                        
//                        for anItem in jsonResult as! [Dictionary<String, AnyObject>] {
//                            
//                            let name = anItem["name"] as! String
//                            let id = anItem["id"] as! Int
//                            
//                            let col = SamCollection(id: id, name: name)
//                            self.availableCollections.append(col)
//                        }
//                        
//                        self.tableView.reloadData()
//
//                        
//                    } catch let error as NSError {
//                        
//                        print(error)
//                        
//                    }
//                }
//                
//        }).resume()
//    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return availableCollections.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(tableviewCellIdentifier, forIndexPath: indexPath) as UITableViewCell
        
        let text = availableCollections[indexPath.row].name
        cell.textLabel!.text = text
        
        if text == selectedCollection!.name {
            cell.accessoryType = .Checkmark
        } else {
            cell.accessoryType = .None
        }
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let theDelegate = delegate {
            selectedCollection = availableCollections[indexPath.row]
            theDelegate.collectionSelection(self, selectedValue: selectedCollection!)
        }
    }
}
