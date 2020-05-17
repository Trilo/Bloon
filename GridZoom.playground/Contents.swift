//: Playground - noun: a place where people can play

import Cocoa

for i in 2 ..< 1000
{
    let widthUnits = Double(i)
    let widthPixels = 4096.0
    let minPixelsPerTick = 16.0
    let minUnitsPerTick = minPixelsPerTick * widthUnits / widthPixels

    var n = floor(ceil(log2(widthUnits)) - log2(minUnitsPerTick))
  
    var unitsPerTick = (pow(0.5, floor(log(widthUnits)/log(0.5)) + n))
    if (log2(widthUnits) == Double(Int(log2(widthUnits))))
    {
        unitsPerTick *= 2
    }
    unitsPerTick
    let pixelsPerTick = unitsPerTick * widthPixels / widthUnits
}
