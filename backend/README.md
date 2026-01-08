# 报价侠系统 - 后端服务

## 项目简介

报价侠是一款面向阿里云BTE/SA人员的智能化报价平台,通过AI能力与自动化手段,将传统7天的报价工作压缩至"选、配、导"三步完成。

## 技术栈

- **Web框架**: FastAPI 0.109+
- **数据库**: PostgreSQL (ADB PG)
- **缓存**: Redis 7.x
- **AI能力**: 阿里云百炼API (Qwen-Max)
- **爬虫**: Scrapy / Playwright
- **Excel处理**: openpyxl
- **对象存储**: 阿里云OSS

## 项目结构

```
backend/
├── main.py                 # 应用入口
├── requirements.txt        # Python依赖
├── .env.example           # 环境变量示例
├── alembic/               # 数据库迁移
├── app/
│   ├── __init__.py
│   ├── core/              # 核心模块
│   │   ├── config.py      # 配置管理
│   │   ├── database.py    # 数据库连接
│   │   └── redis_client.py # Redis客户端
│   ├── models/            # 数据模型
│   ├── schemas/           # Pydantic模式
│   ├── api/               # API路由
│   │   └── v1/
│   │       ├── endpoints/ # API端点
│   │       │   ├── products.py    # 产品API
│   │       │   ├── quotes.py      # 报价API
│   │       │   ├── ai_chat.py     # AI交互API
│   │       │   └── export.py      # 导出API
│   │       └── __init__.py
│   ├── services/          # 业务逻辑
│   ├── crud/              # 数据库操作
│   ├── agents/            # AI Agent
│   └── utils/             # 工具函数
├── tests/                 # 测试
└── logs/                  # 日志
```

## 快速开始

### 1. 环境准备

```bash
# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt
```

### 2. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env 文件,填写数据库、Redis、百炼API等配置
```

### 3. 数据库迁移

```bash
# 初始化Alembic
alembic init alembic

# 创建迁移
alembic revision --autogenerate -m "Initial migration"

# 执行迁移
alembic upgrade head
```

### 4. 启动服务

```bash
# 开发模式
python main.py

# 或使用uvicorn
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 5. 访问文档

- Swagger文档: http://localhost:8000/api/docs
- ReDoc文档: http://localhost:8000/api/redoc

## 核心功能模块

### 1. 产品数据服务
- 产品目录查询与搜索
- 产品价格获取
- 产品规格配置验证

### 2. 报价管理服务
- 报价单CRUD操作
- 报价单版本管理
- 报价历史记录查询

### 3. 计费计算引擎
- 大模型Token计费
- 思考模式/非思考模式
- Batch调用折扣
- 阶梯折扣/套餐组合

### 4. AI智能引擎
- 需求理解与实体抽取
- 产品推荐
- 配置自动生成
- 对话式交互

### 5. 爬虫服务
- 阿里云产品价格爬取
- 火山引擎产品价格爬取
- 定时调度与数据更新

### 6. 导出服务
- Excel报价单生成
- PDF格式转换
- OSS文件上传

## 开发规范

### 代码风格
- 使用Black进行代码格式化
- 使用Flake8进行代码检查
- 使用MyPy进行类型检查

### 提交规范
- feat: 新功能
- fix: 修复bug
- docs: 文档更新
- refactor: 代码重构
- test: 测试相关

## API设计规范

### 统一响应格式

成功响应:
```json
{
  "success": true,
  "data": { ... },
  "message": "操作成功"
}
```

失败响应:
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "错误描述"
  }
}
```

## 测试

```bash
# 运行所有测试
pytest

# 运行特定测试
pytest tests/test_products.py

# 生成覆盖率报告
pytest --cov=app tests/
```

## 部署

### Docker部署

```bash
# 构建镜像
docker build -t quote-system-backend .

# 运行容器
docker run -d -p 8000:8000 --env-file .env quote-system-backend
```

### 生产环境

生产环境建议使用Gunicorn + Uvicorn Workers:

```bash
gunicorn main:app --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

## 许可证

内部项目

## 联系方式

技术支持: 产研团队
