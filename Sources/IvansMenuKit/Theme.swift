import Foundation

public enum Theme {
    // Colors as (r,g,b) 0...1 so Kit stays AppKit-free and testable.
    public static let accent = (r: 0.235, g: 0.725, b: 0.902)   // #3CB9E6
    public static let bottomBar = (r: 0.824, g: 0.839, b: 0.859) // #D2D6DB
    public static let clockText = (r: 0.518, g: 0.525, b: 0.541) // #84868A
    public static let bgCenter = (r: 0.957, g: 0.957, b: 0.957)  // #F4F4F4
    public static let bgEdge = (r: 0.816, g: 0.824, b: 0.851)    // #D0D2D9

    public static let columns = 4
    public static let rows = 3
    public static let pageCount = 4
    public static var slotsPerPage: Int { columns * rows }       // 12
    public static var totalSlots: Int { slotsPerPage * pageCount } // 48
    public static let tileAspect: Double = 1.82                  // width : height
    public static let tileCornerFraction: Double = 0.06
    public static let hoverScaleFrom: Double = 0.94
}
