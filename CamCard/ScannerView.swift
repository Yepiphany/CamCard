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
    @State private var showsName = false
    @State private var showsLanguages = false
    @State private var isSaving = false
    @State private var previewPage = 0
    @State private var languages = Self.languageOptions

    private static let languageOptions = ["en-US", "zh-Hans", "zh-Hant"]

    private let accent = Color(red: 0.11, green: 0.64, blue: 0.93)
    private let editorBackground = Color(white: 0.94)
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
                    recognizeAgain(result, source: source, boundary: boundary)
                }
            }
        }
        .fullScreenCover(isPresented: $showsName) {
            if let result {
                nameEditor(result)
            }
        }
        .sheet(isPresented: $showsLanguages) {
            if let result {
                languageEditor(result)
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
            ZStack {
                Text("编辑名片")
                    .accessibilityIdentifier("scan-result")
                HStack {
                    Button("重新拍摄") {
                        self.result = nil
                        fields = ContactFields()
                        previewPage = 0
                    }
                    .tint(.primary)
                    Spacer()
                    Button("保存", action: save)
                        .disabled(isSaving)
                        .accessibilityIdentifier("scan-save")
                }
            }
            .font(.system(size: 17))
            .padding(.horizontal, 16)
            .frame(height: 52)
            .disabled(work != nil)

            ScrollView {
                VStack(spacing: 10) {
                    preview(result)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    if result.needsManualCrop {
                        Text("未检测到名片边界。可手动裁剪后重新识别。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Toggle(isOn: $accurate) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("AI高精度识别")
                            Text("使用设备端高精度识别")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.white)
                    .onChange(of: accurate) {
                        recognizeAgain(result, source: result.source, boundary: existingBoundary(result))
                    }

                    HStack(spacing: 12) {
                        fieldLabel("识别语言")
                        Text(Self.languageOptions.filter(result.recognition.languages.contains).map(languageName).joined(separator: ", "))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("更改") { showsLanguages = true }
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 50)
                    .background(.white)

                    Button { showsName = true } label: {
                        HStack(spacing: 12) {
                            fieldLabel("姓名")
                            Text(fields.name ?? "")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 50)
                        .background(.white)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("scan-name")

                    multipleFields("手机", keyPath: \.mobile)
                    if !fields.officePhone.isEmpty {
                        multipleFields("办公电话", keyPath: \.officePhone)
                    }
                    multipleFields("工作邮箱", keyPath: \.email)
                    VStack(spacing: 0) {
                        editRow("公司", value: optionalField(\.company))
                        Divider().padding(.horizontal, 16)
                        editRow("职位", value: optionalField(\.jobTitle))
                    }
                    editRow("首页", value: optionalField(\.website), blueLabel: true)
                    editRow("公司地址", value: optionalField(\.address), blueLabel: true)
                    if !fields.fax.isEmpty {
                        multipleFields("传真", keyPath: \.fax)
                    }

                    Menu {
                        Button("手机") { fields.mobile.append("") }
                        Button("办公电话") { fields.officePhone.append("") }
                        Button("工作邮箱") { fields.email.append("") }
                        Button("传真") { fields.fax.append("") }
                    } label: {
                        Text("添加字段")
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(.white)
                    }
                    .accessibilityIdentifier("scan-add-field")

                    DisclosureGroup("OCR 原文") {
                        Text(result.recognition.rawText.isEmpty ? "未识别到文字" : result.recognition.rawText)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("scan-raw-text")
                    }
                    .padding(12)
                    .background(.white)

                    Button("取消") { dismiss() }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(work != nil)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .tint(accent)
        .background(editorBackground.ignoresSafeArea())
    }

    private func preview(_ result: ScanResult) -> some View {
        let ratio = CGFloat(result.corrected.width) / CGFloat(result.corrected.height)
        return ZStack(alignment: .bottomTrailing) {
            TabView(selection: $previewPage) {
                GeometryReader { proxy in
                    let width = min(proxy.size.width, proxy.size.height * ratio)
                    highlightedCard(result)
                        .frame(width: width, height: width / ratio)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .tag(0)
                Image(decorative: result.original, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .aspectRatio(max(ratio, 1.05), contentMode: .fit)
            .overlay(alignment: .bottom) {
                HStack(spacing: 10) {
                    ForEach(0..<2) { page in
                        Button {
                            previewPage = page
                        } label: {
                            Circle()
                                .fill(page == previewPage ? accent : .gray.opacity(0.6))
                                .frame(width: 8, height: 8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(page == 0 ? "校正图" : "原图")
                    }
                }
                .padding(.bottom, 14)
            }
            Button { showsCrop = true } label: {
                Image(systemName: "crop")
                    .font(.system(size: 15))
                    .frame(width: 32, height: 32)
                    .background(.white, in: Circle())
            }
            .accessibilityLabel("手动裁剪")
            .accessibilityIdentifier("scan-crop")
            .padding(10)
        }
        .background(.white)
        .clipShape(.rect(cornerRadius: 8))
    }

    private func highlightedCard(_ result: ScanResult) -> some View {
        Image(decorative: result.corrected, scale: 1)
            .resizable()
            .overlay {
                GeometryReader { proxy in
                    ForEach(Array(result.recognition.regions.enumerated()), id: \.offset) { _, region in
                        Rectangle().fill(.orange.opacity(0.20))
                            .frame(width: region.width * proxy.size.width, height: region.height * proxy.size.height)
                            .position(x: (region.x + region.width / 2) * proxy.size.width,
                                      y: (region.y + region.height / 2) * proxy.size.height)
                    }
                }
                .accessibilityHidden(true)
            }
    }

    private func nameEditor(_ result: ScanResult) -> some View {
        ScanNameEditor(
            name: fields.name,
            background: editorBackground,
            preview: highlightedCard(result)
        ) { fields.name = $0 }
    }

    private func languageEditor(_ result: ScanResult) -> some View {
        NavigationStack {
            List {
                ForEach(Self.languageOptions, id: \.self) { code in
                    Toggle(languageName(code), isOn: Binding(
                        get: { languages.contains(code) },
                        set: { selected in
                            if selected { languages.append(code) }
                            else if languages.count > 1 { languages.removeAll { $0 == code } }
                        }
                    ))
                }
            }
            .interactiveDismissDisabled()
            .navigationTitle("识别语言")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        showsLanguages = false
                        if Set(result.recognition.languages) != Set(languages) {
                            recognizeAgain(result, source: result.source, boundary: existingBoundary(result))
                        }
                    }
                }
            }
        }
    }

    private func existingBoundary(_ result: ScanResult) -> CardBoundary? {
        result.needsManualCrop ? nil : result.boundary
    }

    private func recognizeAgain(_ result: ScanResult, source: CGImage, boundary: CardBoundary?) {
        let accurate = accurate
        let languages = languages
        process {
            try ScanProcessor.recognize(original: result.original, source: source,
                                        boundary: boundary, accurate: accurate, languages: languages)
        }
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
        if code == "en-US" { return "英语" }
        return Locale(identifier: "zh-Hans").localizedString(forIdentifier: code) ?? code
    }

    private func fieldLabel(_ label: String, blue: Bool = false) -> some View {
        Text(label)
            .font(.subheadline)
            .foregroundStyle(blue ? accent : Color.secondary)
            .frame(width: 80, alignment: .leading)
    }

    private func editRow(_ label: String, value: Binding<String>, blueLabel: Bool = false,
                         identifier: String? = nil) -> some View {
        HStack(spacing: 12) {
            fieldLabel(label, blue: blueLabel)
            TextField(label, text: value, prompt: Text(""), axis: .vertical)
                .autocorrectionDisabled()
                .accessibilityIdentifier(identifier ?? "field-\(label)")
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .background(.white)
    }

    private func optionalField(_ keyPath: WritableKeyPath<ContactFields, String?>) -> Binding<String> {
        Binding(get: { fields[keyPath: keyPath] ?? "" }, set: { fields[keyPath: keyPath] = $0.isEmpty ? nil : $0 })
    }

    private func multipleFields(_ label: String, keyPath: WritableKeyPath<ContactFields, [String]>) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<max(fields[keyPath: keyPath].count, 1), id: \.self) { index in
                editRow(label, value: Binding(
                    get: {
                        let values = fields[keyPath: keyPath]
                        return values.indices.contains(index) ? values[index] : ""
                    },
                    set: { value in
                        if fields[keyPath: keyPath].indices.contains(index) {
                            fields[keyPath: keyPath][index] = value
                        } else {
                            fields[keyPath: keyPath].append(value)
                        }
                    }
                ), blueLabel: true, identifier: "field-\(label)-\(index)")
            }
        }
    }

    private func save() {
        guard let result, work == nil, !isSaving else { return }
        isSaving = true
        do {
            try onSave(result, fields.cleaned)
            dismiss()
        } catch {
            isSaving = false
            cameraDenied = false
            message = "保存失败，请重试。"
        }
    }

    private func recognize(_ data: Data) {
        let accurate = accurate
        let languages = languages
        process {
            let image = try ScanProcessor.decode(data)
            return try ScanProcessor.recognize(original: image, source: image, accurate: accurate, languages: languages)
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
                if let previous = result?.recognition.candidates {
                    fields.refreshUnedited(from: previous, with: scanned.recognition.candidates)
                } else {
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

private struct ScanNameEditor<Preview: View>: View {
    @Environment(\.dismiss) private var dismiss
    @State private var surname: String
    @State private var givenName: String
    let background: Color
    let preview: Preview
    let onBack: (String?) -> Void

    init(name: String?, background: Color, preview: Preview, onBack: @escaping (String?) -> Void) {
        let name = name ?? ""
        if name.range(of: #"^\p{Han}{2,4}$"#, options: .regularExpression) != nil {
            _surname = State(initialValue: String(name.prefix(1)))
            _givenName = State(initialValue: String(name.dropFirst()))
        } else {
            let parts = name.split(separator: " ")
            _surname = State(initialValue: parts.count > 1 ? String(parts.last ?? "") : "")
            _givenName = State(initialValue: parts.count > 1 ? parts.dropLast().joined(separator: " ") : name)
        }
        self.background = background
        self.preview = preview
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    let parts = [surname, givenName].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    let isChinese = parts.joined().range(of: #"^\p{Han}+$"#, options: .regularExpression) != nil
                    let name = isChinese ? parts.joined() : parts.reversed().filter { !$0.isEmpty }.joined(separator: " ")
                    onBack(name.isEmpty ? nil : name)
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
                .accessibilityIdentifier("scan-name-back")
                Spacer()
            }
            .background(.white)
            preview.scaledToFill()
                .frame(height: 100, alignment: .top)
                .clipped()
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                nameRow("姓", value: $surname, id: "field-surname")
                Divider().padding(.horizontal, 16)
                nameRow("名字", value: $givenName, id: "field-given-name")
            }
            .background(.white)
            Spacer()
        }
        .background(background.ignoresSafeArea())
    }

    private func nameRow(_ title: String, value: Binding<String>, id: String) -> some View {
        HStack(spacing: 12) {
            Text(title).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
            TextField(title, text: value, prompt: Text(""))
                .autocorrectionDisabled()
                .accessibilityIdentifier(id)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
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
