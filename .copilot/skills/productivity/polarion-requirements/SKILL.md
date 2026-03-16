---
name: polarion-requirements
description: Guides requirements management and traceability tracking in Siemens Polarion ALM. Use this skill whenever the user mentions Polarion, needs to manage SOR/system requirements, track requirement completion status, build traceability matrices, query work items, automate Polarion via REST API, or import/export ReqIF files. Also trigger when the user asks how to set up requirement workflows, filter by status, generate coverage reports, or link work items across documents in Polarion.
---

# Polarion 需求管理与追踪 Skill

本 Skill 专注于 Polarion 中**需求文件管理（如 SOR）、状态追踪和追溯矩阵**的操作指引。

---

## 核心概念速查

| 概念 | 说明 |
|------|------|
| **Project** | 项目空间，所有工作项、文档归属于某个项目 |
| **Work Item（工作项）** | Polarion 的基本数据单元，可以是需求、任务、缺陷等 |
| **LiveDoc（动态文档）** | 包含工作项的富文本文档，类似 Word 但实时协作，SOR 通常以 LiveDoc 形式存在 |
| **Work Item Type** | 工作项类型，如 `requirement`、`systemRequirement`、`testCase` 等（每个项目可自定义）|
| **Status / Workflow** | 工作项的状态机（如 Draft → In Review → Approved → Implemented → Verified）|
| **Link Role** | 工作项间的关系类型（如 `implements`、`verifies`、`derives_from`）|
| **Traceability** | 追溯关系，需求 → 设计 → 测试用例的全链路映射 |
| **ReqIF** | 需求交换格式，用于与 OEM 或其他工具（如 DOORS）交换需求 |

---

## 一、理解 SOR 类需求文件的典型结构

SOR（Statement of Requirements，需求声明）在 Polarion 中通常以 **LiveDoc** 形式存在：

```
Project
└── Documents (LiveDocs)
    └── SOR_v1.0 (LiveDoc)
        ├── Section 1 - Functional Requirements
        │   ├── REQ-001: 系统应支持 ... [status: Approved]
        │   ├── REQ-002: 系统应在 3 秒内 ... [status: In Review]
        └── Section 2 - Non-Functional Requirements
            └── REQ-010: 系统可靠性 ... [status: Draft]
```

每条需求对应一个 **Work Item**，具有：
- **ID**（如 `PROJ-123`）
- **Title / Description**
- **Status**（当前完成状态）
- **Assignee**（负责人）
- **Links**（与测试用例、设计项的追溯链接）
- **自定义字段**（如 Priority、Source、Maturity）

---

## 二、需求状态追踪

### 2.1 典型需求工作流状态

```
Draft → In Review → Approved → Implemented → Verified → Closed
                 ↘ Rejected
```

| 状态 | 含义 |
|------|------|
| Draft | 初稿，尚未评审 |
| In Review | 评审中 |
| Approved | 已批准，可以开始实现 |
| Implemented | 开发侧已实现（有对应代码/设计） |
| Verified | 测试已验证 |
| Closed | 关闭/废弃 |

> 注：实际状态名称取决于项目配置，可在 Polarion 后台 Administration → Workflow 查看。

### 2.2 在 Polarion UI 中过滤需求状态

1. 进入 **Work Items** 视图（左侧导航 → Work Items）
2. 点击 **Filter** 按钮，添加条件：
   - `Type = requirement`
   - `Status = Approved`（或其他目标状态）
3. 可保存为**查询（Saved Query）**，方便复用

### 2.3 在 LiveDoc 中查看状态

- 打开 LiveDoc，顶部可切换视图（Document / Table）
- **Table 视图**：每行一条需求，列可配置显示 Status、Assignee、Links 数量等
- 支持按列排序和过滤

---

## 三、追溯矩阵（Traceability Matrix）

### 3.1 建立需求追溯链

典型链路（箭头方向表示 link 的发出方指向目标方）：
```
SOR Requirement  <──(derives_from)──  System Requirement  <──(verifies)──  Test Case
（父需求）                              （子需求，派生自 SOR）                （验证子需求）
```

Link Role 方向说明：
- `derives_from`：**子需求**持有此链接，指向其父需求（即"我派生自..."）
- `verifies`：**测试用例**持有此链接，指向被验证的需求（即"我验证..."）
- `implements`：**设计/代码工作项**持有此链接，指向被实现的需求

在 Polarion UI 中添加链接：
1. 打开**子需求**工作项（如 System Requirement）
2. 点击 **Links** 选项卡
3. 点击 **Add Link** → 选择 Link Role（如 `derives_from`）→ 搜索并选择目标工作项（如 SOR Requirement）

### 3.2 查看追溯覆盖率报告

1. 进入项目 → **Reports** → **Traceability Report**（或通过 LiveDoc 右上角的 Traceability 图标）
2. 可生成：
   - 需求 → 测试用例 覆盖矩阵
   - 未追溯需求列表（Coverage Gap）
   - 双向追溯表

### 3.3 常用追溯 Link Role

> **注意**：Link Role 的实际名称取决于 Polarion 项目配置，以下为行业常见命名，使用前须在项目 Administration → Link Roles 中确认。

| Link Role | 链接持有方（发出方） | 链接目标方 | 含义 |
|-----------|------|------|------|
| `derives_from` | 子需求 | 父需求 | 此需求派生自父需求 |
| `verifies` | 测试用例 | 需求 | 此测试用例验证该需求 |
| `implements` | 设计/代码工作项 | 需求 | 此工作项实现了该需求 |
| `depends_on` | 工作项 A | 工作项 B | A 依赖于 B |
| `duplicates` | 工作项 A | 工作项 B | A 与 B 重复 |

---

## 四、批量查询与导出

### 4.1 Lucene 查询语法（Work Items 查询）

Polarion 使用 Lucene 语法查询工作项。

> **重要**：查询中所有字段值（如 `status:`、`type:` 后的值）使用的是**配置 ID**（小写），
> 而非 UI 上显示的 Label（如 UI 显示 "Approved"，查询用 `status:approved`）。
> 实际 ID 请在 Administration → Workflow / Work Item Types 中确认。

```
# 查询所有已批准的需求（status 后跟 ID，非 UI 显示名）
type:requirement AND status:approved

# 查询特定文档中的需求
# ⚠ document 相关字段名因 Polarion 版本而异，以下仅供参考
# 实际字段名请在 Administration 中查询 Lucene Index Fields，或咨询管理员确认
type:requirement AND document.title:"SOR_v1.0"

# 查询指定负责人且未验证的需求
# ⚠ assignee 字段名因版本/配置而异，常见有 assignee.id 或 author.id，使用前请确认
type:requirement AND assignee.id:john AND NOT status:verified

# 查询无任何追溯链接的需求
# ⚠ linkedWorkItems 为常见字段名，实际名称请在 Lucene Index Fields 中核对
type:requirement AND NOT HAS_VALUE:linkedWorkItems
```

### 4.2 导出需求列表

**方式一：Excel 导出**
- Work Items 视图 → 过滤条件设置好 → 右上角 **Export** → Excel

**方式二：LiveDoc → Word/PDF 导出**
- 打开 LiveDoc → 右上角菜单 → **Export to Word/PDF**

**方式三：ReqIF 导出（与外部工具交换）**
- LiveDoc → 右上角菜单 → **Export to ReqIF**
- 生成 `.reqifz` 文件，可导入 DOORS / Jama 等工具

---

## 五、Python 自动化（REST API）

详见 `references/polarion-api.md`，以下为快速示例。

### 5.1 安装依赖

```bash
pip install polarion-rest-api-client
```

### 5.2 连接并查询需求状态

```python
import polarion_rest_api_client as polarion_api
from collections import Counter

# 初始化客户端
# 注意：endpoint 格式通常为 http://your-server/polarion/rest/v1 或 http://your-server/api
# 具体路径请向 Polarion 管理员确认
client = polarion_api.PolarionClient(
    polarion_api_endpoint="http://your-polarion-server/polarion/rest/v1",
    polarion_access_token="YOUR_PAT_TOKEN",  # 在 Polarion → User Profile → Personal Access Tokens 获取
)

# 获取项目客户端，并验证项目存在
project_client = client.generate_project_client("YOUR_PROJECT_ID")
if not project_client.exists():
    raise ValueError("项目不存在，请检查 Project ID")

# 查询所有需求工作项（get_all 自动处理分页）
work_items = project_client.work_items.get_all(
    query="type:requirement"
)

# 统计各状态需求数量
status_count = Counter(
    wi.status.id if wi.status else "unknown"
    for wi in work_items
)
print(status_count)
# 输出示例：Counter({'approved': 45, 'verified': 30, 'draft': 12})
```

### 5.3 生成需求完成度报告

```python
import pandas as pd

records = []
for wi in work_items:
    # 注意：assignee 和 linked_work_items 的具体属性结构以实际 WorkItem 对象为准
    # 使用前建议先执行 print(vars(wi)) 确认字段名和类型
    records.append({
        "ID": wi.id,
        "Title": wi.title,
        "Status": wi.status.id if wi.status else "N/A",
        "Assignee": str(wi.assignee) if wi.assignee else "未分配",
        "Links 数量": len(wi.linked_work_items) if wi.linked_work_items else 0,
    })

df = pd.DataFrame(records)
df.to_excel("requirements_status.xlsx", index=False)
print(f"共 {len(df)} 条需求，已导出到 requirements_status.xlsx")
```

### 5.4 创建与更新需求状态

> **注意**：高级客户端的 `create` / `update` 方法接受 `WorkItem` 对象，
> 具体字段名称以所连接的 Polarion 版本 OpenAPI 规范为准。
> 如需精确控制，建议使用低级 OpenAPI 客户端，详见 `references/polarion-api.md`。

```python
# ⚠ 以下为概念示意，WorkItem 各字段名以实际库版本为准
# 使用前执行：help(polarion_api.WorkItem) 查看所有可用字段
new_wi = polarion_api.WorkItem(
    title="系统应支持多语言界面",
    # type/status 字段的传入方式以版本文档为准，可能是字符串 ID 或嵌套对象
)
# 执行前先用 help(project_client.work_items.create) 确认参数签名和返回值
project_client.work_items.create(new_wi)
```

---

## 六、常见操作场景指引

| 场景 | 操作路径 |
|------|---------|
| 查看所有需求的当前状态 | Work Items → Filter by Type=requirement → Table 视图 |
| 找出未追溯的需求（Coverage Gap）| Reports → Traceability Report，配置过滤条件显示无链接工作项（选项名以实际版本为准） |
| 批量导出需求列表给外部评审 | LiveDoc → Export to Word / Export to Excel |
| 从 OEM 导入 ReqIF 需求包 | Documents → Import → ReqIF |
| 追踪某条需求的完整变更历史 | 打开工作项 → History 选项卡 |
| 设置需求评审通知 | 工作项 → Watch（关注），或配置 Workflow Notifications |
| 生成追溯矩阵报告 | Project → Reports → Traceability Report，选择源类型和目标类型 |

---

## 七、注意事项

1. **Work Item Type 名称因项目而异**：先在 Administration → Work Item Types 确认项目中实际使用的类型名称（如可能是 `sysReq` 而非 `requirement`）。
2. **PAT Token 权限**：API 访问需要在 Polarion 用户设置中生成 Personal Access Token，并确保该用户对目标项目有读写权限。
3. **LiveDoc 编辑锁**：多人同时编辑同一 LiveDoc 可能触发锁定，请注意协调。
4. **ReqIF 映射规则**：首次导入/导出 ReqIF 前需手动配置字段映射，之后才能自动化。
5. **版本控制**：Polarion 内置版本历史，每次修改自动留存，无需额外版本管理。

---

## 参考资源

- 详细 API 用法：读取 `references/polarion-api.md`
- Polarion 官方文档：https://docs.sw.siemens.com/en-US/doc/230235217
- `polarion-rest-api-client` 库文档：https://polarion-rest-api-client.readthedocs.io/en/latest/
- `polarion-rest-api-client` GitHub：https://github.com/DSD-DBS/polarion-rest-api-client
