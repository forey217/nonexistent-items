# 世界不按说明书

衍月的平行世界解谜游戏，使用 **Godot 4.7.2 标准版 / GDScript** 制作。同一块镇纸，在冰晶、重力与倒悬世界中拥有不同物性，玩家需要组合规则完成观察局的第一次校准。

当前版本 **v0.24**，包含启动界面、接待大厅、星系仪、水晶碎片选关和一张可完整通关的新手校准室。游戏原名为《不存在的物品》，仓库地址沿用原名。

源码中的启动界面使用观察局内部档案室、毛笔标题与文字菜单。标题保持固定，字面有横向流光和轻微辉光呼吸；背景保留镜头移动、星系仪绕行流光、窗边光束和台灯呼吸光。“选项”中的动态开关可冻结这些效果。大厅和关卡右下角有“返回主界面”按钮。最新菜单、动画开关、选关和返回共43项检查已在 Windows 原生渲染下通过，见[报告](showcase/checks/start-menu-v07/menu-checks.json)及[说明](game/docs/启动界面-v01.md)。下方 v0.24 下载包仍为原发布版本。

![观察局启动界面](showcase/start-menu-v07.png)

![水晶碎片选关](showcase/v24/fragment-selection.png)

## 下载与运行

- [下载 Windows 试玩版](https://github.com/forey217/nonexistent-items/releases/download/v0.24.0/world-without-manual-v0.24-windows-x86_64.exe)：双击运行，无需安装Godot。
- [v0.24发布页、源码与许可文件](https://github.com/forey217/nonexistent-items/releases/tag/v0.24.0)。
- [水晶分裂与旋转入场动画](https://github.com/forey217/nonexistent-items/releases/download/v0.24.0/crystal-fragment-selection-v0.24.gif)。
- 编辑工程：克隆仓库，使用Godot **4.7.2标准版**导入 [`game/project.godot`](game/project.godot)，运行主场景。无需.NET。

Windows导出使用Compatibility / ANGLE渲染，已在Windows与RTX 5060 Laptop上验证；其他设备尚待试玩。

## 从观察局出发

**开始旅程 → 接待大厅 → 点击星系仪 → 水晶分裂选关 → 新手校准室。**

星图最初只有一枚完整水晶，鼠标悬停时细裂缝亮起，点击后向四周分裂为六块关卡碎片。当前只有 **01 / 新手校准室**可进入，其余五块显示问号。

选择01后，其他碎片带拖尾旋转汇入它；镜头跟随选中碎片旋转、放大、亮起，随后衍月从空间裂隙中走进关卡。通关后，校准室缩成档案卡，盖章后沿抛物线归档，再返回接待大厅。

| 接待大厅 | 悬停微裂 |
| --- | --- |
| ![大厅](showcase/v24/reception.png) | ![开裂](showcase/v24/crystal-hover.png) |

![新手校准室](showcase/v24/tutorial.png)

## 玩法与操作

| 世界 | 物理规则 | 镇纸特性 |
| --- | --- | --- |
| 冰晶 | 低摩擦 | 推动后持续滑行，碰到挡板才停 |
| 重力 | 向下受力增强 | 重量×4，可压动机关 |
| 倒悬 | 重力方向向上 | 向上漂浮，触碰高处机关 |

切换世界保留镇纸位置和机关记录。组合物性完成星位、月痕与界缝校准，归位门就会开启。任务只展示阶段目标，具体解法可按H逐步查看。

| 输入 | 功能 |
| --- | --- |
| WASD / 方向键 | 人物移动 |
| 鼠标左键 | 点击地面寻路；点击星系仪和关卡水晶 |
| 右键镇纸 / E | 互动镇纸，轨道两侧均可就近操作 |
| 1 / 2 / 3 | 切换世界，共享冷却 **1.5秒** |
| 左Alt + 左键水平拖动 | 旋转校准室视角，范围±45° |
| H / R | 逐步提示 / 重置校准室 |
| M / F11 | 静音 / 切换全屏 |
| F10 | 从正常玩法或大厅返回启动界面 |
| Esc | 关闭手册、退出未进入的选关界面，或取消行走 |

角色不能跳跃。选关和归档等切场景动画不会被重复点击或F10打断。

<details>
<summary>完整教程解法（含剧透）</summary>

冰晶推动至第一踏板 → 重力压下踏板并释放挡板 → 冰晶推动至末端 → 倒悬上浮完成月痕压印 → 重力落下压住末端踏板、封合界缝 → 走入归位门。

</details>

## 当前完成度

已完成：启动界面与操作手册、人物行走和互动动作、碰撞与点击寻路、特斯拉NPC、星系仪光效、水晶分裂选关、三世界规则与环境动效、完整新手解谜、世界切换胶片过渡、±45°视角、背景音乐与音效、裂隙出入场，以及盖章归档返回大厅。

待制作：NPC漫画对话、正式关卡和完整主线剧情。本版尚未接入男女角色语音。

启动界面保留组员提交的插画设计，并接入当前大厅与选关流程；仓库历史保留该提交。

## 工程与验证

```text
game/
  project.godot     工程入口
  scenes/          角色、启动界面与关卡场景
  scripts/         玩法、人物、UI和场景流程
  shaders/         星空、水晶和过渡效果
  assets/          美术、音频、字体及来源许可
  tests/           玩法、交互和完整流程检查
  docs/            设计、迭代、AI提示词和素材来源记录
showcase/          公开实机截图与检查报告
```

**v0.24 Windows导出检查：35项选关及完整通关返回、29项启动界面整合，共64项，全部通过。** 已逐帧检查完整水晶、悬停微裂、碎片展开、旋转汇聚与裂隙入场，运行日志无脚本或着色器错误。

报告见 [`showcase/checks/v24`](showcase/checks/v24)。在图形环境中执行：

```text
Godot --path game --fixed-fps 60 -- --hub-check --artifacts=<报告目录>
Godot --path game --fixed-fps 60 -- --menu-self-test --artifacts=<报告目录>
```

## 素材与AI辅助制作

- 衍月和特斯拉参考比赛官方角色设定；人物分件、部分家具、NPC与星海插画使用AI辅助制作，提示词与来源记录保存在 [`game/docs`](game/docs)。
- 墙板、线缆与门框来自 **Kenney / Modular Space Kit 1.0（CC0）**，附[许可](game/assets/kenney_modular_space/License.txt)及[来源](game/assets/kenney_modular_space/SOURCE.json)。
- 背景音乐 **Magic Puzzle In-Game 1 / MintoDog** 与Kenney音效采用CC0，详见[音频来源](game/assets/audio/SOURCE.json)和[许可文件](game/assets/audio/licenses)。
- 站酷小薇体采用 **SIL Open Font License 1.1**，附[字体许可](game/assets/fonts/zcool_xiaowei/OFL.txt)。
- 轨道、机关、水晶分裂、星系仪光效、拖尾与动画过渡由代码绘制。项目代码实现、迭代和检查通过Codex辅助完成。

第三方许可仅适用于相应素材，不代表全部角色、美术或代码统一采用CC0。

项目作者：周书屹。
