import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Ajout manuel : coller un lien ou un texte, ou choisir des captures d'écran.
struct AddInspirationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var text = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isWorking = false

    private var detectedSource: InspirationSource? { InspirationSource.detect(urlString: link) }
    private var canSubmit: Bool { !link.isEmpty || !text.isEmpty || !photoItems.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://www.instagram.com/p/…", text: $link)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if let source = detectedSource, !link.isEmpty {
                        Label("Source détectée : \(source.label)", systemImage: source.symbol)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button {
                        if let pasted = UIPasteboard.general.string { link = pasted }
                    } label: {
                        Label("Coller depuis le presse-papiers", systemImage: "doc.on.clipboard")
                    }
                } header: {
                    Text("Lien")
                } footer: {
                    Text("Instagram, Facebook, TikTok, YouTube Shorts, Pinterest, Google Maps, blog…")
                }

                Section("Texte ou légende (facultatif)") {
                    TextEditor(text: $text).frame(minHeight: 90)
                }

                Section {
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .images) {
                        Label(photoItems.isEmpty ? "Choisir des photos ou captures d'écran" : "\(photoItems.count) image(s) sélectionnée(s)",
                              systemImage: "photo.on.rectangle.angled")
                    }
                } footer: {
                    Text("Le texte des captures est lu directement sur ton iPhone (OCR), rien n'est envoyé.")
                }
            }
            .navigationTitle("Nouvelle inspiration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Analyser") { Task { await submit() } }
                            .disabled(!canSubmit)
                    }
                }
            }
        }
    }

    private func submit() async {
        isWorking = true
        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLink.isEmpty || !text.isEmpty {
            await InspirationPipeline.add(urlString: trimmedLink.isEmpty ? nil : trimmedLink, text: text, imageData: nil, into: context)
        }
        for item in photoItems {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await InspirationPipeline.add(urlString: nil, text: text, imageData: data, into: context)
            }
        }
        isWorking = false
        dismiss()
    }
}
