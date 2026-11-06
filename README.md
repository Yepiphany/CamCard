# CamCard 课程项目

用 Swift 和 SwiftUI 黑盒复刻 iOS 名片全能王的「名片数字化与联系人管理」功能切片。项目采用规格驱动开发（SDD），保留原版观察、实现差异、测试及回归证据。

用户可以从名片夹拍摄或导入名片，校正图像，核对识别字段，保存后搜索、分组、编辑和导出联系人。Apple Vision 在设备端识别文字，应用在本地保存名片及图像。

## 当前状态

当前处于规格准备阶段。应用工程和测试目标将在下阶段建立。原版通过 iPhone 镜像观察，复刻应用通过 Xcode 的 iOS 模拟器验收。实时相机预览和拍摄属于实现范围，实际预览和拍摄标记为未验证。

- [需求范围](docs/requirements.md)
- [黑盒规格](docs/spec.md)
- [用户故事](docs/user-stories.md) · [验收标准](docs/acceptance-criteria.md)
- [架构](docs/architecture.md) · [数据模型](docs/database.md) · [内部接口](docs/api.md) · [界面规格](docs/ui-spec.md)
- [阶段计划](docs/plan.md) · [任务清单](docs/tasks.md) · [项目决策](docs/decisions.md)
- [协作约定](AGENTS.md)

## 开发环境

使用 Xcode 27.2（27B52）和 iPhone 18 Pro 模拟器，运行 iOS 27.2（24B8117）。2026-11-06 已验证模拟器启动、导入测试图片 CC-001 及启动系统「照片」。可用 `xcrun simctl list devices available` 检查模拟设备。工程建立后，在 Xcode 中打开工程，选择已安装的 iPhone 模拟器并运行。具体 Scheme、构建和测试命令随工程一起验证并补录。

课程交付使用模拟器演示。发行渠道和签名配置待确认。
