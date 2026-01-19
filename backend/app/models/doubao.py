"""
豆包(Doubao)定价数据模型 - 用于存储火山引擎豆包大模型的定价信息
"""
from datetime import datetime
from decimal import Decimal
from sqlalchemy import Column, String, Text, DateTime, Integer, Boolean, Numeric, ForeignKey, Index
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class DoubaoSnapshot(Base):
    """豆包定价快照表 - 记录每次爬取的元信息"""
    __tablename__ = "doubao_snapshot"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    source_url = Column(Text, nullable=False, comment="数据来源URL")
    crawl_time = Column(DateTime, default=func.now(), comment="爬取时间")
    status = Column(String(20), default='success', comment="状态: success/failed")
    total_count = Column(Integer, default=0, comment="模型总数")
    is_latest = Column(Boolean, default=False, comment="是否最新")
    created_at = Column(DateTime, default=func.now(), comment="创建时间")
    
    # 关系
    categories = relationship("DoubaoCategory", back_populates="snapshot")


class DoubaoCategory(Base):
    """豆包模型分类表"""
    __tablename__ = "doubao_category"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    snapshot_id = Column(Integer, ForeignKey("doubao_snapshot.id"), comment="快照ID")
    code = Column(String(50), index=True, comment="分类代码")
    name = Column(String(100), nullable=False, comment="分类名称: 大语言模型/深度思考模型/视觉理解模型/视觉大模型/语音大模型")
    sort_order = Column(Integer, default=0, comment="排序")
    model_count = Column(Integer, default=0, comment="该分类下模型数量")
    is_active = Column(Boolean, default=True, comment="是否激活")
    created_at = Column(DateTime, default=func.now(), comment="创建时间")
    
    # 关系
    snapshot = relationship("DoubaoSnapshot", back_populates="categories")
    models = relationship("DoubaoModel", back_populates="category")
    
    # 索引
    __table_args__ = (
        Index('ix_doubao_category_snapshot_code', 'snapshot_id', 'code'),
    )


class DoubaoModel(Base):
    """豆包模型定价表 - 存储具体模型的定价信息"""
    __tablename__ = "doubao_model"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    snapshot_id = Column(Integer, ForeignKey("doubao_snapshot.id"), comment="快照ID")
    category_id = Column(Integer, ForeignKey("doubao_category.id"), comment="分类ID")
    
    # 模型基本信息
    provider = Column(String(50), nullable=False, comment="供应商: 字节跳动/深度求索/月之暗面")
    model_name = Column(String(200), nullable=False, index=True, comment="模型名称")
    model_code = Column(String(100), index=True, comment="模型代码(标准化后)")
    
    # 规格信息
    context_length = Column(String(100), comment="上下文长度: 32k/128k/256k或范围描述")
    service_type = Column(String(50), comment="服务类型: 推理（输入）/推理（输出）/批量推理（输入）/批量推理（输出）")
    
    # 价格信息
    price = Column(Numeric(15, 8), nullable=False, comment="单价")
    unit = Column(String(50), nullable=False, comment="单位: 元/千tokens/元/张/元/万字符")
    currency = Column(String(10), default='CNY', comment="货币")
    
    # 附加信息
    free_quota = Column(String(100), comment="免费额度")
    remark = Column(Text, comment="备注")
    
    # 状态
    status = Column(String(20), default='active', comment="状态")
    created_at = Column(DateTime, default=func.now(), comment="创建时间")
    
    # 关系
    category = relationship("DoubaoCategory", back_populates="models")
    
    # 索引
    __table_args__ = (
        Index('ix_doubao_model_snapshot_category', 'snapshot_id', 'category_id'),
        Index('ix_doubao_model_provider', 'provider'),
        Index('ix_doubao_model_service_type', 'service_type'),
    )


class DoubaoCompetitorMapping(Base):
    """豆包与竞品模型映射表 - 用于竞品对比"""
    __tablename__ = "doubao_competitor_mapping"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    doubao_model_name = Column(String(200), nullable=False, index=True, comment="豆包模型名称")
    competitor_vendor = Column(String(50), nullable=False, comment="竞品厂商: 阿里云/百度/腾讯等")
    competitor_model_name = Column(String(200), nullable=False, comment="竞品模型名称")
    mapping_type = Column(String(20), default='similar', comment="映射类型: exact/similar/alternative")
    confidence = Column(Numeric(3, 2), default=0.8, comment="匹配置信度")
    remark = Column(Text, comment="备注")
    is_active = Column(Boolean, default=True, comment="是否激活")
    created_at = Column(DateTime, default=func.now(), comment="创建时间")
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), comment="更新时间")
    
    # 索引
    __table_args__ = (
        Index('ix_doubao_mapping_competitor', 'competitor_vendor', 'competitor_model_name'),
    )


class DebateList(Base):
    """模型映射关系表 - 存储竞品对比页面建立的模型映射"""
    __tablename__ = "debate_list"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    qwen_model_name = Column(String(200), nullable=False, comment="阿里云模型准确名称")
    qwen_display_name = Column(String(200), comment="阿里云模型显示名称")
    doubao_input_model_name = Column(String(200), nullable=False, comment="豆包输入价格模型名称")
    doubao_output_model_name = Column(String(200), nullable=False, comment="豆包输出价格模型名称")
    is_active = Column(Boolean, default=True, comment="是否激活")
    created_at = Column(DateTime, default=func.now(), comment="创建时间")
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), comment="更新时间")
    
    # 索引
    __table_args__ = (
        Index('ix_debate_list_qwen', 'qwen_model_name'),
        Index('ix_debate_list_doubao_input', 'doubao_input_model_name'),
    )
