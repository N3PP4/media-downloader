import Foundation

/// Labels the source resolution without rounding higher resolutions down to 4K.
public enum ResolutionLabel {
    public static func name(for height: Int) -> String {
        switch height {
        case 4320: "8K"
        case 2160: "4K"
        default: "\(height)p"
        }
    }
}
