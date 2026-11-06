import Photos
import PhotosUI
import SwiftUI

struct ScanAlbum: View {
    @Environment(\.dismiss) private var dismiss
    @State private var status = PHAuthorizationStatus.notDetermined
    @State private var assets: [PHAsset] = []
    @State private var selected: PHAsset?
    @State private var loading = false
    @State private var failed = false
    @State private var observer: AlbumObserver?
    @State private var requestID: PHImageRequestID?
    let onConfirm: (Data) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text("最近项目").font(.headline)
                Spacer()
                Button("取消") { dismiss() }.accessibilityIdentifier("album-cancel")
            }
            .padding(16)
            .foregroundStyle(.white)
            .background(Color.black.ignoresSafeArea(edges: .top))

            if status == .limited {
                VStack(spacing: 8) {
                    Text("当前仅显示你允许访问的图片。").font(.footnote)
                    Button("选择更多图片", action: chooseMore)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(CardPalette.background)
            }

            if status == .denied || status == .restricted {
                ContentUnavailableView {
                    Label("无法访问照片", systemImage: "photo")
                } description: {
                    Text("请在设置中允许访问相册。")
                } actions: {
                    Button("前往设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } else if assets.isEmpty {
                if status == .notDetermined {
                    ProgressView().frame(maxHeight: .infinity)
                } else {
                    ContentUnavailableView("暂无照片", systemImage: "photo")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            Button {
                                selected = selected == asset ? nil : asset
                            } label: {
                                AlbumThumbnail(asset: asset, selected: selected == asset)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("照片")
                            .accessibilityAddTraits(selected == asset ? .isSelected : [])
                            .accessibilityIdentifier("album-photo")
                        }
                    }
                    .padding(4)
                }
            }

            HStack {
                Spacer()
                if loading { ProgressView().tint(.white) }
                Button(selected == nil ? "完成" : "1 完成", action: loadSelected)
                    .foregroundStyle(selected == nil ? .gray : .white)
                    .disabled(selected == nil || loading)
                    .accessibilityIdentifier("album-done")
            }
            .padding(16)
            .background(Color.black.ignoresSafeArea(edges: .bottom))
        }
        .background(.white)
        .task {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard !Task.isCancelled else { return }
            reload()
            let observer = AlbumObserver { reload() }
            self.observer = observer
            PHPhotoLibrary.shared().register(observer)
        }
        .onDisappear {
            if let observer { PHPhotoLibrary.shared().unregisterChangeObserver(observer) }
            observer = nil
            if let requestID { PHImageManager.default().cancelImageRequest(requestID) }
            requestID = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            reload()
        }
        .alert("无法读取图片", isPresented: $failed) {
            Button("好", role: .cancel) {}
        }
    }

    private func reload() {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let photos = PHAsset.fetchAssets(with: .image, options: options)
        assets = photos.objects(at: IndexSet(integersIn: 0..<photos.count))
        if let selected, !assets.contains(selected) { self.selected = nil }
    }

    private func chooseMore() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              var controller = scene.keyWindow?.rootViewController else { return }
        while let presented = controller.presentedViewController { controller = presented }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
    }

    private func loadSelected() {
        guard let selected else { return }
        loading = true
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        requestID = PHImageManager.default().requestImageDataAndOrientation(for: selected, options: options) { data, _, _, info in
            Task { @MainActor in
                guard requestID != nil else { return }
                requestID = nil
                loading = false
                guard info?[PHImageCancelledKey] as? Bool != true else { return }
                if let data { onConfirm(data) } else { failed = true }
            }
        }
    }
}

private final class AlbumObserver: NSObject, PHPhotoLibraryChangeObserver {
    let onChange: @MainActor () -> Void
    init(onChange: @escaping @MainActor () -> Void) { self.onChange = onChange }
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in onChange() }
    }
}

private struct AlbumThumbnail: View {
    let asset: PHAsset
    let selected: Bool
    @State private var thumbnail: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Color(white: 0.94)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    GeometryReader { proxy in
                        Image(uiImage: thumbnail).resizable().scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: selected ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(selected ? CardPalette.blue : .white)
                    .padding(5)
            }
            .accessibilityHidden(true)
            .onAppear {
                guard thumbnail == nil else { return }
                requestID = PHImageManager.default().requestImage(
                    for: asset, targetSize: CGSize(width: 360, height: 360),
                    contentMode: .aspectFill, options: nil
                ) { image, _ in
                    Task { @MainActor in if let image { thumbnail = image } }
                }
            }
            .onDisappear {
                if let requestID { PHImageManager.default().cancelImageRequest(requestID) }
            }
    }
}
