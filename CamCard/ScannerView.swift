import AVFoundation
import SwiftUI

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss

    var opensAlbum = false
    let onSave: (ScanResult, ContactFields) throws -> Void

    @State private var showsAlbum = false
    @State private var accurate = false
    @State private var fields = ContactFields()
    @State private var editedNameParts: Set<WritableKeyPath<CardName, String>> = []
    @State private var camera = ScannerCamera()
    @State private var cameraReady = false
    @State private var torch = false
    @State private var mode: CaptureMode = .single
    @State private var batch: [Data] = []
    @State private var pending: [(image: CGImage, boundary: CardBoundary?)] = []
    @State private var showsMultiGuide = false
    @AppStorage("hasSeenMultiGuide") private var hasSeenMultiGuide = false
    @State private var qr: String?
    @State private var showsScannerOptions = false
    @State private var openedAlbum = false
#if DEBUG && targetEnvironment(simulator)
    @State private var corruptNextImport = ProcessInfo.processInfo.arguments.contains("--test-invalid-image")
#endif

    private enum CaptureMode: String, CaseIterable {
        case continuous = "连续拍摄", multiple = "多张拍摄", single = "单张拍摄", qr = "二维码"
    }

    private var shouldRunCamera: Bool { result == nil && !showsAlbum }
    private static let batchLimit = 5
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
            ScanAlbum(limit: mode == .continuous ? max(1, Self.batchLimit - batch.count) : 1) { images in
                showsAlbum = false
#if DEBUG && targetEnvironment(simulator)
                if corruptNextImport {
                    corruptNextImport = false
                    importImages([Data("invalid image".utf8)])
                    return
                }
#endif
                importImages(images)
            }
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
        .onAppear {
            if opensAlbum, !openedAlbum {
                openedAlbum = true
                showsAlbum = true
            }
        }
        .task(id: shouldRunCamera) {
            if shouldRunCamera { await startPreview() }
            else { stopPreview() }
        }
        .onDisappear { stopPreview() }
        .alert("新增多张拍摄功能", isPresented: $showsMultiGuide) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text("可一次拍摄多张名片，系统会自动寻找每张名片的边框。")
        }
        .alert("二维码", isPresented: Binding(get: { qr != nil }, set: { if !$0 { qr = nil } })) {
            Button("复制") { UIPasteboard.general.string = qr; qr = nil }
            Button("关闭", role: .cancel) { qr = nil }
        } message: {
            Text(qr ?? "")
        }
        .confirmationDialog("扫描设置", isPresented: $showsScannerOptions, titleVisibility: .visible) {
            Button("基础识别") { accurate = false }
            Button("AI高精度识别") { accurate = true }
        }
        .preferredColorScheme(result == nil ? .dark : .light)
        .statusBarHidden(result == nil && !showsAlbum)
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
            ZStack {
                HStack(spacing: 0) {
                    recognitionMode("基础识别", accurate: false)
                    recognitionMode("AI高精度识别", accurate: true)
                }
                .font(.subheadline)
                .padding(3)
                .background(.black, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.28)))
                HStack {
                    Button {
                        work?.cancel()
                        dismiss()
                    } label: { Image(systemName: "xmark").font(.title2) }
                    .accessibilityLabel("关闭")
                    .accessibilityIdentifier("close-scanner")
                    Spacer()
                    Button { showsScannerOptions = true } label: {
                        Image(systemName: "ellipsis").font(.title2)
                    }
                    .accessibilityLabel("扫描设置")
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 42)

            viewfinder
            modePicker
            HStack {
                Button { showsAlbum = true } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "photo").font(.title3)
                        Text("相册").font(.caption)
                    }
                    .foregroundStyle(mode == .qr ? .gray : .white)
                    .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("scan-photo-picker")
                Button(action: openCamera) {
                    Circle().fill(mode == .qr ? .gray : .white)
                        .frame(width: 55, height: 55)
                        .padding(8)
                        .background(.white.opacity(0.22), in: Circle())
                }
                .disabled(mode == .qr)
                .accessibilityLabel("拍摄")
                .accessibilityIdentifier("scan-shutter")
                Group {
                    if mode == .continuous || mode == .single {
                        Button {
                            if batch.isEmpty { selectMode(.continuous); showsAlbum = true }
                            else { finishBatch() }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: batch.isEmpty ? "rectangle.on.rectangle" : "checkmark.circle.fill")
                                    .font(.title3)
                                Text(batch.isEmpty ? "\(Self.batchLimit)" : "\(batch.count) 完成").font(.caption)
                            }
                        }
                        .accessibilityIdentifier("scan-batch")
                    } else {
                        Color.clear.frame(height: 1).accessibilityHidden(true)
                    }
                }.frame(maxWidth: .infinity)
            }
            .padding(.top, 12)
            .padding(.bottom, 49)
            .disabled(work != nil)
        }
        .foregroundStyle(.white)
        .background {
            ZStack {
                Color(white: 0.06)
                if cameraReady { ScannerPreview(session: camera.session) }
            }.ignoresSafeArea()
        }
        .environment(\.colorScheme, .dark)
    }

    private var viewfinder: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width * 0.76, proxy.size.height * 0.60)
            let qrWidth = min(proxy.size.width * 0.65, max(0, proxy.size.height - 130))
            let torchY = mode == .single || mode == .continuous
                ? (proxy.size.height + width / 0.60) / 2 - 30
                : proxy.size.height - 32
            ZStack {
                if mode == .qr {
                    VStack(spacing: 16) {
                        QRGuide().frame(width: qrWidth, height: qrWidth)
                        Text("扫描 CC 名片二维码，面对面交换名片").font(.footnote)
                    }.padding(.bottom, 48)
                } else if mode == .multiple {
                    Text("正在寻找名片边框").font(.subheadline)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 18)
                } else {
                    Rectangle()
                        .strokeBorder(.white, lineWidth: 1.5)
                        .overlay(alignment: .top) {
                            Text("请将镜头靠近名片")
                                .font(.subheadline)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                                .padding(.top, 6)
                        }
                        .frame(width: width, height: width / 0.60)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                Button(action: toggleTorch) {
                    Label(torch ? "轻触关闭" : "轻触照亮",
                          systemImage: torch ? "flashlight.off.fill" : "flashlight.on.fill")
                        .font(.footnote).padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.black.opacity(0.65), in: Capsule())
                }
                .buttonStyle(.plain)
                .position(x: proxy.size.width / 2, y: max(18, torchY))
            }
        }
    }

    private var modePicker: some View {
        GeometryReader { proxy in
            let step: CGFloat = min(76, proxy.size.width * 0.177)
            let modes = CaptureMode.allCases
            let active = modes.firstIndex(of: mode) ?? 2
            ZStack {
                ForEach(Array(modes.enumerated()), id: \.element) { index, item in
                    Button { selectMode(item) } label: {
                        VStack(spacing: 6) {
                            Capsule().fill(item == mode ? CardPalette.blue : .clear).frame(width: 23, height: 2)
                            Text(item.rawValue)
                                .font(item == mode ? .subheadline.weight(.semibold) : abs(index - active) > 1 ? .caption2 : .footnote)
                                .foregroundStyle(item == mode ? .white : .gray)
                        }
                        .frame(width: step, height: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("scan-mode-\(item.rawValue)")
                    .accessibilityAddTraits(item == mode ? .isSelected : [])
                    .position(x: proxy.size.width / 2 + CGFloat(index - active) * step, y: 18)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 24).onEnded { gesture in
                let next = active + (gesture.translation.width < 0 ? 1 : -1)
                if modes.indices.contains(next) { selectMode(modes[next]) }
            })
            .clipped()
        }
        .frame(height: 36)
        .disabled(work != nil)
    }

    private func selectMode(_ item: CaptureMode) {
        guard mode != item else { return }
        if mode == .continuous, !batch.isEmpty {
            message = "请先完成当前连续拍摄。"
            return
        }
        withAnimation(.easeInOut(duration: 0.20)) { mode = item }
        camera.enableQR(item == .qr)
        if item == .multiple && !hasSeenMultiGuide {
            hasSeenMultiGuide = true
            showsMultiGuide = true
        }
    }

    private func resultView(_ result: ScanResult) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Text("编辑名片")
                    .accessibilityIdentifier("scan-result")
                HStack {
                    Button("重新拍摄") {
                        pending.removeAll()
                        clearDraft()
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

                    if result.recognition.rawText.isEmpty {
                        Text("未识别到文字。可调整裁剪或手动填写。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

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
        RecognizedCardImage(image: result.corrected, regions: result.recognition.regions)
    }

    private func nameEditor(_ result: ScanResult) -> some View {
        let original = fields.nameDetails ?? CardName(name: fields.name)
        return CardNameEditor(
            details: original,
            preview: NameImagePreview(image: result.corrected, recognition: result.recognition)
        ) { details in
            let changed = CardName.parts.filter { original[keyPath: $0] != details[keyPath: $0] }
            guard !changed.isEmpty else { return }
            editedNameParts.formUnion(changed)
            fields.name = details.displayName
            fields.nameDetails = details
        }
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
                .fontWeight(self.accurate == accurate ? .semibold : .regular)
                .frame(width: 117, height: 26)
                .foregroundStyle(self.accurate == accurate ? .black : .white)
                .background(self.accurate == accurate ? .white : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(work != nil)
        .accessibilityAddTraits(self.accurate == accurate ? .isSelected : [])
    }

    private func toggleTorch() {
        cameraDenied = false
        let enabled = !torch
        camera.setTorch(enabled) { applied in
            if applied { torch = enabled }
            else { message = "当前设备无法照亮。" }
        }
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
            if pending.isEmpty {
                dismiss()
            } else {
                let next = pending.removeFirst()
                clearDraft()
                recognize(next.image, boundary: next.boundary)
            }
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

    private func clearDraft() {
        result = nil
        fields = ContactFields()
        editedNameParts = []
        previewPage = 0
        isSaving = false
    }

    private func recognize(_ image: CGImage, boundary: CardBoundary?) {
        let accurate = accurate
        let languages = languages
        process {
            try ScanProcessor.recognize(original: image, source: image, boundary: boundary,
                                        accurate: accurate, languages: languages)
        }
    }

    private func importImages(_ images: [Data]) {
        guard let first = images.first else { return }
        switch mode {
        case .single: recognize(first)
        case .qr: readQR(first)
        case .continuous:
            let captures = batch + images
            batch.removeAll()
            prepareBatch(captures, detectMultiple: false)
        case .multiple: prepareBatch([first], detectMultiple: true)
        }
    }

    private func prepareBatch(_ images: [Data], detectMultiple: Bool) {
        guard work == nil else { return }
        work = Task {
            defer { work = nil }
            do {
                let accurate = accurate
                let languages = languages
                let (firstResult, rest) = try await Task.detached(priority: .userInitiated) {
                    let jobs = try images.flatMap { data -> [(CGImage, CardBoundary?)] in
                        let image = try ScanProcessor.decode(data)
                        guard detectMultiple else { return [(image, nil)] }
                        let boundaries = try ScanProcessor.boundaries(in: image)
                        return boundaries.isEmpty ? [(image, nil)] : boundaries.map { (image, $0) }
                    }
                    guard let first = jobs.first else { throw ScanProcessor.ScanError.unreadableImage }
                    let result = try ScanProcessor.recognize(original: first.0, source: first.0, boundary: first.1,
                                                             accurate: accurate, languages: languages)
                    return (result, Array(jobs.dropFirst()))
                }.value
                try Task.checkCancellation()
                pending = rest
                fields = firstResult.recognition.candidates
                result = firstResult
            } catch {
                guard !Task.isCancelled else { return }
                message = (error as? ScanProcessor.ScanError)?.errorDescription ?? "无法识别这张图片，请重试。"
            }
        }
    }

    private func finishBatch() {
        let captures = batch
        batch.removeAll()
        prepareBatch(captures, detectMultiple: false)
    }

    private func readQR(_ data: Data) {
        guard work == nil else { return }
        work = Task {
            defer { work = nil }
            do {
                let payload = try await Task.detached(priority: .userInitiated) {
                    try ScanProcessor.qrPayload(in: data)
                }.value
                try Task.checkCancellation()
                if let payload { qr = payload }
                else { message = "未找到二维码，请重新选择。" }
            } catch {
                guard !Task.isCancelled else { return }
                message = (error as? ScanProcessor.ScanError)?.errorDescription ?? "无法读取二维码。"
            }
        }
    }

    private func startPreview() async {
#if !targetEnvironment(simulator)
        let authorized: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authorized = true
        case .notDetermined: authorized = await AVCaptureDevice.requestAccess(for: .video)
        default: authorized = false
        }
        guard authorized, !Task.isCancelled, shouldRunCamera else { return }
        let started = await camera.start { payload in
            if mode == .qr && shouldRunCamera && qr == nil { qr = payload }
        }
        guard !Task.isCancelled, shouldRunCamera else { return }
        cameraReady = started
        camera.enableQR(mode == .qr)
#endif
    }

    private func stopPreview() {
        camera.stop()
        cameraReady = false
        torch = false
    }

    private func openCamera() {
        cameraDenied = false
#if targetEnvironment(simulator)
        message = "当前设备无法使用相机，请从相册导入。"
#else
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            showCameraDenied()
            return
        }
        guard cameraReady else {
            message = "当前设备无法使用相机，请从相册导入。"
            return
        }
        guard work == nil else { return }
        let captureMode = mode
        camera.capture { data in
            guard shouldRunCamera else { return }
            guard let data else { message = "拍摄失败，请重试。"; return }
            if captureMode == .continuous {
                batch.append(data)
                if batch.count == Self.batchLimit { finishBatch() }
            } else {
                importImages([data])
            }
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
                    fields.refreshUnedited(from: previous, with: scanned.recognition.candidates,
                                           preservingNameParts: editedNameParts)
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

private struct QRGuide: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            GeometryReader { proxy in
                let size = proxy.size.width
                let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.5) / 2.5
                Path { path in
                    let inset: CGFloat = 1
                    let length: CGFloat = 20
                    for (x, y, dx, dy) in [(inset, inset, length, length), (size - inset, inset, -length, length),
                                           (inset, size - inset, length, -length), (size - inset, size - inset, -length, -length)] {
                        path.move(to: CGPoint(x: x, y: y + dy))
                        path.addLine(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + dx, y: y))
                    }
                }.stroke(CardPalette.blue, lineWidth: 2)
                Rectangle().fill(CardPalette.blue.opacity(0.8)).frame(height: 2)
                    .position(x: size / 2, y: 8 + (size - 16) * phase)
            }
        }.background(.black.opacity(0.30)).accessibilityHidden(true)
    }
}

private struct ScannerPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.preview.session = session
        view.preview.videoGravity = .resizeAspectFill
        if let connection = view.preview.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

private final class ScannerCamera: NSObject, AVCapturePhotoCaptureDelegate, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "CamCard.ScannerCamera")
    private let photo = AVCapturePhotoOutput()
    private let metadata = AVCaptureMetadataOutput()
    private var device: AVCaptureDevice?
    private var photoHandler: ((Data?) -> Void)?
    private var qrHandler: ((String) -> Void)?
    private var lastQR: String?

    func start(onQR: @escaping (String) -> Void) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                if self.device == nil {
                    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                          let input = try? AVCaptureDeviceInput(device: device),
                          self.session.canAddInput(input), self.session.canAddOutput(self.photo) else {
                        continuation.resume(returning: false)
                        return
                    }
                    self.session.beginConfiguration()
                    self.session.sessionPreset = .photo
                    self.session.addInput(input)
                    self.session.addOutput(self.photo)
                    if self.session.canAddOutput(self.metadata) {
                        self.session.addOutput(self.metadata)
                        self.metadata.setMetadataObjectsDelegate(self, queue: self.queue)
                    }
                    self.session.commitConfiguration()
                    self.device = device
                }
                self.qrHandler = onQR
                if !self.session.isRunning { self.session.startRunning() }
                continuation.resume(returning: self.session.isRunning)
            }
        }
    }

    func stop() {
        queue.async {
            self.qrHandler = nil
            self.lastQR = nil
            _ = self.applyTorch(false)
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func enableQR(_ enabled: Bool) {
        queue.async {
            self.lastQR = nil
            guard self.metadata.availableMetadataObjectTypes.contains(.qr) else { return }
            self.metadata.metadataObjectTypes = enabled ? [.qr] : []
        }
    }

    func capture(completion: @escaping (Data?) -> Void) {
        queue.async {
            guard self.photoHandler == nil else { return }
            guard self.session.isRunning else { DispatchQueue.main.async { completion(nil) }; return }
            self.photoHandler = completion
            if let connection = self.photo.connection(with: .video) {
                if #available(iOS 17.0, *), connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            }
            self.photo.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func setTorch(_ enabled: Bool, completion: @escaping (Bool) -> Void) {
        queue.async {
            let applied = self.applyTorch(enabled)
            DispatchQueue.main.async { completion(applied) }
        }
    }

    private func applyTorch(_ enabled: Bool) -> Bool {
        guard let device, device.hasTorch, device.isTorchAvailable else { return false }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.torchMode = enabled ? .on : .off
            return true
        } catch { return false }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        queue.async {
            let completion = self.photoHandler
            self.photoHandler = nil
            DispatchQueue.main.async { completion?(data) }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let payload = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue,
              payload != lastQR else { return }
        lastQR = payload
        let callback = qrHandler
        DispatchQueue.main.async { callback?(payload) }
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
                            .accessibilityLabel("角点 \(index + 1)")
                            .accessibilityIdentifier("crop-corner-\(index)")
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
