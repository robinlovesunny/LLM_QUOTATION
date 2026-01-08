"""
报价管理服务测试
"""
import pytest
from uuid import uuid4
from decimal import Decimal

from app.models.quote import QuoteSheet, QuoteItem, QuoteStatus


class TestQuoteService:
    """报价管理服务测试"""
    
    @pytest.mark.asyncio
    async def test_create_quote(self, db_session):
        """测试创建报价单"""
        quote = QuoteSheet(
            quote_id=str(uuid4()),
            customer_name="测试客户",
            project_name="测试项目",
            status=QuoteStatus.DRAFT,
            total_amount=Decimal("0.00"),
            currency="CNY"
        )
        
        db_session.add(quote)
        await db_session.commit()
        await db_session.refresh(quote)
        
        assert quote.customer_name == "测试客户"
        assert quote.status == QuoteStatus.DRAFT
    
    @pytest.mark.asyncio
    async def test_create_quote_item(self, db_session):
        """测试创建报价明细"""
        # 先创建报价单
        quote_id = str(uuid4())
        quote = QuoteSheet(
            quote_id=quote_id,
            customer_name="测试客户",
            status=QuoteStatus.DRAFT,
            total_amount=Decimal("0.00")
        )
        db_session.add(quote)
        
        # 创建明细
        item = QuoteItem(
            item_id=str(uuid4()),
            quote_id=quote_id,
            product_code="bailian",
            product_name="百炼大模型服务",
            spec_config={"model": "qwen-max"},
            quantity=1,
            duration_months=1,
            unit_price=Decimal("100.00"),
            subtotal=Decimal("100.00")
        )
        db_session.add(item)
        
        await db_session.commit()
        await db_session.refresh(item)
        
        assert item.quote_id == quote_id
        assert item.product_name == "百炼大模型服务"
        assert float(item.subtotal) == 100.00
    
    @pytest.mark.asyncio
    async def test_update_quote_status(self, db_session):
        """测试更新报价单状态"""
        quote_id = str(uuid4())
        quote = QuoteSheet(
            quote_id=quote_id,
            customer_name="测试客户",
            status=QuoteStatus.DRAFT,
            total_amount=Decimal("1000.00")
        )
        db_session.add(quote)
        await db_session.commit()
        
        # 更新状态
        quote.status = QuoteStatus.FINALIZED
        await db_session.commit()
        await db_session.refresh(quote)
        
        assert quote.status == QuoteStatus.FINALIZED
