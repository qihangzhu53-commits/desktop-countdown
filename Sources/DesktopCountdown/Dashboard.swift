import AppKit

struct DashboardItem {
    let id: String
    let title: String
    let icon: String
    let targetDate: Date
    let accent: NSColor
    let isVisible: Bool
    let isCustom: Bool
    let canEdit: Bool
}

protocol CountdownDashboardDelegate: AnyObject {
    func dashboardItems() -> [DashboardItem]
    func dashboardRequestsAddCountdown()
    func dashboardRequestsToggleCountdown(id: String)
    func dashboardRequestsEditCountdown(id: String)
    func dashboardRequestsDeleteCountdown(id: String)
    func dashboardRequestsShowAll()
    func dashboardRequestsHideAll()
}

private final class IdentifiedButton: NSButton {
    var countdownID = ""
}

private final class IdentifiedSwitch: NSSwitch {
    var countdownID = ""
}

private final class PrimaryActionButton: NSButton {
    override var wantsUpdateLayer: Bool { true }

    init(title: String, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        isBordered = false
        focusRingType = .none
        font = .systemFont(ofSize: 13, weight: .semibold)
        contentTintColor = NSColor(calibratedRed: 0.05, green: 0.27, blue: 0.58, alpha: 1)
        wantsLayer = true
        layer?.cornerRadius = 11
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.16
        layer?.shadowRadius = 8
        layer?.shadowOffset = NSSize(width: 0, height: -2)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(isHighlighted ? 0.78 : 0.96).cgColor
    }
}

private final class SummaryPillView: NSView {
    private let label = NSTextField(labelWithString: "")

    var text: String {
        get { label.stringValue }
        set { label.stringValue = newValue }
    }

    init(symbol: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.13).cgColor

        let imageView = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentTintColor = NSColor.white.withAlphaComponent(0.82)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11.5, weight: .medium)
        label.textColor = NSColor.white.withAlphaComponent(0.86)
        addSubview(imageView)
        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 27),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 13),
            imageView.heightAnchor.constraint(equalToConstant: 13),
            label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

private final class StatusBadgeView: NSView {
    init(text: String, accent: NSColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.backgroundColor = accent.withAlphaComponent(0.13).cgColor
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = accent
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 24),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

private final class DashboardHeaderView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSGradient(colors: [
            NSColor(calibratedRed: 0.055, green: 0.12, blue: 0.34, alpha: 1),
            NSColor(calibratedRed: 0.12, green: 0.38, blue: 0.72, alpha: 1),
            NSColor(calibratedRed: 0.11, green: 0.62, blue: 0.70, alpha: 1)
        ])?.draw(in: bounds, angle: 8)

        NSColor.white.withAlphaComponent(0.07).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.maxX - 185, y: bounds.maxY - 150, width: 230, height: 230)).fill()
        NSColor.white.withAlphaComponent(0.05).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.maxX - 310, y: bounds.maxY - 94, width: 150, height: 150)).fill()
        NSColor.white.withAlphaComponent(0.04).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.maxX - 430, y: -70, width: 190, height: 190)).fill()
    }
}

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

private final class DashboardRowView: NSView {
    let visibilityButton = IdentifiedSwitch()
    let editButton = IdentifiedButton(title: "编辑", target: nil, action: nil)
    let deleteButton = IdentifiedButton(title: "删除", target: nil, action: nil)
    private let accent: NSColor
    private var isHovering = false

    override var wantsUpdateLayer: Bool { true }

    init(item: DashboardItem) {
        accent = item.accent
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOffset = NSSize(width: 0, height: -3)
        updateLayer()

        let accentBar = NSView()
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.wantsLayer = true
        accentBar.layer?.cornerRadius = 2
        accentBar.layer?.backgroundColor = item.accent.cgColor

        let iconBackground = NSView()
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.wantsLayer = true
        iconBackground.layer?.cornerRadius = 12
        iconBackground.layer?.backgroundColor = item.accent.withAlphaComponent(0.16).cgColor

        let iconLabel = NSTextField(labelWithString: item.icon)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = .systemFont(ofSize: 27)
        iconLabel.alignment = .center
        iconBackground.addSubview(iconLabel)

        let titleLabel = NSTextField(labelWithString: item.title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = "yyyy 年 M 月 d 日 · EEEE"
        let dateLabel = NSTextField(labelWithString: dateFormatter.string(from: item.targetDate))
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = .systemFont(ofSize: 11.5)
        dateLabel.textColor = .secondaryLabelColor

        let statusBadge = StatusBadgeView(text: Self.statusText(for: item.targetDate), accent: item.accent)

        visibilityButton.translatesAutoresizingMaskIntoConstraints = false
        visibilityButton.countdownID = item.id
        visibilityButton.state = item.isVisible ? .on : .off
        visibilityButton.setAccessibilityLabel("在桌面显示\(item.title)")

        let visibilityLabel = NSTextField(labelWithString: "桌面显示")
        visibilityLabel.translatesAutoresizingMaskIntoConstraints = false
        visibilityLabel.font = .systemFont(ofSize: 11.5, weight: .medium)
        visibilityLabel.textColor = .secondaryLabelColor

        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.countdownID = item.id
        editButton.bezelStyle = .rounded
        editButton.controlSize = .small
        editButton.isHidden = !item.canEdit

        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.countdownID = item.id
        deleteButton.bezelStyle = .rounded
        deleteButton.controlSize = .small
        deleteButton.contentTintColor = .systemRed
        deleteButton.isHidden = !item.isCustom

        [accentBar, iconBackground, titleLabel, dateLabel, statusBadge, visibilityLabel, visibilityButton, editButton, deleteButton].forEach(addSubview)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 98),
            accentBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
            accentBar.centerYAnchor.constraint(equalTo: centerYAnchor),
            accentBar.widthAnchor.constraint(equalToConstant: 4),
            accentBar.heightAnchor.constraint(equalToConstant: 62),
            iconBackground.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 10),
            iconBackground.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconBackground.widthAnchor.constraint(equalToConstant: 58),
            iconBackground.heightAnchor.constraint(equalToConstant: 58),
            iconLabel.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: iconBackground.trailingAnchor, constant: 14),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: visibilityLabel.leadingAnchor, constant: -18),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            statusBadge.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            statusBadge.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 7),

            visibilityButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            visibilityButton.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            visibilityLabel.trailingAnchor.constraint(equalTo: visibilityButton.leadingAnchor, constant: -7),
            visibilityLabel.centerYAnchor.constraint(equalTo: visibilityButton.centerYAnchor),
            editButton.trailingAnchor.constraint(equalTo: deleteButton.isHidden ? trailingAnchor : deleteButton.leadingAnchor, constant: deleteButton.isHidden ? -16 : -8),
            editButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            deleteButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    override func updateLayer() {
        layer?.backgroundColor = (isHovering ? NSColor.controlBackgroundColor : NSColor.controlBackgroundColor.withAlphaComponent(0.84)).cgColor
        layer?.borderWidth = isHovering ? 1.2 : 1
        layer?.borderColor = (isHovering ? accent.withAlphaComponent(0.58) : NSColor.separatorColor.withAlphaComponent(0.42)).cgColor
        layer?.shadowOpacity = isHovering ? 0.14 : 0.06
        layer?.shadowRadius = isHovering ? 12 : 5
    }

    private static func statusText(for target: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let now = Date()
        if calendar.isDate(target, inSameDayAs: now) { return "就是今天 🎉" }
        if target < now { return "目标日期已到达" }
        let components = calendar.dateComponents([.day, .hour], from: now, to: target)
        return "还有 \(max(0, components.day ?? 0)) 天 \(max(0, components.hour ?? 0)) 小时"
    }
}

final class CountdownDashboardController: NSWindowController, NSWindowDelegate {
    weak var dashboardDelegate: CountdownDashboardDelegate?

    private let headerTitle = NSTextField(labelWithString: "桌面倒计时")
    private let countdownSummary = SummaryPillView(symbol: "calendar")
    private let visibleSummary = SummaryPillView(symbol: "eye")
    private let listStack = NSStackView()
    private let scrollView = NSScrollView()
    private let emptyLabel = NSTextField(labelWithString: "还没有倒计时")

    init(delegate: CountdownDashboardDelegate) {
        dashboardDelegate = delegate
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.delegate = self
        window.title = "桌面倒计时"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 680, height: 480)
        window.center()
        buildInterface()
        reloadData()
    }

    required init?(coder: NSCoder) { fatalError() }

    func present() {
        reloadData()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func reloadData() {
        guard let dashboardDelegate else { return }
        let items = dashboardDelegate.dashboardItems()
        let visibleCount = items.filter(\.isVisible).count
        countdownSummary.text = "\(items.count) 个倒计时"
        visibleSummary.text = "\(visibleCount) 个正在显示"

        listStack.arrangedSubviews.forEach {
            listStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for item in items {
            let row = DashboardRowView(item: item)
            row.visibilityButton.target = self
            row.visibilityButton.action = #selector(toggleCountdown(_:))
            row.editButton.target = self
            row.editButton.action = #selector(editCountdown(_:))
            row.deleteButton.target = self
            row.deleteButton.action = #selector(deleteCountdown(_:))
            listStack.addArrangedSubview(row)
        }
        emptyLabel.isHidden = !items.isEmpty
    }

    private func buildInterface() {
        guard let window else { return }
        let root = NSVisualEffectView()
        root.material = .underWindowBackground
        root.blendingMode = .behindWindow
        root.state = .active
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = root

        let header = DashboardHeaderView()
        header.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(header)

        let appMark = NSView()
        appMark.translatesAutoresizingMaskIntoConstraints = false
        appMark.wantsLayer = true
        appMark.layer?.cornerRadius = 13
        appMark.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
        appMark.layer?.borderWidth = 1
        appMark.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        header.addSubview(appMark)
        let markImage = NSImageView(image: NSImage(systemSymbolName: "timer", accessibilityDescription: "桌面倒计时") ?? NSImage())
        markImage.translatesAutoresizingMaskIntoConstraints = false
        markImage.contentTintColor = .white
        markImage.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 23, weight: .semibold)
        appMark.addSubview(markImage)

        headerTitle.translatesAutoresizingMaskIntoConstraints = false
        headerTitle.font = .systemFont(ofSize: 30, weight: .bold)
        headerTitle.textColor = .white
        header.addSubview(headerTitle)

        let subtitle = NSTextField(labelWithString: "把期待放在桌面，让重要日子清晰可见")
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = NSColor.white.withAlphaComponent(0.78)
        header.addSubview(subtitle)

        header.addSubview(countdownSummary)
        header.addSubview(visibleSummary)

        let addButton = PrimaryActionButton(title: "＋  新增倒计时", target: self, action: #selector(addCountdown(_:)))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.keyEquivalent = "n"
        addButton.keyEquivalentModifierMask = [.command]
        header.addSubview(addButton)

        let sectionTitle = NSTextField(labelWithString: "我的倒计时")
        sectionTitle.translatesAutoresizingMaskIntoConstraints = false
        sectionTitle.font = .systemFont(ofSize: 17, weight: .semibold)
        root.addSubview(sectionTitle)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        root.addSubview(scrollView)

        let document = FlippedDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = document

        listStack.translatesAutoresizingMaskIntoConstraints = false
        listStack.orientation = .vertical
        listStack.alignment = .leading
        listStack.spacing = 11
        document.addSubview(listStack)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = .systemFont(ofSize: 15)
        emptyLabel.textColor = .secondaryLabelColor
        root.addSubview(emptyLabel)

        let footer = NSView()
        footer.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(footer)
        let showAllButton = NSButton(title: "显示全部", target: self, action: #selector(showAll(_:)))
        let hideAllButton = NSButton(title: "隐藏全部", target: self, action: #selector(hideAll(_:)))
        let footerHint = NSTextField(labelWithString: "提示：拖动桌面卡片可移动，拖动右下角可调整大小")
        [showAllButton, hideAllButton, footerHint].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            footer.addSubview($0)
        }
        showAllButton.bezelStyle = .rounded
        hideAllButton.bezelStyle = .rounded
        footerHint.font = .systemFont(ofSize: 11)
        footerHint.textColor = .tertiaryLabelColor

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: root.topAnchor),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 168),
            appMark.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 30),
            appMark.topAnchor.constraint(equalTo: header.topAnchor, constant: 45),
            appMark.widthAnchor.constraint(equalToConstant: 48),
            appMark.heightAnchor.constraint(equalToConstant: 48),
            markImage.centerXAnchor.constraint(equalTo: appMark.centerXAnchor),
            markImage.centerYAnchor.constraint(equalTo: appMark.centerYAnchor),
            markImage.widthAnchor.constraint(equalToConstant: 27),
            markImage.heightAnchor.constraint(equalToConstant: 27),
            headerTitle.leadingAnchor.constraint(equalTo: appMark.trailingAnchor, constant: 13),
            headerTitle.topAnchor.constraint(equalTo: header.topAnchor, constant: 45),
            subtitle.leadingAnchor.constraint(equalTo: headerTitle.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: headerTitle.bottomAnchor, constant: 3),
            countdownSummary.leadingAnchor.constraint(equalTo: headerTitle.leadingAnchor),
            countdownSummary.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 13),
            visibleSummary.leadingAnchor.constraint(equalTo: countdownSummary.trailingAnchor, constant: 8),
            visibleSummary.centerYAnchor.constraint(equalTo: countdownSummary.centerYAnchor),
            addButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -30),
            addButton.centerYAnchor.constraint(equalTo: header.centerYAnchor, constant: 6),
            addButton.widthAnchor.constraint(equalToConstant: 136),
            addButton.heightAnchor.constraint(equalToConstant: 38),

            sectionTitle.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 26),
            sectionTitle.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 18),
            scrollView.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            scrollView.bottomAnchor.constraint(equalTo: footer.topAnchor),

            document.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            document.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            listStack.topAnchor.constraint(equalTo: document.topAnchor, constant: 2),
            listStack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 2),
            listStack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -2),
            listStack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -12),
            listStack.widthAnchor.constraint(equalTo: document.widthAnchor, constant: -4),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),

            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: 62),
            showAllButton.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            showAllButton.centerYAnchor.constraint(equalTo: footer.centerYAnchor, constant: -2),
            hideAllButton.leadingAnchor.constraint(equalTo: showAllButton.trailingAnchor, constant: 8),
            hideAllButton.centerYAnchor.constraint(equalTo: showAllButton.centerYAnchor),
            footerHint.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            footerHint.centerYAnchor.constraint(equalTo: showAllButton.centerYAnchor)
        ])
    }

    @objc private func addCountdown(_ sender: Any?) {
        dashboardDelegate?.dashboardRequestsAddCountdown()
        reloadData()
    }

    @objc private func toggleCountdown(_ sender: IdentifiedButton) {
        dashboardDelegate?.dashboardRequestsToggleCountdown(id: sender.countdownID)
        reloadData()
    }

    @objc private func editCountdown(_ sender: IdentifiedButton) {
        dashboardDelegate?.dashboardRequestsEditCountdown(id: sender.countdownID)
        reloadData()
    }

    @objc private func deleteCountdown(_ sender: IdentifiedButton) {
        dashboardDelegate?.dashboardRequestsDeleteCountdown(id: sender.countdownID)
        reloadData()
    }

    @objc private func showAll(_ sender: Any?) {
        dashboardDelegate?.dashboardRequestsShowAll()
        reloadData()
    }

    @objc private func hideAll(_ sender: Any?) {
        dashboardDelegate?.dashboardRequestsHideAll()
        reloadData()
    }
}
