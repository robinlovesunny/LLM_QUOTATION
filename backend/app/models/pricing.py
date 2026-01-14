"""
定价数据模型 - 用于pricing_*表的ORM映射
"""
from datetime import datetime
from decimal import Decimal
from sqlalchemy import Column, String, Text, DateTime, Integer, Boolean, Numeric, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class PricingSnapshot(Base):
    """定价快照表"""
    __tablename__ = "pricing_snapshot"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    source_url = Column(Text, nullable=False, comment="数据来源URL")
    captured_at = Column(DateTime, default=func.now(), comment="抓取时间")
    status = Column(String(20), default='success', comment="状态")
    parser_version = Column(String(20), default='v3.0', comment="解析器版本")
    raw_content_path = Column(Text, comment="原始内容路径")
    is_latest = Column(Boolean, default=False, comment="是否最新")
    created_at = Column(DateTime, default=func.now(), comment="创建时间")
    
    # 关系
    models = relationship("PricingModel", back_populates="snapshot")


class PricingCategory(Base):
    """定价分类表"""
    __tablename__ = "pricing_category"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    code = Column(String(50), unique=True, nullable=False, comment="分类代码")
    name = Column(String(100), nullable=False, comment="分类名称")
    parent_code = Column(String(50), comment="父分类代码")
    sort_order = Column(Integer, default=0, comment="排序")
    is_active = Column(Boolean, default=True, comment="是否激活")
    created_at = Column(DateTime, default=func.now(), comment="创建时间")
    
    # 关系
    models = relationship("PricingModel", back_populates="category")


class PricingDimension(Base):
    """定价维度表"""
    __tablename__ = "pricing_dimension"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    code = Column(String(50), unique=True, nullable=False, comment="维度代码")
    name = Column(String(100), nullable=False, comment="维度名称")
    default_unit = Column(String(50), nullable=False, comment="默认单位")
    value_type = Column(String(20), default='float', comment="值类型")
    description = Column(Text, comment="描述")
    created_at = Column(DateTime, default=func.now(), comment="创建时间")


class PricingModel(Base):
    """定价模型表（增强版）"""
    __tablename__ = "pricing_model"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    snapshot_id = Column(Integer, ForeignKey("pricing_snapshot.id"), comment="快照ID")
    category_id = Column(Integer, ForeignKey("pricing_category.id"), comment="分类ID")
    model_code = Column(String(100), index=True, comment="模型代码")
    model_name = Column(String(200), nullable=False, comment="模型名称")
    display_name = Column(String(200), nullable=False, comment="显示名称")
    sub_category = Column(String(100), comment="子分类")
    
    # 结构化字段
    mode = Column(String(50), comment="模式：仅非思考模式/非思考和思考模式/仅思考模式")
    token_tier = Column(String(50), comment="Token阶梯：0<Token≤32K 等")
    resolution = Column(String(20), comment="视频分辨率：720P/1080P 等")
    supports_batch = Column(Boolean, default=False, comment="是否支持Batch调用半价")
    supports_cache = Column(Boolean, default=False, comment="是否支持上下文缓存折扣")
    remark = Column(Text, comment="备注")
    
    # 兼容字段
    rule_text = Column(Text, comment="完整规则文本")
    status = Column(String(20), default='active', comment="状态")
    created_at = Column(DateTime, default=func.now(), comment="创建时间")
    
    # 关系
    snapshot = relationship("PricingSnapshot", back_populates="models")
    category = relationship("PricingCategory", back_populates="models")
    prices = relationship("PricingModelPrice", back_populates="model")


class PricingModelPrice(Base):
    """定价模型价格表（增强版）"""
    __tablename__ = "pricing_model_price"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    snapshot_id = Column(Integer, ForeignKey("pricing_snapshot.id"), comment="快照ID")
    model_id = Column(Integer, ForeignKey("pricing_model.id"), index=True, comment="模型ID")
    dimension_code = Column(String(50), comment="维度代码")
    unit_price = Column(Numeric(15, 6), nullable=False, comment="单价")
    currency = Column(String(10), default='CNY', comment="货币")
    unit = Column(String(50), nullable=False, comment="单位")
    
    # 冗余字段（便于直接查询）
    mode = Column(String(50), comment="模式")
    token_tier = Column(String(50), comment="Token阶梯")
    resolution = Column(String(20), comment="分辨率")
    rule_text = Column(Text, comment="规则文本")
    created_at = Column(DateTime, default=func.now(), comment="创建时间")
    
    # 关系
    model = relationship("PricingModel", back_populates="prices")
