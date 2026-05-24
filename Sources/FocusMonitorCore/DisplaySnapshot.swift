import CoreGraphics

public struct DisplaySnapshot: Equatable, Identifiable {
    public let id: String
    public let frame: CGRect
    public let isMain: Bool

    public init(id: String, frame: CGRect, isMain: Bool) {
        self.id = id
        self.frame = frame
        self.isMain = isMain
    }
}
