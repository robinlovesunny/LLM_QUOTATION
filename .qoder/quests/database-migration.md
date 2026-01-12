¬# 数据库迁移设计文档

## 业务背景

随着报价管理系统功能的增强，现有数据模型需要扩展以支持更完善的业务流程，包括报价单编号管理、人员信息记录、折扣计算、产品属性扩展等功能。本次迁移旨在增强数据模型的表达能力和业务支撑能力。

## 设计目标

- 支持自动生成和管理唯一的报价单编号
- 记录报价创建者、销售负责人等关键人员信息
- 完善折扣计算体系，支持全局折扣和单项折扣
- 扩展产品属性，支持多地域、多模态的产品配置
- 增强版本管理，记录变更类型和变更摘要
- 保证数据类型的准确性，使用数值类型存储金额和价格
- 优化查询性能，为常用查询字段建立索引

## 业务流程影响

### 报价单创建流程
创建报价单时，系统将自动生成唯一的报价单编号，记录创建人信息，并初始化全局折扣率为 1.0000（无折扣）。

### 价格计算流程
价格计算将支持两级折扣：
- 单项折扣：每个报价明细可设置独立的折扣率
- 全局折扣：应用于整个报价单的统一折扣

计算逻辑：
1. 计算每个明细的原价（unit_price × quantity × duration_months）
2. 应用单项折扣率得到明细折后价
3. 汇总所有明细的原价和折后价
4. 应用全局折扣率得到最终报价总额

### 版本管理流程
当报价单发生变更时，系统将记录变更类型（如创建、修改、审批等）和变更摘要，便于追溯历史版本和审计。

## 数据模型变更

### QuoteSheet 表（报价单主表）

#### 新增字段

| 字段名称 | 数据类型 | 约束 | 默认值 | 业务含义 |
|---------|---------|------|--------|---------|
| quote_no | String(50) | unique, not null | 无 | 报价单编号，格式如 QTYYYYMMDDXXXX |
| created_by | String(100) | not null | 无 | 创建人标识或名称 |
| sales_name | String(100) | nullable | 无 | 销售负责人姓名 |
| customer_contact | String(100) | nullable | 无 | 客户方联系人 |
| customer_email | String(255) | nullable | 无 | 客户方邮箱地址 |
| remarks | Text | nullable | 无 | 备注信息，记录特殊说明 |
| terms | Text | nullable | 无 | 合同条款说明 |
| global_discount_rate | Numeric(5,4) | not null | 1.0000 | 全局折扣率，1.0000表示无折扣 |
| global_discount_remark | String(255) | nullable | 无 | 折扣原因或说明 |
| total_original_amount | Numeric(20,6) | nullable | 无 | 报价总金额（折前） |

#### 字段类型变更

| 字段名称 | 原类型 | 新类型 | 变更原因 |
|---------|-------|--------|---------|
| total_amount | String(20) | Numeric(20,6) | 使用数值类型以便精确计算和聚合 |

#### 新增索引

| 索引名称 | 索引字段 | 业务目的 |
|---------|---------|---------|
| ix_quote_no | quote_no | 加速按编号查询报价单 |
| ix_quote_created_by | created_by | 加速查询特定人员创建的报价单 |
| ix_quote_created_at | created_at | 加速按创建时间范围查询 |

### QuoteItem 表（报价明细表）

#### 新增字段

| 字段名称 | 数据类型 | 约束 | 默认值 | 业务含义 |
|---------|---------|------|--------|---------|
| region | String(50) | not null | cn-beijing | 产品所在地域代码 |
| region_name | String(100) | nullable | 无 | 地域显示名称（如"华北2（北京）"） |
| modality | String(50) | not null | 无 | 模态类型（如文本、图像、视频等） |
| capability | String(50) | nullable | 无 | 能力类型（如理解、生成等） |
| model_type | String(50) | nullable | 无 | 模型类型（如基础模型、微调模型） |
| context_spec | String(50) | nullable | 无 | 上下文规格（如 4K、32K、128K） |
| input_tokens | BigInteger | nullable | 无 | 预估输入 token 数量 |
| output_tokens | BigInteger | nullable | 无 | 预估输出 token 数量 |
| inference_mode | String(50) | nullable | 无 | 推理方式（如实时、离线） |
| original_price | Numeric(20,6) | not null | 无 | 原价（元），用于计算折扣 |
| discount_rate | Numeric(5,4) | not null | 1.0000 | 单项折扣率 |
| final_price | Numeric(20,6) | not null | 无 | 折后价（元） |
| billing_unit | String(50) | not null | 无 | 计费单位（如千Token、次、GB等） |
| sort_order | Integer | not null | 0 | 明细排序序号，用于控制显示顺序 |

#### 字段类型变更

| 字段名称 | 原类型 | 新类型 | 变更原因 |
|---------|-------|--------|---------|
| unit_price | String(20) | Numeric(20,6) | 使用数值类型以便精确计算 |
| subtotal | String(20) | Numeric(20,6) | 使用数值类型以便精确计算 |

#### 字段默认值调整

| 字段名称 | 调整内容 | 业务含义 |
|---------|---------|---------|
| quantity | 增加默认值 1 | 数量至少为1 |
| duration_months | 增加默认值 1 | 时长至少为1个月 |

#### 新增索引

| 索引名称 | 索引字段 | 业务目的 |
|---------|---------|---------|
| ix_item_sort_order | quote_id, sort_order | 加速按排序顺序检索明细 |

### QuoteVersion 表（版本快照表）

#### 新增字段

| 字段名称 | 数据类型 | 约束 | 默认值 | 业务含义 |
|---------|---------|------|--------|---------|
| change_type | String(50) | nullable | 无 | 变更类型（如创建、修改、提交审批、审批通过等） |
| changes_summary | String(500) | nullable | 无 | 变更摘要，简述本次变更内容 |

#### 新增索引

| 索引名称 | 索引字段 | 业务目的 |
|---------|---------|---------|
| ix_version_number | quote_id, version_number | 加速按版本号查询特定版本 |

## 迁移策略

### 迁移工具
使用 Alembic 管理数据库迁移，确保迁移的可追溯性和可回滚性。

### 迁移阶段

#### 阶段一：迁移脚本生成
在项目 backend 目录下执行 Alembic 自动生成迁移脚本，命令为：
```
alembic revision --autogenerate -m "enhance_quote_models_add_fields"
```

生成的脚本将位于 backend/alembic/versions/ 目录。

#### 阶段二：脚本审查与调整
人工审查生成的迁移脚本，重点关注：
- 新增 not null 字段是否需要临时默认值
- 类型转换是否安全（String 转 Numeric）
- 索引创建顺序是否合理

#### 阶段三：数据回填逻辑设计
针对已存在的历史数据，需在迁移脚本中加入数据回填逻辑：

**QuoteSheet 表数据回填规则**

| 字段 | 回填策略 | 规则说明 |
|-----|---------|---------|
| quote_no | 生成历史编号 | 格式为 QT + 创建日期(YYYYMMDD) + 4位顺序号，如 QT20260115001 |
| created_by | 设置默认值 | 统一设为 "system" 表示系统历史数据 |
| global_discount_rate | 设置默认值 | 设为 1.0000（无折扣） |
| total_original_amount | 计算汇总 | 从关联的 quote_items 汇总计算原价总额 |

**QuoteItem 表数据回填规则**

| 字段 | 回填策略 | 规则说明 |
|-----|---------|---------|
| region | 设置默认值 | 统一设为 "cn-beijing" |
| modality | 业务映射 | 根据 product 的 category 字段映射（如 LLM → 文本） |
| original_price | 计算复制 | 计算 unit_price × quantity × duration_months |
| discount_rate | 设置默认值 | 设为 1.0000（无折扣） |
| final_price | 计算复制 | 复制 original_price 的值 |
| billing_unit | 设置默认值 | 统一设为 "千Token" |
| sort_order | 自增序列 | 按 item_id 或 created_at 顺序分配递增序号 |

#### 阶段四：测试环境验证
在测试环境执行迁移，验证：
- 迁移脚本执行无错误
- 表结构符合设计预期
- 数据回填正确完整
- 索引创建成功
- 应用服务能正常读写数据

#### 阶段五：生产环境执行
在维护窗口期间执行生产环境迁移：
1. 停止应用服务或切换为只读模式
2. 备份生产数据库
3. 执行迁移命令：`alembic upgrade head`
4. 验证迁移结果
5. 启动应用服务
6. 监控应用日志和数据库性能

### 回滚计划
若迁移失败或发现严重问题，可执行回滚操作：
```
alembic downgrade -1
```

回滚将撤销本次迁移的所有变更，恢复到迁移前的数据库状态。

### 风险控制措施

#### 数据安全
- 迁移前必须完整备份生产数据库
- 备份数据应保存至独立存储介质
- 验证备份数据的完整性和可恢复性

#### 执行时机
- 选择业务低峰期或维护窗口执行
- 预留充足的迁移时间和应急处理时间
- 提前通知相关人员和用户

#### 监控与验证
- 迁移过程中实时监控数据库状态
- 迁移后检查关键业务指标
- 验证 API 接口返回数据的正确性

## 验证检查清单

迁移完成后，需逐项验证以下内容：

### 数据库层面
- [ ] QuoteSheet 表所有新字段已创建且类型正确
- [ ] QuoteSheet 表 total_amount 字段类型已转换为 Numeric
- [ ] QuoteSheet 表三个新索引（ix_quote_no、ix_quote_created_by、ix_quote_created_at）已创建
- [ ] QuoteItem 表所有新字段已创建且类型正确
- [ ] QuoteItem 表 unit_price 和 subtotal 字段类型已转换为 Numeric
- [ ] QuoteItem 表 quantity 和 duration_months 默认值已设置
- [ ] QuoteItem 表索引 ix_item_sort_order 已创建
- [ ] QuoteVersion 表新字段已创建
- [ ] QuoteVersion 表索引 ix_version_number 已创建

### 数据层面
- [ ] 历史报价单的 quote_no 已正确生成且无重复
- [ ] 历史报价单的必填字段均有值
- [ ] 历史报价明细的 region、modality 等必填字段均有值
- [ ] 价格字段的数值转换正确，无精度丢失
- [ ] 原有数据的关联关系完整

### 应用层面
- [ ] 报价单列表查询功能正常
- [ ] 报价单详情展示正常
- [ ] 新建报价单功能正常（quote_no 自动生成）
- [ ] 报价单修改功能正常
- [ ] 价格计算逻辑正确（包含折扣计算）
- [ ] 版本历史记录正常
- [ ] API 接口响应时间未明显增加

### 性能层面
- [ ] 常用查询的执行计划使用了正确的索引
- [ ] 数据库连接池状态正常
- [ ] 无慢查询告警

## 注意事项

1. **不可逆操作警示**：字段类型从 String 转为 Numeric 是不可逆操作，回滚后需手动恢复数据
2. **编号唯一性保证**：报价单编号生成逻辑需考虑并发场景，避免产生重复编号
3. **索引维护成本**：新增索引会增加写入操作的开销，需持续监控写入性能
4. **兼容性考虑**：迁移后的 API 响应结构需保持向后兼容，避免影响前端应用
5. **版本控制**：迁移脚本必须纳入 Git 版本控制，确保团队同步

## 后续优化建议

1. **报价单编号生成服务**：考虑实现独立的编号生成服务，支持自定义编号规则
2. **折扣策略配置化**：将折扣计算逻辑抽象为可配置的策略，提高灵活性
3. **审计日志增强**：基于版本管理表实现完整的审计日志查询功能
4. **性能优化**：根据实际查询模式，考虑增加复合索引或分区表
5. **数据归档**：对历史报价数据建立归档机制，保持主表数据量可控
