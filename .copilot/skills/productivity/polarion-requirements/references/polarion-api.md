# Polarion REST API 详细参考

> **重要说明**：本文档基于 `polarion-rest-api-client` v1.4.x（高级客户端）和官方 README 编写。
> 高级客户端功能尚不完整（README 标注 "still incomplete"），部分操作需使用低级 OpenAPI 客户端。
> 代码示例中已标注确认程度，使用前建议对照官方文档：
> https://polarion-rest-api-client.readthedocs.io/en/latest/

---

## 安装与认证

### 安装

```bash
# 推荐：使用国内镜像源
pip install polarion-rest-api-client -i https://pypi.tuna.tsinghua.edu.cn/simple
```

### API Endpoint 地址确认

Polarion REST API 的 endpoint 路径因服务器部署配置而异，使用前向管理员确认：

| 常见格式 | 说明 |
|---------|------|
| `http://server/polarion/rest/v1` | 标准部署（含 /polarion 前缀） |
| `http://server/api` | 部分云/容器部署 |

### 认证方式

**方式一：Personal Access Token（推荐）**

1. 登录 Polarion → 右上角头像 → **My Profile**
2. 进入 **Personal Access Tokens** → **Generate New Token**
3. 复制 Token（只显示一次，请妥善保存）

```python
import polarion_rest_api_client as polarion_api

client = polarion_api.PolarionClient(
    polarion_api_endpoint="http://your-server/polarion/rest/v1",
    polarion_access_token="YOUR_PAT_TOKEN",
)
```

**方式二：用户名/密码**（部分版本支持，优先使用 PAT）

> 用户名/密码的具体参数名需以所安装版本为准，建议通过
> `help(polarion_api.PolarionClient)` 查看构造函数签名，
> 或直接查阅：https://polarion-rest-api-client.readthedocs.io/en/latest/
> **优先使用 PAT，避免在代码中明文存储密码。**

---

## 项目操作（已验证）

```python
# 获取项目客户端（已验证）
project_client = client.generate_project_client("PROJECT_ID")

# 验证项目是否存在（已验证）
if not project_client.exists():
    raise ValueError("项目不存在，请检查 Project ID")
```

---

## Work Item 查询（已验证）

### get_all —— 自动分页获取全部工作项

```python
# 获取所有工作项，库自动处理分页（已验证）
work_items = project_client.work_items.get_all()

# 带 Lucene 查询过滤
work_items = project_client.work_items.get_all(
    query="type:requirement AND status:approved"
)
```

### 自定义工作项类（含自定义字段）

```python
import dataclasses

@dataclasses.dataclass
class MyWorkItem(polarion_api.WorkItem):
    # 映射 Polarion 中的自定义字段（字段 ID 以项目配置为准）
    custom_priority: str | None = None

work_items = project_client.work_items.get_all(
    work_item_cls=MyWorkItem
)
# 现在可以直接访问：wi.custom_priority
```

---

## 需求状态追踪报告

### 生成完整状态统计

```python
import pandas as pd
from collections import Counter

def generate_requirements_report(project_client, query="type:requirement",
                                  output_file="requirements_report.xlsx"):
    """生成需求完成度报告（基于 get_all 已验证接口）"""

    work_items = project_client.work_items.get_all(query=query)

    records = []
    for wi in work_items:
        # 注意：WorkItem 各属性名以实际版本为准
        # 首次使用前执行 print(vars(wi)) 确认字段名和数据类型
        link_count = len(wi.linked_work_items) if wi.linked_work_items else 0

        records.append({
            "需求 ID": wi.id,
            "标题": wi.title,
            "状态": wi.status.id if wi.status else "未知",
            # assignee 可能为单个对象或列表，str() 兜底保证不报错
            "负责人": str(wi.assignee) if wi.assignee else "未分配",
            "链接数量": link_count,
        })

    df = pd.DataFrame(records)

    # 状态分布汇总（使用兼容 pandas 1.x / 2.x 的写法）
    status_summary = (
        df["状态"]
        .value_counts()
        .rename_axis("状态")
        .reset_index(name="数量")
    )

    with pd.ExcelWriter(output_file, engine="openpyxl") as writer:
        df.to_excel(writer, sheet_name="需求明细", index=False)
        status_summary.to_excel(writer, sheet_name="状态汇总", index=False)

    print(f"报告已生成：{output_file}，共 {len(df)} 条需求")
    return df


# 使用示例
df = generate_requirements_report(project_client)
```

---

## Work Item 创建与更新（需参考版本文档）

> **注意**：以下代码展示高级客户端的推荐模式。
> 由于高级客户端仍在开发中，`create` / `update` 的精确参数
> 需以所安装版本的 API 文档为准（`help(project_client.work_items.create)`）。

### 创建新需求

```python
# ⚠ 以下为概念示意，WorkItem 字段结构以实际库版本为准
# 使用前先执行：help(polarion_api.WorkItem) 查看所有可用字段及类型
new_wi = polarion_api.WorkItem(
    title="系统应支持多语言界面",
    # type / status 的传值方式（字符串 ID 或嵌套对象）以版本文档为准
)
# 使用前先执行：help(project_client.work_items.create) 确认参数签名和返回值
project_client.work_items.create(new_wi)
```

### 更新需求状态

```python
# ⚠ work_items.get(id) 方法是否存在以库版本为准
# 如不支持单条 get，可用 get_all 加 id 过滤替代
# 注意：Polarion Lucene 中 id 字段存储完整 ID（含项目前缀，如 PROJ-123）
# 若查询无结果，请确认 ID 格式是否与 Polarion 中一致
results = project_client.work_items.get_all(query="id:PROJ-123")
if not results:
    raise ValueError("未找到工作项 PROJ-123")
wi = results[0]

wi.status = polarion_api.StatusItem(id="approved")
# 使用前先执行：help(project_client.work_items.update) 确认参数签名
project_client.work_items.update(wi)
```

### 批量更新（谨慎使用）

```python
import time

items_to_approve = project_client.work_items.get_all(
    query="type:requirement AND status:in_review"
)

failed = []
for wi in items_to_approve:
    try:
        wi.status = polarion_api.StatusItem(id="approved")
        project_client.work_items.update(wi)
        print(f"✓ {wi.id} 状态已更新为 approved")
    except Exception as e:
        # 单条失败不中断整批，收集后统一报告
        failed.append({"id": wi.id, "error": str(e)})
        print(f"✗ {wi.id} 更新失败：{e}")
    time.sleep(0.5)  # 避免请求过快触发服务器限流

if failed:
    print(f"\n以下 {len(failed)} 条更新失败，请手动处理：")
    for f in failed:
        print(f"  {f['id']}: {f['error']}")
```

---

## 追溯链接操作

> **注意**：`WorkItemLink` 是已确认的数据类。链接的增删操作建议通过
> 低级 OpenAPI 客户端实现，或查阅当前版本 `project_client.work_items` 的方法列表：
> `[m for m in dir(project_client.work_items) if not m.startswith('_')]`

### WorkItemLink 数据类（类名已确认，字段名需运行时验证）

```python
# WorkItemLink 类名已在官方文档索引中确认
# 以下字段名（primary_work_item_id 等）为推断，使用前执行以下命令确认：
# help(polarion_api.WorkItemLink)
link = polarion_api.WorkItemLink(
    primary_work_item_id="PROJ-100",      # 持有链接的工作项（如子需求）
    secondary_work_item_id="PROJ-001",    # 目标工作项（如父需求）
    role="derives_from",                   # Link Role ID（以项目配置为准）
    secondary_work_item_project="PROJ",
    suspect=False,
)
```

### 查询所有未追溯的需求

```python
all_reqs = project_client.work_items.get_all(
    query="type:requirement AND status:approved"
)

untraced = []
for req in all_reqs:
    links = req.linked_work_items or []
    # 注意：lnk.role 可能是字符串或对象（取决于库版本）
    # 若 role 为对象，应改为：lnk.role.id == "verifies"
    # 确认类型（仅在 links 非空时执行）：
    # if links: print(type(links[0].role))
    has_verify = any(
        (lnk.role == "verifies" or getattr(lnk.role, "id", None) == "verifies")
        for lnk in links
    )
    if not has_verify:
        untraced.append({"ID": req.id, "Title": req.title})

print(f"发现 {len(untraced)} 条已批准但缺少验证链接的需求：")
for r in untraced:
    print(f"  {r['ID']}: {r['Title']}")
```

---

## 异常处理（已验证类名）

```python
from polarion_rest_api_client import (
    PolarionApiException,          # 基础异常类
    PolarionApiUnexpectedException,
    PolarionApiInternalException,
    PolarionWorkItemException,
)

try:
    # ⚠ work_items.get() 是否存在以库版本为准，以下用 get_all 兜底
    results = project_client.work_items.get_all(query="id:PROJ-999")
    if not results:
        # 使用标准 ValueError 而非 PolarionWorkItemException（后者构造签名未确认）
        raise ValueError("工作项 PROJ-999 不存在，请核对 ID 和项目权限")
    wi = results[0]
except ValueError as e:
    print(f"工作项查找失败：{e}")
except PolarionWorkItemException as e:
    print(f"工作项操作错误：{e}")
except PolarionApiInternalException as e:
    print(f"服务器内部错误（可能是权限不足或工作项不存在）：{e}")
except PolarionApiUnexpectedException as e:
    print(f"意外错误：{e}")
except PolarionApiException as e:
    print(f"API 通用错误：{e}")
except Exception as e:
    print(f"连接错误（请检查 endpoint 地址和网络）：{e}")
```

---

## 环境变量配置（推荐）

避免在代码中硬编码凭据：

```bash
# .env 文件（加入 .gitignore，不要提交到代码仓库）
POLARION_URL=http://your-server/polarion/rest/v1
POLARION_PROJECT=YOUR_PROJECT_ID
POLARION_TOKEN=YOUR_PAT_TOKEN
```

```python
import os
from dotenv import load_dotenv  # pip install python-dotenv

load_dotenv()

# 环境变量读取后做非空校验，避免 None 值被静默传入导致难以排查的错误
_url = os.getenv("POLARION_URL")
_token = os.getenv("POLARION_TOKEN")
_project = os.getenv("POLARION_PROJECT")

missing = [k for k, v in {"POLARION_URL": _url, "POLARION_TOKEN": _token,
                            "POLARION_PROJECT": _project}.items() if not v]
if missing:
    raise EnvironmentError(f"缺少必要环境变量：{missing}，请检查 .env 文件")

client = polarion_api.PolarionClient(
    polarion_api_endpoint=_url,
    polarion_access_token=_token,
)
project_client = client.generate_project_client(_project)
```

---

## 低级 OpenAPI 客户端（精确控制）

当高级客户端不支持所需操作时，使用自动生成的低级客户端：

```python
from polarion_rest_api_client.open_api_client import AuthenticatedClient

low_client = AuthenticatedClient(
    base_url="http://your-server/polarion/rest/v1",
    token="YOUR_PAT_TOKEN",
)

# 通过低级客户端调用具体 API 端点
# 具体模块和函数名以 polarion_rest_api_client.open_api_client.api 下的模块为准
```

---

## 快速调试工具

```python
# 查看当前版本 work_items 支持的所有方法
print([m for m in dir(project_client.work_items) if not m.startswith('_')])

# 查看 WorkItem 对象的所有属性（安全写法，防止结果为空时 IndexError）
all_wi = project_client.work_items.get_all(query="type:requirement")
if all_wi:
    print(vars(all_wi[0]))
else:
    print("未找到任何需求工作项，请检查 query 条件或 Project ID")
```
