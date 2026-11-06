import SwiftUI

enum CardPalette {
    static let blue = Color(red: 0.10, green: 0.65, blue: 0.95)
    static let navy = Color(red: 0.08, green: 0.21, blue: 0.39)
    static let background = Color(white: 0.94)
}

struct CardLibraryView: View {
    let repository: any CardRepository
    @State private var cards: [BusinessCard] = []
    @State private var loadFailed = false
    @State private var showsScanner = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    searchBar
                    shortcuts
                    cardPanel
                }
            }
            .background(CardPalette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showsScanner) { ScannerView() }
            .onAppear(perform: loadCards)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "ellipsis.message").font(.title2)
            Label("请输入姓名/公司/职位搜索", systemImage: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(.white, in: Capsule())
            Image(systemName: "plus.circle").font(.title2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 7)
    }

    private var shortcuts: some View {
        HStack(spacing: 12) {
            shortcut("新的人脉", icon: "person.crop.circle.fill", color: CardPalette.blue)
            shortcut("分组管理", icon: "folder.fill.badge.plus", color: .orange)
            shortcut("人脉地图", icon: "map.fill", color: .green)
            shortcut("人脉分析", icon: "chart.bar.fill", color: CardPalette.blue)
        }
        .padding(.horizontal, 16)
    }

    private func shortcut(_ title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(title).font(.footnote)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 84)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
    }

    private var cardPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                (Text("名片").bold() + Text(" (\(cards.count)张)").foregroundColor(.secondary))
                    .accessibilityIdentifier("card-count")
                Spacer()
                Label("管理", systemImage: "square.3.layers.3d").font(.footnote)
            }

            if loadFailed {
                Text("无法读取名片")
                Button("重试", action: loadCards)
            } else if cards.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.title2)
                        .foregroundStyle(CardPalette.blue)
                        .frame(width: 100, height: 60)
                        .background(CardPalette.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("30秒快速认识CC").font(.headline)
                        Text("体验智能的名片识别、人脉管理")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            } else {
                ForEach(cards) { card in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(card.createdAt, format: .iso8601.year().month().day().dateSeparator(.dash))
                            .font(.footnote).foregroundStyle(.secondary)
                        NavigationLink {
                            CardDetailView(card: card)
                        } label: {
                            cardRow(card)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("card-\(card.id.uuidString)")
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 5))
    }

    private func cardRow(_ card: BusinessCard) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.fields.name ?? "未命名名片").font(.system(size: 9, weight: .bold))
                Text(card.fields.company ?? "").font(.system(size: 7))
                Spacer(minLength: 0)
                Image(systemName: "square.on.square").foregroundStyle(CardPalette.navy)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(8)
            .frame(width: 100, height: 60)
            .background(.white)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.fields.name ?? "未命名名片").font(.headline)
                Text(card.fields.jobTitle ?? "").font(.footnote).foregroundStyle(.secondary)
                Text(card.fields.company ?? "").font(.footnote).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 2)
            Image(systemName: "ellipsis").foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private var bottomBar: some View {
        HStack {
            tab("首页", icon: "house")
            tab("名片夹", icon: "person.text.rectangle.fill", selected: true)
            Button {
                showsScanner = true
            } label: {
                Image(systemName: "camera.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(CardPalette.blue, in: Circle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("扫描")
            .accessibilityIdentifier("open-scanner")
            tab("企业", icon: "building.2")
            tab("登录注册", icon: "person")
        }
        .padding(.vertical, 5)
        .background(Color(white: 0.98).ignoresSafeArea(edges: .bottom))
    }

    private func tab(_ title: String, icon: String, selected: Bool = false) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption2)
        }
        .foregroundStyle(selected ? CardPalette.blue : .secondary)
        .frame(maxWidth: .infinity)
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
