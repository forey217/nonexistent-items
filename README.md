# 世界不按说明书

**当前最新整合版：v0.56.1 · 20261024-08。** 衍月的平行世界解谜游戏，使用 Godot 4.7.2 标准版 / GDScript。游戏原名《不存在的物品》，仓库地址沿用原名。

## 下载与运行

- **[下载 Windows 64 位试玩程序](https://github.com/forey217/nonexistent-items/releases/download/v0.56.1/world-without-manual-v0.56.1-windows-x86_64.exe)**：单文件，双击运行，无需安装 Godot。
- **[v0.56.1 发布页](https://github.com/forey217/nonexistent-items/releases/tag/v0.56.1)**：对应完整工程、验证报告、实机截图与 SHA-256 校验值。
- [下载完整 Godot 工程](https://github.com/forey217/nonexistent-items/releases/download/v0.56.1/world-without-manual-v0.56.1-godot-source.zip)，或克隆仓库并用 Godot **4.7.2 标准版**导入 [`game/project.godot`](game/project.godot)，无需 .NET。
- [历史发布](https://github.com/forey217/nonexistent-items/releases)保留。程序和工程 ZIP 在 Releases，仓库保存可编辑源码及公开验收资料。

程序主界面标识“整合试玩 v0.56.1 · 20261024-08”。Windows 使用 Compatibility / ANGLE 渲染。

## 本版整合

- 第二关实际完成当前任务后盖“校准完成”章，保留原任务约1.2秒，再切换下一步；读档不补播旧回执。
- 修复人物移动时落物口与吊台井口边缘的共面闪烁，护栏增加0.16秒遮挡恢复缓冲；保留材质和阴影。
- 保留冰晶导轨约0.9秒逐段结霜、双层世界胶片、水岸护栏、圆角轨道、木铜卷轴归档门、倒悬实物、轻声脚步及主角提速30%（271.44）。
- 包含观察局大厅、星系仪选关、两关完整解谜、逐句配音、薄玻璃观测界面、三档存档删除确认和第二关完整演示。

实现说明：[本版整合](game/docs/最新整合-v0.56.1.md)、[任务完成盖章](game/docs/第二关任务完成盖章-v0.56.0.md)、[移动防闪](game/docs/移动时井口闪烁修复-v0.55.1.md)、[导轨结霜](game/docs/第二关导轨结霜-v0.55.0.md)。历史记录保留在 [`game/docs`](game/docs)。

## 操作与内容

第一关“新手校准室”使用冰晶、重力、倒悬三规则；第二关“纸山叠影”拥有上下层独立四规则、显影旧廊、留影夹、山水镇纸、踏板、水闸、吊台与双锚。第二关需正常完成第一关后解锁。

| 输入 | 功能 |
| --- | --- |
| WASD / 方向键 | 移动；第二关走入楼梯自动上下楼 |
| 左键地面 | 点击寻路 |
| 右键镇纸 / E | 按关卡交互；第二关选择方向后推动 |
| 1 / 2 / 3 / 4 | 切换规则，4显影仅在第二关使用 |
| H | 提示或观测记录 |
| M / F11 | 静音 / 全屏 |

第二关“观测仪表 → 演示 → 第二关完整演示”执行真实路线与机关，支持暂停、继续、退出及重播，不覆盖玩家原进度。

## 验证与源码

本版 **6组386项检查通过**：防闪15、任务完成盖章32、世界胶片143、导出程序完整通关125、重启读档4、第一关67。前三组采用Windows ANGLE实机渲染，后三组直接运行本版导出程序，存档测试使用隔离目录。

[验证汇总](showcase/current-v0561/validation.json) · [分组报告](showcase/current-v0561/reports) · [实机截图](showcase/current-v0561)。Release中的完整工程与程序运行代码对应，附逐文件SHA-256；Git文本文件仅按仓库规则统一行尾。

| 闪烁修复前 | 修复后 |
| --- | --- |
| ![修复前](showcase/current-v0561/flicker-before.png) | ![修复后](showcase/current-v0561/flicker-after.png) |

## 素材与作者

人物设定参考比赛官方资料；部分人物、美术和素材由AI辅助制作，来源、提示词与第三方许可保存在 [`game/assets`](game/assets) 和 [`game/docs`](game/docs)。Kenney素材采用CC0，字体按其随附许可使用。

项目作者：周书屹。
