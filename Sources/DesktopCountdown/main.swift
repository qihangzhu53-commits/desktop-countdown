import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

private func qaLog(_ message: String) {
    guard ProcessInfo.processInfo.environment["DESKTOP_COUNTDOWN_TEST_MODE"] == "1" else { return }
    FileHandle.standardError.write(Data("[DesktopCountdown QA] \(message)\n".utf8))
}

private enum WidgetKind: Hashable {
    case graduation
    case springFestival
    case custom(id: String, title: String, targetDate: Date, icon: String, theme: Int)

    static let builtIns: [WidgetKind] = [.graduation, .springFestival]

    var id: String {
        switch self {
        case .graduation: return "graduation"
        case .springFestival: return "springFestival"
        case .custom(let id, _, _, _, _): return id
        }
    }

    var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }

    var isGraduation: Bool { id == "graduation" }

    private var themeValue: Int {
        switch self {
        case .graduation: return 0
        case .springFestival: return 1
        case .custom(_, _, _, _, let theme): return theme
        }
    }

    var title: String {
        switch self {
        case .graduation: return "毕业倒计时"
        case .springFestival: return "2027 元旦倒计时"
        case .custom(_, let title, _, _, _): return title
        }
    }

    var shortTitle: String {
        switch self {
        case .graduation: return "距离毕业"
        case .springFestival: return "距离元旦"
        case .custom(_, let title, _, _, _): return "距离\(title)"
        }
    }

    var icon: String {
        switch self {
        case .graduation: return "🎓"
        case .springFestival: return "🎆"
        case .custom(_, _, _, let icon, _): return icon
        }
    }

    var accent: NSColor {
        switch self {
        case .graduation: return NSColor(calibratedRed: 0.22, green: 0.78, blue: 0.96, alpha: 1)
        case .springFestival: return NSColor(calibratedRed: 1.0, green: 0.70, blue: 0.25, alpha: 1)
        case .custom:
            switch themeValue {
            case 2: return NSColor(calibratedRed: 0.82, green: 0.56, blue: 1.0, alpha: 1)
            case 3: return NSColor(calibratedRed: 0.38, green: 0.92, blue: 0.62, alpha: 1)
            default: return NSColor(calibratedRed: 0.42, green: 0.72, blue: 1.0, alpha: 1)
            }
        }
    }

    var defaultGradient: [NSColor] {
        switch self {
        case .graduation:
            return [
                NSColor(calibratedRed: 0.08, green: 0.26, blue: 0.52, alpha: 1),
                NSColor(calibratedRed: 0.05, green: 0.62, blue: 0.72, alpha: 1)
            ]
        case .springFestival:
            return [
                NSColor(calibratedRed: 0.48, green: 0.035, blue: 0.08, alpha: 1),
                NSColor(calibratedRed: 0.92, green: 0.18, blue: 0.08, alpha: 1)
            ]
        case .custom:
            switch themeValue {
            case 2:
                return [NSColor(calibratedRed: 0.20, green: 0.08, blue: 0.46, alpha: 1), NSColor(calibratedRed: 0.56, green: 0.20, blue: 0.72, alpha: 1)]
            case 3:
                return [NSColor(calibratedRed: 0.04, green: 0.30, blue: 0.22, alpha: 1), NSColor(calibratedRed: 0.08, green: 0.62, blue: 0.44, alpha: 1)]
            default:
                return [NSColor(calibratedRed: 0.08, green: 0.18, blue: 0.46, alpha: 1), NSColor(calibratedRed: 0.16, green: 0.46, blue: 0.82, alpha: 1)]
            }
        }
    }

    var targetDate: Date {
        switch self {
        case .graduation: return Preferences.shared.graduationDate
        case .springFestival: return Preferences.shared.springFestivalDate
        case .custom(_, _, let date, _, _): return date
        }
    }
}

private struct CustomCountdownRecord: Codable {
    var id: String
    var title: String
    var targetDate: Date
    var icon: String
    var theme: Int
}

private enum PreferenceKey {
    static let graduationDate = "graduationDate"
    static let alwaysOnTop = "alwaysOnTop"
    static let positionsLocked = "positionsLocked"
    static let hasShownWelcome = "hasShownWelcome"
    static let customCountdowns = "customCountdowns"

    static func frameOrigin(for kind: WidgetKind) -> String { "frameOrigin.\(kind.id)" }
    static func cardSize(for kind: WidgetKind) -> String { "cardSize.\(kind.id)" }
    static func photoPath(for kind: WidgetKind) -> String { "photoPath.\(kind.id)" }
    static func hidden(for kind: WidgetKind) -> String { "hidden.\(kind.id)" }
}

private final class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            PreferenceKey.alwaysOnTop: false,
            PreferenceKey.positionsLocked: false
        ])
    }

    var graduationDate: Date {
        get {
            if let saved = defaults.string(forKey: PreferenceKey.graduationDate) {
                let parts = saved.split(separator: "-").compactMap { Int($0) }
                if parts.count == 3 {
                    return date(year: parts[0], month: parts[1], day: parts[2])
                }
            }

            if let legacyDate = defaults.object(forKey: PreferenceKey.graduationDate) as? Date {
                let components = localGregorianCalendar.dateComponents([.year, .month, .day], from: legacyDate)
                if let year = components.year, let month = components.month, let day = components.day {
                    let migrated = date(year: year, month: month, day: day)
                    defaults.set(String(format: "%04d-%02d-%02d", year, month, day), forKey: PreferenceKey.graduationDate)
                    return migrated
                }
            }

            return date(year: 2027, month: 6, day: 30)
        }
        set {
            let components = localGregorianCalendar.dateComponents([.year, .month, .day], from: newValue)
            guard let year = components.year, let month = components.month, let day = components.day else { return }
            defaults.set(String(format: "%04d-%02d-%02d", year, month, day), forKey: PreferenceKey.graduationDate)
        }
    }

    var springFestivalDate: Date {
        date(year: 2027, month: 1, day: 1)
    }

    var localGregorianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar
    }

    func startOfLocalGregorianDay(for date: Date) -> Date {
        localGregorianCalendar.startOfDay(for: date)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = localGregorianCalendar
        components.timeZone = TimeZone.current
        components.year = year
        components.month = month
        components.day = day
        return components.date ?? Date()
    }

    var alwaysOnTop: Bool {
        get { defaults.bool(forKey: PreferenceKey.alwaysOnTop) }
        set { defaults.set(newValue, forKey: PreferenceKey.alwaysOnTop) }
    }

    var positionsLocked: Bool {
        get { defaults.bool(forKey: PreferenceKey.positionsLocked) }
        set { defaults.set(newValue, forKey: PreferenceKey.positionsLocked) }
    }

    var hasShownWelcome: Bool {
        get { defaults.bool(forKey: PreferenceKey.hasShownWelcome) }
        set { defaults.set(newValue, forKey: PreferenceKey.hasShownWelcome) }
    }

    func targetDate(for kind: WidgetKind) -> Date {
        kind.targetDate
    }

    func origin(for kind: WidgetKind) -> NSPoint? {
        guard let string = defaults.string(forKey: PreferenceKey.frameOrigin(for: kind)) else { return nil }
        return NSPointFromString(string)
    }

    func setOrigin(_ origin: NSPoint, for kind: WidgetKind) {
        defaults.set(NSStringFromPoint(origin), forKey: PreferenceKey.frameOrigin(for: kind))
    }

    func size(for kind: WidgetKind) -> NSSize? {
        guard let string = defaults.string(forKey: PreferenceKey.cardSize(for: kind)) else { return nil }
        let size = NSSizeFromString(string)
        guard size.width > 0, size.height > 0 else { return nil }
        return size
    }

    func setSize(_ size: NSSize, for kind: WidgetKind) {
        defaults.set(NSStringFromSize(size), forKey: PreferenceKey.cardSize(for: kind))
    }

    func clearSize(for kind: WidgetKind) {
        defaults.removeObject(forKey: PreferenceKey.cardSize(for: kind))
    }

    func clearSizes() {
        allKinds().forEach { clearSize(for: $0) }
    }

    func clearOrigins() {
        allKinds().forEach { defaults.removeObject(forKey: PreferenceKey.frameOrigin(for: $0)) }
    }

    func photoPath(for kind: WidgetKind) -> String? {
        defaults.string(forKey: PreferenceKey.photoPath(for: kind))
    }

    func setPhotoPath(_ path: String?, for kind: WidgetKind) {
        defaults.set(path, forKey: PreferenceKey.photoPath(for: kind))
    }

    func isHidden(_ kind: WidgetKind) -> Bool {
        defaults.bool(forKey: PreferenceKey.hidden(for: kind))
    }

    func setHidden(_ hidden: Bool, for kind: WidgetKind) {
        defaults.set(hidden, forKey: PreferenceKey.hidden(for: kind))
    }

    func allKinds() -> [WidgetKind] {
        WidgetKind.builtIns + customRecords().map { .custom(id: $0.id, title: $0.title, targetDate: $0.targetDate, icon: $0.icon, theme: $0.theme) }
    }

    func customRecords() -> [CustomCountdownRecord] {
        guard let data = defaults.data(forKey: PreferenceKey.customCountdowns),
              let records = try? JSONDecoder().decode([CustomCountdownRecord].self, from: data) else { return [] }
        return records
    }

    @discardableResult
    func addCustom(title: String, targetDate: Date, icon: String, theme: Int) -> WidgetKind {
        let record = CustomCountdownRecord(id: UUID().uuidString, title: title, targetDate: targetDate, icon: icon, theme: theme)
        var records = customRecords()
        records.append(record)
        saveCustomRecords(records)
        return .custom(id: record.id, title: record.title, targetDate: record.targetDate, icon: record.icon, theme: record.theme)
    }

    func updateCustom(id: String, title: String, targetDate: Date, icon: String, theme: Int) {
        var records = customRecords()
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index] = CustomCountdownRecord(id: id, title: title, targetDate: targetDate, icon: icon, theme: theme)
        saveCustomRecords(records)
    }

    func removeCustom(id: String) {
        saveCustomRecords(customRecords().filter { $0.id != id })
    }

    private func saveCustomRecords(_ records: [CustomCountdownRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: PreferenceKey.customCountdowns)
    }
}

private struct CountdownValue {
    let days: Int
    let hours: Int
    let minutes: Int
    let seconds: Int
    let isToday: Bool
    let isPast: Bool

    init(target: Date, now: Date = Date()) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        isToday = calendar.isDate(target, inSameDayAs: now)
        isPast = target <= now && !isToday

        if target > now {
            let components = calendar.dateComponents([.day, .hour, .minute, .second], from: now, to: target)
            days = max(0, components.day ?? 0)
            hours = max(0, components.hour ?? 0)
            minutes = max(0, components.minute ?? 0)
            seconds = max(0, components.second ?? 0)
        } else {
            days = 0
            hours = 0
            minutes = 0
            seconds = 0
        }
    }
}

private protocol CountdownCardViewDelegate: AnyObject {
    var positionsAreLocked: Bool { get }
    func cardViewChoosePhoto(_ view: CountdownCardView)
    func cardViewUsePhoto(_ view: CountdownCardView, from url: URL)
    func cardViewShowMenu(_ view: CountdownCardView, event: NSEvent)
    func cardViewDidFinishDragging(_ view: CountdownCardView)
    func cardViewDidFinishResizing(_ view: CountdownCardView)
}

private final class CountdownCardView: NSView {
    weak var delegate: CountdownCardViewDelegate?
    var kind: WidgetKind
    var targetDate: Date
    var backgroundImage: NSImage?
    private var isHovering = false
    private var isReceivingDrop = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy.MM.dd · EEEE"
        return formatter
    }()

    init(frame: NSRect, kind: WidgetKind, targetDate: Date, backgroundImage: NSImage?) {
        self.kind = kind
        self.targetDate = targetDate
        self.backgroundImage = backgroundImage
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.masksToBounds = true
        registerForDraggedTypes([.fileURL])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        updateAccessibilityText()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: delegate?.positionsAreLocked == true ? .arrow : .openHand)
        addCursorRect(resizeHandleRect, cursor: .resizeLeftRight)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if resizeHandleRect.contains(point) {
            resizeWindow(with: event)
            return
        }
        if optionsButtonRect.contains(point) {
            delegate?.cardViewShowMenu(self, event: event)
            return
        }
        if event.clickCount >= 2 {
            delegate?.cardViewChoosePhoto(self)
            return
        }
        guard delegate?.positionsAreLocked != true else { return }
        window?.performDrag(with: event)
    }

    private func resizeWindow(with initialEvent: NSEvent) {
        guard let window else { return }
        let startingFrame = window.frame
        let startingMouse = NSEvent.mouseLocation
        let minimumWidth: CGFloat = 235
        let maximumWidth: CGFloat = 840
        let aspectRatio = WidgetController.cardSize.width / WidgetController.cardSize.height

        while let event = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if event.type == .leftMouseUp { break }
            let mouse = NSEvent.mouseLocation
            let horizontalScale = (startingFrame.width + mouse.x - startingMouse.x) / startingFrame.width
            let verticalScale = (startingFrame.height - (mouse.y - startingMouse.y)) / startingFrame.height
            let scale = abs(horizontalScale - 1) >= abs(verticalScale - 1) ? horizontalScale : verticalScale
            let width = min(maximumWidth, max(minimumWidth, startingFrame.width * scale))
            let height = width / aspectRatio
            let frame = NSRect(x: startingFrame.minX, y: startingFrame.maxY - height, width: width, height: height)
            window.setFrame(frame, display: true)
        }
        delegate?.cardViewDidFinishResizing(self)
    }

    override func rightMouseDown(with event: NSEvent) {
        delegate?.cardViewShowMenu(self, event: event)
    }

    override func keyDown(with event: NSEvent) {
        guard let window else { return }
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
        var origin = window.frame.origin
        switch event.keyCode {
        case 123: origin.x -= step
        case 124: origin.x += step
        case 125: origin.y -= step
        case 126: origin.y += step
        case 36, 49:
            let menuPoint = convert(NSPoint(x: bounds.maxX - 24, y: bounds.maxY - 24), to: nil)
            if let synthetic = NSEvent.mouseEvent(
                with: .rightMouseDown,
                location: menuPoint,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 0
            ) {
                delegate?.cardViewShowMenu(self, event: synthetic)
            }
            return
        default:
            super.keyDown(with: event)
            return
        }
        guard delegate?.positionsAreLocked != true else { return }
        window.setFrameOrigin(origin)
        delegate?.cardViewDidFinishDragging(self)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard firstImageURL(from: sender) != nil else { return [] }
        isReceivingDrop = true
        needsDisplay = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isReceivingDrop = false
        needsDisplay = true
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        firstImageURL(from: sender) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer {
            isReceivingDrop = false
            needsDisplay = true
        }
        guard let url = firstImageURL(from: sender) else { return false }
        delegate?.cardViewUsePhoto(self, from: url)
        return true
    }

    private func firstImageURL(from sender: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL] else {
            return nil
        }
        return urls
            .compactMap { $0 as URL }
            .first(where: isImageURL)
    }

    private func isImageURL(_ url: URL) -> Bool {
        if let values = try? url.resourceValues(forKeys: [.contentTypeKey]),
           let contentType = values.contentType {
            return contentType.conforms(to: .image)
        }
        return UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
    }

    private var optionsButtonRect: NSRect {
        NSRect(x: bounds.maxX - 48, y: bounds.maxY - 48, width: 34, height: 34)
    }

    private var resizeHandleRect: NSRect {
        NSRect(x: bounds.maxX - 32, y: 0, width: 32, height: 32)
    }

    func refresh() {
        updateAccessibilityText()
        needsDisplay = true
    }

    private func updateAccessibilityText() {
        let value = CountdownValue(target: targetDate)
        let status: String
        if value.isToday {
            status = "就是今天"
        } else if value.isPast {
            status = "日期已到"
        } else {
            status = "还有 \(value.days) 天 \(value.hours) 小时"
        }
        setAccessibilityLabel("\(kind.title)，\(status)。可移动和调整大小的卡片窗口。")
        setAccessibilityHelp("拖动右下角调整大小，双击更换照片，右键打开操作菜单。")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let roundedPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 20, yRadius: 20)
        context.saveGState()
        roundedPath.addClip()

        if let image = backgroundImage {
            drawAspectFill(image, in: bounds)
        } else {
            NSGradient(colors: kind.defaultGradient)?.draw(in: bounds, angle: 18)
            drawDefaultDecoration()
        }

        NSColor.black.withAlphaComponent(backgroundImage == nil ? 0.12 : 0.24).setFill()
        bounds.fill()

        if let overlay = NSGradient(colorsAndLocations:
            (NSColor.black.withAlphaComponent(0.78), 0.0),
            (NSColor.black.withAlphaComponent(0.25), 0.58),
            (NSColor.black.withAlphaComponent(0.10), 1.0)
        ) {
            overlay.draw(in: bounds, angle: 90)
        }

        drawContent()

        if isReceivingDrop {
            kind.accent.withAlphaComponent(0.28).setFill()
            bounds.fill()
            let dropPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 9, dy: 9), xRadius: 14, yRadius: 14)
            dropPath.lineWidth = 2
            kind.accent.setStroke()
            dropPath.setLineDash([7, 5], count: 2, phase: 0)
            dropPath.stroke()
            drawCentered("松开以更换照片", y: bounds.midY - 10, font: .systemFont(ofSize: 17, weight: .semibold), color: .white)
        }

        context.restoreGState()

        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.75, dy: 0.75), xRadius: 20, yRadius: 20)
        border.lineWidth = isHovering ? 1.5 : 1
        (isHovering ? kind.accent.withAlphaComponent(0.72) : NSColor.white.withAlphaComponent(0.22)).setStroke()
        border.stroke()
    }

    private func drawAspectFill(_ image: NSImage, in rect: NSRect) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let destination = NSRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        image.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    }

    private func drawDefaultDecoration() {
        let circles: [(NSPoint, CGFloat, CGFloat)] = [
            (NSPoint(x: bounds.width * 0.84, y: bounds.height * 0.74), 84, 0.10),
            (NSPoint(x: bounds.width * 0.72, y: bounds.height * 0.22), 54, 0.08),
            (NSPoint(x: bounds.width * 0.98, y: bounds.height * 0.18), 110, 0.07)
        ]
        for (center, radius, alpha) in circles {
            NSColor.white.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
        }
    }

    private func drawContent() {
        let value = CountdownValue(target: targetDate)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail

        let iconAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18),
            .foregroundColor: NSColor.white
        ]
        kind.icon.draw(at: NSPoint(x: 18, y: bounds.maxY - 39), withAttributes: iconAttributes)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        kind.shortTitle.draw(in: NSRect(x: 45, y: bounds.maxY - 39, width: bounds.width - 103, height: 22), withAttributes: titleAttributes)

        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.75)
        ]
        dateFormatter.string(from: targetDate).draw(at: NSPoint(x: 19, y: bounds.maxY - 62), withAttributes: dateAttributes)

        let mainText: String
        let unitText: String
        if value.isToday {
            mainText = "就是今天"
            unitText = "🎉"
        } else if value.isPast {
            mainText = kind.isGraduation ? "毕业快乐" : "新年快乐"
            unitText = "✨"
        } else {
            mainText = "\(value.days)"
            unitText = "天"
        }

        let mainFontSize: CGFloat
        if value.isToday || value.isPast {
            mainFontSize = 43
        } else {
            mainFontSize = value.days >= 1_000 ? 50 : 64
        }
        let mainFont = NSFont.monospacedDigitSystemFont(ofSize: mainFontSize, weight: .heavy)
        let mainAttributes: [NSAttributedString.Key: Any] = [
            .font: mainFont,
            .foregroundColor: NSColor.white,
            .kern: -1.8
        ]
        let mainSize = mainText.size(withAttributes: mainAttributes)
        mainText.draw(at: NSPoint(x: 18, y: 69), withAttributes: mainAttributes)

        let unitAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: value.isToday || value.isPast ? 22 : 18, weight: .bold),
            .foregroundColor: kind.accent
        ]
        unitText.draw(at: NSPoint(x: min(bounds.width - 45, 22 + mainSize.width), y: 80), withAttributes: unitAttributes)

        if !value.isPast && !value.isToday {
            let timeText = String(format: "%02d 小时   %02d 分钟   %02d 秒", value.hours, value.minutes, value.seconds)
            let timeAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .semibold),
                .foregroundColor: NSColor.white.withAlphaComponent(0.90)
            ]
            timeText.draw(at: NSPoint(x: 20, y: 49), withAttributes: timeAttributes)
        }

        if isHovering {
            let hint = delegate?.positionsAreLocked == true ? "位置已锁定  ·  右键管理" : "拖动移动  ·  双击换照片  ·  右键管理"
            let hintAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.68)
            ]
            hint.draw(at: NSPoint(x: 20, y: 19), withAttributes: hintAttributes)
        } else {
            let label = kind.isGraduation ? "向着下一站，继续发光" : "新岁启封，万事胜意"
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.58)
            ]
            label.draw(at: NSPoint(x: 20, y: 19), withAttributes: labelAttributes)
        }

        if isHovering {
            NSColor.black.withAlphaComponent(0.30).setFill()
            NSBezierPath(ovalIn: optionsButtonRect).fill()
            drawCentered("•••", in: optionsButtonRect.offsetBy(dx: 0, dy: 6), font: .systemFont(ofSize: 12, weight: .bold), color: .white)
            let handle = NSBezierPath()
            handle.lineWidth = 1.5
            handle.move(to: NSPoint(x: bounds.maxX - 18, y: 7))
            handle.line(to: NSPoint(x: bounds.maxX - 7, y: 18))
            handle.move(to: NSPoint(x: bounds.maxX - 12, y: 7))
            handle.line(to: NSPoint(x: bounds.maxX - 7, y: 12))
            NSColor.white.withAlphaComponent(0.72).setStroke()
            handle.stroke()
        }
    }

    private func drawCentered(_ text: String, y: CGFloat, font: NSFont, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let width = text.size(withAttributes: attributes).width
        text.draw(at: NSPoint(x: bounds.midX - width / 2, y: y), withAttributes: attributes)
    }

    private func drawCentered(_ text: String, in rect: NSRect, font: NSFont, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attributes)
    }
}

private final class WidgetWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private protocol WidgetControllerDelegate: AnyObject {
    func widgetControllerDidChangeVisibility(_ controller: WidgetController)
    func widgetControllerRequestsLockToggle(_ controller: WidgetController)
    func widgetControllerRequestsTopmostToggle(_ controller: WidgetController)
    func widgetControllerRequestsQuit(_ controller: WidgetController)
    func widgetControllerRequestsEdit(_ controller: WidgetController)
    func widgetControllerRequestsDelete(_ controller: WidgetController)
}

private final class WidgetController: NSObject, NSWindowDelegate, CountdownCardViewDelegate {
    static let cardSize = NSSize(width: 336, height: 208)

    var kind: WidgetKind
    private let preferences = Preferences.shared
    private weak var appDelegate: WidgetControllerDelegate?
    private(set) var window: WidgetWindow!
    private(set) var cardView: CountdownCardView!
    private var isApplyingSavedFrame = false
    private var pendingSnapWorkItem: DispatchWorkItem?
    private let photoProcessingQueue = DispatchQueue(label: "com.codex.desktop-countdown.photo", qos: .userInitiated)
    private var photoProcessingGeneration = 0

    var positionsAreLocked: Bool { preferences.positionsLocked }
    var isVisible: Bool { window.isVisible }

    init(kind: WidgetKind, defaultOrigin: NSPoint, appDelegate: WidgetControllerDelegate) {
        self.kind = kind
        self.appDelegate = appDelegate
        super.init()

        let target = preferences.targetDate(for: kind)
        let image = preferences.photoPath(for: kind).flatMap { NSImage(contentsOfFile: $0) }
        let origin = preferences.origin(for: kind) ?? defaultOrigin
        let savedSize = preferences.size(for: kind) ?? Self.cardSize
        let width = min(840, max(235, savedSize.width))
        let size = NSSize(width: width, height: width * Self.cardSize.height / Self.cardSize.width)
        let frame = NSRect(origin: origin, size: size)
        window = WidgetWindow(
            contentRect: frame,
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.delegate = self
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.contentAspectRatio = Self.cardSize
        window.contentMinSize = NSSize(width: 235, height: 235 * Self.cardSize.height / Self.cardSize.width)
        window.contentMaxSize = NSSize(width: 840, height: 840 * Self.cardSize.height / Self.cardSize.width)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.title = kind.title
        window.setAccessibilityTitle(kind.title)

        cardView = CountdownCardView(frame: NSRect(origin: .zero, size: size), kind: kind, targetDate: target, backgroundImage: image)
        cardView.autoresizingMask = [.width, .height]
        cardView.setBoundsSize(Self.cardSize)
        cardView.delegate = self
        window.contentView = cardView
        applyWindowLevel()
        recoverWindowIfOffscreen(defaultOrigin: defaultOrigin)

        if !preferences.isHidden(kind) {
            window.orderFrontRegardless()
        }
    }

    func applyWindowLevel() {
        if preferences.alwaysOnTop {
            window.level = .floating
        } else {
            let desktopIconLevel = CGWindowLevelForKey(.desktopIconWindow)
            window.level = NSWindow.Level(rawValue: Int(desktopIconLevel) + 1)
        }
    }

    func refresh() {
        cardView.targetDate = preferences.targetDate(for: kind)
        cardView.refresh()
    }

    func update(kind newKind: WidgetKind) {
        kind = newKind
        cardView.kind = newKind
        cardView.targetDate = newKind.targetDate
        window.title = newKind.title
        window.setAccessibilityTitle(newKind.title)
        refresh()
    }

    func toggleVisibility() {
        setVisible(!window.isVisible)
    }

    func setVisible(_ visible: Bool) {
        if visible {
            recoverWindowIfOffscreen(defaultOrigin: defaultOrigin())
            window.orderFrontRegardless()
        } else {
            window.orderOut(nil)
        }
        preferences.setHidden(!visible, for: kind)
        appDelegate?.widgetControllerDidChangeVisibility(self)
    }

    func resetPosition() {
        let origin = defaultOrigin()
        window.setFrameOrigin(origin)
        preferences.setOrigin(origin, for: kind)
    }

    func resetSize() {
        resize(toWidth: Self.cardSize.width, animate: true)
        preferences.clearSize(for: kind)
    }

    private func resize(toWidth requestedWidth: CGFloat, animate: Bool) {
        let oldFrame = window.frame
        let width = min(840, max(235, requestedWidth))
        let height = width * Self.cardSize.height / Self.cardSize.width
        let frame = NSRect(x: oldFrame.minX, y: oldFrame.maxY - height, width: width, height: height)
        window.setFrame(frame, display: true, animate: animate)
        preferences.setSize(frame.size, for: kind)
        preferences.setOrigin(frame.origin, for: kind)
        cardView.setBoundsSize(Self.cardSize)
        cardView.needsDisplay = true
    }

    func recoverIfOffscreen() {
        recoverWindowIfOffscreen(defaultOrigin: defaultOrigin())
    }

    private func defaultOrigin() -> NSPoint {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let currentSize = window?.frame.size ?? Self.cardSize
        let x = visible.maxX - currentSize.width - 34
        let topY = visible.maxY - currentSize.height - 40
        let y = kind.isGraduation ? topY : topY - currentSize.height - 18
        return NSPoint(x: x, y: max(visible.minY + 24, y))
    }

    private func recoverWindowIfOffscreen(defaultOrigin: NSPoint) {
        guard !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame.insetBy(dx: 20, dy: 20)) }) else { return }
        isApplyingSavedFrame = true
        window.setFrameOrigin(defaultOrigin)
        preferences.setOrigin(defaultOrigin, for: kind)
        isApplyingSavedFrame = false
    }

    func windowDidMove(_ notification: Notification) {
        guard !isApplyingSavedFrame else { return }
        preferences.setOrigin(window.frame.origin, for: kind)
        scheduleSnapAfterMovement()
    }

    func windowDidResize(_ notification: Notification) {
        guard window != nil, cardView != nil else { return }
        cardView.setBoundsSize(Self.cardSize)
        cardView.needsDisplay = true
        preferences.setSize(window.frame.size, for: kind)
    }

    private func scheduleSnapAfterMovement() {
        pendingSnapWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if (NSEvent.pressedMouseButtons & 1) != 0 {
                self.scheduleSnapAfterMovement()
                return
            }
            self.snapToVisibleScreenEdges()
            self.preferences.setOrigin(self.window.frame.origin, for: self.kind)
        }
        pendingSnapWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }

    func cardViewChoosePhoto(_ view: CountdownCardView) {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "为\(kind.title)选择背景照片"
        panel.prompt = "使用这张照片"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.begin { [weak self] response in
            guard response == .OK, let self, let url = panel.url else { return }
            self.usePhoto(from: url)
        }
    }

    func cardViewUsePhoto(_ view: CountdownCardView, from url: URL) {
        usePhoto(from: url)
    }

    private func usePhoto(from url: URL) {
        photoProcessingGeneration += 1
        let generation = photoProcessingGeneration

        photoProcessingQueue.async { [weak self] in
            guard let self else { return }
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: 2_048
            ]

            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.photoProcessingGeneration == generation else { return }
                    self.showError(title: "无法读取照片", message: "请选择 JPG、PNG、HEIC 或其他常见图片格式。")
                }
                return
            }

            let representation = NSBitmapImageRep(cgImage: cgImage)
            guard let jpeg = representation.representation(using: .jpeg, properties: [.compressionFactor: 0.90]) else {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.photoProcessingGeneration == generation else { return }
                    self.showError(title: "照片保存失败", message: "图片转换失败。")
                }
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.photoProcessingGeneration == generation else { return }
                do {
                    let destination = try self.storedPhotoURL()
                    try jpeg.write(to: destination, options: .atomic)
                    self.preferences.setPhotoPath(destination.path, for: self.kind)
                    self.cardView.backgroundImage = NSImage(cgImage: cgImage, size: .zero)
                    self.cardView.needsDisplay = true
                } catch {
                    self.showError(title: "照片保存失败", message: error.localizedDescription)
                }
            }
        }
    }

    private func storedPhotoURL() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("桌面倒计时", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(kind.id)-background.jpg")
    }

    @objc private func choosePhotoFromMenu(_ sender: Any?) {
        cardViewChoosePhoto(cardView)
    }

    @objc private func resetPhoto(_ sender: Any?) {
        if let path = preferences.photoPath(for: kind) {
            try? FileManager.default.removeItem(atPath: path)
        }
        preferences.setPhotoPath(nil, for: kind)
        cardView.backgroundImage = nil
        cardView.needsDisplay = true
    }

    @objc private func resetCardSize(_ sender: Any?) { resetSize() }

    @objc private func setCardScale(_ sender: NSMenuItem) {
        guard let scale = sender.representedObject as? Double else { return }
        resize(toWidth: Self.cardSize.width * CGFloat(scale), animate: true)
    }

    @objc private func editGraduationDate(_ sender: Any?) {
        presentGraduationDateEditor()
    }

    @objc private func editCustomCountdown(_ sender: Any?) { appDelegate?.widgetControllerRequestsEdit(self) }
    @objc private func deleteCustomCountdown(_ sender: Any?) { appDelegate?.widgetControllerRequestsDelete(self) }

    func presentGraduationDateEditor() {
        guard kind.isGraduation else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "设置毕业日期"
        alert.informativeText = "倒计时会以当天 00:00 为目标时间。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let picker = NSDatePicker(frame: NSRect(x: 0, y: 0, width: 280, height: 28))
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.yearMonthDay]
        picker.locale = Locale(identifier: "zh_CN")
        picker.calendar = preferences.localGregorianCalendar
        picker.dateValue = preferences.graduationDate
        alert.accessoryView = picker

        if alert.runModal() == .alertFirstButtonReturn {
            preferences.graduationDate = preferences.startOfLocalGregorianDay(for: picker.dateValue)
            refresh()
        }
    }

    @objc private func toggleLock(_ sender: Any?) {
        appDelegate?.widgetControllerRequestsLockToggle(self)
    }

    @objc private func toggleTopmost(_ sender: Any?) {
        appDelegate?.widgetControllerRequestsTopmostToggle(self)
    }

    @objc private func hideWidget(_ sender: Any?) {
        setVisible(false)
    }

    @objc private func quitApp(_ sender: Any?) {
        appDelegate?.widgetControllerRequestsQuit(self)
    }

    func cardViewShowMenu(_ view: CountdownCardView, event: NSEvent) {
        let menu = NSMenu(title: kind.title)
        let choose = NSMenuItem(title: "更换照片…", action: #selector(choosePhotoFromMenu(_:)), keyEquivalent: "")
        choose.target = self
        menu.addItem(choose)

        if cardView.backgroundImage != nil {
            let reset = NSMenuItem(title: "恢复默认背景", action: #selector(resetPhoto(_:)), keyEquivalent: "")
            reset.target = self
            menu.addItem(reset)
        }

        menu.addItem(.separator())
        if kind.isGraduation {
            let edit = NSMenuItem(title: "修改毕业日期…", action: #selector(editGraduationDate(_:)), keyEquivalent: "")
            edit.target = self
            menu.addItem(edit)
        } else if kind.isCustom {
            let edit = NSMenuItem(title: "编辑倒计时…", action: #selector(editCustomCountdown(_:)), keyEquivalent: "")
            edit.target = self
            menu.addItem(edit)
            let remove = NSMenuItem(title: "删除此倒计时…", action: #selector(deleteCustomCountdown(_:)), keyEquivalent: "")
            remove.target = self
            menu.addItem(remove)
        } else {
            let fixed = NSMenuItem(title: "元旦日期：2027 年 1 月 1 日", action: nil, keyEquivalent: "")
            fixed.isEnabled = false
            menu.addItem(fixed)
        }

        let lock = NSMenuItem(title: "锁定卡片位置", action: #selector(toggleLock(_:)), keyEquivalent: "")
        lock.target = self
        lock.state = preferences.positionsLocked ? .on : .off
        menu.addItem(lock)

        let sizeMenuItem = NSMenuItem(title: "卡片大小", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu(title: "卡片大小")
        let currentScale = window.frame.width / Self.cardSize.width
        for (title, scale) in [("小（75%）", 0.75), ("默认（100%）", 1.0), ("大（125%）", 1.25), ("特大（150%）", 1.5)] {
            let item = NSMenuItem(title: title, action: #selector(setCardScale(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = scale
            item.state = abs(currentScale - CGFloat(scale)) < 0.03 ? .on : .off
            sizeMenu.addItem(item)
        }
        sizeMenuItem.submenu = sizeMenu
        menu.addItem(sizeMenuItem)

        let size = NSMenuItem(title: "恢复默认大小", action: #selector(resetCardSize(_:)), keyEquivalent: "")
        size.target = self
        menu.addItem(size)

        let topmost = NSMenuItem(title: "始终置顶", action: #selector(toggleTopmost(_:)), keyEquivalent: "")
        topmost.target = self
        topmost.state = preferences.alwaysOnTop ? .on : .off
        menu.addItem(topmost)

        menu.addItem(.separator())
        let hide = NSMenuItem(title: "隐藏此卡片", action: #selector(hideWidget(_:)), keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)
        let quit = NSMenuItem(title: "退出桌面倒计时", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        NSMenu.popUpContextMenu(menu, with: event, for: cardView)
    }

    func cardViewDidFinishDragging(_ view: CountdownCardView) {
        snapToVisibleScreenEdges()
        preferences.setOrigin(window.frame.origin, for: kind)
    }

    func cardViewDidFinishResizing(_ view: CountdownCardView) {
        preferences.setSize(window.frame.size, for: kind)
        preferences.setOrigin(window.frame.origin, for: kind)
        snapToVisibleScreenEdges()
    }

    private func snapToVisibleScreenEdges() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = window.frame
        let threshold: CGFloat = 14

        if abs(frame.minX - visible.minX) < threshold { frame.origin.x = visible.minX }
        if abs(frame.maxX - visible.maxX) < threshold { frame.origin.x = visible.maxX - frame.width }
        if abs(frame.minY - visible.minY) < threshold { frame.origin.y = visible.minY }
        if abs(frame.maxY - visible.maxY) < threshold { frame.origin.y = visible.maxY - frame.height }

        let minVisible: CGFloat = 48
        frame.origin.x = min(max(frame.origin.x, visible.minX - frame.width + minVisible), visible.maxX - minVisible)
        frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - minVisible)
        guard frame.origin != window.frame.origin else { return }
        isApplyingSavedFrame = true
        window.setFrameOrigin(frame.origin)
        isApplyingSavedFrame = false
    }

    private func showError(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

private final class CountdownEditorView: NSView {
    let titleField = NSTextField(string: "")
    let datePicker = NSDatePicker()
    let iconField = NSTextField(string: "⏰")
    let themePopup = NSPopUpButton()

    init(existing: WidgetKind?) {
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 142))
        let labels = ["名称", "日期", "图标", "主题"]
        for (index, text) in labels.enumerated() {
            let label = NSTextField(labelWithString: text)
            label.frame = NSRect(x: 0, y: 108 - index * 32, width: 48, height: 22)
            addSubview(label)
        }
        titleField.frame = NSRect(x: 58, y: 108, width: 292, height: 24)
        titleField.placeholderString = "例如：旅行、考试、纪念日"
        addSubview(titleField)
        datePicker.frame = NSRect(x: 58, y: 76, width: 180, height: 24)
        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.datePickerElements = [.yearMonthDay]
        datePicker.locale = Locale(identifier: "zh_CN")
        datePicker.calendar = Preferences.shared.localGregorianCalendar
        addSubview(datePicker)
        iconField.frame = NSRect(x: 58, y: 44, width: 70, height: 24)
        iconField.placeholderString = "⏰"
        addSubview(iconField)
        themePopup.frame = NSRect(x: 58, y: 12, width: 140, height: 26)
        themePopup.addItems(withTitles: ["海蓝", "暖红", "紫色", "绿色"])
        addSubview(themePopup)
        titleField.stringValue = existing?.title ?? ""
        datePicker.dateValue = existing?.targetDate ?? Preferences.shared.startOfLocalGregorianDay(for: Date().addingTimeInterval(86400 * 30))
        iconField.stringValue = existing?.icon ?? "⏰"
        themePopup.selectItem(at: existing.map { max(0, min(3, $0.themeValueForEditor)) } ?? 0)
    }
    required init?(coder: NSCoder) { fatalError() }
}

private extension WidgetKind { var themeValueForEditor: Int { switch self { case .custom(_,_,_,_,let theme): return theme; default: return 0 } } }

private final class AppDelegate: NSObject, NSApplicationDelegate, WidgetControllerDelegate, NSMenuDelegate, CountdownDashboardDelegate {
    private let preferences = Preferences.shared
    private var controllers: [String: WidgetController] = [:]
    private var statusItem: NSStatusItem!
    private var refreshTimer: Timer?
    private var dashboardController: CountdownDashboardController?
    private var hasCompletedLaunchSetup = false

    private weak var graduationMenuItem: NSMenuItem?
    private weak var springFestivalMenuItem: NSMenuItem?
    private weak var lockMenuItem: NSMenuItem?
    private weak var topmostMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !hasCompletedLaunchSetup else { return }
        hasCompletedLaunchSetup = true
        qaLog("applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.regular)
        qaLog("activation policy configured")
        setupApplicationMenu()
        if ProcessInfo.processInfo.environment["DESKTOP_COUNTDOWN_FORCE_LAUNCH_FOR_QA"] == "1" {
            qaLog("status item skipped in sandbox QA")
        } else {
            setupStatusItem()
            qaLog("status item configured")
        }
        setupWidgets()
        qaLog("widgets configured")
        setupTimer()
        qaLog("timer configured")
        setupDashboard()
        qaLog("dashboard configured")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        preferences.hasShownWelcome = true
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow(nil)
        return true
    }

    private func setupDashboard() {
        let controller = CountdownDashboardController(delegate: self)
        dashboardController = controller
        DispatchQueue.main.async { [weak controller] in controller?.present() }
    }

    private func setupApplicationMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "桌面倒计时")
        appMenu.addItem(withTitle: "关于桌面倒计时", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏桌面倒计时", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出桌面倒计时", action: #selector(quit(_:)), keyEquivalent: "q").target = self
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "文件")
        let addItem = fileMenu.addItem(withTitle: "新增倒计时…", action: #selector(addCountdown(_:)), keyEquivalent: "n")
        addItem.target = self
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "窗口")
        let dashboardItem = windowMenu.addItem(withTitle: "倒计时管理中心", action: #selector(showMainWindow(_:)), keyEquivalent: "1")
        dashboardItem.target = self
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = mainMenu
    }

    private func setupWidgets() {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let baseX = visible.maxX - WidgetController.cardSize.width - 34
        let topY = visible.maxY - WidgetController.cardSize.height - 40
        let graduationOrigin = NSPoint(x: baseX, y: topY)
        let springOrigin = NSPoint(x: baseX, y: max(visible.minY + 24, topY - WidgetController.cardSize.height - 18))

        let kinds = preferences.allKinds()
        for (index, kind) in kinds.enumerated() {
            let origin: NSPoint
            if kind.isGraduation {
                origin = graduationOrigin
            } else if kind.id == "springFestival" {
                origin = springOrigin
            } else {
                let visibleRow = index - 1
                origin = NSPoint(x: baseX, y: max(visible.minY + 24, topY - CGFloat(visibleRow + 1) * (WidgetController.cardSize.height + 18)))
            }
            controllers[kind.id] = WidgetController(kind: kind, defaultOrigin: origin, appDelegate: self)
        }
        updateMenuStates()
    }

    private func setupTimer() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.controllers.values.forEach { $0.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "桌面倒计时")
            button.toolTip = "桌面倒计时"
        }

        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        let menu = NSMenu(title: "桌面倒计时")
        menu.delegate = self
        let title = NSMenuItem(title: "桌面倒计时", action: nil, keyEquivalent: "")
        title.isEnabled = false; menu.addItem(title); menu.addItem(.separator())
        let openDashboard = NSMenuItem(title: "打开主页面", action: #selector(showMainWindow(_:)), keyEquivalent: "")
        openDashboard.target = self
        menu.addItem(openDashboard)
        menu.addItem(.separator())
        let kinds = preferences.allKinds()
        for (index, kind) in kinds.enumerated() {
            let item = NSMenuItem(title: kind.title, action: #selector(toggleCountdown(_:)), keyEquivalent: index < 9 ? "\(index + 1)" : "")
            item.target = self; item.representedObject = kind.id; menu.addItem(item)
            if kind.isGraduation { graduationMenuItem = item }
            if kind.id == "springFestival" { springFestivalMenuItem = item }
        }
        menu.addItem(.separator())
        let add = NSMenuItem(title: "新增倒计时…", action: #selector(addCountdown(_:)), keyEquivalent: "n")
        add.target = self; menu.addItem(add)
        let showAll = NSMenuItem(title: "显示全部卡片", action: #selector(showAll(_:)), keyEquivalent: "0")
        showAll.target = self
        menu.addItem(showAll)

        let reset = NSMenuItem(title: "重置卡片位置", action: #selector(resetPositions(_:)), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        let resetSizes = NSMenuItem(title: "恢复全部默认大小", action: #selector(resetSizes(_:)), keyEquivalent: "")
        resetSizes.target = self
        menu.addItem(resetSizes)

        let lock = NSMenuItem(title: "锁定卡片位置", action: #selector(toggleLock(_:)), keyEquivalent: "l")
        lock.target = self
        menu.addItem(lock)
        lockMenuItem = lock

        let topmost = NSMenuItem(title: "始终置顶", action: #selector(toggleTopmost(_:)), keyEquivalent: "t")
        topmost.target = self
        menu.addItem(topmost)
        topmostMenuItem = topmost

        menu.addItem(.separator())
        let editDate = NSMenuItem(title: "修改毕业日期…", action: #selector(editGraduationDate(_:)), keyEquivalent: ",")
        editDate.target = self
        menu.addItem(editDate)

        let help = NSMenuItem(title: "使用说明", action: #selector(showHelp(_:)), keyEquivalent: "?")
        help.target = self
        menu.addItem(help)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        updateMenuStates()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuStates()
    }

    private func updateMenuStates() {
        graduationMenuItem?.state = controllers[WidgetKind.graduation.id]?.isVisible == true ? .on : .off
        springFestivalMenuItem?.state = controllers[WidgetKind.springFestival.id]?.isVisible == true ? .on : .off
        statusItem?.menu?.items.forEach { item in
            if let id = item.representedObject as? String { item.state = controllers[id]?.isVisible == true ? .on : .off }
        }
        lockMenuItem?.state = preferences.positionsLocked ? .on : .off
        topmostMenuItem?.state = preferences.alwaysOnTop ? .on : .off
        controllers.values.forEach { $0.cardView.needsDisplay = true }
        dashboardController?.reloadData()
    }

    @objc private func toggleGraduation(_ sender: Any?) {
        controllers[WidgetKind.graduation.id]?.toggleVisibility()
    }

    @objc private func toggleSpringFestival(_ sender: Any?) {
        controllers[WidgetKind.springFestival.id]?.toggleVisibility()
    }

    @objc private func toggleCountdown(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        controllers[id]?.toggleVisibility()
    }

    @objc private func addCountdown(_ sender: Any?) { presentCustomEditor(existing: nil) }

    @objc private func showMainWindow(_ sender: Any?) {
        dashboardController?.present()
    }

    @objc private func showAll(_ sender: Any?) {
        controllers.values.forEach { $0.setVisible(true) }
        updateMenuStates()
    }

    @objc private func resetPositions(_ sender: Any?) {
        preferences.clearOrigins()
        controllers.values.forEach {
            $0.resetPosition()
            $0.setVisible(true)
        }
        updateMenuStates()
    }

    @objc private func resetSizes(_ sender: Any?) {
        preferences.clearSizes()
        controllers.values.forEach { $0.resetSize() }
        updateMenuStates()
    }

    @objc private func toggleLock(_ sender: Any?) {
        preferences.positionsLocked.toggle()
        updateMenuStates()
    }

    @objc private func toggleTopmost(_ sender: Any?) {
        preferences.alwaysOnTop.toggle()
        controllers.values.forEach { $0.applyWindowLevel() }
        updateMenuStates()
    }

    @objc private func editGraduationDate(_ sender: Any?) {
        controllers[WidgetKind.graduation.id]?.presentGraduationDateEditor()
    }

    @objc private func showHelp(_ sender: Any?) {
        showWelcome(force: true)
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    @objc private func screenParametersChanged(_ notification: Notification) {
        controllers.values.forEach { $0.recoverIfOffscreen() }
    }

    private func showWelcome(force: Bool = false) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "桌面倒计时已准备好"
        alert.informativeText = "拖动卡片可移动位置，拖动右下角可调整大小；双击卡片或把图片拖到卡片上即可换照片；右键可管理单张卡片。\n\n毕业日期暂设为 2027 年 6 月 30 日，可随时修改。元旦日期为 2027 年 1 月 1 日。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "设置毕业日期")
        alert.addButton(withTitle: "知道了")
        preferences.hasShownWelcome = true
        if alert.runModal() == .alertFirstButtonReturn {
            showGraduationDatePicker()
        }
    }

    private func showGraduationDatePicker() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "设置毕业日期"
        alert.informativeText = "倒计时会以当天 00:00 为目标时间。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        let picker = NSDatePicker(frame: NSRect(x: 0, y: 0, width: 280, height: 28))
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.yearMonthDay]
        picker.locale = Locale(identifier: "zh_CN")
        picker.calendar = preferences.localGregorianCalendar
        picker.dateValue = preferences.graduationDate
        alert.accessoryView = picker
        if alert.runModal() == .alertFirstButtonReturn {
            preferences.graduationDate = preferences.startOfLocalGregorianDay(for: picker.dateValue)
            controllers[WidgetKind.graduation.id]?.refresh()
        }
    }

    private func presentCustomEditor(existing: WidgetKind?) {
        NSApp.activate(ignoringOtherApps: true)
        let editor = CountdownEditorView(existing: existing)
        let alert = NSAlert()
        alert.messageText = existing == nil ? "新增倒计时" : "编辑倒计时"
        alert.informativeText = "设置名称、目标日期，也可以选择图标和主题。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        alert.accessoryView = editor
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let title = editor.titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let date = preferences.startOfLocalGregorianDay(for: editor.datePicker.dateValue)
        let icon = editor.iconField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "⏰" : editor.iconField.stringValue
        let theme = editor.themePopup.indexOfSelectedItem
        if let existing, existing.isCustom {
            preferences.updateCustom(id: existing.id, title: title, targetDate: date, icon: icon, theme: theme)
            let updated = WidgetKind.custom(id: existing.id, title: title, targetDate: date, icon: icon, theme: theme)
            controllers[existing.id]?.update(kind: updated)
        } else {
            let kind = preferences.addCustom(title: title, targetDate: date, icon: icon, theme: theme)
            addController(for: kind)
        }
        rebuildStatusMenu()
    }

    private func addController(for kind: WidgetKind) {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let baseX = visible.maxX - WidgetController.cardSize.width - 34
        let topY = visible.maxY - WidgetController.cardSize.height - 40
        let row = max(1, controllers.count)
        let origin = NSPoint(x: baseX, y: max(visible.minY + 24, topY - CGFloat(row) * (WidgetController.cardSize.height + 18)))
        controllers[kind.id] = WidgetController(kind: kind, defaultOrigin: origin, appDelegate: self)
        controllers[kind.id]?.setVisible(true)
    }

    func widgetControllerDidChangeVisibility(_ controller: WidgetController) {
        updateMenuStates()
    }

    func widgetControllerRequestsLockToggle(_ controller: WidgetController) {
        toggleLock(nil)
    }

    func widgetControllerRequestsTopmostToggle(_ controller: WidgetController) {
        toggleTopmost(nil)
    }

    func widgetControllerRequestsQuit(_ controller: WidgetController) {
        NSApp.terminate(nil)
    }

    func widgetControllerRequestsEdit(_ controller: WidgetController) {
        guard controller.kind.isCustom else { return }
        presentCustomEditor(existing: controller.kind)
    }

    func widgetControllerRequestsDelete(_ controller: WidgetController) {
        deleteCustomCountdown(id: controller.kind.id)
    }

    private func deleteCustomCountdown(id: String) {
        guard let controller = controllers[id], controller.kind.isCustom else { return }
        let alert = NSAlert()
        alert.messageText = "删除“\(controller.kind.title)”？"
        alert.informativeText = "这会移除倒计时卡片及其设置。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        controller.setVisible(false)
        preferences.removeCustom(id: controller.kind.id)
        controllers.removeValue(forKey: controller.kind.id)
        rebuildStatusMenu()
        dashboardController?.reloadData()
    }

    func dashboardItems() -> [DashboardItem] {
        preferences.allKinds().map { kind in
            DashboardItem(
                id: kind.id,
                title: kind.title,
                icon: kind.icon,
                targetDate: preferences.targetDate(for: kind),
                accent: kind.accent,
                isVisible: controllers[kind.id]?.isVisible == true,
                isCustom: kind.isCustom,
                canEdit: kind.isGraduation || kind.isCustom
            )
        }
    }

    func dashboardRequestsAddCountdown() {
        presentCustomEditor(existing: nil)
    }

    func dashboardRequestsToggleCountdown(id: String) {
        controllers[id]?.toggleVisibility()
    }

    func dashboardRequestsEditCountdown(id: String) {
        guard let controller = controllers[id] else { return }
        if controller.kind.isGraduation {
            controller.presentGraduationDateEditor()
        } else if controller.kind.isCustom {
            presentCustomEditor(existing: controller.kind)
        }
        dashboardController?.reloadData()
    }

    func dashboardRequestsDeleteCountdown(id: String) {
        deleteCustomCountdown(id: id)
    }

    func dashboardRequestsShowAll() {
        showAll(nil)
    }

    func dashboardRequestsHideAll() {
        controllers.values.forEach { $0.setVisible(false) }
        updateMenuStates()
    }
}

private func renderPreview(to outputURL: URL) throws {
    let cardSize = WidgetController.cardSize
    let canvasSize = NSSize(width: cardSize.width + 40, height: cardSize.height * 2 + 58)
    let canvas = NSImage(size: canvasSize)

    func renderedCard(kind: WidgetKind, target: Date) -> NSImage {
        let view = CountdownCardView(
            frame: NSRect(origin: .zero, size: cardSize),
            kind: kind,
            targetDate: target,
            backgroundImage: nil
        )
        let image = NSImage(size: cardSize)
        image.lockFocus()
        view.draw(view.bounds)
        image.unlockFocus()
        return image
    }

    canvas.lockFocus()
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: canvasSize).fill()

    let graduation = renderedCard(kind: .graduation, target: Preferences.shared.graduationDate)
    let spring = renderedCard(kind: .springFestival, target: Preferences.shared.springFestivalDate)
    graduation.draw(in: NSRect(x: 20, y: cardSize.height + 38, width: cardSize.width, height: cardSize.height))
    spring.draw(in: NSRect(x: 20, y: 20, width: cardSize.width, height: cardSize.height))
    canvas.unlockFocus()

    guard let tiff = canvas.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "DesktopCountdown", code: 2, userInfo: [NSLocalizedDescriptionKey: "预览图编码失败"])
    }
    try png.write(to: outputURL, options: .atomic)
}

if let previewIndex = CommandLine.arguments.firstIndex(of: "--render-preview"),
   CommandLine.arguments.indices.contains(previewIndex + 1) {
    do {
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[previewIndex + 1])
        try renderPreview(to: outputURL)
        print("Preview: \(outputURL.path)")
        exit(0)
    } catch {
        fputs("Preview failed: \(error.localizedDescription)\n", stderr)
        exit(2)
    }
}

qaLog("entering main")
private let application = NSApplication.shared
qaLog("NSApplication created")
private let delegate = AppDelegate()
qaLog("AppDelegate created")
application.delegate = delegate
if ProcessInfo.processInfo.environment["DESKTOP_COUNTDOWN_FORCE_LAUNCH_FOR_QA"] == "1" {
    qaLog("forcing launch callback for sandbox QA")
    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification, object: application))
}
qaLog("starting run loop")
application.run()
qaLog("run loop ended")
