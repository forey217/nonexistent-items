# 特斯拉 NPC · 生成记录

- 工具：内置 image_gen（imagegen 技能，非 CLI）。
- 日期：2026-10-21。
- 最终资产：`game/assets/npc/tesla_v01.png`，1024 × 1536，RGBA 透明背景。
- 参考一：用户提供的官方 `尼古拉特斯拉.png`，用于角色身份、发型、胡须、三件套、长外套和怀表链。
- 参考二：项目现有 `game/assets/yanyue_rig_v02.png`，仅用于与衍月一致的 2D 插画风格。
- 游戏使用：接待大厅办公桌后，显示高度约 143 像素；运行时缩放，不破坏生成原图。
- 权利说明：基于用户提供的比赛角色参考制作，未将该 NPC 或官方角色素材声明为 CC0。原有音频、字体、模型各自保留独立许可。

完整生成提示词：

```text
Use case: style-transfer. Asset type: single full-body NPC sprite for an existing 2D isometric adventure game, actual transparent background. Image 1 is the official identity and clothing reference for Nikola Tesla, the senior employee of a parallel universe observation bureau. Image 2 is the existing heroine's paper cutout sprite style reference ONLY: clean fine ink contours, anime/semi-realistic illustrated face, soft painterly shading, muted natural colors, slightly overhead isometric view. Generate ONE complete standing full body Nikola Tesla, NOT a character sheet, NOT disconnected pieces. Preserve recognizable swept-back dark hair, slender mustache, thoughtful adult male face, black late-Victorian three-piece suit and long coat, white shirt, dark cravat, gold pocket watch chain, polished black shoes. Pose calm senior scientist with hands resting naturally at his waist, three-quarter facing viewer and slightly screen-left, viewed from about 25 degrees above. Head and body proportions like the heroine reference, adult natural proportions. Full head to soles visible with clear silhouette, both legs and arms anatomically natural, no accessories in hands. Match heroine's illustrated 2D style, no photographic background or grain, no furniture, no text, no border, no other characters, no large lightning effects, no ground shadow. Center the full body with modest transparent margin, feet at same baseline. This sprite will stand behind a brass-trimmed wooden reception desk. Keep subdued black suit with enough warm-grey fold highlights to read at 140px height.
```
