import Humation
import SwiftUI

public struct HumationEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding private var profile: HumationProfile
    @State private var draft: ResolvedHumation?
    @State private var selectedTabID: String

    private let seed: String?
    private let configuration: HumationEditorConfiguration

    private static let previewSize: CGFloat = 132
    private static let tabBarHeight: CGFloat = 58
    private static let horizontalInset: CGFloat = 16
    private static let partCellHeight: CGFloat = 100
    private static let partGridGap: CGFloat = 6
    private static let scrollTopID = "humation-editor-scroll-top"

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 76), spacing: Self.partGridGap),
            count: 3
        )
    }

    public init(
        profile: Binding<HumationProfile>,
        seed: String? = nil,
        configuration: HumationEditorConfiguration = .init()
    ) {
        _profile = profile
        self.seed = seed
        self.configuration = configuration
        _selectedTabID = State(initialValue: configuration.tabs.first?.id ?? "")
    }

    public var body: some View {
        Group {
            if let manifest = Humation.manifest {
                content(manifest: manifest, draft: currentDraft(in: manifest))
            } else {
                Text("Humation assets unavailable")
                    .font(configuration.font(15, .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(HumationEditorColor.background)
        .onAppear {
            initializeDraftIfNeeded()
        }
    }

    private func content(manifest: HumationManifest, draft: ResolvedHumation) -> some View {
        VStack(spacing: 0) {
            previewHeader(manifest: manifest, draft: draft)

            if configuration.tabs.count > 1 {
                tabBar
            }

            partsPanel(manifest: manifest, draft: draft)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tabBar: some View {
        Picker("Parts", selection: $selectedTabID) {
            ForEach(configuration.tabs) { tab in
                Text(tab.title)
                    .font(configuration.font(15, .semibold))
                    .tag(tab.id)
            }
        }
        .pickerStyle(.segmented)
        .font(configuration.font(15, .semibold))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .frame(height: Self.tabBarHeight, alignment: .top)
    }

    private func previewHeader(manifest: HumationManifest, draft: ResolvedHumation) -> some View {
        VStack(spacing: 12) {
            HumationAvatarView(resolved: draft, size: Self.previewSize)
                .clipShape(Circle())
                .background(HumationEditorColor.color(hex: draft.background), in: Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))

            Button {
                randomize(manifest: manifest)
            } label: {
                Label("Randomize", systemImage: "arrow.triangle.2.circlepath")
                    .font(configuration.font(15, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .buttonStyle(.bordered)
            .tint(configuration.accent)
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private func partsPanel(manifest: HumationManifest, draft: ResolvedHumation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id(Self.scrollTopID)

                if !globalColorSlots.isEmpty {
                    colorSection(title: "Colors", colorSlots: globalColorSlots, draft: draft, manifest: manifest)
                        .padding(.bottom, 18)
                }

                if let tab = selectedTab {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(tab.slots, id: \.self) { slot in
                            slotSection(slot: slot, draft: draft, manifest: manifest)
                        }
                    }
                }
            }
            .onChange(of: selectedTabID) { _ in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    proxy.scrollTo(Self.scrollTopID, anchor: .top)
                }
            }
        }
    }

    private func slotSection(
        slot: HumationSelectionSlot,
        draft: ResolvedHumation,
        manifest: HumationManifest
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            let colorSlots = colorSlots(for: slot)
            if !colorSlots.isEmpty {
                colorRows(colorSlots: colorSlots, draft: draft, manifest: manifest)
                    .padding(.bottom, 2)
            }

            Text(slotTitle(slot))
                .font(configuration.font(14, .heavy))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Self.horizontalInset)

            LazyVGrid(columns: columns, spacing: Self.partGridGap) {
                ForEach(manifest.parts(in: slot), id: \.id) { part in
                    partCell(part: part, slot: slot, draft: draft, manifest: manifest)
                }
            }
            .padding(.horizontal, Self.horizontalInset)
        }
    }

    private func partCell(
        part: HumationManifest.Part,
        slot: HumationSelectionSlot,
        draft: ResolvedHumation,
        manifest: HumationManifest
    ) -> some View {
        let variant = partPreviewVariant(part: part, slot: slot, draft: draft)
        let crop = HumationEditorPartCrop.crop(for: part, slot: slot, in: manifest)
        let isSelected = draft.selections[slot] == part.id

        return Button {
            select(part: part, slot: slot, manifest: manifest)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                    .fill(cellBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                            .strokeBorder(
                                isSelected ? configuration.accent : Color.clear,
                                lineWidth: 3
                            )
                    }

                if let crop {
                    HumationEditorRenderView(
                        resolved: variant,
                        manifest: manifest,
                        size: HumationEditorPartCrop.previewSize(for: slot),
                        crop: crop
                    )
                } else {
                    Image(systemName: "slash.circle")
                        .font(configuration.font(25, .bold))
                        .foregroundStyle(Color.secondary.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.partCellHeight)
            .contentShape(
                RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(part.name ?? part.id)
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    private func colorSection(
        title: String,
        colorSlots: [HumationColorSlot],
        draft: ResolvedHumation,
        manifest: HumationManifest
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(configuration.font(14, .heavy))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Self.horizontalInset)

            colorRows(colorSlots: colorSlots, draft: draft, manifest: manifest)
        }
    }

    private func colorRows(
        colorSlots: [HumationColorSlot],
        draft: ResolvedHumation,
        manifest: HumationManifest
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(colorSlots, id: \.self) { colorSlot in
                VStack(alignment: .leading, spacing: 8) {
                    Text(colorTitle(colorSlot))
                        .font(configuration.font(13, .heavy))
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, Self.horizontalInset)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 9) {
                            ForEach(configuration.colorPalettes[colorSlot] ?? [], id: \.self) { hex in
                                colorDot(
                                    colorSlot: colorSlot,
                                    hex: hex,
                                    draft: draft,
                                    manifest: manifest
                                )
                            }
                        }
                        .padding(.horizontal, Self.horizontalInset)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func colorDot(
        colorSlot: HumationColorSlot,
        hex: String,
        draft: ResolvedHumation,
        manifest: HumationManifest
    ) -> some View {
        let normalized = HumationEngine.normalizeHex(hex)
        let current = draft.hex(for: colorSlot)
        let isSelected = current?.caseInsensitiveCompare(normalized) == .orderedSame

        return Button {
            select(colorSlot: colorSlot, hex: normalized, manifest: manifest)
        } label: {
            Circle()
                .fill(HumationEditorColor.color(hex: normalized))
                .frame(width: 40, height: 40)
                .overlay(Circle().strokeBorder(colorChipBorder, lineWidth: 1.5))
                .padding(6)
                .overlay(
                    Circle().strokeBorder(
                        isSelected ? configuration.accent : Color.clear,
                        lineWidth: 3
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(colorTitle(colorSlot))
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    private var selectedTab: HumationEditorConfiguration.Tab? {
        if let exact = configuration.tabs.first(where: { $0.id == selectedTabID }) {
            return exact
        }
        return configuration.tabs.first
    }

    private var globalColorSlots: [HumationColorSlot] {
        var slots: [HumationColorSlot] = [.stroke]
        if configuration.showsBackgroundColors {
            slots.insert(.background, at: 0)
        }
        return slots.filter { !(configuration.colorPalettes[$0] ?? []).isEmpty }
    }

    private var cellBackground: Color {
        configuration.cellBackground ?? HumationEditorColor.secondaryBackground
    }

    private var colorChipBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.30) : Color.black.opacity(0.22)
    }

    private func colorSlots(for slot: HumationSelectionSlot) -> [HumationColorSlot] {
        let slots: [HumationColorSlot]
        switch slot {
        case .head:
            slots = [.hair]
        case .body:
            slots = [.clothes, .skin]
        case .bottom:
            slots = [.bottom]
        case .item, .glasses:
            slots = []
        }
        return slots.filter { !(configuration.colorPalettes[$0] ?? []).isEmpty }
    }

    private func partPreviewVariant(
        part: HumationManifest.Part,
        slot: HumationSelectionSlot,
        draft: ResolvedHumation
    ) -> ResolvedHumation {
        var variant = draft
        variant.selections = [slot: part.id]
        variant.background = "transparent"
        return variant
    }

    private func select(
        part: HumationManifest.Part,
        slot: HumationSelectionSlot,
        manifest: HumationManifest
    ) {
        var updated = currentDraft(in: manifest)
        updated.selections[slot] = part.id
        draft = updated
        commit(updated)
    }

    private func select(
        colorSlot: HumationColorSlot,
        hex: String,
        manifest: HumationManifest
    ) {
        var updated = currentDraft(in: manifest)
        if colorSlot == .background {
            updated.background = HumationEngine.normalizeHex(hex)
        } else {
            updated.colors[colorSlot] = HumationEngine.normalizeHex(hex)
        }
        draft = updated
        commit(updated)
    }

    private func randomize(manifest: HumationManifest) {
        var updated = currentDraft(in: manifest)

        for slot in HumationSelectionSlot.allCases {
            if let pick = manifest.parts(in: slot).randomElement() {
                updated.selections[slot] = pick.id
            }
        }

        for colorSlot in HumationColorSlot.allCases {
            guard let hex = configuration.colorPalettes[colorSlot]?.randomElement() else {
                continue
            }
            let normalized = HumationEngine.normalizeHex(hex)
            if colorSlot == .background {
                updated.background = normalized
            } else {
                updated.colors[colorSlot] = normalized
            }
        }

        draft = updated
        commit(updated)
    }

    private func initializeDraftIfNeeded() {
        guard draft == nil, let manifest = Humation.manifest else {
            return
        }
        let resolved = profile.resolved(against: manifest, seed: seed)
        draft = resolved
    }

    private func currentDraft(in manifest: HumationManifest) -> ResolvedHumation {
        draft ?? profile.resolved(against: manifest, seed: seed)
    }

    private func commit(_ resolved: ResolvedHumation) {
        profile = HumationProfile(resolved: resolved)
    }

    private func colorTitle(_ slot: HumationColorSlot) -> String {
        switch slot {
        case .background:
            return "Background"
        case .stroke:
            return "Line"
        case .hair:
            return "Hair"
        case .skin:
            return "Skin"
        case .clothes:
            return "Wear"
        case .bottom:
            return "Bottom"
        }
    }

    private func slotTitle(_ slot: HumationSelectionSlot) -> String {
        switch slot {
        case .head:
            return "Head"
        case .body:
            return "Body"
        case .bottom:
            return "Bottom"
        case .item:
            return "Item"
        case .glasses:
            return "Glasses"
        }
    }
}
