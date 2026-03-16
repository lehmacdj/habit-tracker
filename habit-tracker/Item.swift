//
//  Item.swift
//  habit-tracker
//
//  Created by Devin Lehmacher on 3/17/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
