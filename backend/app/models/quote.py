"""
报价单数据模型
"""
import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, Integer, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func

from app.core.database import Base


class QuoteSheet(Base):
    """报价单主表"""
    __tablename__ = "quote_sheets"
    
    quote_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, comment="报价单ID")
    customer_name = Column(String(255), nullable=False, comment="客户名称")
    project_name = Column(String(255), comment="项目名称")
    status = Column(String(50), nullable=False, default="draft", comment="状态")
    total_amount = Column(String(20), comment="报价总金额")
    currency = Column(String(10), default="CNY", comment="币种")
    valid_until = Column(DateTime(timezone=True), comment="报价有效期")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), comment="创建时间")
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), comment="更新时间")
    
    __table_args__ = (
        Index('ix_quote_customer', 'customer_name'),
        Index('ix_quote_status', 'status'),
        {'comment': '报价单主表'}
    )


class QuoteItem(Base):
    """报价明细表"""
    __tablename__ = "quote_items"
    
    item_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, comment="明细ID")
    quote_id = Column(UUID(as_uuid=True), ForeignKey('quote_sheets.quote_id', ondelete='CASCADE'), nullable=False, comment="所属报价单")
    product_code = Column(String(100), nullable=False, comment="产品代码")
    product_name = Column(String(255), nullable=False, comment="产品名称")
    spec_config = Column(JSONB, comment="规格配置")
    quantity = Column(Integer, nullable=False, comment="数量")
    duration_months = Column(Integer, comment="时长(月)")
    usage_estimation = Column(JSONB, comment="用量估算")
    unit_price = Column(String(20), comment="单价")
    subtotal = Column(String(20), comment="小计")
    discount_info = Column(JSONB, comment="折扣信息")
    
    __table_args__ = (
        Index('ix_item_quote', 'quote_id'),
        {'comment': '报价明细表'}
    )


class QuoteDiscount(Base):
    """折扣记录表"""
    __tablename__ = "quote_discounts"
    
    discount_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, comment="折扣ID")
    quote_id = Column(UUID(as_uuid=True), ForeignKey('quote_sheets.quote_id', ondelete='CASCADE'), nullable=False, comment="所属报价单")
    discount_type = Column(String(50), comment="折扣类型")
    discount_value = Column(String(20), comment="折扣值")
    apply_reason = Column(String(255), comment="应用原因")
    
    __table_args__ = (
        Index('ix_discount_quote', 'quote_id'),
        {'comment': '折扣记录表'}
    )


class QuoteVersion(Base):
    """版本快照表"""
    __tablename__ = "quote_versions"
    
    version_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, comment="版本ID")
    quote_id = Column(UUID(as_uuid=True), ForeignKey('quote_sheets.quote_id', ondelete='CASCADE'), nullable=False, comment="所属报价单")
    version_number = Column(Integer, nullable=False, comment="版本号")
    snapshot_data = Column(JSONB, comment="快照数据")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), comment="创建时间")
    
    __table_args__ = (
        Index('ix_version_quote', 'quote_id'),
        {'comment': '版本快照表'}
    )
