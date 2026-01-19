#!/usr/bin/env python3
"""
豆包(Doubao)定价数据导入脚本

功能：
- 从 doubao_list 目录读取 JSON 文件
- 将数据导入到 doubao_* 数据库表中

使用方法：
    cd backend
    python scripts/import_doubao_data.py

依赖：
    - 需要先执行数据库迁移创建表
    - 环境变量 DATABASE_URL 需要配置正确
"""
import os
import sys
import json
import asyncio
from datetime import datetime
from decimal import Decimal
from pathlib import Path

# 添加项目路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.models.doubao import DoubaoSnapshot, DoubaoCategory, DoubaoModel


# JSON 文件与分类的映射
CATEGORY_MAPPING = {
    'llm_models.json': {'name': '大语言模型', 'code': 'llm', 'sort': 1},
    'deep_thinking_models.json': {'name': '深度思考模型', 'code': 'deep_thinking', 'sort': 2},
    'vision_understanding_models.json': {'name': '视觉理解模型', 'code': 'vision_understanding', 'sort': 3},
    'vision_generation_models.json': {'name': '视觉大模型', 'code': 'vision_generation', 'sort': 4},
    'speech_models.json': {'name': '语音大模型', 'code': 'speech', 'sort': 5},
}


def parse_price(price_str: str) -> Decimal:
    """解析价格字符串为 Decimal"""
    try:
        # 移除可能的空格和特殊字符
        price_str = str(price_str).strip()
        return Decimal(price_str)
    except Exception:
        return Decimal('0')


async def import_doubao_data():
    """主导入函数"""
    # 创建数据库连接
    database_url = settings.DATABASE_URL
    if database_url.startswith('postgresql://'):
        database_url = database_url.replace('postgresql://', 'postgresql+asyncpg://')
    
    engine = create_async_engine(database_url, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    # JSON 文件目录
    json_dir = Path(__file__).parent.parent / 'doubao_list'
    
    if not json_dir.exists():
        print(f"错误: 找不到 JSON 目录: {json_dir}")
        return False
    
    async with async_session() as session:
        try:
            # 1. 将之前的快照标记为非最新
            await session.execute(
                update(DoubaoSnapshot).where(DoubaoSnapshot.is_latest == True).values(is_latest=False)
            )
            
            # 2. 创建新快照
            snapshot = DoubaoSnapshot(
                source_url='https://www.volcengine.com/pricing?product=ark_bd&tab=1',
                crawl_time=datetime.now(),
                status='success',
                total_count=0,
                is_latest=True
            )
            session.add(snapshot)
            await session.flush()  # 获取 snapshot.id
            
            print(f"创建快照 ID: {snapshot.id}")
            
            total_models = 0
            
            # 3. 遍历 JSON 文件
            for json_file, cat_info in CATEGORY_MAPPING.items():
                json_path = json_dir / json_file
                
                if not json_path.exists():
                    print(f"警告: 文件不存在，跳过: {json_file}")
                    continue
                
                print(f"处理文件: {json_file}")
                
                with open(json_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                
                # 创建分类
                category = DoubaoCategory(
                    snapshot_id=snapshot.id,
                    code=cat_info['code'],
                    name=cat_info['name'],
                    sort_order=cat_info['sort'],
                    model_count=len(data.get('models', [])),
                    is_active=True
                )
                session.add(category)
                await session.flush()
                
                print(f"  分类: {cat_info['name']}, 模型数: {len(data.get('models', []))}")
                
                # 导入模型
                for model_data in data.get('models', []):
                    model = DoubaoModel(
                        snapshot_id=snapshot.id,
                        category_id=category.id,
                        provider=model_data.get('provider', '未知'),
                        model_name=model_data.get('model', ''),
                        model_code=model_data.get('model', '').lower().replace(' ', '-'),
                        context_length=model_data.get('context_length'),
                        service_type=model_data.get('service_type'),
                        price=parse_price(model_data.get('price', '0')),
                        unit=model_data.get('unit', ''),
                        free_quota=model_data.get('free_quota'),
                        status='active'
                    )
                    session.add(model)
                    total_models += 1
                
                await session.flush()
            
            # 4. 更新快照总数
            snapshot.total_count = total_models
            
            # 5. 提交事务
            await session.commit()
            
            print(f"\n导入完成！")
            print(f"  - 快照ID: {snapshot.id}")
            print(f"  - 总模型数: {total_models}")
            
            return True
            
        except Exception as e:
            await session.rollback()
            print(f"导入失败: {str(e)}")
            import traceback
            traceback.print_exc()
            return False
        finally:
            await engine.dispose()


async def create_tables():
    """创建数据库表（如果不存在）"""
    from app.core.database import Base
    from app.models.doubao import DoubaoSnapshot, DoubaoCategory, DoubaoModel, DoubaoCompetitorMapping
    
    database_url = settings.DATABASE_URL
    if database_url.startswith('postgresql://'):
        database_url = database_url.replace('postgresql://', 'postgresql+asyncpg://')
    
    engine = create_async_engine(database_url, echo=False)
    
    async with engine.begin() as conn:
        # 只创建 doubao 相关的表
        await conn.run_sync(Base.metadata.create_all, tables=[
            DoubaoSnapshot.__table__,
            DoubaoCategory.__table__,
            DoubaoModel.__table__,
            DoubaoCompetitorMapping.__table__,
        ])
    
    await engine.dispose()
    print("数据库表创建/检查完成")


if __name__ == '__main__':
    print("=" * 50)
    print("豆包(Doubao)定价数据导入工具")
    print("=" * 50)
    
    # 运行
    asyncio.run(create_tables())
    success = asyncio.run(import_doubao_data())
    
    sys.exit(0 if success else 1)
