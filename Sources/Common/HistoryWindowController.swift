import Foundation
import AppKit

final class HistoryWindowController: NSWindowController {
    static let shared = HistoryWindowController()
    
    private var currentFilter: HistoryItemType = .all
    private var filteredItems: [HistoryItem] = []
    private var selectedIndex: Int = 0
    
    // UI elements
    private var filterButtons: [HistoryItemType: NSButton] = [:]
    private var carouselContainer: NSView!
    private var metaLabel: NSTextField!
    private var restoreButton: NSButton!
    private var emptyLabel: NSTextField!
    private var localKeyMonitor: Any?
    private var scrollWheelMonitor: Any?
    
    init() {
        let width: CGFloat = 880
        let height: CGFloat = 260
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = screenRect.minX + (screenRect.width - width) / 2.0
        // Positioned right at the top directly beneath the notch / menu bar
        let y = screenRect.maxY - height - 12
        
        let window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        super.init(window: window)
        setupUI(width: width, height: height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI(width: CGFloat, height: CGFloat) {
        guard let window = self.window else { return }
        
        let root = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        
        // 1. Sleek Frosted Glass Backdrop Card
        let glass = NSVisualEffectView(frame: root.bounds)
        glass.material = .hudWindow
        glass.blendingMode = .withinWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = 20
        glass.layer?.masksToBounds = true
        glass.layer?.borderColor = NSColor.white.withAlphaComponent(0.22).cgColor
        glass.layer?.borderWidth = 1.0
        root.addSubview(glass)
        
        // Close button on top-right
        let closeBtn = NSButton(frame: NSRect(x: width - 34, y: height - 34, width: 22, height: 22))
        closeBtn.bezelStyle = .circular
        closeBtn.title = "×"
        closeBtn.font = NSFont.boldSystemFont(ofSize: 13)
        closeBtn.target = self
        closeBtn.action = #selector(dismissHistory)
        glass.addSubview(closeBtn)
        
        // 2. Top Filter Pills: [All] [Screenshots] [Videos] [GIFs]
        let pillStack = NSStackView()
        pillStack.orientation = .horizontal
        pillStack.alignment = .centerY
        pillStack.spacing = 8
        pillStack.translatesAutoresizingMaskIntoConstraints = false
        glass.addSubview(pillStack)
        
        for filterType in HistoryItemType.allCases {
            let btn = NSButton(title: filterType.rawValue, target: self, action: #selector(filterClicked(_:)))
            btn.bezelStyle = .regularSquare
            btn.isBordered = false
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 13
            btn.layer?.masksToBounds = true
            btn.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            
            filterButtons[filterType] = btn
            pillStack.addArrangedSubview(btn)
        }
        
        NSLayoutConstraint.activate([
            pillStack.topAnchor.constraint(equalTo: glass.topAnchor, constant: 14),
            pillStack.centerXAnchor.constraint(equalTo: glass.centerXAnchor)
        ])
        
        // 3. Carousel Center Container (Wide horizontal strip)
        carouselContainer = NSView(frame: NSRect(x: 0, y: 52, width: width, height: 155))
        glass.addSubview(carouselContainer)
        
        // Empty State label
        emptyLabel = NSTextField(labelWithString: "No captures taken yet.\nTake a screenshot or screen recording to see it here!")
        emptyLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        emptyLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        emptyLabel.alignment = .center
        emptyLabel.frame = NSRect(x: 40, y: 50, width: width - 80, height: 44)
        emptyLabel.isHidden = true
        carouselContainer.addSubview(emptyLabel)
        
        // 4. Bottom Metadata & Restore Bar
        let bottomBar = NSView(frame: NSRect(x: 0, y: 10, width: width, height: 36))
        glass.addSubview(bottomBar)
        
        metaLabel = NSTextField(labelWithString: "")
        metaLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        metaLabel.textColor = NSColor.white.withAlphaComponent(0.65)
        metaLabel.alignment = .right
        metaLabel.frame = NSRect(x: 24, y: 8, width: (width / 2.0) - 80, height: 18)
        bottomBar.addSubview(metaLabel)
        
        // Restore Button [ ↩ Restore ]
        let restoreW: CGFloat = 110
        let restoreH: CGFloat = 30
        restoreButton = NSButton(title: "↩  Restore", target: self, action: #selector(restoreClicked))
        restoreButton.frame = NSRect(x: (width - restoreW) / 2.0, y: 3, width: restoreW, height: restoreH)
        restoreButton.bezelStyle = .regularSquare
        restoreButton.isBordered = false
        restoreButton.wantsLayer = true
        restoreButton.layer?.cornerRadius = 15
        restoreButton.layer?.masksToBounds = true
        restoreButton.layer?.backgroundColor = NSColor(red: 0.05, green: 0.52, blue: 1.0, alpha: 1.0).cgColor
        restoreButton.contentTintColor = .white
        restoreButton.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        restoreButton.keyEquivalent = "\r"
        bottomBar.addSubview(restoreButton)
        
        window.contentView = root
        updateFilterAppearance()
    }
    
    func showHistory() {
        // Recalculate screen position to stay right under the notch
        if let screen = NSScreen.main?.visibleFrame, let win = self.window {
            let width = win.frame.width
            let height = win.frame.height
            let x = screen.minX + (screen.width - width) / 2.0
            let y = screen.maxY - height - 12
            win.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        self.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        reloadHistoryList()
        
        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.window?.isVisible == true else { return event }
                if event.keyCode == 53 { // Escape
                    self.dismissHistory()
                    return nil
                }
                if event.keyCode == 123 { // Left Arrow
                    self.selectPrevious()
                    return nil
                }
                if event.keyCode == 124 { // Right Arrow
                    self.selectNext()
                    return nil
                }
                if event.keyCode == 36 { // Return
                    self.restoreClicked()
                    return nil
                }
                if event.keyCode == 51 { // Delete
                    self.deleteCurrentItem()
                    return nil
                }
                return event
            }
        }
        
        if scrollWheelMonitor == nil {
            scrollWheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self = self, self.window?.isVisible == true else { return event }
                if abs(event.scrollingDeltaX) > 14 {
                    if event.scrollingDeltaX > 0 {
                        self.selectPrevious()
                    } else {
                        self.selectNext()
                    }
                    return nil
                }
                return event
            }
        }
    }
    
    @objc func dismissHistory() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = scrollWheelMonitor {
            NSEvent.removeMonitor(monitor)
            scrollWheelMonitor = nil
        }
        self.close()
    }
    
    func reloadHistoryList() {
        let allItems = HistoryManager.shared.items
        
        switch currentFilter {
        case .all:
            filteredItems = allItems
        case .screenshot:
            filteredItems = allItems.filter { $0.itemType == .screenshot }
        case .video:
            filteredItems = allItems.filter { $0.itemType == .video }
        case .gif:
            filteredItems = allItems.filter { $0.itemType == .gif }
        }
        
        selectedIndex = min(max(selectedIndex, 0), max(filteredItems.count - 1, 0))
        renderCarousel(animated: false)
    }
    
    private func updateFilterAppearance() {
        for (type, btn) in filterButtons {
            let isSelected = (type == currentFilter)
            btn.contentTintColor = .white
            if isSelected {
                btn.layer?.backgroundColor = NSColor(red: 0.05, green: 0.52, blue: 1.0, alpha: 1.0).cgColor
            } else {
                btn.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
            }
        }
    }
    
    @objc private func filterClicked(_ sender: NSButton) {
        guard let entry = filterButtons.first(where: { $0.value == sender }) else { return }
        currentFilter = entry.key
        selectedIndex = 0
        updateFilterAppearance()
        reloadHistoryList()
    }
    
    private func selectPrevious() {
        guard !filteredItems.isEmpty, selectedIndex > 0 else { return }
        selectedIndex -= 1
        renderCarousel(animated: true)
    }
    
    private func selectNext() {
        guard !filteredItems.isEmpty, selectedIndex < filteredItems.count - 1 else { return }
        selectedIndex += 1
        renderCarousel(animated: true)
    }
    
    private func deleteCurrentItem() {
        guard !filteredItems.isEmpty, selectedIndex < filteredItems.count else { return }
        let item = filteredItems[selectedIndex]
        HistoryManager.shared.removeItem(id: item.id)
        reloadHistoryList()
    }
    
    // MARK: - Carousel Rendering (Smooth Horizontal Sliding Strip)
    
    private func renderCarousel(animated: Bool) {
        carouselContainer.subviews.filter { $0 !== emptyLabel }.forEach { $0.removeFromSuperview() }
        
        if filteredItems.isEmpty {
            emptyLabel.isHidden = false
            restoreButton.isHidden = true
            metaLabel.stringValue = ""
            return
        }
        
        emptyLabel.isHidden = true
        restoreButton.isHidden = false
        
        let containerW = carouselContainer.bounds.width
        let containerH = carouselContainer.bounds.height
        
        let cardW: CGFloat = 210
        let cardH: CGFloat = 135
        let spacing: CGFloat = 18
        
        let currentItem = filteredItems[selectedIndex]
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let relTime = formatter.localizedString(for: currentItem.timestamp, relativeTo: Date())
        metaLabel.stringValue = "\(Int(currentItem.dimensions.width)) × \(Int(currentItem.dimensions.height))  •  \(relTime)"
        
        // Render 5 visible slots centered around selectedIndex: [i-2, i-1, i (center), i+1, i+2]
        let centerX = (containerW - cardW) / 2.0
        let centerY = (containerH - cardH) / 2.0
        
        let minIdx = max(selectedIndex - 2, 0)
        let maxIdx = min(selectedIndex + 2, filteredItems.count - 1)
        
        for idx in minIdx...maxIdx {
            let offset = idx - selectedIndex
            let cardX = centerX + CGFloat(offset) * (cardW + spacing)
            let isSelected = (idx == selectedIndex)
            
            let card = createCardView(
                item: filteredItems[idx],
                frame: NSRect(x: cardX, y: centerY, width: cardW, height: cardH),
                isSelected: isSelected,
                index: idx
            )
            
            if !isSelected {
                card.alphaValue = abs(offset) == 1 ? 0.6 : 0.28
            }
            
            carouselContainer.addSubview(card)
        }
        
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            }
        }
    }
    
    private func createCardView(item: HistoryItem, frame: NSRect, isSelected: Bool, index: Int) -> NSView {
        let card = NSView(frame: frame)
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.masksToBounds = true
        
        if isSelected {
            // Radiant Electric Blue border glow matching CleanShot X
            card.layer?.borderColor = NSColor(red: 0.05, green: 0.52, blue: 1.0, alpha: 1.0).cgColor
            card.layer?.borderWidth = 3.5
        } else {
            card.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
            card.layer?.borderWidth = 1.0
        }
        
        // Image View
        let imgView = NSImageView(frame: card.bounds.insetBy(dx: isSelected ? 3.5 : 0, dy: isSelected ? 3.5 : 0))
        imgView.image = item.image
        imgView.imageScaling = .scaleProportionallyUpOrDown
        imgView.wantsLayer = true
        imgView.layer?.cornerRadius = 11
        imgView.layer?.masksToBounds = true
        imgView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.28).cgColor
        card.addSubview(imgView)
        
        // Item Type Badge (GIF / Video)
        if item.itemType == .gif || item.itemType == .video {
            let badge = NSTextField(labelWithString: item.itemType == .gif ? "GIF" : "VIDEO")
            badge.font = NSFont.boldSystemFont(ofSize: 10)
            badge.textColor = .white
            badge.backgroundColor = NSColor.black.withAlphaComponent(0.68)
            badge.drawsBackground = true
            badge.alignment = .center
            badge.wantsLayer = true
            badge.layer?.cornerRadius = 4
            badge.layer?.masksToBounds = true
            badge.frame = NSRect(x: 8, y: frame.height - 26, width: 42, height: 18)
            card.addSubview(badge)
        }
        
        // Click to select this card
        let click = CustomCardClickGesture(target: self, action: #selector(cardClicked(_:)))
        click.cardIndex = index
        card.addGestureRecognizer(click)
        
        return card
    }
    
    @objc private func cardClicked(_ sender: CustomCardClickGesture) {
        selectedIndex = sender.cardIndex
        renderCarousel(animated: true)
    }
    
    @objc private func restoreClicked() {
        guard !filteredItems.isEmpty, selectedIndex < filteredItems.count else { return }
        let item = filteredItems[selectedIndex]
        
        dismissHistory()
        
        // 1. Copy to clipboard
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([item.image])
        
        // 2. Show floating Quick Access or open in Editor
        if SettingsManager.shared.openEditorDirectly {
            WindowManager.shared.openEditor(with: item.image)
        } else {
            WindowManager.shared.showQuickAccess(image: item.image, fileURL: item.fileURL)
        }
        
        WindowManager.shared.showToast(message: "✓ Restored to Quick Access & Clipboard!")
    }
}

final class CustomCardClickGesture: NSClickGestureRecognizer {
    var cardIndex: Int = 0
}
