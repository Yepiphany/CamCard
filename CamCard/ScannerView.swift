import AVFoundation
import PhotosUI
import SwiftUI

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selection: PhotosPickerItem?
    @State private var showsCamera = false
    @State private var showsCrop = false
    @State private var result: ScanResult?
    @State private var work: Task<Void, Never>?
    @State private var message: String?
    @State private var cameraDenied = false

    var body: some View {
        Group {
            if let result {
                resultView(result)
            } else {
                scanner
            }
        }
        .overlay {
            if work != nil {
                ProgressView("正在识别…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            process {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw ScanProcessor.ScanError.unreadableImage
                }
                let image = try ScanProcessor.decode(data)
                return try ScanProcessor.recognize(original: image, source: image)
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraCapture { data in
                showsCamera = false
                guard let data else { return }
                process {
                    let image = try ScanProcessor.decode(data)
                    return try ScanProcessor.recognize(original: image, source: image)
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showsCrop) {
            if let result {
                CropEditor(source: result.source, boundary: result.boundary) { source, boundary in
                    showsCrop = false
                    process {
                        try ScanProcessor.recognize(original: result.original, source: source, boundary: boundary)
                    }
                }
            }
        }
        .alert("扫描名片", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            if cameraDenied {
                Button("前往设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            Button("好", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private var scanner: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    work?.cancel()
                    dismiss()
                } label: {
                    Image(systemName: "xmark").font(.title2)
                }
                .accessibilityLabel("关闭")
                .accessibilityIdentifier("close-scanner")
                Spacer()
                HStack {
                    Text("基础识别").padding(.horizontal, 14)
                    Text("AI高精度识别")
                        .padding(.horizontal, 14).padding(.vertical, 5)
                        .foregroundStyle(.indigo)
                        .background(.white, in: Capsule())
                }
                .font(.subheadline)
                .padding(3)
                .background(.black, in: Capsule())
                Spacer()
                Image(systemName: "ellipsis").font(.title2)
            }
            .padding(.horizontal, 20)

            GeometryReader { proxy in
                Rectangle()
                    .strokeBorder(.white, lineWidth: 1.5)
                    .aspectRatio(0.60, contentMode: .fit)
                    .frame(maxWidth: proxy.size.width - 64, maxHeight: proxy.size.height - 12)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .background(.black.opacity(0.35))

            HStack(spacing: 22) {
                Text("连续拍摄").font(.footnote).foregroundStyle(.secondary)
                Text("单张拍摄").font(.subheadline.bold())
            }
            HStack {
                PhotosPicker(selection: $selection, matching: .images) {
                    VStack(spacing: 6) {
                        Image(systemName: "photo").font(.title3)
                        Text("相册").font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("scan-photo-picker")
                Button(action: openCamera) {
                    Circle().fill(.white)
                        .frame(width: 55, height: 55)
                        .padding(8)
                        .background(.white.opacity(0.22), in: Circle())
                }
                .accessibilityLabel("拍摄")
                .accessibilityIdentifier("scan-shutter")
                Image(systemName: "rectangle.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 20)
            .disabled(work != nil)
        }
        .padding(.top, 9)
        .foregroundStyle(.white)
        .background(Color(white: 0.08).ignoresSafeArea())
        .environment(\.colorScheme, .dark)
    }

    private func resultView(_ result: ScanResult) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button("重新拍摄") { self.result = nil }
                    .disabled(work != nil)
                Spacer()
                Text("识别结果").font(.headline)
                    .accessibilityIdentifier("scan-result")
                Spacer()
                Button("关闭") {
                    work?.cancel()
                    dismiss()
                }
            }
            .padding(16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(decorative: result.corrected, scale: 1)
                            .resizable()
                            .overlay {
                                GeometryReader { proxy in
                                    ForEach(Array(result.recognition.regions.enumerated()), id: \.offset) { _, region in
                                        Rectangle().fill(.orange.opacity(0.20))
                                            .frame(width: region.width * proxy.size.width,
                                                   height: region.height * proxy.size.height)
                                            .position(x: (region.x + region.width / 2) * proxy.size.width,
                                                      y: (region.y + region.height / 2) * proxy.size.height)
                                    }
                                }
                                .accessibilityHidden(true)
                            }
                            .aspectRatio(CGFloat(result.corrected.width) / CGFloat(result.corrected.height), contentMode: .fit)

                        Button { showsCrop = true } label: {
                            Image(systemName: "crop")
                                .padding(10)
                                .background(.regularMaterial, in: Circle())
                        }
                        .accessibilityLabel("手动裁剪")
                        .accessibilityIdentifier("scan-crop")
                        .padding(8)
                        .disabled(work != nil)
                    }

                    if result.needsManualCrop {
                        Text("未检测到名片边界。可手动裁剪后重新识别。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text("识别语言").font(.subheadline.bold())
                    Text(result.recognition.languages.joined(separator: "、"))
                        .font(.footnote)
                    Text("OCR 原文").font(.subheadline.bold())
                    Text(result.recognition.rawText.isEmpty ? "未识别到文字" : result.recognition.rawText)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("scan-raw-text")
                }
                .padding(16)
            }
        }
        .background(CardPalette.background)
    }

    private func openCamera() {
        cameraDenied = false
#if targetEnvironment(simulator)
        message = "当前设备无法使用相机，请从相册导入。"
#else
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            message = "当前设备无法使用相机，请从相册导入。"
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showsCamera = true
        case .notDetermined:
            Task {
                if await AVCaptureDevice.requestAccess(for: .video) {
                    showsCamera = true
                } else {
                    showCameraDenied()
                }
            }
        default:
            showCameraDenied()
        }
#endif
    }

    private func showCameraDenied() {
        cameraDenied = true
        message = "相机权限不可用。你可以从相册导入，或在设置中开启相机权限。"
    }

    private func process(_ operation: @escaping @Sendable () async throws -> ScanResult) {
        guard work == nil else { return }
        work = Task {
            defer {
                work = nil
                selection = nil
            }
            do {
                let scanned = try await Task.detached(priority: .userInitiated, operation: operation).value
                try Task.checkCancellation()
                result = scanned
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                cameraDenied = false
                message = (error as? ScanProcessor.ScanError)?.errorDescription
                    ?? "无法识别这张图片，请重试。"
            }
        }
    }
}

private struct CameraCapture: UIViewControllerRepresentable {
    var completion: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (Data?) -> Void

        init(completion: @escaping (Data?) -> Void) { self.completion = completion }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            completion((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.95))
        }
    }
}

private struct CropEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var source: CGImage
    @State var boundary: CardBoundary
    var onConfirm: (CGImage, CardBoundary) -> Void

    var body: some View {
        VStack {
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("旋转") {
                    if let rotated = try? ScanProcessor.rotate(source) {
                        source = rotated
                        boundary = boundary.rotated
                    }
                }
                .accessibilityIdentifier("crop-rotate")
                Spacer()
                Button("完成") { onConfirm(source, boundary) }
                    .disabled(!boundary.isValid)
                    .accessibilityIdentifier("crop-done")
            }
            .padding(16)

            GeometryReader { proxy in
                let scale = min(proxy.size.width / CGFloat(source.width), proxy.size.height / CGFloat(source.height))
                let size = CGSize(width: CGFloat(source.width) * scale, height: CGFloat(source.height) * scale)
                ZStack {
                    Image(decorative: source, scale: 1).resizable()
                    Path { path in
                        path.addLines(boundary.corners.map { point($0, in: size) })
                        path.closeSubpath()
                    }
                    .stroke(boundary.isValid ? CardPalette.blue : .red, lineWidth: 2)
                    ForEach(boundary.corners.indices, id: \.self) { index in
                        Circle().fill(CardPalette.blue)
                            .frame(width: 16, height: 16)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .position(point(boundary.corners[index], in: size))
                            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("crop-image"))
                                .onChanged { value in
                                    guard size.width > 0, size.height > 0 else { return }
                                    boundary.corners[index] = CGPoint(
                                        x: min(1, max(0, value.location.x / size.width)),
                                        y: min(1, max(0, value.location.y / size.height))
                                    )
                                })
                    }
                }
                .frame(width: size.width, height: size.height)
                .coordinateSpace(name: "crop-image")
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
    }

    private func point(_ normalized: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
    }
}
