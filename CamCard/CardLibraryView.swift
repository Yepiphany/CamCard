import SwiftUI

struct CardLibraryView: View {
    let repository: any CardRepository
    @State private var cards: [BusinessCard] = []
    @State private var loadFailed = false
    @State private var showsScanner = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if loadFailed {
                        ContentUnavailableView("无法读取名片", systemImage: "exclamationmark.circle")
                        Button("重试", action: loadCards)
                    } else if cards.isEmpty {
                        ContentUnavailableView(
                            "还没有名片",
                            systemImage: "person.crop.rectangle",
                            description: Text("点击下方扫描按钮添加名片")
                        )
                        .accessibilityIdentifier("empty-library")
                    }
                    ForEach(cards) { card in
                        NavigationLink {
                            CardDetailView(card: card)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(card.fields.name ?? "未命名名片").font(.headline)
                                    if let jobTitle = card.fields.jobTitle {
                                        Text(jobTitle).foregroundStyle(.secondary)
                                    }
                                    if let company = card.fields.company {
                                        Text(company).foregroundStyle(.secondary)
                                    }
                                    Text(card.createdAt, format: .dateTime.year().month().day())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "person.crop.rectangle")
                            }
                        }
                        .accessibilityIdentifier("card-\(card.id.uuidString)")
                    }
                } header: {
                    if !loadFailed {
                        Text("名片（\(cards.count) 张）")
                            .accessibilityIdentifier("card-count")
                    }
                }
            }
            .navigationTitle("名片夹")
            .safeAreaInset(edge: .bottom) {
                Button {
                    showsScanner = true
                } label: {
                    Label("扫描", systemImage: "camera")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("open-scanner")
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
            .fullScreenCover(isPresented: $showsScanner) {
                ScannerView()
            }
            .onAppear(perform: loadCards)
        }
    }

    private func loadCards() {
        do {
            cards = try repository.listCards()
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }
}

private struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white, lineWidth: 2)
                    .aspectRatio(1.6, contentMode: .fit)
                    .padding(28)
            }
            .navigationTitle("扫描名片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .accessibilityIdentifier("close-scanner")
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
