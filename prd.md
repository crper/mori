# Mori

Mori is a native workspace terminal for macOS.

# Design
下面是一版 Workspace Terminal 详细设计文档 v0.1。
我先按你已经确认的方向写死：
	•	macOS 原生应用
	•	Project-first
	•	Project 下有多个 Worktree
	•	1 Worktree = 1 tmux session
	•	tmux = 持久化 / layout / runtime backend
	•	libghostty = terminal renderer
	•	App 自己负责 sidebar / workspace / 状态聚合 / 搜索 / 原生交互

⸻

Workspace Terminal 详细设计文档 v0.1

1. 背景与目标

我们希望构建一个 macOS 原生 workspace terminal，它不是传统意义上的“终端 tab 管理器”，而是一个围绕 Project / Worktree / Task 组织的开发工作台。

传统终端的问题是：
	•	tab 只是 UI 容器，不是工作单元
	•	tab/window 与 project、repo、worktree 没有直接语义
	•	关闭终端后，若没有 tmux，session 就消失
	•	多个 repo、多条分支、多 worktree 并行时容易失控
	•	无法很好承载 agent、日志、服务、测试等多任务场景

因此本项目的核心目标是：
	1.	以 Project 为主要导航单位
	2.	以 Worktree 为实际开发单位
	3.	以 tmux 作为持久化运行时
	4.	以 libghostty 作为高质量终端渲染层
	5.	提供原生 macOS 的 sidebar / command palette / 通知 / 搜索体验
	6.	保证 GUI 关闭后，工作仍然可通过 tmux 在任意 SSH 客户端中继续

⸻

2. 设计原则

2.1 Project-first，而不是 tab-first

用户关注的是项目，而不是某个 terminal tab。

2.2 Worktree-aware，而不是 branch-blind

同一个 project 下可能同时存在多个 worktree；产品必须把这件事当一等公民。

2.3 tmux 是后端真相源

布局、pane、window、session 持久化全部交给 tmux，不重复造一个 terminal multiplexer。

2.4 原生 App 负责体验层

App 负责：
	•	信息组织
	•	状态展示
	•	快速导航
	•	搜索/命令
	•	macOS 集成

2.5 渐进式增强

先做可用 MVP，再逐步增加：
	•	Git 状态
	•	未读输出
	•	Agent 状态
	•	模板化 workspace
	•	CLI / automation / socket API

⸻

3. 产品定义

一句话定义：

一个以 Project 为核心、以 Worktree 为工作单元、以 tmux 为运行时后端、以 libghostty 为终端渲染内核的 macOS 原生开发工作台。

⸻

4. 核心对象模型

系统中有 4 个核心层级：

Project
  ├─ Worktree
  │    ├─ tmux Session
  │    │    ├─ tmux Window
  │    │    │    └─ tmux Pane

映射规则：
	•	Project：逻辑组织单元，不直接映射 tmux
	•	Worktree：实际开发单元，映射为 1 个 tmux session
	•	Window：任务/tab 单元，映射为 1 个 tmux window
	•	Pane：终端分屏单元，映射为 1 个 tmux pane

⸻

5. 术语定义

Project

代表一个 Git 仓库的逻辑项目容器。
一个 Project 可以包含多个 Worktree。

例如：
	•	anna
	•	gateway
	•	infra

Worktree

代表同一个 Project 下的某个具体工作副本。
通常对应：
	•	main
	•	feat/sidebar
	•	fix/auth
	•	release/1.2

Session

tmux session。
在系统中，每个 Worktree 绑定一个 tmux session。

Window

tmux window。
在产品语义中更接近 task/tab。

Pane

tmux pane。
由 tmux 管理，不在产品上提升为更高层导航对象。

⸻

6. 用户场景

6.1 单项目多分支并行开发

用户在 anna 项目下同时维护：
	•	main
	•	feat/sidebar
	•	fix/login

每个 worktree 都有独立 tmux session，可保存各自 layout、日志、服务进程。

6.2 GUI 关闭后继续工作

用户关闭 macOS App，稍后从手机 SSH 到服务器，仍可：

tmux attach -t ws::anna::feat-sidebar

继续相同工作。

6.3 Agent / 服务 / 测试并行

某个 worktree 下存在多个 tmux windows：
	•	editor
	•	server
	•	tests
	•	logs
	•	agent

sidebar 能清晰展示这些运行单元及状态。

⸻

7. 非目标

当前版本暂不做：
	1.	自建 terminal multiplexer
	2.	替代 tmux 的 pane/layout persistence
	3.	跨平台 GUI 支持
	4.	云同步
	5.	复杂协作功能
	6.	浏览器内嵌 devtools/preview 体系
	7.	自定义 shell runtime 管理器

⸻

8. 顶层架构

+-------------------------------------------------------+
|                   macOS Native App                    |
|                                                       |
|  +----------------+   +----------------------------+  |
|  | Project Rail   |   | Worktree / Window Sidebar |  |
|  +----------------+   +----------------------------+  |
|                                                       |
|  +-------------------------------------------------+  |
|  |            Terminal Content Area                |  |
|  |        (libghostty-backed terminal view)        |  |
|  +-------------------------------------------------+  |
|                                                       |
|  +----------------+  +----------------------------+   |
|  | CommandPalette |  | Notifications / Status     |   |
|  +----------------+  +----------------------------+   |
+-------------------------------------------------------+

                 |                     |
                 v                     v

      +------------------+   +----------------------+
      | Workspace Core   |   | Metadata Aggregator  |
      +------------------+   +----------------------+
                 |                     |
                 +----------+----------+
                            |
                            v
                  +--------------------+
                  | Tmux Backend Layer |
                  | Control Mode Client|
                  +--------------------+
                            |
                            v
                         tmux server
                            |
                            v
                   shell / editor / agent / logs


⸻

9. 模块拆分

建议分成以下模块。

9.1 AppShell

负责整个 macOS 应用壳层：
	•	主窗口
	•	sidebar 布局
	•	toolbar
	•	菜单
	•	命令面板
	•	settings
	•	焦点管理
	•	原生快捷键

建议：AppKit 为主，SwiftUI 为辅

⸻

9.2 WorkspaceCore

负责业务核心模型与状态协调：
	•	Project 管理
	•	Worktree 管理
	•	选中状态
	•	session 映射
	•	状态聚合
	•	命令分发

它是 UI 和 tmux backend 之间的核心协调层。

⸻

9.3 GitDiscovery

负责识别和扫描 Git 信息：
	•	当前路径是否属于 git repo
	•	project identity
	•	worktree 列表
	•	branch / HEAD / dirty 状态
	•	git common dir

⸻

9.4 TmuxBackend

负责与 tmux control mode 交互：
	•	attach / start session
	•	list sessions / windows / panes
	•	监听异步事件
	•	发送 select/new/split/rename 命令
	•	把 tmux 的 runtime 状态翻译成应用内部事件

⸻

9.5 TerminalHost

负责把 terminal surface 嵌入到 UI 中：
	•	管理 libghostty surface/view
	•	将输入事件传入 terminal
	•	响应焦点、滚动、复制、粘贴
	•	绑定当前 pane/render target

⸻

9.6 MetadataEngine

负责补充 tmux 本身没有的高层状态：
	•	cwd
	•	git branch
	•	dirty 状态
	•	unread output
	•	最近活跃时间
	•	agent waiting
	•	command summary

⸻

9.7 Persistence

负责本地保存应用状态：
	•	最近打开项目
	•	pinned/favorite project
	•	project 展开/折叠状态
	•	UI 布局
	•	用户设置
	•	session 恢复偏好

⸻

10. 数据模型

10.1 Project

struct Project {
    let id: UUID
    var name: String
    var repoRootPath: String
    var gitCommonDir: String
    var originURL: String?
    var iconName: String?
    var isFavorite: Bool
    var isCollapsed: Bool
    var lastActiveAt: Date?
    var aggregateUnreadCount: Int
    var aggregateAlertState: AlertState
}

说明
	•	gitCommonDir 用于识别同一个 repo 的不同 worktree
	•	aggregateAlertState 用于 project 级 badge 聚合

⸻

10.2 Worktree

struct Worktree {
    let id: UUID
    let projectId: UUID
    var name: String
    var path: String
    var branch: String?
    var headSHA: String?
    var isMainWorktree: Bool
    var isDetached: Bool
    var hasUncommittedChanges: Bool
    var aheadCount: Int
    var behindCount: Int
    var lastActiveAt: Date?
    var tmuxSessionId: String?
    var tmuxSessionName: String?
    var unreadCount: Int
    var agentState: AgentState
    var status: WorktreeStatus
}


⸻

10.3 RuntimeWindow

struct RuntimeWindow {
    let tmuxWindowId: String
    let worktreeId: UUID
    var tmuxWindowIndex: Int
    var title: String
    var activePaneId: String?
    var paneCount: Int
    var cwd: String?
    var commandSummary: String?
    var hasUnreadOutput: Bool
    var lastOutputAt: Date?
    var badge: WindowBadge?
}


⸻

10.4 RuntimePane

struct RuntimePane {
    let tmuxPaneId: String
    let tmuxWindowId: String
    var title: String?
    var cwd: String?
    var tty: String?
    var isActive: Bool
    var isZoomed: Bool
}


⸻

10.5 UIState

struct UIState {
    var selectedProjectId: UUID?
    var selectedWorktreeId: UUID?
    var selectedWindowId: String?
    var sidebarMode: SidebarMode
    var searchQuery: String
}


⸻

11. Project Identity 识别规则

Project 必须稳定识别，不能只靠路径。

推荐规则：
	1.	优先使用：

git rev-parse --git-common-dir

	2.	结合：

git config --get remote.origin.url

	3.	回退到 repo root path

原因

同一个 repo 的多个 worktree 路径可能不同，但它们属于同一个 Project。
git-common-dir 是最稳定的聚合依据。

⸻

12. Worktree 发现机制

使用：

git worktree list --porcelain

解析得到：
	•	worktree path
	•	branch
	•	HEAD
	•	detached 状态

每次以下事件发生时触发重扫：
	•	Project 首次打开
	•	用户显式刷新
	•	新建 worktree
	•	删除 worktree
	•	切分支/checkout
	•	App 启动恢复时

⸻

13. tmux 绑定规则

核心规则：

1 个 Worktree = 1 个 tmux session

建议 session 命名规则：

ws::<project-slug>::<worktree-slug>

例如：

ws::anna::main
ws::anna::feat-sidebar
ws::gateway::fix-retry

必要时加入短 hash 防止重名：

ws::anna::feat-sidebar::a1b2

但内部识别仍以：
	•	app worktree.id
	•	tmux session_id

为准，不依赖 session name 作为唯一键。

⸻

14. tmux backend 设计

14.1 职责

TmuxBackend 负责：
	•	连接 tmux
	•	初始化 runtime tree
	•	监听 tmux 事件流
	•	执行控制命令
	•	向 WorkspaceCore 派发标准事件

⸻

14.2 初始化流程
	1.	检查 tmux server 是否可用
	2.	获取所有 session
	3.	获取 session -> windows -> panes
	4.	建立内部映射
	5.	将 runtime tree 推送到 WorkspaceCore

初始化命令示例

tmux list-sessions
tmux list-windows -a
tmux list-panes -a

建议统一使用可格式化输出，避免脆弱解析。

⸻

14.3 事件监听

TmuxBackend 使用 control mode 持续监听：
	•	window 新建
	•	window 关闭
	•	pane 新建/关闭
	•	session 切换
	•	active window/pane 变化
	•	输出事件

内部统一转成应用事件：

enum TmuxEvent {
    case sessionAdded(...)
    case sessionRemoved(...)
    case windowAdded(...)
    case windowClosed(...)
    case windowRenamed(...)
    case paneAdded(...)
    case paneClosed(...)
    case paneFocusChanged(...)
    case outputReceived(...)
}


⸻

14.4 命令接口

protocol TmuxControlling {
    func selectSession(_ id: String)
    func selectWindow(_ id: String)
    func selectPane(_ id: String)
    func createWindow(in sessionId: String, name: String?)
    func splitPane(targetPaneId: String, direction: SplitDirection)
    func renameWindow(windowId: String, title: String)
    func sendKeys(targetPaneId: String, keys: String)
    func killWindow(windowId: String)
    func killSession(sessionId: String)
}


⸻

15. Terminal 渲染设计

15.1 目标

App 不直接自己实现 terminal emulator，而是嵌入 libghostty 提供的 terminal surface。

TerminalHost 负责：
	•	创建 surface
	•	与当前 pane 绑定
	•	输入事件转发
	•	渲染生命周期管理

⸻

15.2 终端区域行为

主区域默认展示：
	•	当前选中 worktree 的当前 active window
	•	当前 active window 的 active pane

初期不要求在 App 层重新实现 pane tree UI。
pane 布局仍由 tmux 决定，App 只负责显示当前 runtime 对应的 terminal content。

⸻

15.3 焦点行为

焦点规则：
	1.	sidebar 可获得键盘焦点
	2.	terminal area 可获得键盘焦点
	3.	command palette 打开时独占焦点
	4.	切换 window 后自动聚焦 terminal area

⸻

16. Sidebar 设计

推荐采用 双栏 结构，而不是单棵超深树。

16.1 左侧窄栏：Project Rail

只显示 Project 列表。

展示信息：
	•	icon / 首字母
	•	project 名称
	•	聚合 badge
	•	收藏状态
	•	最近活跃标识

交互：
	•	点击选中 project
	•	右键 project 菜单
	•	支持拖拽排序（后续）

⸻

16.2 中间侧栏：Worktree + Windows

显示当前 Project 下的：
	•	worktree 列表
	•	每个 worktree 下的 window 列表

示意：

Anna
  main
    editor
    server
    tests
  feat/sidebar
    ui
    logs
    agent

每个 worktree 展示：
	•	branch
	•	dirty 状态
	•	unread count
	•	agent badge
	•	最后活跃时间

每个 window 展示：
	•	title
	•	badge
	•	pane count
	•	active indicator

⸻

17. 主界面布局

建议布局如下：

+-------------------------------------------------------------+
| Toolbar / Breadcrumb / Search / Quick Actions               |
+-------------+------------------------+----------------------+
| ProjectRail | WorktreeWindowSidebar  | Terminal Content     |
|             |                        |                      |
|             |                        |                      |
+-------------+------------------------+----------------------+
| Status Bar / Notification Strip                             |
+-------------------------------------------------------------+


⸻

18. 交互设计

18.1 选择 Project
	•	更新右侧 worktree 列表
	•	默认恢复上次活跃 worktree
	•	若没有 worktree，则显示 onboarding/action panel

18.2 选择 Worktree
	•	若不存在 tmux session，则创建
	•	切换到该 session
	•	显示上次活跃 window

18.3 选择 Window
	•	调用 tmux select-window
	•	主区域切换到对应 runtime

18.4 新建 Worktree
	•	输入 branch 名或新 path
	•	调用 git worktree add
	•	创建 tmux session
	•	套用默认 window 模板

⸻

19. 默认模板机制

为了让新 worktree 打开即用，支持 Worktree Template。

19.1 基础模板

shell
run
logs

19.2 Go 项目模板

editor
server
tests
logs

19.3 Agent 项目模板

editor
agent
server
logs

模板应用流程：
	1.	创建 worktree
	2.	创建 tmux session
	3.	批量创建 windows
	4.	可选发送初始化命令

例如：

cd /path/to/worktree && nvim
cd /path/to/worktree && go test ./...
cd /path/to/worktree && air


⸻

20. 状态聚合设计

20.1 Window 级状态
	•	has unread output
	•	running / idle
	•	exited with error
	•	agent waiting
	•	long running command

20.2 Worktree 级状态
	•	dirty
	•	ahead/behind
	•	unread count
	•	alert badge
	•	active runtime

20.3 Project 级状态
	•	子 worktree 状态聚合
	•	是否存在高优先级告警
	•	未读总数

聚合优先级建议：

error > waiting > unread > dirty > normal


⸻

21. 未读输出设计

目标：让 sidebar 能知道哪个 window 有新输出，而不是用户必须逐个看。

21.1 触发规则

当某 window 非当前可见，且收到输出事件，则标记为 unread。

21.2 清除规则

以下任一发生时清除 unread：
	•	用户切到该 window
	•	用户显式 mark read
	•	输出被视为低优先级噪声且策略忽略

⸻

22. Agent 状态设计

后续很重要，所以现在先预留。

22.1 AgentState

enum AgentState {
    case none
    case running
    case waitingForInput
    case error
    case completed
}

22.2 来源

可从以下来源推断：
	•	特定 pane 标记
	•	shell prompt hook
	•	tmux user option
	•	sidecar metadata
	•	命令输出模式识别

初版先保留接口，不急着做复杂检测。

⸻

23. 本地存储设计

建议使用：
	•	SQLite：保存业务数据、Project/Worktree 映射、最近状态
	•	UserDefaults / plist：保存轻量 UI 配置

SQLite 存储内容
	•	projects
	•	worktrees
	•	recent selections
	•	window template configs
	•	badge cache
	•	session mapping cache

⸻

24. 启动流程

24.1 冷启动
	1.	加载本地存储
	2.	初始化 AppShell
	3.	启动 TmuxBackend
	4.	扫描最近 Project
	5.	恢复上次选中状态
	6.	渲染 UI

24.2 唤醒恢复
	1.	检查 tmux sessions 是否仍存在
	2.	重建 runtime tree
	3.	恢复选中 worktree/window
	4.	清理失效缓存

⸻

25. 会话恢复策略

恢复优先级：
	1.	上次 active project
	2.	上次 active worktree
	3.	上次 active window
	4.	若 runtime 丢失则回退到该 project 的主 worktree
	5.	若 project 丢失则显示 Project 列表首页

⸻

26. CLI / IPC 设计

后续建议提供一个轻量 CLI，便于自动化。

命令示例：

ws open /path/to/repo
ws project list
ws worktree create anna feat/sidebar
ws focus anna feat/sidebar
ws send anna feat/sidebar agent "continue"
ws new-window anna feat/sidebar logs

内部可通过：
	•	local unix socket
	•	XPC
	•	custom URL scheme

进行通信。

⸻

27. macOS 原生集成

建议提供以下原生能力：

27.1 Finder 集成
	•	“Open in Workspace Terminal”
	•	“Open Project”
	•	“Create Worktree Here”

27.2 菜单栏
	•	Recent Projects
	•	Active Sessions
	•	Quick Focus
	•	New Worktree

27.3 Dock 集成
	•	未读 badge
	•	跳转最近 active project

27.4 Spotlight / URL Scheme

后续可支持：

workspace-terminal://project/anna/worktree/feat-sidebar


⸻

28. 快捷键设计

建议初版默认快捷键：

Cmd+P          打开 command palette
Cmd+1..9       切换当前 project 下的常用 window
Cmd+Shift+[    切换上一个 window
Cmd+Shift+]    切换下一个 window
Cmd+Option+N   新建 worktree
Cmd+T          新建 window
Cmd+W          关闭当前 window（确认）
Cmd+K          清除当前 pane 显示
Cmd+\          聚焦 terminal
Cmd+0          聚焦 sidebar


⸻

29. 错误与异常处理

29.1 tmux 不可用

提示安装或定位 tmux 可执行文件。

29.2 worktree 路径失效

在 UI 中标记为 unavailable，并允许：
	•	remove from app
	•	relink path

29.3 session 丢失

若 worktree 存在但 tmux session 不存在，允许用户：
	•	recreate session
	•	attach existing session
	•	ignore

29.4 Git 命令失败

仅影响 metadata，不应阻塞 terminal 核心功能。

⸻

30. 安全与隔离

本项目不负责 sandbox shell 命令。
默认假设 tmux 中运行的命令就是用户自己的终端命令。

但应用层应避免：
	•	无限制自动执行危险命令
	•	未经确认删除 worktree
	•	silent 覆盖 session

所有 destructive 操作需确认：
	•	删除 worktree
	•	kill session
	•	kill all windows
	•	remove project

⸻

31. 工程目录建议

WorkspaceTerminal/
  App/
    AppDelegate.swift
    MainWindowController.swift
    RootSplitViewController.swift

  UI/
    ProjectRail/
    WorktreeSidebar/
    TerminalArea/
    CommandPalette/
    Settings/

  Core/
    WorkspaceCore/
    Models/
    State/
    Commands/

  Integrations/
    Tmux/
      TmuxBackend.swift
      TmuxParser.swift
      TmuxCommandRunner.swift
    Git/
      GitDiscovery.swift
      WorktreeScanner.swift
    Terminal/
      TerminalHost.swift
      GhosttyAdapter.swift

  Persistence/
    Database/
    Repositories/
    Preferences/

  Services/
    NotificationService.swift
    BadgeService.swift
    TemplateService.swift

  IPC/
    SocketServer.swift
    CLIEntry.swift

  Resources/
  Tests/


⸻

32. 核心协议设计

32.1 WorkspaceCore

protocol WorkspaceManaging {
    func loadProjects()
    func selectProject(_ id: UUID)
    func selectWorktree(_ id: UUID)
    func selectWindow(_ tmuxWindowId: String)
    func createProject(from path: String)
    func createWorktree(projectId: UUID, branch: String)
    func refreshProject(_ id: UUID)
}

32.2 GitDiscovery

protocol GitDiscovering {
    func resolveProject(at path: String) throws -> ProjectDescriptor
    func listWorktrees(project: ProjectDescriptor) throws -> [WorktreeDescriptor]
    func readStatus(path: String) throws -> GitStatusSnapshot
}

32.3 TerminalHost

protocol TerminalHosting {
    func attach(to paneId: String)
    func focus()
    func copySelection()
    func paste()
}


⸻

33. MVP 范围

MVP-1
	•	主窗口
	•	Project Rail
	•	Worktree/Window Sidebar
	•	tmux session/window/pane 扫描
	•	选择 worktree / window
	•	terminal area 可用
	•	最近项目恢复

MVP-2
	•	Git worktree 扫描
	•	create worktree
	•	create session
	•	默认模板
	•	unread output
	•	basic badges

MVP-3
	•	command palette
	•	notifications
	•	CLI/socket
	•	worktree 状态增强
	•	agent 状态预留

⸻

34. 里程碑拆解

Phase 0：技术验证
	•	Swift AppKit 壳子
	•	嵌 terminal surface
	•	调 tmux 命令
	•	解析 tmux 状态
	•	能切换 window

Phase 1：基础可用
	•	Project / Worktree / Window 数据模型
	•	sidebar
	•	session 绑定
	•	最近状态恢复

Phase 2：Product 化
	•	Git 状态
	•	模板
	•	badge
	•	命令面板
	•	原生菜单

Phase 3：Agent-first
	•	waiting 状态
	•	window semantic tag
	•	automation hooks
	•	richer metadata

⸻

35. 风险与应对

35.1 libghostty 嵌入变动风险

应对：
	•	做 GhosttyAdapter
	•	避免业务层直接依赖底层 API
	•	单独封装 TerminalHost 协议

35.2 tmux 事件解析复杂

应对：
	•	初始化走显式 list 命令
	•	增量更新靠事件
	•	定期全量 reconcile

35.3 Git worktree 状态不一致

应对：
	•	所有 metadata 可异步刷新
	•	UI 不因 metadata 失败而阻塞

35.4 状态源过多

应对：
定义清晰边界：
	•	tmux：runtime truth
	•	git：repo/worktree truth
	•	app db：UI truth

⸻

36. 真相源边界

这是很关键的一节。

tmux 是这些信息的真相源
	•	session
	•	window
	•	pane
	•	active focus
	•	layout
	•	runtime existence

git 是这些信息的真相源
	•	project identity
	•	worktree list
	•	branch
	•	HEAD
	•	dirty/ahead/behind

app 本地存储是这些信息的真相源
	•	收藏
	•	排序
	•	折叠状态
	•	最近打开
	•	UI 恢复状态
	•	template 选择

⸻

37. 推荐的第一版实现顺序

最务实的顺序是：
	1.	先做 Project / Worktree / Window 纯数据模型
	2.	再做 tmux runtime tree
	3.	然后做 sidebar
	4.	再接 terminal area
	5.	再做 worktree discovery
	6.	最后做模板、badge、恢复

不要一开始就追求：
	•	太复杂的 pane 级 UI
	•	agent 自动识别
	•	高级通知
	•	云同步

⸻

38. 结论

这个产品最关键的设计结论有四个：
	1.	Project 是主导航对象
	2.	Worktree 是实际 workspace
	3.	每个 Worktree 绑定一个 tmux session
	4.	tmux 管 runtime，App 管体验，libghostty 管渲染

这样设计后，你得到的是一个真正适合现代开发流的 terminal：
	•	既有 tmux 的持久化与可迁移性
	•	又有原生 macOS 的组织能力和体验层
	•	还能自然承接多 worktree、多任务、agent workflow

⸻

如果你愿意，我下一条可以继续写 技术实现文档 v0.2，把它进一步落成：
进程模型、tmux control mode 协议、Swift 类设计、SQLite schema、以及 MVP 任务拆分清单。