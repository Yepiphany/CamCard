# 应用内部接口

CamCard 在同一进程中调用以下 Swift 类型。界面负责处理用户取消、系统权限和错误提示。

| 模块 | 当前入口 | 行为 |
| --- | --- | --- |
| 相机与相册 | `ScannerView`、`ScannerCamera`、`ScanAlbum` | 相机通过 AVFoundation 提供预览、拍摄、补光和实时二维码读取。相册确认后通过 `onConfirm` 交回选中图片的 `[Data]`。 |
| 图像处理与 OCR | `ScanProcessor.decode`、`rotate`、`boundaries`、`recognize`、`qrPayload` | 解码图片、旋转并检测边界。识别接受原图、当前图像、可选边界、精度和语言，返回含校正图及识别记录的 `ScanResult`。无边界时用当前图像识别并提示手动裁剪。无法解码或裁剪无效时抛出错误。 |
| 字段解析 | `ContactExtraction.fields(from:)` | 从 OCR 原文提取 `ContactFields`。缺失或无法确认的字段留空。 |
| 本地仓库 | `CardRepository` | 按 ID 读取名片，保存或删除名片、分组与备注，读取图像和附件。写入失败抛出错误。 |
| 搜索与筛选 | `BusinessCard.matches`、名片的 `groupIDs` | 在名片夹和分组界面按姓名、公司、职位、电话或邮箱匹配。分组界面按名片的分组 ID 筛选。 |
| 联系人导出 | `ContactExport.save`、`ContactExport.vCard`、`ContactExportFile` | 将已确认字段写入系统通讯录并返回标识，或序列化为 VCF 数据并保存为可分享的文件。通讯录授权由详情页处理。 |

识别记录包含实际使用的语言、原文、文字区域、字段候选值和识别时间。文字区域保存文本和归一化坐标。解析器以整段 OCR 原文为输入，置信度和字段到文字区域的映射不写入识别记录。 [扫描处理](../CamCard/ScanProcessor.swift) · [本地数据模型](database.md)

通讯录与 VCF 使用相同的已确认字段和映射规则，保留多电话、多邮箱及电话类型。通讯录权限被拒绝时，用户仍可导出 VCF。 [联系人导出](../CamCard/ContactExport.swift)
