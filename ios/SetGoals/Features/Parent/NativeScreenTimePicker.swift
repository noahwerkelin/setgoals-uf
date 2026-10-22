import SwiftUI
import FamilyControls

/// Edits a draft: opening/cancelling never writes an empty selection.
struct NativeScreenTimePicker: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: SettingsStore
    let alwaysAllowed: Bool
    let onSave: () -> Void
    @State private var draft: FamilyActivitySelection

    init(alwaysAllowed: Bool, onSave: @escaping () -> Void) {
        self.alwaysAllowed = alwaysAllowed
        self.onSave = onSave
        _draft = State(initialValue: alwaysAllowed ? ScreenTimeRules.alwaysAllowed : ScreenTimeRules.restricted)
    }

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $draft)
                .navigationTitle(L.t(alwaysAllowed ? "dashboard.always" : "dashboard.earned_only"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L.t("settings.cancel")) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L.t("settings.save")) {
                            // The child cannot change the parent's policy on this device.
                            guard settings.role != "child" else { dismiss(); return }
                            ScreenTimeService.shared.replaceSelection(draft, alwaysAllowed: alwaysAllowed)
                            onSave()
                            dismiss()
                        }
                    }
                }
        }
        .tint(theme.primary)
    }
}