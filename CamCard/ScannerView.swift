import AVFoundation
import SwiftUI

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (ScanResult, ContactFields) throws -> Void

    @State private var showsAlbum = false
    @State private var accurate = false
    @State private var fields = ContactFields()
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
        .fullScreenCover(isPresented: $showsAlbum) {
            ScanAlbum { data in
                showsAlbum = false
                recognize(data)
            }
            .preferredColorScheme(.light)
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraCapture { data in
                showsCamera = false
                guard let data else { return }
                recognize(data)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showsCrop) {
            if let result {
                CropEditor(source: result.source, boundary: result.boundary) { source, boundary in
                    showsCrop = false
                    let accurate = accurate
                    process {
                        try ScanProcessor.recognize(original: result.original, source: source,
                                                    boundary: boundary, accurate: accurate)
                    }
                }
            }
        }
        .preferredColorScheme(result == nil ? .dark : .light)
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
                    recognitionMode("基础识别", accurate: false)
                    recognitionMode("AI高精度识别", accurate: true)
                }
                .font(.subheadline)
                .padding(3)
                .background(.black, in: Capsule())
                Spacer()
                Image(systemName: "ellipsis").font(.title2)
            }
            .padding(.horizontal, 20)

            GeometryReader { proxy in
                let width = min(proxy.size.width * 0.76, proxy.size.height * 0.60)
                Rectangle()
                    .strokeBorder(.white, lineWidth: 1.5)
                    .overlay(alignment: .top) {
                        Text("请将镜头靠近名片")
                            .font(.subheadline)
                            .padding(5)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            .padding(.top, 7)
                    }
                    .overlay(alignment: .bottom) {
                        Button(action: toggleTorch) {
                            Label("轻触照亮", systemImage: "flashlight.on.fill")
                                .font(.footnote).padding(8)
                                .background(.black.opacity(0.65), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 20)
                    }
                    .frame(width: max(0, width), height: max(0, width / 0.60))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .background(.black.opacity(0.35))

            HStack(spacing: 16) {
                Text("连续拍摄").font(.caption2).foregroundStyle(.secondary)
                Text("多张拍摄").font(.footnote).foregroundStyle(.secondary)
                VStack(spacing: 4) {
                    Capsule().fill(CardPalette.blue).frame(width: 23, height: 3)
                    Text("单张拍摄").font(.subheadline.bold())
                }
                Text("二维码").font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                Button { showsAlbum = true } label: {
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
                Button("重新拍摄") {
                    self.result = nil
                    fields = ContactFields()
                }
                    .disabled(work != nil)
                Spacer()
                Text("编辑名片").font(.headline)
                    .accessibilityIdentifier("scan-result")
                Spacer()
                Button("保存", action: save)
                    .disabled(work != nil)
                    .accessibilityIdentifier("scan-save")
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
                    HStack {
                        Text("识别语言")
                        Spacer()
                        Text(result.recognition.languages.map(languageName).joined(separator: "、"))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.white)

                    VStack(spacing: 1) {
                        editRow("姓名", value: optionalField(\.name))
                        editRow("手机", value: multipleField(\.mobile))
                        editRow("办公电话", value: multipleField(\.officePhone))
                        editRow("工作邮箱", value: multipleField(\.email))
                        editRow("公司", value: optionalField(\.company))
                        editRow("职位", value: optionalField(\.jobTitle))
                        editRow("主页", value: optionalField(\.website))
                        editRow("公司地址", value: optionalField(\.address))
                        editRow("传真", value: multipleField(\.fax))
                    }

                    DisclosureGroup("OCR 原文") {
                        Text(result.recognition.rawText.isEmpty ? "未识别到文字" : result.recognition.rawText)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("scan-raw-text")
                    }
                    .padding(12)
                    .background(.white)

                    Button("取消") { dismiss() }
                        .frame(maxWidth: .infinity)
                }
                .padding(16)
            }
        }
        .background(CardPalette.background)
    }

    private func recognitionMode(_ title: String, accurate: Bool) -> some View {
        Button { self.accurate = accurate } label: {
            Text(title)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .foregroundStyle(self.accurate == accurate ? .black : .white)
                .background(self.accurate == accurate ? .white : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(work != nil)
        .accessibilityAddTraits(self.accurate == accurate ? .isSelected : [])
    }

    private func toggleTorch() {
        cameraDenied = false
        message = "请在打开的相机界面调整闪光灯。"
    }

    private func languageName(_ code: String) -> String {
        Locale(identifier: "zh-Hans").localizedString(forIdentifier: code) ?? code
    }

    private func editRow(_ label: String, value: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Text(label).foregroundStyle(.secondary).frame(width: 75, alignment: .leading)
            TextField(label, text: value, axis: .vertical)
                .accessibilityIdentifier("field-\(label)")
        }
        .padding(12)
        .background(.white)
        .disabled(work != nil)
    }

    private func optionalField(_ keyPath: WritableKeyPath<ContactFields, String?>) -> Binding<String> {
        Binding(get: { fields[keyPath: keyPath] ?? "" }, set: { fields[keyPath: keyPath] = $0.isEmpty ? nil : $0 })
    }

    private func multipleField(_ keyPath: WritableKeyPath<ContactFields, [String]>) -> Binding<String> {
        Binding(get: { fields[keyPath: keyPath].joined(separator: "、") }, set: {
            fields[keyPath: keyPath] = $0.split(whereSeparator: { $0 == "、" || $0.isNewline })
                .map(String.init)
        })
    }

    private func save() {
        guard let result, work == nil else { return }
        do {
            try onSave(result, fields)
            dismiss()
        } catch {
            cameraDenied = false
            message = "保存失败，请重试。"
        }
    }

    private func recognize(_ data: Data) {
        let accurate = accurate
        process {
            let image = try ScanProcessor.decode(data)
            return try ScanProcessor.recognize(original: image, source: image, accurate: accurate)
        }
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
            }
            do {
                let scanned = try await Task.detached(priority: .userInitiated, operation: operation).value
                try Task.checkCancellation()
                if result == nil || fields == result?.recognition.candidates {
                    fields = scanned.recognition.candidates
                }
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
                    .accessibilityIdentifier("crop-cancel")
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
                    .foregroundStyle(CardPalette.blue)
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
                    ForEach(boundary.corners.indices, id: \.self) { index in
                        let next = (index + 1) % 4
                        let a = boundary.corners[index]
                        let b = boundary.corners[next]
                        let middle = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                        Circle().fill(.white)
                            .overlay(Circle().strokeBorder(CardPalette.blue))
                            .frame(width: 16, height: 16)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                            .position(point(middle, in: size))
                            .accessibilityLabel("边缘控制点 \(index + 1)")
                            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("crop-image"))
                                .onChanged { value in
                                    guard size.width > 0, size.height > 0 else { return }
                                    let dx = min(1 - max(a.x, b.x), max(-min(a.x, b.x), value.location.x / size.width - middle.x))
                                    let dy = min(1 - max(a.y, b.y), max(-min(a.y, b.y), value.location.y / size.height - middle.y))
                                    boundary.corners[index] = CGPoint(x: a.x + dx, y: a.y + dy)
                                    boundary.corners[next] = CGPoint(x: b.x + dx, y: b.y + dy)
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
