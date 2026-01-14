# 数据模型增强与报价管理功能设计

## 一、设计目标

为报价侠系统的报价管理模块提供完整的数据模型增强、商品筛选和报价单 CRUD 能力，使系统能够支持完整的报价单生命周期管理，包括报价单创建、商品选配、价格计算、折扣管理和版本控制等核心功能。

## 二、业务背景

当前系统已具备基础的数据模型和 API 框架，但缺少以下关键能力：
- 报价单缺少必要的业务字段（编号、创建人、客户联系信息、折扣信息等）
- 报价明细表缺少价格计算相关的细粒度字段
- 商品筛选功能尚未实现，无法按地域、模态、能力等维度筛选模型
- 报价单 CRUD 功能仅有框架，缺乏完整的业务逻辑

本次设计旨在填补这些空白，构建完整的报价管理能力。

## 三、数据模型设计

### 3.1 QuoteSheet（报价单主表）字段增强

#### 3.1.1 新增字段定义

| 字段名 | 数据类型 | 约束 | 默认值 | 说明 |
|--------|---------|------|--------|------|
| quote_no | String(50) | unique, not null | 系统生成 | 报价单编号，格式：QT{YYYYMMDD}{4位序号} |
| created_by | String(100) | not null | - | 创建人ID或名称 |
| sales_name | String(100) | nullable | - | 销售负责人姓名 |
| customer_contact | String(100) | nullable | - | 客户联系人 |
| customer_email | String(255) | nullable | - | 客户邮箱 |
| remarks | Text | nullable | - | 备注信息 |
| terms | Text | nullable | - | 条款说明，支持默认模板 |
| global_discount_rate | Numeric(5,4) | not null | 1.0000 | 全局折扣率（1.0=无折扣，0.85=85折） |
| global_discount_remark | String(255) | nullable | - | 折扣备注说明 |

#### 3.1.2 字段设计说明

**报价单编号（quote_no）生成规则**：
- 格式：QT + 年月日(8位) + 当日序号(4位)
- 示例：QT202601080001、QT202601080002
- 生成时机：报价单创建时自动生成
- 唯一性保障：通过数据库唯一约束和序号生成机制保证

**全局折扣率（global_discount_rate）计算逻辑**：
- 取值范围：0.0001 ~ 1.0000
- 应用方式：在单项折扣基础上再次应用全局折扣
- 计算公式：`最终价格 = 原价 × 单项折扣率 × 全局折扣率`

**字段更新时金额重算规则**：
- total_amount 字段类型需从 String(20) 调整为 Numeric(20,6) 以支持精确计算
- 增加 total_original_amount 字段存储折扣前总金额

#### 3.1.3 索引优化

需要新增的索引：
- `ix_quote_no` 在 quote_no 字段上创建唯一索引
- `ix_quote_created_by` 在 created_by 字段上创建普通索引
- `ix_quote_created_at` 在 created_at 字段上创建普通索引（支持时间范围查询）

### 3.2 QuoteItem（报价明细表）字段增强

#### 3.2.1 新增字段定义

| 字段名 | 数据类型 | 约束 | 默认值 | 说明 |
|--------|---------|------|--------|------|
| region | String(50) | not null | cn-beijing | 地域代码 |
| region_name | String(100) | nullable | - | 地域显示名称 |
| modality | String(50) | not null | - | 模态类型（枚举） |
| capability | String(50) | nullable | - | 能力类型（枚举） |
| model_type | String(50) | nullable | - | 模型类型（枚举） |
| context_spec | String(50) | nullable | - | context规格（如32K、128K） |
| input_tokens | BigInteger | nullable | - | 预估输入tokens数量 |
| output_tokens | BigInteger | nullable | - | 预估输出tokens数量 |
| inference_mode | String(50) | nullable | - | 推理方式（枚举） |
| original_price | Numeric(20,6) | not null | - | 原价（元） |
| discount_rate | Numeric(5,4) | not null | 1.0000 | 单项折扣率 |
| final_price | Numeric(20,6) | not null | - | 折后价（元） |
| billing_unit | String(50) | not null | - | 计费单位 |
| sort_order | Integer | not null | 0 | 排序顺序 |

#### 3.2.2 枚举值定义

**模态类型（modality）枚举值**：
- text: 文本
- image: 图片
- audio: 音频
- video: 视频
- multimodal: 全模态

**能力类型（capability）枚举值**：
- understanding: 理解
- generation: 生成
- both: 理解并生成

**模型类型（model_type）枚举值**：
- llm: 大语言模型
- text_embedding: 文本向量
- multimodal_embedding: 多模态向量
- rerank: 重排序

**推理方式（inference_mode）枚举值**：
- thinking: 思考模式
- non_thinking: 非思考模式

#### 3.2.3 价格字段计算逻辑

**价格计算流程**：
1. 从 product_prices 表根据 product_code 和 region 获取基础价格
2. 根据 input_tokens 和 output_tokens 计算基础费用
3. 如果 inference_mode 为 thinking，使用思考模式价格
4. 应用单项 discount_rate 得到折后价
5. 最终再应用报价单的 global_discount_rate

**计算公式**：
```
基础费用 = (input_price × input_tokens + output_price × output_tokens) / 1000
原价 = 基础费用 × quantity × duration_months
折后价 = 原价 × discount_rate × global_discount_rate
```

#### 3.2.4 字段映射规则

从 Product 表的 category 字段映射到 QuoteItem 的 modality 字段：
- "AI-大模型-文本生成" → "text"
- "AI-大模型-视觉理解" → "image"
- "AI-大模型-语音" → "audio"
- "AI-大模型-多模态" → "multimodal"
- "AI-大模型-向量" → "text_embedding"
- "AI-大模型-重排序" → "rerank"

### 3.3 数据模型调整说明

#### 3.3.1 原有字段保留策略
- spec_config 字段保留，用于存储额外的规格配置信息
- usage_estimation 字段保留，用于存储复杂的用量估算场景
- discount_info 字段保留，可用于存储更详细的折扣信息（如折扣依据、审批记录等）

#### 3.3.2 字段类型调整
需要调整的原有字段：
- unit_price: String(20) → Numeric(20,6)
- subtotal: String(20) → Numeric(20,6)
- total_amount (QuoteSheet): String(20) → Numeric(20,6)

## 四、Schema 层设计

### 4.1 报价单请求 Schema

#### 4.1.1 QuoteCreateRequest（创建报价单）

| 字段名 | 类型 | 必填 | 校验规则 | 说明 |
|--------|------|------|---------|------|
| customer_name | str | 是 | min_length=1, max_length=255 | 客户名称 |
| project_name | str | 否 | max_length=255 | 项目名称 |
| created_by | str | 是 | min_length=1 | 创建人 |
| sales_name | str | 否 | max_length=100 | 销售负责人 |
| customer_contact | str | 否 | max_length=100 | 客户联系人 |
| customer_email | EmailStr | 否 | 邮箱格式校验 | 客户邮箱 |
| remarks | str | 否 | - | 备注信息 |
| valid_days | int | 否 | default=30, ge=1 | 有效期天数 |

#### 4.1.2 QuoteUpdateRequest（更新报价单）

所有字段均为可选：
- customer_name: str
- project_name: str
- sales_name: str
- customer_contact: str
- customer_email: EmailStr
- remarks: str
- terms: str
- status: str（枚举值：draft/confirmed/expired/cancelled）

**状态流转规则**：
- draft → confirmed: 确认报价
- draft → cancelled: 取消报价
- confirmed → expired: 系统自动过期（valid_until 超期）
- 其他状态转换：不允许

#### 4.1.3 QuoteItemCreateRequest（添加商品）

| 字段名 | 类型 | 必填 | 校验规则 | 默认值 | 说明 |
|--------|------|------|---------|--------|------|
| product_code | str | 是 | - | - | 产品代码 |
| region | str | 是 | - | cn-beijing | 地域代码 |
| quantity | int | 是 | ge=1 | 1 | 数量 |
| input_tokens | int | 否 | ge=0 | - | 预估输入tokens |
| output_tokens | int | 否 | ge=0 | - | 预估输出tokens |
| inference_mode | str | 否 | 枚举：thinking/non_thinking | - | 推理模式 |
| duration_months | int | 否 | ge=1 | 1 | 时长（月） |

#### 4.1.4 QuoteItemBatchCreateRequest（批量添加）

| 字段名 | 类型 | 必填 | 校验规则 | 说明 |
|--------|------|------|---------|------|
| items | List[QuoteItemCreateRequest] | 是 | min_items=1, max_items=100 | 商品列表 |

#### 4.1.5 QuoteDiscountRequest（设置折扣）

| 字段名 | 类型 | 必填 | 校验规则 | 说明 |
|--------|------|------|---------|------|
| discount_rate | Decimal | 是 | ge=0.01, le=1.0 | 折扣率 |
| remark | str | 否 | max_length=255 | 折扣备注 |

### 4.2 报价单响应 Schema

#### 4.2.1 QuoteItemResponse（报价项响应）

包含字段：
- item_id: UUID
- product_code: str
- product_name: str
- region: str
- region_name: str
- modality: str
- capability: str
- context_spec: str
- input_tokens: int
- output_tokens: int
- inference_mode: str
- quantity: int
- duration_months: int
- original_price: Decimal
- discount_rate: Decimal
- final_price: Decimal
- billing_unit: str
- sort_order: int

#### 4.2.2 QuoteDetailResponse（报价单详情响应）

包含字段：
- quote_id: UUID
- quote_no: str
- customer_name: str
- project_name: str
- created_by: str
- sales_name: str
- customer_contact: str
- customer_email: str
- status: str
- remarks: str
- terms: str
- global_discount_rate: Decimal
- global_discount_remark: str
- total_original_amount: Decimal
- total_final_amount: Decimal
- currency: str
- valid_until: datetime
- created_at: datetime
- updated_at: datetime
- items: List[QuoteItemResponse]
- version: int

#### 4.2.3 QuoteListResponse（报价单列表项响应）

包含字段：
- quote_id: UUID
- quote_no: str
- customer_name: str
- project_name: str
- status: str
- total_final_amount: Decimal
- items_count: int
- created_by: str
- created_at: datetime
- updated_at: datetime

#### 4.2.4 PaginatedQuoteListResponse（分页列表响应）

包含字段：
- total: int（总记录数）
- page: int（当前页码）
- page_size: int（每页大小）
- data: List[QuoteListResponse]

## 五、商品筛选 API 设计

### 5.1 获取筛选条件选项

**端点**：`GET /api/v1/products/filters`

**功能说明**：返回所有可用的筛选维度及其选项，用于前端动态渲染筛选控件。

**响应数据结构**：
```
{
  "regions": [
    {"code": "cn-beijing", "name": "中国内地（北京）"},
    {"code": "cn-shanghai", "name": "中国内地（上海）"},
    {"code": "ap-southeast-1", "name": "国际（新加坡）"}
  ],
  "modalities": [
    {"code": "text", "name": "文本"},
    {"code": "image", "name": "图片"},
    {"code": "audio", "name": "音频"},
    {"code": "video", "name": "视频"},
    {"code": "multimodal", "name": "全模态"}
  ],
  "capabilities": [
    {"code": "understanding", "name": "理解"},
    {"code": "generation", "name": "生成"},
    {"code": "both", "name": "理解并生成"}
  ],
  "model_types": [
    {"code": "llm", "name": "大语言模型"},
    {"code": "text_embedding", "name": "文本向量"},
    {"code": "multimodal_embedding", "name": "多模态向量"},
    {"code": "rerank", "name": "重排序"}
  ]
}
```

**业务逻辑**：
1. 从 products 表和 product_prices 表聚合查询所有已存在的筛选维度值
2. 使用静态映射表将数据库值转换为前端友好的显示名称
3. 对结果进行去重和排序
4. 考虑使用 Redis 缓存结果（过期时间：1小时）

### 5.2 获取大模型商品列表

**端点**：`GET /api/v1/products/models`

**查询参数**：

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| region | str | 否 | 地域筛选 |
| modality | str | 否 | 模态筛选（多选逗号分隔，如：text,image） |
| capability | str | 否 | 能力筛选 |
| model_type | str | 否 | 类型筛选 |
| vendor | str | 否 | 厂商筛选 |
| keyword | str | 否 | 关键词搜索（匹配产品名称或代码） |
| page | int | 否 | 页码，默认1 |
| page_size | int | 否 | 每页数量，默认20，最大100 |

**响应数据结构**：
```
{
  "total": 150,
  "page": 1,
  "page_size": 20,
  "data": [
    {
      "model_id": "qwen-max",
      "model_name": "通义千问Max",
      "vendor": "aliyun",
      "category": "AI-大模型-文本生成",
      "modality": "text",
      "capability": "both",
      "context_specs": ["32K", "128K"],
      "supports_thinking": true,
      "pricing": {
        "region": "cn-beijing",
        "input_price": 0.04,
        "output_price": 0.12,
        "unit": "千Token"
      },
      "status": "active"
    }
  ]
}
```

**业务逻辑**：
1. 联合查询 products 和 product_prices 表
2. 根据 category 字段映射 modality 和 capability
3. 支持多条件 AND 组合筛选
4. modality 参数支持多选（逗号分隔，使用 IN 查询）
5. keyword 参数对 product_name 和 product_code 字段进行模糊匹配（ILIKE）
6. 按 vendor + model_name 排序
7. 分页处理

**性能优化建议**：
- 在 products 表的 (category, vendor) 字段上建立复合索引
- 对于常用筛选条件组合，考虑使用 Redis 缓存查询结果
- 使用数据库的 EXPLAIN 分析查询计划，优化慢查询

### 5.3 批量名称搜索

**端点**：`POST /api/v1/products/search`

**请求体**：
```
{
  "names": ["通义千问", "Qwen-Max", "文心一言"],
  "region": "cn-beijing"
}
```

**请求参数校验**：
- names: 必填，最多50个
- region: 可选，默认 cn-beijing

**响应数据结构**：
```
{
  "found": [
    {
      "model_id": "qwen-max",
      "model_name": "通义千问Max",
      "match_type": "exact",
      "search_term": "Qwen-Max"
    }
  ],
  "not_found": ["文心一言"]
}
```

**匹配逻辑**：
1. 精确匹配（优先级1）：product_code 或 product_name 完全相等（忽略大小写）
2. 模糊匹配（优先级2）：product_name 包含搜索词（忽略大小写）
3. 对每个搜索词只返回优先级最高的一个匹配结果
4. 未匹配到的搜索词放入 not_found 列表

### 5.4 获取模型详情

**端点**：`GET /api/v1/products/models/{model_id}`

**路径参数**：
- model_id: 模型ID（即 product_code）

**查询参数**：
- region: 地域（可选，默认 cn-beijing）

**响应数据结构**：
```
{
  "model_id": "qwen-max",
  "model_name": "通义千问Max",
  "vendor": "aliyun",
  "description": "通义千问超大规模语言模型...",
  "category": "AI-大模型-文本生成",
  "specs": {
    "max_context_length": 131072,
    "max_input_tokens": 100000,
    "max_output_tokens": 8192,
    "supports_thinking": true
  },
  "pricing": [
    {
      "region": "cn-beijing",
      "region_name": "中国内地（北京）",
      "input_price": 0.04,
      "output_price": 0.12,
      "thinking_input_price": 0.06,
      "thinking_output_price": 0.18,
      "batch_discount": 0.5,
      "unit": "千Token"
    }
  ],
  "status": "active"
}
```

**业务逻辑**：
1. 从 products 表查询基础信息
2. 从 product_specs 表查询规格信息
3. 从 product_prices 表查询定价信息（支持返回多个地域的价格）
4. 如果指定了 region 参数，只返回该地域的价格
5. 如果模型不存在，返回 404 错误

### 5.5 ProductFilterService 服务层设计

**职责**：封装商品筛选的业务逻辑。

**核心方法**：

#### 5.5.1 get_filter_options
- **功能**：获取所有筛选维度的可选项
- **返回**：FilterOptions 对象
- **实现要点**：
  - 聚合查询数据库获取所有可用选项
  - 应用静态映射转换为友好名称
  - 结果按字母顺序排序

#### 5.5.2 filter_models
- **功能**：根据筛选条件查询模型列表
- **参数**：ModelFilterParams（包含所有筛选参数）
- **返回**：PaginatedResult
- **实现要点**：
  - 构建动态 SQL 查询（使用 SQLAlchemy 的条件构建器）
  - 支持多条件 AND 组合
  - 处理分页逻辑

#### 5.5.3 search_by_names
- **功能**：批量名称搜索
- **参数**：names（名称列表）、region（地域）
- **返回**：SearchResult（found 和 not_found 列表）
- **实现要点**：
  - 对每个名称执行精确匹配和模糊匹配
  - 精确匹配优先
  - 返回匹配统计

#### 5.5.4 get_model_detail
- **功能**：获取模型详情
- **参数**：model_id（产品代码）、region（地域）
- **返回**：ModelDetail 对象
- **实现要点**：
  - 联合查询三张表（products、product_specs、product_prices）
  - 组装完整的模型信息

#### 5.5.5 map_category_to_modality
- **功能**：将数据库 category 映射为前端 modality
- **参数**：category（产品类别）
- **返回**：modality 代码
- **映射规则**：
  - "AI-大模型-文本生成" → "text"
  - "AI-大模型-视觉理解" → "image"
  - "AI-大模型-语音" → "audio"
  - "AI-大模型-多模态" → "multimodal"
  - "AI-大模型-向量" → "text_embedding"
  - "AI-大模型-重排序" → "rerank"
  - 其他 → "unknown"

## 六、报价单 CRUD API 设计

### 6.1 创建报价单

**端点**：`POST /api/v1/quotes`

**请求体**：QuoteCreateRequest

**业务流程**：
1. 校验请求数据（customer_name 不为空等）
2. 调用 QuoteService.generate_quote_no() 生成唯一报价单编号
3. 计算有效期：valid_until = created_at + valid_days 天
4. 创建报价单记录，状态设为 draft
5. 创建初始版本快照（version=1，change_type="create"）
6. 返回报价单详情（此时 items 为空数组）

**响应**：QuoteDetailResponse

**错误处理**：
- 400：请求数据校验失败
- 500：报价单编号生成失败或数据库错误

### 6.2 获取报价单列表

**端点**：`GET /api/v1/quotes`

**查询参数**：

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| status | str | 否 | 状态筛选（draft/confirmed/expired/cancelled） |
| customer_name | str | 否 | 客户名称模糊搜索 |
| created_by | str | 否 | 创建人精确筛选 |
| start_date | date | 否 | 创建时间起（格式：YYYY-MM-DD） |
| end_date | date | 否 | 创建时间止（格式：YYYY-MM-DD） |
| page | int | 否 | 页码，默认1 |
| page_size | int | 否 | 每页数量，默认20，最大100 |

**业务逻辑**：
1. 构建动态查询条件（多条件 AND 组合）
2. customer_name 使用 ILIKE 模糊匹配
3. start_date 和 end_date 构成时间范围查询
4. 按 created_at DESC 排序（最新的在前）
5. 子查询统计每个报价单的 items_count
6. 分页处理

**响应**：PaginatedQuoteListResponse

### 6.3 获取报价单详情

**端点**：`GET /api/v1/quotes/{quote_id}`

**路径参数**：
- quote_id: UUID 格式的报价单ID

**业务逻辑**：
1. 查询报价单主表记录
2. 查询关联的所有报价项（按 sort_order ASC 排序）
3. 计算 total_original_amount（所有 original_price 之和）
4. 计算 total_final_amount（所有 final_price 之和）
5. 查询当前最新版本号
6. 组装完整响应

**响应**：QuoteDetailResponse

**错误处理**：
- 404：报价单不存在

### 6.4 更新报价单

**端点**：`PUT /api/v1/quotes/{quote_id}`

**请求体**：QuoteUpdateRequest（所有字段可选）

**业务逻辑**：
1. 校验报价单存在
2. 校验状态：只有 draft 状态的报价单可以修改基本信息
3. 更新指定的字段（只更新请求中包含的字段）
4. 如果更新了 status，需校验状态流转合法性
5. 更新 updated_at 时间戳
6. 创建版本快照（change_type="update"）
7. 返回更新后的报价单详情

**状态流转校验**：
- draft → confirmed: 允许
- draft → cancelled: 允许
- 其他状态 → 任何状态: 不允许（返回 400 错误）

**响应**：QuoteDetailResponse

**错误处理**：
- 400：状态流转不合法或数据校验失败
- 403：报价单状态不允许修改
- 404：报价单不存在

### 6.5 删除报价单

**端点**：`DELETE /api/v1/quotes/{quote_id}`

**业务逻辑**：
1. 校验报价单存在
2. 采用软删除：将 status 设置为 "deleted"
3. 或采用硬删除：物理删除记录（级联删除关联的 items、discounts、versions）

**删除策略选择**：
- 推荐使用软删除，保留历史记录便于审计
- 硬删除适用于测试数据清理场景

**响应**：
```
{
  "success": true,
  "message": "删除成功"
}
```

**错误处理**：
- 404：报价单不存在
- 500：数据库删除失败

### 6.6 添加商品到报价单

**端点**：`POST /api/v1/quotes/{quote_id}/items`

**请求体**：QuoteItemCreateRequest

**业务流程**：
1. 校验报价单存在且状态为 draft
2. 根据 product_code 从 products 表查询商品信息
3. 根据 region 从 product_prices 表查询价格信息
4. 调用 PricingEngine 计算价格：
   - 根据 input_tokens、output_tokens 计算基础费用
   - 如果 inference_mode 为 thinking，使用思考模式价格
   - 计算 original_price
   - 应用报价单的 global_discount_rate 计算 final_price
5. 填充 QuoteItem 的其他字段（modality、capability 等）
6. 创建报价项记录
7. 调用 QuoteService.recalculate_total() 重新计算报价单总金额
8. 创建版本快照（change_type="add_item"）
9. 返回新增的报价项

**响应**：QuoteItemResponse

**错误处理**：
- 400：商品不存在或价格信息缺失
- 403：报价单状态不允许添加商品
- 404：报价单不存在

### 6.7 批量添加商品

**端点**：`POST /api/v1/quotes/{quote_id}/items/batch`

**请求体**：QuoteItemBatchCreateRequest

**业务逻辑**：
1. 校验报价单存在且状态为 draft
2. 使用数据库事务批量处理
3. 遍历每个商品请求：
   - 捕获单个商品处理异常
   - 记录失败的商品和错误原因
   - 不影响其他商品处理
4. 批量插入成功的报价项
5. 重新计算报价单总金额
6. 创建版本快照
7. 返回批量处理结果

**响应**：
```
{
  "success_count": 8,
  "failed_items": [
    {
      "product_code": "unknown-model",
      "error": "商品不存在"
    }
  ],
  "quote": QuoteDetailResponse
}
```

**错误处理**：
- 部分失败：返回成功和失败统计
- 全部失败：返回 400 错误

### 6.8 更新报价项

**端点**：`PUT /api/v1/quotes/{quote_id}/items/{item_id}`

**请求体**（所有字段可选）：
```
{
  "quantity": 10,
  "input_tokens": 50000,
  "output_tokens": 20000,
  "inference_mode": "thinking",
  "discount_rate": 0.85
}
```

**业务逻辑**：
1. 校验报价项存在且关联的报价单状态为 draft
2. 更新指定字段
3. 重新调用 PricingEngine 计算价格
4. 更新 original_price 和 final_price
5. 调用 QuoteService.recalculate_total() 重新计算报价单总金额
6. 创建版本快照（change_type="update_item"）
7. 返回更新后的报价项

**响应**：QuoteItemResponse

**错误处理**：
- 403：报价单状态不允许修改
- 404：报价项不存在

### 6.9 删除报价项

**端点**：`DELETE /api/v1/quotes/{quote_id}/items/{item_id}`

**业务逻辑**：
1. 校验报价项存在且关联的报价单状态为 draft
2. 删除报价项记录
3. 调用 QuoteService.recalculate_total() 重新计算报价单总金额
4. 创建版本快照（change_type="delete_item"）

**响应**：
```
{
  "success": true
}
```

**错误处理**：
- 403：报价单状态不允许删除商品
- 404：报价项不存在

### 6.10 设置批量折扣

**端点**：`PUT /api/v1/quotes/{quote_id}/discount`

**请求体**：QuoteDiscountRequest

**业务逻辑**：
1. 校验报价单存在且状态为 draft
2. 更新 global_discount_rate 和 global_discount_remark 字段
3. 遍历所有报价项，重新计算 final_price：
   - final_price = original_price × item.discount_rate × global_discount_rate
4. 批量更新所有报价项的 final_price
5. 调用 QuoteService.recalculate_total() 重新计算报价单总金额
6. 创建版本快照（change_type="apply_discount"）
7. 返回更新后的报价单详情

**响应**：QuoteDetailResponse

**错误处理**：
- 400：折扣率超出范围（0.01~1.0）
- 403：报价单状态不允许修改
- 404：报价单不存在

### 6.11 重新计算价格

**端点**：`POST /api/v1/quotes/{quote_id}/calculate`

**功能说明**：当商品价格表更新后，可调用此接口重新计算报价单价格。

**业务逻辑**：
1. 校验报价单存在
2. 遍历所有报价项
3. 从 product_prices 表重新获取最新价格
4. 重新调用 PricingEngine 计算每个报价项的价格
5. 重新应用折扣规则
6. 批量更新所有报价项的价格字段
7. 重新计算报价单总金额
8. 创建版本快照（change_type="recalculate"）
9. 返回更新后的报价单详情

**响应**：QuoteDetailResponse

**使用场景**：
- 产品价格表更新后批量更新历史报价单
- 修复价格计算错误

### 6.12 获取版本历史

**端点**：`GET /api/v1/quotes/{quote_id}/versions`

**响应数据结构**：
```
[
  {
    "version_id": "uuid",
    "version_number": 3,
    "change_type": "add_item",
    "created_at": "2026-01-08T10:30:00Z",
    "changes_summary": "添加商品：通义千问Max"
  },
  {
    "version_id": "uuid",
    "version_number": 2,
    "change_type": "update",
    "created_at": "2026-01-08T10:15:00Z",
    "changes_summary": "更新客户信息"
  }
]
```

**业务逻辑**：
1. 查询 quote_versions 表
2. 按 version_number DESC 排序
3. 从 snapshot_data 中提取变更摘要

### 6.13 克隆报价单

**端点**：`POST /api/v1/quotes/{quote_id}/clone`

**业务逻辑**：
1. 查询源报价单及其所有报价项
2. 生成新的报价单编号
3. 创建新报价单记录：
   - 复制所有基本信息字段
   - 状态设为 draft
   - 重置创建时间和更新时间
4. 复制所有报价项记录：
   - 生成新的 item_id
   - 关联到新报价单
5. 不复制版本历史记录
6. 创建新报价单的初始版本快照
7. 返回新报价单详情

**响应**：QuoteDetailResponse

**使用场景**：
- 基于历史报价快速创建新报价
- 创建报价模板

## 七、QuoteService 服务层设计

### 7.1 服务职责

QuoteService 封装报价单管理的核心业务逻辑，包括：
- 报价单编号生成
- 报价单 CRUD 操作
- 报价项管理
- 价格计算和折扣应用
- 版本快照管理

### 7.2 核心方法设计

#### 7.2.1 generate_quote_no
**功能**：生成唯一报价单编号

**实现方案**：

方案一：使用 Redis 自增（推荐）
- Key 格式：`quote_no:{YYYYMMDD}`
- 每天零点重置为 0
- 使用 Redis INCR 命令原子性自增
- 格式化为 4 位序号（左补零）
- 优点：高性能、分布式安全
- 缺点：依赖 Redis

方案二：使用数据库序列
- 创建 PostgreSQL 序列：`quote_no_seq_{YYYYMMDD}`
- 每天创建新序列
- 使用 nextval() 获取序号
- 优点：不依赖外部服务
- 缺点：需要维护大量序列对象

**生成流程**：
1. 获取当前日期（YYYYMMDD）
2. 从 Redis 获取并自增序号
3. 格式化为：QT + 日期 + 序号（4位补零）
4. 校验唯一性（查询数据库）
5. 如果冲突，重试最多3次

#### 7.2.2 create_quote
**功能**：创建报价单草稿

**参数**：QuoteCreateRequest

**返回**：QuoteSheet 实例

**实现要点**：
- 生成报价单编号
- 计算有效期
- 设置默认值（status=draft、global_discount_rate=1.0）
- 创建初始版本快照

#### 7.2.3 get_quote_detail
**功能**：获取报价单完整详情

**参数**：quote_id

**返回**：QuoteDetailResponse

**实现要点**：
- 联合查询报价单和报价项
- 计算总金额
- 获取最新版本号
- 组装响应对象

#### 7.2.4 update_quote
**功能**：更新报价单基本信息

**参数**：quote_id、QuoteUpdateRequest

**返回**：QuoteSheet 实例

**实现要点**：
- 校验状态
- 部分更新（只更新提供的字段）
- 创建版本快照

#### 7.2.5 add_item
**功能**：添加单个商品

**参数**：quote_id、QuoteItemCreateRequest

**返回**：QuoteItem 实例

**实现要点**：
- 查询商品和价格信息
- 调用 PricingEngine 计算价格
- 填充报价项字段
- 重新计算总金额
- 创建版本快照

#### 7.2.6 add_items_batch
**功能**：批量添加商品

**参数**：quote_id、List[QuoteItemCreateRequest]

**返回**：BatchResult（包含成功和失败统计）

**实现要点**：
- 使用数据库事务
- 逐个处理，捕获异常
- 批量插入成功的记录
- 返回详细的成功/失败信息

#### 7.2.7 update_item
**功能**：更新报价项

**参数**：quote_id、item_id、更新数据

**返回**：QuoteItem 实例

**实现要点**：
- 校验权限
- 重新计算价格
- 更新总金额
- 创建版本快照

#### 7.2.8 delete_item
**功能**：删除报价项

**参数**：quote_id、item_id

**返回**：bool（成功/失败）

**实现要点**：
- 校验权限
- 删除记录
- 更新总金额
- 创建版本快照

#### 7.2.9 apply_global_discount
**功能**：应用全局折扣

**参数**：quote_id、discount_rate、remark

**返回**：QuoteSheet 实例

**实现要点**：
- 更新报价单折扣字段
- 批量重新计算所有报价项的 final_price
- 更新总金额
- 创建版本快照

#### 7.2.10 recalculate_total
**功能**：重新计算总金额

**参数**：quote_id

**返回**：Decimal（新的总金额）

**实现要点**：
- 查询所有报价项
- 汇总 original_price 得到 total_original_amount
- 汇总 final_price 得到 total_final_amount
- 更新报价单主表
- 返回新的总金额

**调用时机**：
- 添加报价项后
- 更新报价项后
- 删除报价项后
- 应用折扣后

#### 7.2.11 create_version_snapshot
**功能**：创建版本快照

**参数**：quote_id、change_type

**实现要点**：
- 查询当前报价单和所有报价项
- 序列化为 JSON 存储到 snapshot_data
- 递增 version_number
- 记录 change_type 和创建时间
- 生成 changes_summary（简要描述变更内容）

**change_type 枚举**：
- create: 创建报价单
- update: 更新基本信息
- add_item: 添加商品
- update_item: 更新商品
- delete_item: 删除商品
- apply_discount: 应用折扣
- recalculate: 重新计算价格

## 八、价格计算集成

### 8.1 PricingEngine 调用场景

报价单模块需要集成现有的 PricingEngine，在以下场景调用：
1. 添加商品到报价单
2. 更新报价项的数量或 tokens
3. 重新计算报价单价格

### 8.2 计算上下文构建

**调用 PricingEngine 时需要构建的 context**：
```
{
  "product_type": "llm" | "standard",
  "token_price": Decimal,  # 从 product_prices 获取
  "estimated_tokens": int,  # input_tokens + output_tokens
  "call_frequency": 1,  # 默认为1
  "thinking_mode_ratio": float,  # 如果 inference_mode=thinking，设为1.0
  "thinking_mode_multiplier": float,  # 从 product_prices 获取
  "batch_call_ratio": 0.0,  # 暂不支持，默认为0
  "quantity": int,
  "duration_months": int
}
```

### 8.3 价格计算流程

#### 8.3.1 大模型产品计价流程
1. 从 product_prices 表获取基础价格（input_price、output_price）
2. 计算基础费用：
   - base_cost = (input_price × input_tokens + output_price × output_tokens) / 1000
3. 如果启用思考模式，应用思考模式系数：
   - thinking_cost = base_cost × thinking_mode_multiplier
4. 计算原价：
   - original_price = cost × quantity × duration_months
5. 应用单项折扣：
   - discounted_price = original_price × discount_rate
6. 应用全局折扣：
   - final_price = discounted_price × global_discount_rate

#### 8.3.2 传统产品计价流程
1. 从 product_prices 表获取单价
2. 计算原价：
   - original_price = unit_price × quantity × duration_months
3. 应用单项折扣和全局折扣（同上）

### 8.4 价格字段存储

每个报价项需要存储以下价格信息：
- original_price: 折扣前原价
- discount_rate: 单项折扣率
- final_price: 最终价格（已应用所有折扣）
- billing_unit: 计费单位（如"千Token"、"次"、"月"）

报价单主表需要存储：
- total_original_amount: 总原价
- total_final_amount: 总最终价格
- global_discount_rate: 全局折扣率

## 九、数据迁移策略

### 9.1 迁移步骤

#### 阶段一：新增字段（向后兼容）
1. 为 quote_sheets 表添加新字段（设置合理默认值）
2. 为 quote_items 表添加新字段（设置合理默认值）
3. 创建新索引
4. 调整字段类型（String → Numeric）

#### 阶段二：数据回填
1. 为已有报价单生成 quote_no
2. 为已有报价项填充 region（默认 cn-beijing）、modality 等字段
3. 重新计算价格字段（original_price、final_price）

#### 阶段三：约束加强
1. 将 nullable 字段改为 not null（如 quote_no、original_price）
2. 添加 unique 约束
3. 添加 check 约束（如折扣率范围）

### 9.2 迁移脚本示例

使用 Alembic 生成迁移脚本，关键步骤：

**步骤1：添加新字段**
- 添加所有新字段，设置 nullable=True 或合理默认值
- 创建索引

**步骤2：数据回填**
- 使用 SQL 或 Python 脚本回填历史数据
- 对于无法自动填充的字段（如 created_by），使用占位符

**步骤3：约束调整**
- 修改字段约束
- 添加数据库级约束

### 9.3 回滚计划

每个迁移步骤都应提供回滚脚本：
- 删除新增字段
- 删除新增索引
- 恢复原字段类型

## 十、异常处理与错误码

### 10.1 错误码设计

| 错误码 | HTTP状态码 | 说明 |
|--------|-----------|------|
| QUOTE_NOT_FOUND | 404 | 报价单不存在 |
| QUOTE_ITEM_NOT_FOUND | 404 | 报价项不存在 |
| PRODUCT_NOT_FOUND | 404 | 商品不存在 |
| PRICE_NOT_FOUND | 400 | 价格信息缺失 |
| INVALID_STATUS_TRANSITION | 400 | 非法的状态流转 |
| QUOTE_NOT_EDITABLE | 403 | 报价单不可编辑 |
| INVALID_DISCOUNT_RATE | 400 | 折扣率超出范围 |
| DUPLICATE_QUOTE_NO | 500 | 报价单编号重复 |
| CALCULATION_ERROR | 500 | 价格计算失败 |

### 10.2 错误响应格式

统一的错误响应结构：
```
{
  "error_code": "QUOTE_NOT_FOUND",
  "message": "报价单不存在",
  "details": {
    "quote_id": "uuid"
  },
  "timestamp": "2026-01-08T12:00:00Z"
}
```

### 10.3 异常处理策略

#### 10.3.1 业务异常
- 使用自定义异常类（如 QuoteNotFoundException）
- 在 API 层统一捕获并转换为 HTTP 响应

#### 10.3.2 数据库异常
- 捕获唯一约束冲突（如报价单编号重复）
- 捕获外键约束冲突（如商品不存在）
- 记录详细日志便于排查

#### 10.3.3 计算异常
- 价格计算失败时返回明确错误信息
- 记录计算上下文便于调试

## 十一、性能优化建议

### 11.1 数据库优化

#### 11.1.1 索引策略
- 为高频查询字段创建索引（quote_no、created_by、created_at、status）
- 为关联查询创建复合索引（product_code + region）
- 定期分析索引使用情况，删除无用索引

#### 11.1.2 查询优化
- 使用 JOIN 减少查询次数
- 避免 N+1 查询问题（使用 joinedload）
- 对大数据量查询使用游标分页

#### 11.1.3 连接池配置
- 合理配置数据库连接池大小
- 设置连接超时和查询超时

### 11.2 缓存策略

#### 11.2.1 Redis 缓存
- 缓存筛选条件选项（过期时间：1小时）
- 缓存商品详情（过期时间：30分钟）
- 缓存报价单详情（过期时间：5分钟）

#### 11.2.2 缓存失效
- 商品信息更新时清除相关缓存
- 报价单修改时清除详情缓存
- 使用 Cache Aside 模式

### 11.3 批量操作优化

- 批量添加商品时使用 bulk_insert
- 批量更新价格时使用 bulk_update
- 合理设置批次大小（建议100条/批次）

### 11.4 异步处理

对于耗时操作考虑异步处理：
- 重新计算大量报价单价格
- 批量导出报价单
- 使用 Celery 任务队列

## 十二、测试策略

### 12.1 单元测试

#### 12.1.1 Service 层测试
- QuoteService 各方法的单元测试
- PricingEngine 集成测试
- 边界条件测试（折扣率、Token 数量等）

#### 12.1.2 测试覆盖目标
- 代码覆盖率 ≥ 80%
- 关键业务逻辑覆盖率 100%

### 12.2 集成测试

#### 12.2.1 API 端点测试
- 所有 CRUD 端点的正常流程测试
- 异常场景测试（不存在的资源、权限不足等）
- 并发场景测试（报价单编号生成）

#### 12.2.2 数据库集成测试
- 使用测试数据库
- 测试事务回滚
- 测试级联删除

### 12.3 性能测试

- 接口响应时间测试（P95 < 200ms）
- 并发性能测试（100 QPS）
- 大数据量场景测试（单个报价单 > 1000 商品）

## 十三、安全考虑

### 13.1 权限控制

- 创建报价单需验证 created_by 身份
- 修改报价单需验证操作人权限
- 查看报价单需验证数据权限（未来可扩展）

### 13.2 数据校验

- 所有输入参数进行严格校验
- 防止 SQL 注入（使用参数化查询）
- 防止 XSS 攻击（转义输出）

### 13.3 敏感信息保护

- 客户邮箱等敏感信息加密存储（可选）
- 日志中脱敏处理敏感信息
- API 响应中不返回内部错误堆栈

## 十四、监控与日志

### 14.1 日志记录

#### 14.1.1 业务日志
- 报价单创建、修改、删除操作
- 价格计算过程（包含计算上下文）
- 版本快照创建记录

#### 14.1.2 错误日志
- API 异常堆栈
- 数据库错误详情
- 价格计算失败原因

### 14.2 监控指标

- API 响应时间（P50、P95、P99）
- API 错误率
- 报价单创建量（按天统计）
- 数据库连接池使用率

### 14.3 告警规则

- API 错误率 > 5% 告警
- 数据库连接池耗尽告警
- 报价单编号生成失败告警

## 十五、后续扩展方向

### 15.1 功能扩展

- 报价单审批流程
- 报价单模板管理
- 报价单对比功能
- 报价单共享和协作
- 报价单转订单

### 15.2 技术优化

- 引入缓存预热机制
- 使用 GraphQL 优化数据查询
- 引入 CQRS 模式分离读写
- 使用消息队列解耦异步任务

## 十六、交付物清单

### 16.1 代码文件

- `app/models/quote.py`（修改）
- `app/schemas/quote.py`（新建）
- `app/api/v1/endpoints/products.py`（修改）
- `app/api/v1/endpoints/quotes.py`（修改）
- `app/services/quote_service.py`（新建）
- `app/services/product_filter_service.py`（新建）
- 数据库迁移脚本（Alembic）

### 16.2 测试文件

- `tests/test_quote_service.py`（新建）
- `tests/test_quote_api.py`（新建）
- `tests/test_product_filter_service.py`（新建）
- `tests/test_product_api.py`（修改）

### 16.3 文档

- API 接口文档（自动生成，基于 FastAPI）
- 数据模型变更说明
- 迁移操作手册

## 十七、实施时间估算

| 任务 | 工作量估算 | 说明 |
|------|-----------|------|
| 数据模型设计与迁移 | 2天 | 包括迁移脚本编写和测试 |
| Schema 层开发 | 1天 | Pydantic 模型定义 |
| ProductFilterService 开发 | 2天 | 包括单元测试 |
| QuoteService 开发 | 3天 | 包括单元测试 |
| API 端点开发（商品筛选） | 2天 | 包括集成测试 |
| API 端点开发（报价单 CRUD） | 3天 | 包括集成测试 |
| 价格计算集成 | 1天 | 集成 PricingEngine |
| 文档编写 | 1天 | API 文档和操作手册 |
| 联调与 Bug 修复 | 2天 | 端到端测试 |
| **总计** | **17天** | 约3.5周 |

注：以上估算基于1名全栈开发工程师的工作量，实际时间可能因团队规模和并行开发而缩短。
