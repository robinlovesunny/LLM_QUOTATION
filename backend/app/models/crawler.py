"""
爬虫任务数据模型
"""
import uuid
from enum import Enum
from datetime import datetime
from sqlalchemy import Column, String, DateTime, Integer, Text, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func

from app.core.database import Base


class TaskStatus(str, Enum):
    """任务状态枚举"""
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


class CrawlerTask(Base):
    """爬虫任务表"""
    __tablename__ = "crawler_tasks"
    
    task_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, comment="任务ID")
    task_type = Column(String(50), nullable=False, comment="任务类型")
    status = Column(String(50), nullable=False, comment="状态")
    start_time = Column(DateTime(timezone=True), comment="开始时间")
    end_time = Column(DateTime(timezone=True), comment="结束时间")
    records_crawled = Column(Integer, comment="爬取记录数")
    records_updated = Column(Integer, comment="更新记录数")
    error_message = Column(Text, comment="错误信息")
    
    __table_args__ = (
        {'comment': '爬虫任务表'}
    )
