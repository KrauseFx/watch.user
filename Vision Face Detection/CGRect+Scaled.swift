//
//  CGRectExtension.swift
//  Vision Face Detection
//
//  Created by Pawel Chmiel on 23.06.2017.
//  Copyright © 2017 Droids On Roids. All rights reserved.
//

import Foundation
import UIKit

extension CGRect {
    func scaled(to size: CGSize) -> CGRect {
        return CGRect(
            x: self.origin.x * size.width,
            y: self.origin.y * size.height,
            width: self.size.width * size.width,
            height: self.size.height * size.height
        )
    }
}
