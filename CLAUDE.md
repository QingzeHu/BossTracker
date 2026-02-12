# BossTracker WoW Addon — Claude Code 开发规范

## 使用说明

将此文件放在你的项目根目录，命名为 `CLAUDE.md`。
Claude Code 会自动读取这个文件作为项目上下文。

然后在终端里进入项目目录，启动 Claude Code：
```bash
cd /你的WoW安装路径/Interface/AddOns/BossTracker
claude
```

---

## 项目概述

BossTracker 是一个魔兽世界怀旧服（Cata Classic, Interface: 38000, 客户端目录 `_classic_titan_`）的独立插件。
用途：多目标Boss战中追踪每个Boss的血量和玩家DOT状态，支持点击切换目标。
额外支持训练假人模式：在主城等非副本环境自动检测附近的训练假人姓名牌并显示追踪框体。

### 设计理念

- **DOT优先布局**：DOT图标是视觉主体（36px），血量信息压缩在顶部窄条（头像+名字+百分比+4px血条）
- **数据驱动**：职业DOT配置、用户偏好全部分离为独立数据文件，逻辑代码不含硬编码数据
- **事件驱动**：用WoW事件系统而非每帧轮询，仅在数据变化时更新对应UI元素（假人模式例外，见下文）
- **宏式点击选中**：使用 SecureActionButtonTemplate + `/targetexact` 宏实现战斗中可点击切换目标

---

## 技术约束

### WoW Lua 环境

- Lua 5.1，**没有** `require`、`module`、`io`、`os` 等标准库
- 文件间通过**全局表**通信：`BossTracker = BossTracker or {}`
- .toc 文件定义加载顺序，按顺序执行每个 .lua 文件（Windows路径用反斜杠 `Data\Classes\...`）
- API 参考：https://warcraft.wiki.gg/wiki/World_of_Warcraft_API (使用 Cata Classic 版本的API)
- 不能在战斗中创建框体或修改 Secure 框体属性（`SetAttribute` 等）
- `SavedVariables` / `SavedVariablesPerCharacter` 用于持久化配置，WoW在登出/reload时自动序列化到磁盘

### Cata Classic 特定 API

```lua
-- 获取BUFF/DEBUFF
name, icon, count, debuffType, duration, expirationTime, source = UnitDebuff(unit, index)
-- 通过name匹配DOT

-- 副本检测
name, instanceType, difficultyID, difficultyName, maxPlayers = GetInstanceInfo()

-- Boss战事件
ENCOUNTER_START: encounterID, encounterName, difficultyID, groupSize
ENCOUNTER_END: encounterID, encounterName, difficultyID, groupSize, success

-- Boss单位
boss1 ~ boss5 是WoW提供的Boss单位ID

-- 姓名牌单位
nameplate1 ~ nameplate40, 通过 NAME_PLATE_UNIT_ADDED/REMOVED 事件追踪
```

### 已踩坑的关键限制

```lua
-- ❌ TargetUnit() 是受保护API，插件调用会导致taint报错并被禁用
-- ❌ SecureUnitButtonTemplate 的 unit 属性不支持 nameplateN 单位（Cata Classic）
--    即使设置 type1="target", unit="nameplate3"，点击也不会切换目标

-- ✅ 正确做法：SecureActionButtonTemplate + 宏方式
btn = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
btn:SetAttribute("type1", "macro")
btn:SetAttribute("macrotext1", "/targetexact 单位名字")
-- macrotext 只能在脱战时通过 SetAttribute 更新
-- 但 frame.unitId（非Secure属性）可以在战斗中自由修改

-- ❌ BackdropTemplate 的纹理拉伸后不显示
-- ✅ 用 SetColorTexture(r,g,b,a) 做纯色背景

-- ❌ CooldownFrameTemplate 自带倒计时数字会与自定义文字重叠
-- ✅ SetHideCountdownNumbers(true) + noCooldownCount = true 禁用自带数字
--    自定义文字放在 textOverlay 子Frame（frameLevel+3）上
```

### 安全框体规则

```lua
-- SecureActionButtonTemplate 属性只能在脱战时设置
btn:SetAttribute("type1", "macro")
btn:SetAttribute("macrotext1", "/targetexact Boss名字")
-- 战斗中不能调用 SetAttribute，需要在进战前或GUID变化时（脱战）设好
-- frame.unitId 不是Secure属性，可以在战斗中随时修改
```

### 中文客户端注意事项

- 法术名、NPC名都是中文，匹配时要用中文
- 字体文件用 `Fonts\\ARKai_T.ttf`（中文客户端自带）
- 编码为 UTF-8（不带BOM）
- Lua字符串匹配中文需用UTF-8字节序列（如 "假人" = `\229\129\135\228\186\186`）

---

## 项目结构（实际文件）

```
BossTracker/
├── CLAUDE.md                          # 本文件（Claude Code上下文）
├── BossTracker.toc                    # WoW插件清单 (Interface: 38000)
├── Core.lua                           # 入口：事件注册、初始化、斜杠命令、假人模式
├── Config.lua                         # 配置系统：默认值、SavedVariables读写
├── Utils.lua                          # 工具函数：颜色计算、边框绘制、调试打印
├── UI/
│   ├── Container.lua                  # 主容器：创建、定位、拖拽手柄、锁定
│   ├── BossFrame.lua                  # 单个Boss条：组装顶栏+血条+DOT区+点击覆盖层
│   ├── Portrait.lua                   # 头像：3D PlayerModel（pcall保护，失败回退2D）
│   ├── HealthBar.lua                  # 血条：4px极细StatusBar + 颜色渐变
│   ├── DotIcons.lua                   # DOT图标：图标+雷达扫描+倒计时+层数+缺失状态
│   ├── Highlight.lua                  # 目标高亮：金色边框（2px）
│   └── ConfigFrame.lua                # 配置面板：DOT顺序拖拽排列
├── Logic/
│   └── DotTracker.lua                 # DOT检测：遍历UnitDebuff匹配玩家的DOT
└── Data/
    ├── ClassRegistry.lua              # 职业注册表：自动检测当前职业天赋
    └── Classes/
        └── WarlockAffliction.lua      # 痛苦术士DOT配置
```

---

## .toc 文件加载顺序

```toc
## Interface: 38000
## Title: BossTracker
## Title-zhCN: BossTracker - 多目标Boss追踪器
## Notes: Multi-target boss DOT tracker with click-to-cast
## Notes-zhCN: DOT优先的多Boss追踪、点击施法、智能排序
## Author: Qingze
## Version: 0.2.0
## SavedVariables: BossTrackerDB
## SavedVariablesPerCharacter: BossTrackerCharDB

Config.lua
Utils.lua
Data\ClassRegistry.lua
Data\Classes\WarlockAffliction.lua
Logic\DotTracker.lua
UI\Container.lua
UI\Portrait.lua
UI\HealthBar.lua
UI\DotIcons.lua
UI\Highlight.lua
UI\ConfigFrame.lua
UI\BossFrame.lua
Core.lua
```

---

## 全局命名空间

所有文件共享一个全局表，每个模块注册为子表：

```lua
-- 每个文件的第一行
BossTracker = BossTracker or {}
local BT = BossTracker

-- 模块注册自己
BT.Utils = {}
BT.Config = {}
BT.UI = { Container, BossFrame, Portrait, HealthBar, DotIcons, Highlight, ConfigFrame }
BT.Logic = { DotTracker }
BT.Data = { ClassRegistry, Classes = {} }
```

---

## 各模块当前实现

### Config.lua

```lua
-- 职责：管理所有配置的默认值与用户覆盖
-- BossTrackerDB (全局SavedVariables) 存储跨角色通用设置
-- BossTrackerCharDB (角色SavedVariables) 存储角色特定设置（位置等）

BT.Config.Defaults = {
    ui = {
        frameWidth = 210, frameHeight = 78, frameSpacing = 4,
        headerHeight = 28, portraitSize = 24, healthBarHeight = 4,
        dotIconSize = 36, dotSpacing = 5, maxBoss = 5, maxDotSlots = 5,
        -- 颜色、字体等...
    },
    options = { locked = false, testMode = false, debugMode = false, ... },
    position = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
}

function BT.Config:Get(category, key) ... end
function BT.Config:Set(category, key, value) ... end
function BT.Config:SavePosition(point, relPoint, x, y) ... end
```

### Utils.lua

```lua
BT.Utils.GetHealthColor(pct)           -- 返回 r,g,b (绿→黄→红)
BT.Utils.MakeBorder(parent, r,g,b,a)   -- 画1px边框，返回borders表
BT.Utils.ColorBorder(borders, r,g,b,a) -- 修改已有边框颜色
BT.Utils.Debug(...)                     -- 调试打印（debugMode开关控制）
BT.Utils.FormatTime(seconds)            -- 格式化倒计时文字
```

### UI/Container.lua

```lua
-- 职责：主容器框体，管理所有BossFrame的父容器
-- 实现细节：
--   容器本身 EnableMouse(false)，点击穿透到子BossFrame
--   拖拽手柄：16x16半透明Frame，位于容器左上方外侧(BOTTOMLEFT→TOPLEFT)
--   拖拽不需要Shift，直接拖动手柄即可
--   根据可见Boss数量动态调整容器高度 (UpdateSize)
--   位置保存到角色级SavedVariables
```

### UI/BossFrame.lua — 核心框体架构

```lua
-- 职责：组装单个Boss条的所有子元素
-- 布局（从上到下）：
--   顶栏 28px：[3D头像 24px] [Boss名字] [血量%]
--   血条 4px：StatusBar
--   DOT区 46px：[36px图标] x N，动态左对齐排列
--
-- 点击架构（重要！）：
--   主框体是普通 Frame（不是Button）
--   所有子元素 EnableMouse(false)：header, portrait, healthBar, dotArea, highlight
--   最顶层放一个透明的 SecureActionButtonTemplate 覆盖层（frameLevel+50）
--   覆盖层使用宏方式点击选中：type1="macro", macrotext1="/targetexact 单位名字"
--
-- 关键方法：
--   frame:UpdateAll()       -- 更新所有数据（Info+Health+Dots+Highlight）
--   frame:UpdateInfo()      -- 名字+头像，GUID变化时重置DOT + 更新点击宏
--   frame:UpdateHealth()    -- 血条+百分比文字+颜色
--   frame:UpdateDots()      -- DOT图标状态 + 动态重排
--   frame:UpdateHighlight() -- 目标高亮
--   frame:SetUnitId(id)     -- 修改追踪单位（战斗中安全，只跳过宏属性更新）
--   frame:ResetDotStates()  -- 重置所有DOT的hasBeenSeen标记
--   frame:RecreateDotIcons() -- 重建DOT图标（配置保存后）
```

### UI/DotIcons.lua

```lua
-- 职责：单个DOT图标的创建与状态更新
-- 视觉元素（从底到顶）：
--   背景(BACKGROUND) → 法术图标(ARTWORK) → CooldownFrameTemplate雷达扫描
--   → 暗色遮罩(OVERLAY) → textOverlay子Frame(frameLevel+3)内的倒计时+层数文字
--
-- 状态机 (currentState)：
--   "hidden"  : 从未在当前目标上检测到，隐藏不占位
--   "active"  : DOT存在，绿色边框，图标全亮，雷达扫描+倒计时
--   "warning" : DOT剩余<5秒，橙色边框，红色倒计时文字
--   "expired" : 曾经释放过但已消失，灰暗图标+暗色遮罩+暗红边框
--
-- hasBeenSeen 机制：
--   首次检测到DOT时设为true，之后即使DOT消失也显示（expired状态）
--   切换目标(GUID变化)时重置为false
--
-- 动态重排 (RepositionIcons)：
--   只给 hasBeenSeen=true 的图标分配位置，左对齐
--   用 lastSlot 缓存避免每帧重设锚点导致闪烁
```

### UI/Highlight.lua

```lua
-- 目标高亮：2px金色边框（比普通1px粗）
-- 通过 UnitIsUnit(frame.unitId, "target") 判断是否显示
-- EnableMouse(false) 不拦截点击
```

### UI/ConfigFrame.lua

```lua
-- 配置面板：/bt config 打开
-- 功能：DOT顺序拖拽排列
```

### Logic/DotTracker.lua

```lua
-- 职责：检测指定单位上玩家施放的DOT
-- CheckDot(unitId, dotName): 检查单个DOT
-- CheckAllDots(unitId, dotList): 检查所有DOT，返回结果数组
-- 方法：遍历 UnitDebuff(unit, 1~40)，匹配 name == dotSpellName 且 source == "player"
-- 返回：{ found=bool, remaining=秒, duration=秒, count=层数 }
```

### Data/Classes/ 文件格式

```lua
BossTracker.Data.Classes["WARLOCK_AFFLICTION"] = {
    className = "术士",
    classNameEN = "WARLOCK",
    specName = "痛苦",
    talentTab = 1,
    dots = {
        { name = "鬼影缠身", spellId = 59164, priority = 1, pandemic = 4 },
        { name = "痛苦无常", spellId = 47843, priority = 2, pandemic = 5 },
        -- ...
    },
}
```

---

## Core.lua 核心架构

### 三种运行模式

| 模式 | unitId来源 | 触发方式 | OnUpdate行为 |
|------|-----------|---------|-------------|
| 正常模式 | boss1~boss5 | INSTANCE_ENCOUNTER_ENGAGE_UNIT | 只更新DOT倒计时文字 |
| 测试模式 | "target" (仅frame1) | `/bt test` | 同正常模式 |
| 假人模式 | nameplate1~40 | NAME_PLATE_UNIT_ADDED + IsDummy检测 | 轮询血量+DOT+高亮（每50ms） |

### 假人模式详细机制

```lua
-- 触发：在非副本环境（主城等）检测到名字包含"假人"的姓名牌
--        已配置副本内由encounter系统管理，不激活假人模式
-- 数据结构：
dummySlots = { [slotIndex] = "nameplateN" }
dummyNameplates = { ["nameplateN"] = slotIndex }

-- 同名去重（关键！训练假人都同名）：
-- 1. AssignDummySlot: 分配前检查已有槽位是否有同名单位，有则跳过
-- 2. UpdateBossFrameVisibility: 同名frame只显示第一个，后续隐藏
-- 3. 动态重排: 可见frame按紧凑顺序重新定位(ClearAllPoints+SetPoint)，消除隐藏frame的间隙

-- DOT换位（TrySwapDummyUnit）：
-- 问题：去重后显示的nameplate可能不是有DOT的那个
-- 方案：每0.5秒扫描所有40个姓名牌，找同名且有玩家DOT的，swap过去
-- 注意：swap中的 SetUnitId + UpdateAll 必须在战斗中也能执行
--        （它们内部已处理Secure属性的战斗锁定）

-- 退出：进入已配置副本时自动退出（encounter系统接管）
--        Boss战开始(ENCOUNTER_START/ENGAGE_UNIT)时自动退出
--        所有假人姓名牌消失时自动退出
--        进入测试模式时退出
```

### OnUpdate 职责

```lua
-- 节流：50ms间隔
-- 假人模式：
--   每50ms: 轮询血量 + DOT + 高亮（姓名牌单位的事件可能不触发）
--   每500ms: TrySwapDummyUnit 检查DOT换位
-- 正常/测试模式：
--   每50ms: 只更新active/warning状态的DOT倒计时数字
```

---

## 斜杠命令

```
/bt              显示帮助
/bt test         切换测试模式（选目标即显示，城里可测试）
/bt config       打开DOT顺序配置面板
/bt lock         切换锁定/解锁位置
/bt reset        重置框体到屏幕中央
/bt debug        切换调试模式
/bt class        显示检测到的职业天赋
```

---

## 事件驱动架构

```
ADDON_LOADED / PLAYER_LOGIN / PLAYER_ENTERING_WORLD → 初始化
INSTANCE_ENCOUNTER_ENGAGE_UNIT  → Boss单位出现 → 退出假人模式 → 刷新显示
ENCOUNTER_START                 → Boss战开始 → 退出假人模式
ENCOUNTER_END                   → Boss战结束 → 隐藏框体
UNIT_HEALTH                     → 只更新对应unit的血条
UNIT_AURA                       → 只更新对应unit的DOT状态
PLAYER_TARGET_CHANGED           → 更新所有高亮 + 测试模式刷新
PLAYER_REGEN_DISABLED           → 进战标记
PLAYER_REGEN_ENABLED            → 脱战 → 处理延迟的假人模式退出
NAME_PLATE_UNIT_ADDED           → 非副本环境检测训练假人 → 进入假人模式
NAME_PLATE_UNIT_REMOVED         → 释放假人槽位 → 可能退出假人模式
```

---

## 代码风格

- 所有模块第一行：`BossTracker = BossTracker or {}; local BT = BossTracker`
- 局部变量优先，减少全局查找
- 频繁调用的API缓存到局部变量：`local UnitHealth = UnitHealth`
- 注释用中文（这是中文用户的项目）
- 缩进用4空格
- 文件编码 UTF-8 无BOM

---