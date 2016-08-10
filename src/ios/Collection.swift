//
//  Collection.swift
//  sam-mobile
//
//  Created by Emergya Hp on 19/4/16.
//
//

import Foundation


class SamCollection: NSObject {
    var id: Int
    var name: String
    var thumbnail: String?
    
    init(id: Int, name: String, thumbnail: String?) {
        self.id = id
        self.name = name
        self.thumbnail = thumbnail
    }
}

//extension SamCollection: Equatable{}

func ==(lhs: SamCollection, rhs: SamCollection) -> Bool {
    return lhs.id == rhs.id
}