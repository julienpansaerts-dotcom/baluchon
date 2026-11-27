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
                        .font(.ticket(14))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .cardRow()
                    if let source = detectedSource, !link.isEmpty {
                        Text("SOURCE : \(source.label.uppercased())")
                            .font(.ticket(10, weight: .bold)).foregroundStyle(Theme.sea)
                            .cardRow()
                    }
                    Button("COLLER LE LIEN") {
                        if let pasted = UIPasteboard.general.string { link = pasted }
                    }
                    .buttonStyle(InkButtonStyle(color: Theme.stamp))
                    .listRowBackground(Color.clear)
                } header: {
                    SectionLabel("Lien")
                } footer: {
                    Text("Instagram, Facebook, TikTok, YouTube Shorts, Pinterest, Google Maps, blog…")
                }

                Section {
                    TextEditor(text: $text).frame(minHeight: 90).cardRow()
                } header: {
                    SectionLabel("Texte ou légende (facultatif)")
                }

                Section {
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .images) {
                        Text(photoItems.isEmpty ? "Choisir des photos ou captures d'écran" : "\(photoItems.count) image(s) sélectionnée(s)")
                            .font(.display(16))
                    }
                    .cardRow()
                } footer: {
                    Text("Le texte des captures est lu directement sur ton iPhone (OCR), rien n'est envoyé.")
                }
            }
            .paperBackground()
            .navigationTitle("Nouvelle envie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Glisser dans le carnet") { Task { await submit() } }
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
