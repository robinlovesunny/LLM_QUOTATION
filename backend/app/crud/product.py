"""
产品数据CRUD操作
"""
from typing import List, Optional
from sqlalchemy import select, or_, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.product import Product, ProductPrice, ProductSpec, CompetitorMapping


class ProductCRUD:
    """产品数据库操作"""
    
    @staticmethod
    async def get_products(
        db: AsyncSession,
        category: Optional[str] = None,
        keyword: Optional[str] = None,
        skip: int = 0,
        limit: int = 20
    ) -> List[Product]:
        """获取产品列表"""
        query = select(Product).where(Product.status == "active")
        
        if category:
            query = query.where(Product.category == category)
        
        if keyword:
            query = query.where(
                or_(
                    Product.product_name.ilike(f"%{keyword}%"),
                    Product.description.ilike(f"%{keyword}%")
                )
            )
        
        query = query.offset(skip).limit(limit)
        result = await db.execute(query)
        return result.scalars().all()
    
    @staticmethod
    async def get_product(db: AsyncSession, product_code: str) -> Optional[Product]:
        """获取产品详情"""
        query = select(Product).where(Product.product_code == product_code)
        result = await db.execute(query)
        return result.scalar_one_or_none()
    
    @staticmethod
    async def get_product_price(
        db: AsyncSession,
        product_code: str,
        region: Optional[str] = None,
        spec_type: Optional[str] = None
    ) -> Optional[ProductPrice]:
        """获取产品价格"""
        query = select(ProductPrice).where(
            ProductPrice.product_code == product_code
        )
        
        if region:
            query = query.where(ProductPrice.region == region)
        
        if spec_type:
            query = query.where(ProductPrice.spec_type == spec_type)
        
        # 获取有效期内的价格
        from datetime import datetime
        query = query.where(
            and_(
                ProductPrice.effective_date <= datetime.now(),
                or_(
                    ProductPrice.expire_date.is_(None),
                    ProductPrice.expire_date > datetime.now()
                )
            )
        )
        
        query = query.order_by(ProductPrice.effective_date.desc())
        result = await db.execute(query)
        return result.scalar_one_or_none()
    
    @staticmethod
    async def create_product(db: AsyncSession, product: Product) -> Product:
        """创建产品"""
        db.add(product)
        await db.commit()
        await db.refresh(product)
        return product
    
    @staticmethod
    async def update_product(
        db: AsyncSession,
        product_code: str,
        update_data: dict
    ) -> Optional[Product]:
        """更新产品"""
        product = await ProductCRUD.get_product(db, product_code)
        if not product:
            return None
        
        for key, value in update_data.items():
            setattr(product, key, value)
        
        await db.commit()
        await db.refresh(product)
        return product
    
    @staticmethod
    async def get_competitor_products(
        db: AsyncSession,
        ali_product_code: str,
        competitor_name: str = "volcano"
    ) -> List[CompetitorMapping]:
        """获取竞品映射"""
        query = select(CompetitorMapping).where(
            and_(
                CompetitorMapping.ali_product_code == ali_product_code,
                CompetitorMapping.competitor_name == competitor_name
            )
        ).order_by(CompetitorMapping.confidence_score.desc())
        
        result = await db.execute(query)
        return result.scalars().all()


# 创建全局实例
product_crud = ProductCRUD()
