//
//  JZWNullTerminatedStringToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/6/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWNullTerminatedStringToken: JZWTerminatedStringToken
{
    init(label: String)
    {
        super.init(label: label, ch: 0)
    }
    
    override func copy() -> JZWToken
    {
        return JZWNullTerminatedStringToken(label: self.label)
    }
}
