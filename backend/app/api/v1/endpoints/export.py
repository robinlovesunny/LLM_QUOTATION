"""
导出服务API端点
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import Optional
import logging

from app.core.database import get_db
from app.crud.quote import QuoteCRUD
from app.services.excel_exporter import get_excel_exporter
from app.services.oss_uploader import get_oss_uploader

logger = logging.getLogger(__name__)
router = APIRouter()


# ========== Schemas ==========
class ExportRequest(BaseModel):
    """导出请求"""
    quote_id: str
    template_type: str = "standard"  # standard/competitor/simplified


class ExportResponse(BaseModel):
    """导出响应"""
    download_url: str
    message: str
    file_size: Optional[int] = None


class TemplateInfo(BaseModel):
    """模板信息"""
    id: str
    name: str
    description: str


# ========== API Endpoints ==========
@router.post("/excel", response_model=ExportResponse)
async def export_excel(
    request: ExportRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    导出Excel报价单
    
    Args:
        request: 导出请求
        db: 数据库会话
    
    Returns:
        下载链接和消息
    """
    try:
        # 1. 获取报价单数据
        quote = await QuoteCRUD.get_quote(db, request.quote_id)
        if not quote:
            raise HTTPException(status_code=404, detail="报价单不存在")
        
        # 2. 获取报价明细
        items = await QuoteCRUD.get_quote_items(db, request.quote_id)
        if not items:
            raise HTTPException(status_code=400, detail="报价单无明细数据")
        
        # 3. 生成Excel文件
        exporter = get_excel_exporter()
        
        if request.template_type == "standard":
            file_content = await exporter.generate_standard_quote(quote, items)
        elif request.template_type == "competitor":
            # 竞品对比版本(需要额外数据)
            file_content = await exporter.generate_competitor_comparison(
                quote, items, {}
            )
        elif request.template_type == "simplified":
            file_content = await exporter.generate_simplified_quote(quote, items)
        else:
            raise HTTPException(status_code=400, detail="不支持的模板类型")
        
        # 4. 上传到OSS
        uploader = get_oss_uploader()
        download_url = await uploader.upload_quote_file(
            file_content,
            request.quote_id,
            "xlsx"
        )
        
        if not download_url:
            raise HTTPException(status_code=500, detail="文件上传失败")
        
        logger.info(f"报价单导出成功: {request.quote_id}")
        
        return ExportResponse(
            download_url=download_url,
            message="Excel导出成功",
            file_size=len(file_content)
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"导出Excel失败: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"导出失败: {str(e)}")


@router.post("/pdf", response_model=ExportResponse)
async def export_pdf(
    request: ExportRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    导出PDF报价单
    
    Args:
        request: 导出请求
        db: 数据库会话
    
    Returns:
        下载链接和消息
    """
    # PDF导出可以后续通过Excel转换实现
    # 目前返回提示信息
    return ExportResponse(
        download_url="",
        message="PDF导出功能将在后续版本提供"
    )


@router.get("/templates")
async def get_templates():
    """
    获取可用模板列表
    
    Returns:
        模板列表
    """
    return [
        TemplateInfo(
            id="standard",
            name="标准报价单",
            description="包含完整产品信息、价格明细、折扣说明的标准格式报价单"
        ),
        TemplateInfo(
            id="competitor",
            name="竞品对比版",
            description="包含火山引擎竞品价格对比的报价单"
        ),
        TemplateInfo(
            id="simplified",
            name="简化版",
            description="简化版报价单,仅包含产品名称、数量和价格"
        )
    ]
