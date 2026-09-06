import SwiftUI

/// The four legal documents, rendered with the app's card styling.
enum LegalDoc: String, Identifiable, CaseIterable {
    case privacy, terms, subs, community

    var id: String { rawValue }
    var titleKey: String { "legal.\(rawValue).title" }
    var bodyKey: String { "legal.\(rawValue).body" }
    var title: String { L.t(titleKey) }
    var body: String { L.t(bodyKey) }

    var icon: String {
        switch self {
        case .privacy: return "lock.shield"
        case .terms: return "doc.text"
        case .subs: return "creditcard"
        case .community: return "person.2"
        }
    }
}

/// List of all documents — opened from Settings → Legal & Privacy.
struct LegalCenterSheet: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    @State private var open: LegalDoc?

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L.t("legal.sub")).font(F.sm).foregroundStyle(theme.p.s600)
                            .padding(.bottom, 4)
                        VStack(spacing: 0) {
                            ForEach(Array(LegalDoc.allCases.enumerated()), id: \.element.id) { i, doc in
                                if i > 0 { Rectangle().fill(theme.p.s100).frame(height: 1) }
                                Button { open = doc } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: doc.icon).font(.system(size: 15))
                                            .foregroundStyle(theme.p.s700)
                                            .frame(width: 32, height: 32)
                                            .background(theme.p.s100,
                                                        in: RoundedRectangle(cornerRadius: R.lg, style: .continuous))
                                        Text(doc.title).font(F.sans(14, .medium))
                                            .foregroundStyle(theme.p.s950)
                                            .multilineTextAlignment(.leading)
                                        Spacer(minLength: 12)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(theme.p.s600)
                                    }
                                    .padding(16)
                                    .contentShape(Rectangle())
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                            .strokeBorder(theme.ringBorder, lineWidth: 1))
                    }
                    .padding(24)
                }
            }
            .navigationTitle(L.t("legal.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t("legal.close")) { dismiss() }
                        .font(F.sans(14, .semibold)).foregroundStyle(theme.p.s700)
                }
            }
        }
        .sheet(item: $open) { LegalDocSheet(doc: $0) }
        .appSheet(detents: [.large])
    }
}

/// A single document.
struct LegalDocSheet: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let doc: LegalDoc

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in
                            if b.isHeading {
                                Text(b.text).font(F.sans(15, .semibold))
                                    .foregroundStyle(theme.p.s950)
                            } else {
                                Text(b.text).font(F.sm).foregroundStyle(theme.p.s700)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                        .strokeBorder(theme.ringBorder, lineWidth: 1))
                    .padding(24)
                }
            }
            .navigationTitle(doc.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t("legal.close")) { dismiss() }
                        .font(F.sans(14, .semibold)).foregroundStyle(theme.p.s700)
                }
            }
        }
        .appSheet(detents: [.large])
    }

    private struct Block { let text: String; let isHeading: Bool }

    private var blocks: [Block] {
        doc.body
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { line in
                line.hasPrefix("## ")
                    ? Block(text: String(line.dropFirst(3)), isHeading: true)
                    : Block(text: line, isHeading: false)
            }
    }
}
