import AgendouCore
import AgendouStore
import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

struct SettingsScreen: View {
    @Environment(AgendaStore.self) private var store
    @Environment(ShiftNotifier.self) private var notifier
    @Environment(\.openURL) private var openURL
    @Environment(\.showTutorial) private var showTutorial
    @State private var importing = false
    @State private var pendingImport: AgendaExport?
    @State private var errorMessage: String?
    @State private var imported = false
    @State private var notificationsDenied = false

    var body: some View {
        NavigationStack {
            Form {
                reminderSection
                Section {
                    ShareLink(item: backup(), preview: SharePreview("Backup do Agendou")) {
                        Label("Exportar dados", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("settings.export")
                    Button {
                        importing = true
                    } label: {
                        Label("Importar dados", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityIdentifier("settings.import")
                } header: {
                    Text("Backup")
                } footer: {
                    Text(
                        "O arquivo tem os locais, as escalas, os plantões marcados à mão e as anotações. Importar substitui tudo o que está no app."
                    )
                }
                Section {
                    Button("Ver tutorial", systemImage: "questionmark.circle", action: showTutorial)
                        .accessibilityIdentifier("settings.tutorial")
                    LabeledContent("Versão") {
                        Text(version)
                            .accessibilityIdentifier("settings.version")
                    }
                } footer: {
                    Text("Os dados ficam só neste iPhone: o app não usa internet nem conta.")
                }
            }
            .navigationTitle("Ajustes")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json], onCompletion: read)
            .confirmationDialog(
                "Substituir todos os dados?",
                isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
                titleVisibility: .visible, presenting: pendingImport
            ) { export in
                Button("Substituir", role: .destructive) { replace(with: export) }
            } message: { export in
                Text(
                    "O arquivo tem \(export.categories.count) locais, \(export.schedules.count) escalas, \(export.overrides.count) marcações e \(export.dayNotes.count) anotações. Tudo o que está no app agora será apagado."
                )
            }
            .errorAlert($errorMessage, title: "Não foi possível importar")
            .alert("Dados importados", isPresented: $imported) {
                Button("OK") {}
            }
            .alert("Notificações desativadas", isPresented: $notificationsDenied) {
                Button("Abrir Ajustes") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Agora não", role: .cancel) {}
            } message: {
                Text("Para receber o lembrete, permita as notificações do Agendou nos Ajustes do iPhone.")
            }
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle(
                "Lembrete do plantão",
                isOn: Binding(
                    get: { notifier.isEnabled },
                    set: { enabled in
                        Task { notificationsDenied = !(await notifier.setEnabled(enabled)) }
                    })
            )
            .accessibilityIdentifier("settings.reminder")
            .tourAnchor(.reminder)
            if notifier.isEnabled {
                DatePicker("Horário", selection: reminderTime, displayedComponents: .hourAndMinute)
                    .accessibilityIdentifier("settings.reminder.time")
            }
        } header: {
            Text("Notificações")
        } footer: {
            Text(
                "Um aviso por dia, só nos dias com plantão. Plantão que passa da meia-noite conta no dia em que começa."
            )
        }
    }

    /// The reminder time as a date today, so the picker edits hour and minute only.
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                CivilCalendar.calendar.date(
                    bySettingHour: notifier.hour, minute: notifier.minute, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = CivilCalendar.calendar.dateComponents([.hour, .minute], from: date)
                Task { await notifier.setTime(hour: parts.hour ?? 7, minute: parts.minute ?? 0) }
            })
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    private func backup() -> AgendaBackup {
        let today = CivilCalendar.date(containing: Date.now.epochSeconds)
        return AgendaBackup(data: (try? store.exportData()) ?? Data(), fileName: "Agendou-\(today.string).json")
    }

    /// Reads and validates the whole file; nothing changes until the user confirms.
    private func read(_ result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            pendingImport = try AgendaExport.decode(Data(contentsOf: url))
        } catch {
            errorMessage = (error as? AgendaImportError)?.message ?? userMessage(for: error)
        }
    }

    private func replace(with export: AgendaExport) {
        do {
            try store.replaceAll(with: export)
            imported = true
        } catch {
            errorMessage = (error as? AgendaImportError)?.message ?? userMessage(for: error)
        }
    }
}

/// The backup as a JSON file named after the day it was made.
nonisolated struct AgendaBackup: Transferable {
    let data: Data
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { backup in
            let url = URL.temporaryDirectory.appending(path: backup.fileName)
            try backup.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

extension AgendaImportError {
    var message: String {
        switch self {
        case .unreadable:
            String(localized: "O arquivo não é um backup do Agendou ou está corrompido.")
        case .unsupportedVersion:
            String(
                localized: "Este backup foi feito por uma versão mais nova do Agendou. Atualize o app para importar.")
        case .duplicateID, .unknownCategory, .invalidSchedule, .overlappingSchedules, .invalidOverride,
            .duplicateOverride, .invalidDayNote:
            String(localized: "O backup tem dados inconsistentes e não foi importado. Nada foi alterado.")
        }
    }
}

#Preview {
    SettingsScreen()
        .environment(AgendaStore.preview)
        .environment(ShiftNotifier.preview)
        .agendouEnvironment()
}
