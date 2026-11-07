import AVFoundation
import CoreLocation
import PhotosUI
import SwiftUI
import UserNotifications

struct CardNotes: View {
    let repository: CardRepository
    let cardID: UUID
    @State private var choosing = false
    @State private var draft: CardNote?
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                Text("备注").frame(maxWidth: .infinity)
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("返回").accessibilityIdentifier("notes-back")
            }.frame(height: 44).background(.white)
            Divider()
            ScrollView {
                if let card = repository.card(id: cardID) {
                    VStack(spacing: 1) {
                        ForEach(card.notes) { note in
                            noteRow(note.visit == nil ? "普通备注" : "拜访日志", date: note.date, text: note.summary) {
                                Menu {
                                    Button("编辑") { draft = note }
                                    Button("删除", role: .destructive) {
                                        do {
                                            try repository.saveNotes(card.notes.filter { $0.id != note.id }, for: cardID)
                                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [note.id.uuidString])
                                        }
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
            .safeAreaInset(edge: .bottom) {
                Button { choosing = true } label: {
                    Label("新增备注", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .foregroundStyle(.white).background(CardPalette.blue, in: Capsule())
                }.padding(.horizontal, 16).padding(.vertical, 10).background(.white)
            }
        }
        .background { Color.white.ignoresSafeArea() }
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
                        Button {
                            choosing = false
                            draft = CardNote(id: UUID(), text: "", date: .now, visit: .init())
                        } label: {
                            noteChoice("拜访日志", icon: "checklist", color: CardPalette.blue)
                        }
                    }.buttonStyle(.plain).padding(.horizontal, 38)
                    Spacer().frame(height: 110)
                    Button { choosing = false } label: {
                        Image(systemName: "xmark.circle.fill").font(.largeTitle).foregroundStyle(.white)
                    }.accessibilityLabel("关闭")
                    Spacer().frame(height: 28)
                }.background(.black.opacity(0.65)).ignoresSafeArea()
            }
        }
        .fullScreenCover(item: $draft) { note in
            NoteEditor(draft: note, subject: repository.card(id: cardID)?.fields.name ?? "",
                       asset: repository.noteAsset) { updated, assets in
                guard let card = repository.card(id: cardID) else { throw CocoaError(.fileNoSuchFile) }
                var notes = card.notes
                if let index = notes.firstIndex(where: { $0.id == note.id }) {
                    notes[index] = updated
                } else {
                    notes.append(updated)
                }
                try repository.saveNotes(notes, assets: assets, for: cardID)
                if note.visit?.followUp != updated.visit?.followUp { scheduleFollowUp(updated) }
            }
        }
        .managementError($error)
    }

    private func scheduleFollowUp(_ note: CardNote) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [note.id.uuidString])
        guard let followUp = note.visit?.followUp, followUp > .now else { return }
        Task {
            do {
                guard try await center.requestAuthorization(options: [.alert, .sound]),
                      repository.card(id: cardID)?.notes.contains(where: {
                          $0.id == note.id && $0.visit?.followUp == followUp
                      }) == true else { return }
                let content = UNMutableNotificationContent()
                content.title = "回访提醒"
                content.body = "打开 CamCard 查看拜访日志。"
                let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: followUp), repeats: false)
                try await center.add(UNNotificationRequest(identifier: note.id.uuidString, content: content, trigger: trigger))
            } catch {
                self.error = "已保存拜访日志，但无法添加系统提醒。"
            }
        }
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
        VStack(spacing: 16) {
            Text(title).font(.system(size: 17, weight: .medium))
            if icon == "checklist" {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(["clock.fill", "person.crop.circle.fill", "doc.circle.fill", "checkmark.circle.fill"].enumerated()), id: \.offset) { index, symbol in
                        HStack(spacing: 7) {
                            Image(systemName: symbol).font(.system(size: 16))
                            Capsule().fill(color.opacity(0.30)).frame(width: index.isMultiple(of: 2) ? 85 : 35, height: 5)
                        }
                    }
                }.accessibilityHidden(true)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Capsule().frame(width: 52, height: 5)
                    Capsule().frame(height: 5)
                    HStack(spacing: 5) {
                        ForEach(["photo", "mic.fill"], id: \.self) { icon in
                            Image(systemName: icon).font(.title3).foregroundStyle(color)
                                .frame(maxWidth: .infinity, minHeight: 54).background(color.opacity(0.25))
                        }
                    }
                }.foregroundStyle(color.opacity(0.28)).padding(.horizontal, 12).accessibilityHidden(true)
            }
        }.foregroundStyle(color).frame(maxWidth: .infinity, minHeight: 155)
            .background(.white, in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct NoteEditor: View {
    @State var draft: CardNote
    let subject: String
    let asset: (UUID) -> Data?
    let save: (CardNote, [UUID: Data]) throws -> Void

    @State private var staged: [UUID: Data] = [:]
    @State private var error: String?
    @State private var photo: PhotosPickerItem?
    @State private var showsCamera = false
    @State private var microphoneRequest: Task<Void, Never>?
    @State private var cameraRequest: Task<Void, Never>?
    @State private var preview: UIImage?
    @State private var audio = NoteAudio()
    @State private var location = NoteLocation()
    @State private var timeField: TimeField?
    @State private var pickedTime = Date.now
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    private enum TimeField { case visit, followUp }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(draft.visit == nil ? "普通备注" : "拜访日志")
                HStack {
                    Button("取消") { dismiss() }.foregroundStyle(.primary)
                    Spacer()
                    Button("保存", action: commit).disabled(!canSave || audio.recording)
                }
            }.padding(.horizontal, 16).frame(height: 44)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let visit = draft.visit { visitForm(visit) }
                    else {
                        ZStack(alignment: .topLeading) {
                            if draft.text.isEmpty {
                                Text("请填写备注信息").foregroundStyle(.secondary)
                                    .padding(.horizontal, 5).padding(.vertical, 8)
                            }
                            TextEditor(text: $draft.text).scrollContentBackground(.hidden)
                                .frame(minHeight: 160).focused($focused)
                                .accessibilityIdentifier("note-text")
                        }
                    }
                    ForEach(draft.attachments ?? []) { attachment in attachmentRow(attachment) }
                }
                .padding(.horizontal, 16).padding(.vertical, draft.visit == nil ? 20 : 36)
            }
            .scrollDismissesKeyboard(.interactively)
            Divider()
            mediaBar
            if let timeField { timePicker(timeField) }
        }
        .background(.white)
        .tint(CardPalette.blue)
        .fullScreenCover(isPresented: $showsCamera) {
            NoteCamera { data in
                showsCamera = false
                if let data { addPhoto(data) }
            }.ignoresSafeArea()
        }
        .sheet(isPresented: Binding(get: { preview != nil }, set: { if !$0 { preview = nil } })) {
            if let preview {
                VStack {
                    Button("关闭") { self.preview = nil }.frame(maxWidth: .infinity, alignment: .trailing).padding()
                    Image(uiImage: preview).resizable().scaledToFit().padding()
                    Spacer()
                }
            }
        }
        .task(id: photo) {
            guard let item = photo else { return }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                try Task.checkCancellation()
                addPhoto(data)
            } catch is CancellationError {
                return
            } catch {
                self.error = "无法读取照片。"
            }
            photo = nil
        }
        .onDisappear {
            microphoneRequest?.cancel()
            cameraRequest?.cancel()
            location.cancel()
            audio.cancel()
        }
        .managementError($error)
    }

    private func visitForm(_ visit: CardNote.Visit) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            visitRow("拜访日期:") {
                Button(visit.date.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day().dateSeparator(.dash))) {
                    showTime(.visit, value: visit.date)
                }.foregroundStyle(.primary).accessibilityIdentifier("visit-date")
            }
            visitRow("拜访对象:") { Text(subject) }
            visitRow("拜访方式:") {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { method(.inPerson); method(.phone); method(.chat); method(.other) }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) { method(.inPerson); method(.phone); method(.chat) }
                        method(.other)
                    }
                }
            }
            visitRow("拜访内容:") {
                TextField("请填写拜访内容", text: $draft.text, axis: .vertical)
                    .lineLimit(1...5).focused($focused).accessibilityIdentifier("visit-content")
            }
            visitRow("拜访结果:") {
                TextField("请填写拜访结果", text: Binding(get: { draft.visit?.outcome ?? "" },
                                                             set: { draft.visit?.outcome = $0 }), axis: .vertical)
                    .lineLimit(1...5).focused($focused).accessibilityIdentifier("visit-outcome")
            }
            visitRow("回访提醒:") {
                HStack {
                    Button(visit.followUp?.formatted(.dateTime.month().day().hour().minute()) ?? "请设置回访时间") {
                        showTime(.followUp, value: visit.followUp ?? .now.addingTimeInterval(3600))
                    }.foregroundStyle(visit.followUp == nil ? .secondary : .primary)
                        .accessibilityIdentifier("visit-follow-up")
                    if visit.followUp != nil {
                        Button { draft.visit?.followUp = nil } label: { Image(systemName: "xmark.circle.fill") }
                            .accessibilityLabel("清除回访提醒")
                    }
                }
            }
        }.font(.subheadline)
    }

    private func visitRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title).frame(width: 65, alignment: .leading).padding(.top, 3)
            content().padding(.top, 3)
            Spacer(minLength: 0)
        }.frame(minHeight: 23)
    }

    private func method(_ method: CardNote.Visit.Method) -> some View {
        let selected = draft.visit?.method == method
        return Button { draft.visit?.method = method } label: {
            Text(method.rawValue).font(.footnote).fixedSize()
                .padding(.horizontal, 10).padding(.vertical, 4)
                .foregroundStyle(selected ? .white : CardPalette.blue)
                .background(selected ? CardPalette.blue : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(CardPalette.blue.opacity(0.4), lineWidth: 0.5))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func showTime(_ field: TimeField, value: Date) {
        focused = false
        pickedTime = value
        timeField = field
    }

    private func timePicker(_ field: TimeField) -> some View {
        VStack(spacing: 0) {
            Divider()
            Button("确定") {
                if field == .visit { draft.visit?.date = pickedTime }
                else { draft.visit?.followUp = pickedTime }
                timeField = nil
            }.foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .trailing).padding(14)
                .accessibilityIdentifier("visit-time-confirm")
            DatePicker(field == .visit ? "拜访日期" : "回访时间", selection: $pickedTime,
                       displayedComponents: field == .visit ? [.date] : [.date, .hourAndMinute])
                .labelsHidden().datePickerStyle(.wheel)
        }.environment(\.locale, Locale(identifier: "zh_Hans_CN"))
    }

    private var mediaBar: some View {
        HStack(spacing: 0) {
            Button {
                if audio.recording {
                    finishRecording()
                } else {
                    microphoneRequest?.cancel()
                    microphoneRequest = Task {
                        let allowed = await AVAudioApplication.requestRecordPermission()
                        guard !Task.isCancelled else { return }
                        if !allowed { error = "未允许使用麦克风。"; return }
                        do { try audio.start(onFinish: finishRecording) } catch { self.error = "无法录制语音。" }
                    }
                }
            } label: {
                mediaIcon(audio.recording ? "stop.circle.fill" : "mic.fill")
            }.accessibilityLabel(audio.recording ? "结束录音" : "录音")
            PhotosPicker(selection: $photo, matching: .images) { mediaIcon("photo.fill") }
                .accessibilityLabel("添加照片")
            Button(action: openAttachmentCamera) { mediaIcon("camera.fill") }.accessibilityLabel("拍摄附件")
            Button {
                location.locate { coordinate in
                    if let coordinate {
                        append(.init(kind: .location, latitude: coordinate.latitude, longitude: coordinate.longitude))
                    } else {
                        error = "无法读取当前位置。"
                    }
                }
            } label: { mediaIcon("mappin.circle.fill") }.accessibilityLabel("添加位置")
            if timeField != nil {
                Button { timeField = nil } label: { mediaIcon("chevron.down") }.accessibilityLabel("收起")
            }
        }
        .buttonStyle(.plain).background(Color(white: 0.97))
    }

    private func openAttachmentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            error = "当前设备无法拍摄，请从相册添加照片。"
            return
        }
        cameraRequest?.cancel()
        cameraRequest = Task {
            let allowed: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: allowed = true
            case .notDetermined: allowed = await AVCaptureDevice.requestAccess(for: .video)
            default: allowed = false
            }
            guard !Task.isCancelled else { return }
            if allowed { showsCamera = true }
            else { error = "未允许使用相机，请从相册添加照片。" }
        }
    }

    private func mediaIcon(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
    }

    private func append(_ attachment: CardNote.Attachment, data: Data? = nil) {
        draft.attachments = (draft.attachments ?? []) + [attachment]
        if let data { staged[attachment.id] = data }
    }

    private func addPhoto(_ data: Data) {
        guard let image = try? ScanProcessor.decode(data),
              let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.80) else {
            error = "无法读取照片。"; return
        }
        append(.init(kind: .photo), data: jpeg)
    }

    private func finishRecording() {
        if let data = audio.finish() { append(.init(kind: .audio), data: data) }
        else { error = "无法保存录音。" }
    }

    private func attachmentRow(_ attachment: CardNote.Attachment) -> some View {
        HStack {
            switch attachment.kind {
            case .photo:
                Button {
                    preview = (staged[attachment.id] ?? asset(attachment.id)).flatMap { UIImage(data: $0) }
                    if preview == nil { error = "无法读取照片附件。" }
                } label: { Label("照片", systemImage: "photo") }
            case .audio:
                Button {
                    do {
                        guard let data = staged[attachment.id] ?? asset(attachment.id) else { throw CocoaError(.fileNoSuchFile) }
                        try audio.play(data)
                    } catch { self.error = "无法播放录音。" }
                } label: { Label("录音", systemImage: "play.circle") }
            case .location:
                if let latitude = attachment.latitude, let longitude = attachment.longitude {
                    Label(String(format: "%.5f, %.5f", latitude, longitude), systemImage: "mappin.circle")
                }
            }
            Spacer()
            Button {
                draft.attachments?.removeAll { $0.id == attachment.id }
                staged.removeValue(forKey: attachment.id)
            } label: { Image(systemName: "xmark.circle") }
                .accessibilityLabel("移除\(attachment.kind.rawValue)")
        }.buttonStyle(.plain).font(.subheadline)
            .padding(10).background(CardPalette.background, in: RoundedRectangle(cornerRadius: 6))
    }

    private var canSave: Bool {
        !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !(draft.visit?.outcome.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
            || draft.attachments?.isEmpty == false
    }

    private func commit() {
        draft.text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let outcome = draft.visit?.outcome {
            draft.visit?.outcome = outcome.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        do { try save(draft, staged); dismiss() } catch { self.error = "无法保存备注。" }
    }
}

@MainActor @Observable
private final class NoteAudio: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var onFinish: (() -> Void)?
    private var temporaryFile: URL?
    private(set) var recording = false

    func start(onFinish: @escaping () -> Void) throws {
        guard !recording else { return }
        player?.stop()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: .defaultToSpeaker)
        try session.setActive(true)
        do {
            let recorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 24_000,
                AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 48_000
            ])
            recorder.delegate = self
            guard recorder.record(forDuration: 60) else { throw CocoaError(.fileWriteUnknown) }
            self.onFinish = onFinish
            self.recorder = recorder
            temporaryFile = url
            recording = true
        } catch {
            try? FileManager.default.removeItem(at: url)
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
    }

    func finish() -> Data? {
        guard let url = temporaryFile else { return nil }
        onFinish = nil
        recorder?.stop()
        recorder = nil
        recording = false
        temporaryFile = nil
        defer {
            try? FileManager.default.removeItem(at: url)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        return try? Data(contentsOf: url)
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in onFinish?() }
    }

    func play(_ data: Data) throws {
        guard !recording else { return }
        player?.stop()
        try AVAudioSession.sharedInstance().setCategory(.playback)
        player = try AVAudioPlayer(data: data)
        player?.play()
    }

    func cancel() {
        player?.stop()
        _ = finish()
    }
}

@MainActor
private final class NoteLocation: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((CLLocationCoordinate2D?) -> Void)?

    func locate(completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        self.completion = completion
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .notDetermined: manager.requestWhenInUseAuthorization()
        default: finish(nil)
        }
    }

    func cancel() {
        completion = nil
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard completion != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: finish(nil)
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(locations.last?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { finish(nil) }

    private func finish(_ coordinate: CLLocationCoordinate2D?) {
        let callback = completion
        completion = nil
        callback?(coordinate)
    }
}

private struct NoteCamera: UIViewControllerRepresentable {
    let completion: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
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
            completion((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.9))
        }
    }
}
