import SwiftUI

// MARK: - Humation Editor Example
//
// A self-contained "build your avatar" editor built only with SwiftUI + Humation
// (no app dependencies). Demonstrates the full flow: live preview, per-slot part
// grid, colour swatches, and randomise. Drop it into any app or preview it as-is.

public struct HumationEditorExample: View {
    @State private var draft: ResolvedHumation?
    @State private var slot: HumationSelectionSlot = .head

    public init() {}

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    public var body: some View {
        Group {
            if let manifest = HumationManifestStore.shared, let draft {
                content(manifest: manifest, draft: draft)
            } else {
                Text("Humation assets unavailable")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if draft == nil, let manifest = HumationManifestStore.shared {
                draft = HumationTraits(seed: "example").resolved(against: manifest)
            }
        }
    }

    @ViewBuilder
    private func content(manifest: HumationManifest, draft: ResolvedHumation) -> some View {
        VStack(spacing: 16) {
            HumationAvatarView(resolved: draft, size: 120)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.quaternary))

            Button {
                randomize(manifest: manifest)
            } label: {
                Label("Randomize", systemImage: "dice")
            }
            .buttonStyle(.bordered)

            Picker("Slot", selection: $slot) {
                ForEach(HumationSelectionSlot.allCases, id: \.self) { s in
                    Text(s.rawValue.capitalized).tag(s)
                }
            }
            .pickerStyle(.segmented)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(manifest.parts(in: slot), id: \.id) { part in
                        partCell(part: part, draft: draft, manifest: manifest)
                    }
                }
                colorRows(draft: draft)
                    .padding(.top, 16)
            }
        }
        .padding()
    }

    private func partCell(
        part: HumationManifest.Part, draft: ResolvedHumation, manifest: HumationManifest
    ) -> some View {
        var variant = draft
        variant.selections = [slot: part.id]
        variant.background = "transparent"
        let isSelected = draft.selections[slot] == part.id
        return Button {
            self.draft?.selections[slot] = part.id
        } label: {
            HumationAvatarView(resolved: variant, size: 88)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                                      lineWidth: isSelected ? 3 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func colorRows(draft: ResolvedHumation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(HumationColorSlot.allCases, id: \.self) { colorSlot in
                VStack(alignment: .leading, spacing: 6) {
                    Text(colorSlot.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Self.palette[colorSlot] ?? [], id: \.self) { hex in
                                colorDot(colorSlot: colorSlot, hex: hex, draft: draft)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func colorDot(
        colorSlot: HumationColorSlot, hex: String, draft: ResolvedHumation
    ) -> some View {
        let current = colorSlot == .background ? draft.background : draft.colors[colorSlot]
        let isSelected = current?.caseInsensitiveCompare(hex) == .orderedSame
        return Circle()
            .fill(Self.color(hex))
            .frame(width: 30, height: 30)
            .overlay(Circle().strokeBorder(.quaternary))
            .padding(4)
            .overlay(Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3))
            .onTapGesture {
                if colorSlot == .background {
                    self.draft?.background = HumationEngine.normalizeHex(hex)
                } else {
                    self.draft?.colors[colorSlot] = HumationEngine.normalizeHex(hex)
                }
            }
    }

    private func randomize(manifest: HumationManifest) {
        for s in HumationSelectionSlot.allCases {
            if let pick = manifest.parts(in: s).randomElement() {
                draft?.selections[s] = pick.id
            }
        }
    }

    // MARK: Demo palette

    private static let palette: [HumationColorSlot: [String]] = [
        .background: ["F6F5F4", "FFFFFF", "FFE5EC", "E6F4EA", "E3F2FD", "EDE7F6"],
        .stroke: ["000000", "3A2E2E", "2B2D42", "4A4A4A"],
        .hair: ["000000", "3A2E2E", "5B3A1E", "8B4513", "C8843C", "D4A017", "BFBFBF", "B23A48"],
        .skin: ["FFFFFF", "FFDCB8", "F1C27D", "E0AC69", "C68642", "8D5524", "5C3A21"],
        .clothes: ["FFFFFF", "2A2A2A", "E63946", "F4A261", "2A9D8F", "457B9D", "6A4C93"],
        .bottom: ["000000", "2B2D42", "3A5F8A", "556B2F", "8B0000"],
    ]

    private static func color(_ hex: String) -> Color {
        guard let rgba = HumationRGBA(hex: hex) else { return .gray }
        return Color(red: rgba.r, green: rgba.g, blue: rgba.b)
    }
}

#if DEBUG
struct HumationEditorExample_Previews: PreviewProvider {
    static var previews: some View {
        HumationEditorExample()
    }
}
#endif
