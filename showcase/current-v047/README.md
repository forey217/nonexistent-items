# v0.47.0 整合试玩

日期：2026-10-23。

本目录保存当前发布版本的代表性实机截图与验证结果。完整Godot工程位于仓库 `game/`；Windows可执行程序发布在 [v0.47.0 Releases](https://github.com/forey217/nonexistent-items/releases/tag/v0.47.0)。

- `globe-guidance.png`：开场结束后星系仪的局部唤醒引导。
- `delete-confirmation.png`：固定档位、默认取消的删除存档确认框。
- `world-selection.png`：世界封存室选关。
- `tutorial-ui.png`：第一关薄玻璃通讯与观测界面。
- `paper-mill-upper.png`：第二关上层纸坊。
- `paper-mill-completed.png`：第二关双锚完成状态。

第一、二张截图来自各功能交付时的实机程序，其余截图来自本次上传的最终Windows程序。当前143份运行脚本、场景和配置，以及全部图像、字体与声音素材，与已完整验收的最终程序导出工程一致。

本次上传前，再次直接运行上传的Windows程序验证星系仪引导、存档删除和新进程恢复。原始结果在 `checks/`。此前同一可执行程序的双关材质、完整剧情、通关、自动楼梯、护栏、相机与存档回归结果见 `baseline-validation.json`；统计项有交叉，不将相加值视为独立功能数。

可执行程序 SHA256：`b71e1a651de8c96049e30a7192835cc66aa14a0ea48fc1a7bd27d8d4f8e8b325`。
