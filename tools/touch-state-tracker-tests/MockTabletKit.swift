public struct TouchContact: Equatable {
    public let id: Int
    public let x: Int
    public let y: Int
    public let contactArea: Int?

    public init(id: Int, x: Int, y: Int, contactArea: Int?) {
        self.id = id
        self.x = x
        self.y = y
        self.contactArea = contactArea
    }
}
