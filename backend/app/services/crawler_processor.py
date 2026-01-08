"""
爬虫数据处理器 - 处理爬虫结果并更新数据库
"""
from typing import Dict, Any, List
from datetime import datetime, date
from decimal import Decimal
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import logging

from app.models.product import Product, ProductPrice
from app.services.crawler_base import CrawlerResult

logger = logging.getLogger(__name__)


class CrawlerDataProcessor:
    """爬虫数据处理器"""
    
    async def process_crawler_result(
        self,
        db: AsyncSession,
        result: CrawlerResult
    ) -> int:
        """
        处理爬虫结果
        
        Args:
            db: 数据库会话
            result: 爬虫结果
        
        Returns:
            更新记录数
        """
        update_count = 0
        
        try:
            # 1. 处理产品数据
            for product_data in result.products:
                updated = await self._upsert_product(db, product_data)
                if updated:
                    update_count += 1
            
            # 2. 处理价格数据
            for price_data in result.prices:
                updated = await self._upsert_price(db, price_data)
                if updated:
                    update_count += 1
            
            await db.commit()
            logger.info(f"数据处理完成,更新 {update_count} 条记录")
        
        except Exception as e:
            await db.rollback()
            logger.error(f"数据处理失败: {str(e)}", exc_info=True)
            raise
        
        return update_count
    
    async def _upsert_product(
        self,
        db: AsyncSession,
        product_data: Dict[str, Any]
    ) -> bool:
        """
        插入或更新产品数据
        
        Args:
            db: 数据库会话
            product_data: 产品数据
        
        Returns:
            是否有更新
        """
        product_code = product_data["product_code"]
        
        # 查询是否存在
        result = await db.execute(
            select(Product).where(Product.product_code == product_code)
        )
        existing_product = result.scalar_one_or_none()
        
        if existing_product:
            # 检查是否需要更新
            has_changes = False
            
            if existing_product.product_name != product_data.get("product_name"):
                existing_product.product_name = product_data["product_name"]
                has_changes = True
            
            if existing_product.description != product_data.get("description"):
                existing_product.description = product_data.get("description")
                has_changes = True
            
            if existing_product.category != product_data.get("category"):
                existing_product.category = product_data["category"]
                has_changes = True
            
            if has_changes:
                existing_product.updated_at = datetime.now()
                logger.info(f"更新产品: {product_code}")
                return True
            else:
                logger.debug(f"产品无变化: {product_code}")
                return False
        else:
            # 新建产品
            new_product = Product(
                product_code=product_code,
                product_name=product_data["product_name"],
                category=product_data["category"],
                vendor=product_data.get("vendor", "aliyun"),
                description=product_data.get("description"),
                status=product_data.get("status", "active")
            )
            db.add(new_product)
            logger.info(f"新增产品: {product_code}")
            return True
    
    async def _upsert_price(
        self,
        db: AsyncSession,
        price_data: Dict[str, Any]
    ) -> bool:
        """
        插入或更新价格数据
        
        Args:
            db: 数据库会话
            price_data: 价格数据
        
        Returns:
            是否有更新
        """
        product_code = price_data["product_code"]
        region = price_data.get("region", "cn-hangzhou")
        spec_type = price_data.get("spec_type", "default")
        billing_mode = price_data.get("billing_mode", "pay-as-you-go")
        
        # 查询是否存在相同配置的价格记录
        result = await db.execute(
            select(ProductPrice).where(
                ProductPrice.product_code == product_code,
                ProductPrice.region == region,
                ProductPrice.spec_type == spec_type,
                ProductPrice.billing_mode == billing_mode,
                ProductPrice.expire_date.is_(None)  # 只查询当前有效的价格
            )
        )
        existing_price = result.scalar_one_or_none()
        
        new_unit_price = Decimal(str(price_data["unit_price"]))
        
        if existing_price:
            # 检查价格是否变化
            if existing_price.unit_price != new_unit_price:
                # 价格变化,将旧价格设为过期
                existing_price.expire_date = date.today()
                
                # 创建新价格记录
                new_price = ProductPrice(
                    product_code=product_code,
                    region=region,
                    spec_type=spec_type,
                    billing_mode=billing_mode,
                    unit_price=new_unit_price,
                    unit=price_data.get("unit", "hour"),
                    pricing_variables=price_data.get("pricing_variables", {}),
                    effective_date=date.today()
                )
                db.add(new_price)
                logger.info(f"价格变更: {product_code} {spec_type}, {existing_price.unit_price} -> {new_unit_price}")
                return True
            else:
                logger.debug(f"价格无变化: {product_code} {spec_type}")
                return False
        else:
            # 新增价格记录
            new_price = ProductPrice(
                product_code=product_code,
                region=region,
                spec_type=spec_type,
                billing_mode=billing_mode,
                unit_price=new_unit_price,
                unit=price_data.get("unit", "hour"),
                pricing_variables=price_data.get("pricing_variables", {}),
                effective_date=date.today()
            )
            db.add(new_price)
            logger.info(f"新增价格: {product_code} {spec_type} = {new_unit_price}")
            return True
    
    async def detect_price_changes(
        self,
        db: AsyncSession,
        days: int = 7
    ) -> List[Dict[str, Any]]:
        """
        检测价格变更
        
        Args:
            db: 数据库会话
            days: 检测最近几天的变更
        
        Returns:
            价格变更列表
        """
        # 查询最近过期的价格记录(说明有新价格替代)
        from datetime import timedelta
        cutoff_date = date.today() - timedelta(days=days)
        
        result = await db.execute(
            select(ProductPrice).where(
                ProductPrice.expire_date >= cutoff_date,
                ProductPrice.expire_date.isnot(None)
            )
        )
        expired_prices = result.scalars().all()
        
        changes = []
        for old_price in expired_prices:
            # 查找新价格
            result = await db.execute(
                select(ProductPrice).where(
                    ProductPrice.product_code == old_price.product_code,
                    ProductPrice.region == old_price.region,
                    ProductPrice.spec_type == old_price.spec_type,
                    ProductPrice.billing_mode == old_price.billing_mode,
                    ProductPrice.effective_date > old_price.expire_date
                )
            )
            new_price = result.scalar_one_or_none()
            
            if new_price:
                change_percent = float(
                    (new_price.unit_price - old_price.unit_price) / old_price.unit_price * 100
                )
                
                changes.append({
                    "product_code": old_price.product_code,
                    "spec_type": old_price.spec_type,
                    "region": old_price.region,
                    "old_price": float(old_price.unit_price),
                    "new_price": float(new_price.unit_price),
                    "change_percent": round(change_percent, 2),
                    "change_date": old_price.expire_date.isoformat()
                })
        
        return changes
