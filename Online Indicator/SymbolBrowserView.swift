import SwiftUI
import AppKit

// MARK: - Notification

extension Notification.Name {
    static let symbolCopied = Notification.Name("com.OnlineIndicator.symbolCopied")
}

// MARK: - SF Symbol Browser

struct SymbolBrowserView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return Self.allSymbols }
        return Self.allSymbols.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 9)

    var body: some View {
        VStack(spacing: 0) {

            // ── Title bar ────────────────────────────────────────────
            HStack {
                Text("SF Symbols")
                    .font(.system(size: 13, weight: .semibold))
                Text("· \(filtered.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.windowBackgroundColor))

            Divider()

            // ── Search ────────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                TextField("Search symbols…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor))
            .overlay(
                Rectangle().frame(height: 1).foregroundStyle(Color.primary.opacity(0.07)),
                alignment: .bottom
            )

            // ── Grid ──────────────────────────────────────────────────
            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No symbols found")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(filtered, id: \.self) { name in
                            SymbolCell(name: name) {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(name, forType: .string)
                                dismiss()
                                NotificationCenter.default.post(
                                    name: .symbolCopied,
                                    object: name
                                )
                            }
                        }
                    }
                    .padding(10)
                }
            }

            // ── Hint bar ──────────────────────────────────────────────
            Divider()
            HStack(spacing: 4) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Text("Tap any symbol to copy its name and close this panel")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Color(.windowBackgroundColor))
        }
        .frame(width: 460, height: 500)
    }
}

// MARK: - Symbol Cell

private struct SymbolCell: View {

    let name: String
    let onTap: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onTap) {
            Image(systemName: name)
                .font(.system(size: 17, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(hovered ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(name)
        .onHover { hovered = $0 }
    }
}

// MARK: - 500+ Pro Symbol Library (macOS Sonoma safe)

extension SymbolBrowserView {

    static let allSymbols: [String] = {

        let candidates: [String] = [

        // ===== NETWORK CORE =====
        "wifi","wifi.slash","wifi.exclamationmark","wifi.circle","wifi.square",
        "wifi.router","network","network.slash",
        "antenna.radiowaves.left.and.right",
        "antenna.radiowaves.left.and.right.slash",
        "dot.radiowaves.left.and.right",
        "dot.radiowaves.forward",
        "dot.radiowaves.right",
        "globe","globe.americas","globe.europe.africa","globe.asia.australia",
        "globe.central.south.asia",
        "cable.connector","server.rack",
        "externaldrive.connected.to.line.below",
        "network.badge.shield.half.filled",

        // ===== SPEED / PERFORMANCE =====
        "speedometer","gauge","timer","stopwatch",
        "bolt","bolt.fill","bolt.circle","bolt.horizontal",
        "bolt.horizontal.circle","bolt.slash",
        "hare","tortoise",
        "arrow.up","arrow.down","arrow.left","arrow.right",
        "arrow.clockwise","arrow.counterclockwise",
        "arrow.triangle.2.circlepath",
        "arrow.up.circle","arrow.down.circle",
        "arrow.left.circle","arrow.right.circle",
        "arrow.up.arrow.down","arrow.left.arrow.right",
        "arrow.up.and.down","arrow.left.and.right",
        "repeat","shuffle","infinity",

        // ===== STATUS =====
        "circle","circle.fill","circle.dashed","circle.dotted",
        "checkmark","xmark","plus","minus",
        "checkmark.circle","checkmark.circle.fill",
        "xmark.circle","xmark.circle.fill",
        "plus.circle","minus.circle",
        "exclamationmark.circle","exclamationmark.circle.fill",
        "questionmark.circle","info.circle",
        "checkmark.seal","checkmark.shield",
        "xmark.seal","xmark.shield",

        // ===== SECURITY / VPN =====
        "lock","lock.fill","lock.open","lock.slash",
        "lock.shield","lock.shield.fill",
        "lock.rotation",
        "shield","shield.fill","shield.slash",
        "shield.lefthalf.filled",
        "checkmark.shield","xmark.shield","exclamationmark.shield",
        "key","key.fill","key.slash",
        "key.icloud","key.radiowaves.forward",
        "eye","eye.fill","eye.slash","eye.circle",
        "eye.trianglebadge.exclamationmark",
        "hand.raised","hand.raised.slash",

        // ===== CLOUD / INTERNET =====
        "icloud","icloud.fill","icloud.slash",
        "icloud.and.arrow.up","icloud.and.arrow.down",
        "externaldrive","externaldrive.fill","externaldrive.badge.plus",
        "internaldrive","internaldrive.fill",
        "cloud","cloud.fill","cloud.slash",
        "cloud.bolt","cloud.bolt.rain",
        "cloud.rain","cloud.heavyrain",
        "cloud.snow","cloud.sun","cloud.moon",
        "cloud.fog","cloud.hail","cloud.drizzle",

        // ===== DEVICES =====
        "desktopcomputer","laptopcomputer","display",
        "display.trianglebadge.exclamationmark",
        "iphone","iphone.circle","iphone.slash",
        "ipad","ipad.landscape",
        "applewatch","applewatch.slash",
        "tv","tv.fill","tv.slash",
        "keyboard","keyboard.fill","keyboard.slash",
        "mouse","mouse.fill","trackpad","trackpad.fill",
        "printer","printer.fill","printer.slash",
        "scanner","camera","camera.fill","camera.slash",
        "video","video.fill","video.slash",
        "speaker","speaker.fill","speaker.slash",
        "speaker.wave.1","speaker.wave.2","speaker.wave.3",
        "mic","mic.fill","mic.slash",
        "cpu","memorychip","opticaldiscdrive",

        // ===== DATA / TRAFFIC =====
        "chart.bar","chart.bar.fill","chart.bar.xaxis",
        "chart.pie","chart.pie.fill",
        "chart.line.uptrend.xyaxis","chart.line.downtrend.xyaxis",
        "chart.xyaxis.line",
        "waveform","waveform.circle",
        "waveform.path.ecg",
        "arrow.up.doc","arrow.down.doc",
        "arrow.up.circle","arrow.down.circle",
        "arrow.left.arrow.right.circle",
        "arrow.up.arrow.down.circle",

        // ===== POWER =====
        "power","power.circle","powerplug",
        "battery.100","battery.75","battery.50","battery.25","battery.0",
        "battery.100.bolt","battery.exclamationmark",
        "bolt.batteryblock",

        // ===== ALERT / WARNING =====
        "exclamationmark.triangle","exclamationmark.octagon",
        "exclamationmark.shield",
        "bell","bell.fill","bell.slash","bell.badge",
        "flag","flag.fill","flag.slash",
        "nosign","slash.circle","xmark.octagon",

        // ===== TOOLS =====
        "gear","gearshape","gearshape.fill",
        "gearshape.2","gearshape.2.fill",
        "slider.horizontal.3","slider.vertical.3",
        "switch.2","dial.low","dial.medium","dial.high",
        "wrench","wrench.fill",
        "hammer","hammer.fill",
        "screwdriver","wrench.and.screwdriver",
        "paintbrush","paintbrush.fill",
        "scissors","pencil","highlighter",

        // ===== USER =====
        "person","person.fill","person.2","person.3",
        "person.crop.circle","person.crop.circle.fill",
        "person.badge.plus","person.badge.minus",
        "person.badge.shield.checkmark",
        "figure.walk","figure.run","figure.stand",
        "figure.wave","figure.cooldown",

        // ===== LOCATION =====
        "location","location.fill","location.slash",
        "location.circle","location.square",
        "map","map.fill",
        "mappin","mappin.circle",
        "location.north","location.north.circle",
        "airplane","airplane.circle",
        "car","car.fill","bus","tram","bicycle",

        // ===== TIME =====
        "clock","clock.fill","clock.circle",
        "alarm","alarm.fill",
        "timer","hourglass",
        "calendar","calendar.badge.clock",

        // ===== COMMUNICATION =====
        "message","message.fill","bubble.left","bubble.right",
        "bubble.left.and.bubble.right",
        "phone","phone.fill","phone.slash",
        "envelope","envelope.fill","envelope.badge",
        "video.badge.plus","megaphone",

        // ===== FAVORITES USERS EXPECT =====
        "star","star.fill","star.circle",
        "bookmark","bookmark.fill",
        "heart","heart.fill","heart.circle",
        "flame","drop","leaf","sparkles",
        "moon","sun.max","sunrise","sunset",

        // ===== DEV / PRO =====
        "terminal","curlybraces","chevron.left.slash.chevron.right",
        "app","app.fill","shippingbox","cube",
        "puzzlepiece","shippingbox.fill",
        "qrcode","barcode","viewfinder",

        // ===== EXTRA MASS (for 500+) =====
        "square","square.fill","rectangle","triangle","diamond",
        "seal","rosette","tag","tag.fill",
        "tray","tray.fill","archivebox","archivebox.fill",
        "doc","doc.fill","doc.text","doc.richtext",
        "folder","folder.fill","folder.badge.plus",
        "trash","trash.fill","trash.slash",
        "link","link.circle","link.badge.plus",
        "pin","pin.fill","pin.circle",
        "cart","cart.fill","creditcard","bag",
        "gift","banknote","chart.donut",
        "music.note","play.fill","pause.fill","stop.fill",
        "forward","backward","record.circle",
        "gamecontroller","dice","trophy","medal"
        ]

        // macOS validation filter
        let valid = candidates.filter {
            NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil
        }

        // remove duplicates + sort
        return Array(Set(valid)).sorted()
    }()
}
