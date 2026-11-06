import SwiftUI

struct CardNotes: View {
    let repository: CardRepository
    let cardID: UUID
    @State private var choosing = false
    @State private var draft: CardNote?
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if let card = repository.card(id: cardID) {
                    VStack(spacing: 1) {
                        ForEach(card.notes) { note in
                            noteRow("普通备注", date: note.date, text: note.text) {
                                Menu {
                                    Button("编辑") { draft = note }
                                    Button("删除", role: .destructive) {
                                        do { try saveNotes(card.notes.filter { $0.id != note.id }) }
                                        catch { self.error = "无法删除备注。" }
                                    }
                                } label: { Image(systemName: "ellipsis").foregroundStyle(.secondary) }
                            }
                        }
                        noteRow("名片保存", date: card.createdAt, text: "来源：其他方式保存") { EmptyView() }
                    }
                }
            }
            .background(CardPalette.background)
            .navigationTitle("备注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }.accessibilityLabel("返回").accessibilityIdentifier("notes-back")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { choosing = true } label: {
                    Label("新增备注", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .foregroundStyle(.white).background(CardPalette.blue, in: Capsule())
                }.padding(.horizontal, 16).padding(.vertical, 10).background(.white)
            }
            .overlay {
                if choosing {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Button {
                                choosing = false
                                draft = CardNote(id: UUID(), text: "", date: .now)
                            } label: {
                                noteChoice("普通备注", icon: "note.text", color: .teal)
                            }
                            Button {} label: {
                                noteChoice("拜访日志", icon: "checklist", color: CardPalette.blue)
                            }.disabled(true)
                        }.buttonStyle(.plain).padding(.horizontal, 38)
                        Spacer().frame(height: 110)
                        Button { choosing = false } label: {
                            Image(systemName: "xmark.circle.fill").font(.largeTitle).foregroundStyle(.white)
                        }.accessibilityLabel("关闭")
                        Spacer().frame(height: 28)
                    }.background(.black.opacity(0.65)).ignoresSafeArea(edges: .top)
                }
            }
            .fullScreenCover(item: $draft) { note in
                NoteEditor(text: note.text) { text in
                    guard let card = repository.card(id: cardID) else { return }
                    var notes = card.notes
                    let updated = CardNote(id: note.id, text: text, date: .now)
                    if let index = notes.firstIndex(where: { $0.id == note.id }) {
                        notes[index] = updated
                    } else {
                        notes.append(updated)
                    }
                    try saveNotes(notes)
                }
            }
            .managementError($error)
        }
    }

    private func saveNotes(_ notes: [CardNote]) throws {
        guard var card = repository.card(id: cardID) else { throw CocoaError(.fileNoSuchFile) }
        card.noteEntries = notes
        card.note = nil
        card.updatedAt = .now
        try repository.save(card)
    }

    private func noteRow<Trailing: View>(_ title: String, date: Date, text: String,
                                         @ViewBuilder trailing: () -> Trailing) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                Text(date.formatted(.iso8601.year().month().day().dateSeparator(.dash)) + " " +
                     date.formatted(.dateTime.hour().minute()))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                trailing()
            }
            Text(text).font(.subheadline)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(.white)
    }

    private func noteChoice(_ title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 18) {
            Text(title)
            Image(systemName: icon).font(.system(size: 45))
        }.foregroundStyle(color).frame(maxWidth: .infinity, minHeight: 155)
            .background(.white, in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct NoteEditor: View {
    @State var text: String
    let save: (String) throws -> Void
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("请填写备注信息").foregroundStyle(.secondary)
                        .padding(.horizontal, 21).padding(.vertical, 28)
                }
                TextEditor(text: $text).scrollContentBackground(.hidden)
                    .accessibilityIdentifier("note-text")
                    .padding(.horizontal, 16).padding(.vertical, 20)
            }
            .navigationTitle("普通备注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do { try save(cleaned); dismiss() } catch { self.error = "无法保存备注。" }
                    }.disabled(cleaned.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    ForEach(["mic.fill", "photo.fill", "camera.fill", "mappin.circle.fill"], id: \.self) { icon in
                        Image(systemName: icon).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 45)
                    }
                }.background(Color(white: 0.98)).accessibilityHidden(true)
            }
            .managementError($error)
        }
    }

    private var cleaned: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
}
