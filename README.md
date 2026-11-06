# CamCard 课程项目

用 Swift 和 SwiftUI 黑盒复刻 iOS 名片全能王的「名片数字化与联系人管理」功能切片。项目采用规格驱动开发（SDD），保留原版观察、实现差异、测试及回归证据。

用户可以从名片夹拍摄或导入名片，校正图像，核对识别字段，保存后搜索、分组、编辑和导出联系人。Apple Vision 在设备端识别文字，应用在本地保存名片及图像。

## 当前状态

扫描页支持勾选照片后确认导入、裁剪、OCR、字段校对和保存。默认使用空的内存存储，使用 `--demo-cards` 启动时显示一张合成名片。原版通过 iPhone 镜像观察，复刻应用通过 Xcode 的 iOS 模拟器验收。实时相机预览和拍摄属于实现范围，实际预览和拍摄标记为未验证。

- [需求范围](docs/requirements.md)
- [黑盒规格](docs/spec.md)
- [用户故事](docs/user-stories.md) · [验收标准](docs/acceptance-criteria.md)
- [架构](docs/architecture.md) · [数据模型](docs/database.md) · [内部接口](docs/api.md) · [界面规格](docs/ui-spec.md)
- [阶段计划](docs/plan.md) · [任务清单](docs/tasks.md) · [项目决策](docs/decisions.md)
- [协作约定](AGENTS.md)

## 开发环境

使用 Xcode 27.2（27B52）和 iPhone 18 Pro 模拟器，运行 iOS 27.2（24B8117）。2026-11-06 已验证模拟器启动、导入测试图片 CC-001 及启动系统「照片」。可用 `xcrun simctl list devices available` 检查模拟设备。打开 `CamCard.xcodeproj`，选择共享的 `CamCard` Scheme 和 iPhone 18 Pro，然后运行。Xcode 27.2 可通过 Device Hub 查看模拟器画面。要手动验证详情，在 Scheme 的 Run 参数中加入 `--demo-cards`，重新运行并点击 Mara Quill。

```sh
xcodebuild -project CamCard.xcodeproj -scheme CamCard \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.2' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build

# 将 CC-001 导入已启动的专用测试模拟器，确保它是照片选择器中的第一张。
xcrun simctl addmedia booted tests/fixtures/business-cards/images/CC-001.png
# 已安装 CamCard 时，在专用模拟器中预先授予相册权限。
xcrun simctl privacy booted grant photos com.yepiphany.camcard

xcodebuild -project CamCard.xcodeproj -scheme CamCard \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.2' \
  -derivedDataPath DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

课程交付使用模拟器演示。发行渠道和签名配置待确认。
