"""
豆包(Doubao)定价数据API端点
提供豆包大模型定价信息的查询接口，用于竞品对比
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_, and_
from loguru import logger

from app.core.database import get_db
from app.models.doubao import DoubaoSnapshot, DoubaoCategory, DoubaoModel, DoubaoCompetitorMapping, DebateList

router = APIRouter()


@router.get("/categories")
async def get_doubao_categories(
    db: AsyncSession = Depends(get_db)
):
    """
    获取豆包模型分类列表
    
    返回所有可用的模型分类，包含各分类下的模型数量
    """
    try:
        # 获取最新快照
        snapshot_query = select(DoubaoSnapshot).where(
            DoubaoSnapshot.is_latest == True
        ).order_by(DoubaoSnapshot.crawl_time.desc())
        snapshot_result = await db.execute(snapshot_query)
        snapshot = snapshot_result.scalars().first()
        
        if not snapshot:
            return {"categories": [], "message": "暂无数据，请先导入豆包定价数据"}
        
        # 获取分类列表
        query = select(DoubaoCategory).where(
            DoubaoCategory.snapshot_id == snapshot.id,
            DoubaoCategory.is_active == True
        ).order_by(DoubaoCategory.sort_order)
        
        result = await db.execute(query)
        categories = result.scalars().all()
        
        return {
            "categories": [
                {
                    "id": cat.id,
                    "code": cat.code,
                    "name": cat.name,
                    "model_count": cat.model_count
                }
                for cat in categories
            ],
            "snapshot_time": snapshot.crawl_time.isoformat() if snapshot.crawl_time else None
        }
    except Exception as e:
        logger.error(f"获取豆包分类失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"获取分类失败: {str(e)}")


@router.get("/models")
async def get_doubao_models(
    category: Optional[str] = Query(None, description="分类名称筛选"),
    provider: Optional[str] = Query(None, description="供应商筛选"),
    service_type: Optional[str] = Query(None, description="服务类型筛选：推理（输入）/推理（输出）/批量推理（输入）/批量推理（输出）"),
    keyword: Optional[str] = Query(None, description="关键词搜索"),
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(50, ge=1, le=200, description="每页数量"),
    db: AsyncSession = Depends(get_db)
):
    """
    获取豆包模型定价列表
    
    支持多条件筛选和关键词搜索
    """
    try:
        # 获取最新快照
        snapshot_query = select(DoubaoSnapshot).where(
            DoubaoSnapshot.is_latest == True
        )
        snapshot_result = await db.execute(snapshot_query)
        snapshot = snapshot_result.scalars().first()
        
        if not snapshot:
            return {
                "total": 0,
                "page": page,
                "page_size": page_size,
                "data": [],
                "message": "暂无数据"
            }
        
        # 构建查询
        query = select(DoubaoModel, DoubaoCategory.name.label('category_name')).join(
            DoubaoCategory, DoubaoModel.category_id == DoubaoCategory.id
        ).where(
            DoubaoModel.snapshot_id == snapshot.id,
            DoubaoModel.status == 'active'
        )
        
        # 分类筛选
        if category:
            query = query.where(DoubaoCategory.name == category)
        
        # 供应商筛选
        if provider:
            query = query.where(DoubaoModel.provider == provider)
        
        # 服务类型筛选
        if service_type:
            query = query.where(DoubaoModel.service_type == service_type)
        
        # 关键词搜索
        if keyword:
            query = query.where(
                or_(
                    DoubaoModel.model_name.ilike(f"%{keyword}%"),
                    DoubaoModel.provider.ilike(f"%{keyword}%")
                )
            )
        
        # 计算总数
        count_query = select(func.count()).select_from(query.subquery())
        total_result = await db.execute(count_query)
        total = total_result.scalar() or 0
        
        # 分页
        offset = (page - 1) * page_size
        query = query.order_by(DoubaoCategory.sort_order, DoubaoModel.model_name)
        query = query.offset(offset).limit(page_size)
        
        result = await db.execute(query)
        rows = result.all()
        
        return {
            "total": total,
            "page": page,
            "page_size": page_size,
            "data": [
                {
                    "id": row.DoubaoModel.id,
                    "provider": row.DoubaoModel.provider,
                    "model_name": row.DoubaoModel.model_name,
                    "category": row.category_name,
                    "context_length": row.DoubaoModel.context_length,
                    "service_type": row.DoubaoModel.service_type,
                    "price": float(row.DoubaoModel.price) if row.DoubaoModel.price else None,
                    "unit": row.DoubaoModel.unit,
                    "free_quota": row.DoubaoModel.free_quota
                }
                for row in rows
            ]
        }
    except Exception as e:
        logger.error(f"查询豆包模型失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"查询失败: {str(e)}")


@router.get("/models/search")
async def search_doubao_models(
    keyword: str = Query(..., description="搜索关键词"),
    limit: int = Query(20, ge=1, le=100, description="返回数量"),
    db: AsyncSession = Depends(get_db)
):
    """
    搜索豆包模型（用于自动完成）
    
    根据关键词搜索模型，返回简要信息
    """
    try:
        # 获取最新快照
        snapshot_query = select(DoubaoSnapshot).where(
            DoubaoSnapshot.is_latest == True
        )
        snapshot_result = await db.execute(snapshot_query)
        snapshot = snapshot_result.scalars().first()
        
        if not snapshot:
            return {"results": []}
        
        query = select(DoubaoModel, DoubaoCategory.name.label('category_name')).join(
            DoubaoCategory, DoubaoModel.category_id == DoubaoCategory.id
        ).where(
            DoubaoModel.snapshot_id == snapshot.id,
            DoubaoModel.status == 'active',
            or_(
                DoubaoModel.model_name.ilike(f"%{keyword}%"),
                DoubaoModel.provider.ilike(f"%{keyword}%")
            )
        ).limit(limit)
        
        result = await db.execute(query)
        rows = result.all()
        
        return {
            "results": [
                {
                    "id": row.DoubaoModel.id,
                    "model_name": row.DoubaoModel.model_name,
                    "provider": row.DoubaoModel.provider,
                    "category": row.category_name,
                    "price": float(row.DoubaoModel.price) if row.DoubaoModel.price else None,
                    "unit": row.DoubaoModel.unit
                }
                for row in rows
            ]
        }
    except Exception as e:
        logger.error(f"搜索豆包模型失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"搜索失败: {str(e)}")


@router.get("/models/{model_id}")
async def get_doubao_model_detail(
    model_id: int,
    db: AsyncSession = Depends(get_db)
):
    """
    获取豆包模型详情
    
    根据模型ID获取完整的模型信息
    """
    try:
        query = select(DoubaoModel, DoubaoCategory.name.label('category_name')).join(
            DoubaoCategory, DoubaoModel.category_id == DoubaoCategory.id
        ).where(DoubaoModel.id == model_id)
        
        result = await db.execute(query)
        row = result.first()
        
        if not row:
            raise HTTPException(status_code=404, detail=f"模型不存在: {model_id}")
        
        return {
            "id": row.DoubaoModel.id,
            "provider": row.DoubaoModel.provider,
            "model_name": row.DoubaoModel.model_name,
            "model_code": row.DoubaoModel.model_code,
            "category": row.category_name,
            "context_length": row.DoubaoModel.context_length,
            "service_type": row.DoubaoModel.service_type,
            "price": float(row.DoubaoModel.price) if row.DoubaoModel.price else None,
            "unit": row.DoubaoModel.unit,
            "currency": row.DoubaoModel.currency,
            "free_quota": row.DoubaoModel.free_quota,
            "remark": row.DoubaoModel.remark,
            "created_at": row.DoubaoModel.created_at.isoformat() if row.DoubaoModel.created_at else None
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取豆包模型详情失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"获取详情失败: {str(e)}")


@router.get("/providers")
async def get_doubao_providers(
    db: AsyncSession = Depends(get_db)
):
    """
    获取豆包平台上的供应商列表
    
    返回火山引擎平台上所有模型供应商
    """
    try:
        # 获取最新快照
        snapshot_query = select(DoubaoSnapshot).where(
            DoubaoSnapshot.is_latest == True
        )
        snapshot_result = await db.execute(snapshot_query)
        snapshot = snapshot_result.scalars().first()
        
        if not snapshot:
            return {"providers": []}
        
        query = select(DoubaoModel.provider, func.count(DoubaoModel.id).label('model_count')).where(
            DoubaoModel.snapshot_id == snapshot.id,
            DoubaoModel.status == 'active'
        ).group_by(DoubaoModel.provider)
        
        result = await db.execute(query)
        rows = result.all()
        
        return {
            "providers": [
                {"name": row.provider, "model_count": row.model_count}
                for row in rows
            ]
        }
    except Exception as e:
        logger.error(f"获取供应商列表失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"获取供应商失败: {str(e)}")


@router.get("/service-types")
async def get_doubao_service_types(
    db: AsyncSession = Depends(get_db)
):
    """
    获取服务类型列表
    
    返回所有可用的服务类型选项
    """
    try:
        # 获取最新快照
        snapshot_query = select(DoubaoSnapshot).where(
            DoubaoSnapshot.is_latest == True
        )
        snapshot_result = await db.execute(snapshot_query)
        snapshot = snapshot_result.scalars().first()
        
        if not snapshot:
            return {"service_types": []}
        
        query = select(DoubaoModel.service_type).where(
            DoubaoModel.snapshot_id == snapshot.id,
            DoubaoModel.service_type.isnot(None)
        ).distinct()
        
        result = await db.execute(query)
        types = result.scalars().all()
        
        return {
            "service_types": sorted([t for t in types if t])
        }
    except Exception as e:
        logger.error(f"获取服务类型失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"获取服务类型失败: {str(e)}")


@router.get("/filters")
async def get_doubao_filters(
    db: AsyncSession = Depends(get_db)
):
    """
    获取所有筛选选项
    
    一次性返回所有筛选维度的可用选项
    """
    try:
        # 获取最新快照
        snapshot_query = select(DoubaoSnapshot).where(
            DoubaoSnapshot.is_latest == True
        )
        snapshot_result = await db.execute(snapshot_query)
        snapshot = snapshot_result.scalars().first()
        
        if not snapshot:
            return {
                "categories": [],
                "providers": [],
                "service_types": [],
                "snapshot_time": None
            }
        
        # 获取分类
        cat_query = select(DoubaoCategory.name).where(
            DoubaoCategory.snapshot_id == snapshot.id,
            DoubaoCategory.is_active == True
        ).distinct()
        cat_result = await db.execute(cat_query)
        categories = cat_result.scalars().all()
        
        # 获取供应商
        provider_query = select(DoubaoModel.provider).where(
            DoubaoModel.snapshot_id == snapshot.id
        ).distinct()
        provider_result = await db.execute(provider_query)
        providers = provider_result.scalars().all()
        
        # 获取服务类型
        type_query = select(DoubaoModel.service_type).where(
            DoubaoModel.snapshot_id == snapshot.id,
            DoubaoModel.service_type.isnot(None)
        ).distinct()
        type_result = await db.execute(type_query)
        service_types = type_result.scalars().all()
        
        return {
            "categories": sorted([c for c in categories if c]),
            "providers": sorted([p for p in providers if p]),
            "service_types": sorted([t for t in service_types if t]),
            "snapshot_time": snapshot.crawl_time.isoformat() if snapshot.crawl_time else None
        }
    except Exception as e:
        logger.error(f"获取筛选选项失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"获取筛选选项失败: {str(e)}")


@router.get("/snapshot/latest")
async def get_latest_snapshot(
    db: AsyncSession = Depends(get_db)
):
    """
    获取最新快照信息
    
    返回最新数据快照的元信息
    """
    try:
        query = select(DoubaoSnapshot).where(
            DoubaoSnapshot.is_latest == True
        )
        result = await db.execute(query)
        snapshot = result.scalars().first()
        
        if not snapshot:
            return {"snapshot": None, "message": "暂无数据快照"}
        
        return {
            "snapshot": {
                "id": snapshot.id,
                "source_url": snapshot.source_url,
                "crawl_time": snapshot.crawl_time.isoformat() if snapshot.crawl_time else None,
                "total_count": snapshot.total_count,
                "status": snapshot.status
            }
        }
    except Exception as e:
        logger.error(f"获取快照信息失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"获取快照失败: {str(e)}")


# ==================== 模型映射关系 API ====================

@router.get("/debate-list")
async def get_debate_list(
    db: AsyncSession = Depends(get_db)
):
    """
    获取所有已保存的模型映射关系
    """
    try:
        query = select(DebateList).where(
            DebateList.is_active == True
        ).order_by(DebateList.created_at.desc())
        
        result = await db.execute(query)
        mappings = result.scalars().all()
        
        return {
            "total": len(mappings),
            "data": [
                {
                    "id": m.id,
                    "qwen_model_name": m.qwen_model_name,
                    "qwen_display_name": m.qwen_display_name,
                    "doubao_input_model_name": m.doubao_input_model_name,
                    "doubao_output_model_name": m.doubao_output_model_name,
                    "created_at": m.created_at.isoformat() if m.created_at else None
                }
                for m in mappings
            ]
        }
    except Exception as e:
        logger.error(f"获取映射关系失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"获取映射关系失败: {str(e)}")


@router.post("/debate-list/batch-save")
async def batch_save_debate_list(
    mappings: List[dict],
    db: AsyncSession = Depends(get_db)
):
    """
    批量保存模型映射关系到数据库
    
    参数:
        mappings: 映射关系列表，每个映射包含:
            - qwen_model_name: 阿里云模型准确名称
            - qwen_display_name: 阿里云模型显示名称
            - doubao_input_model_name: 豆包输入价格模型名称
            - doubao_output_model_name: 豆包输出价格模型名称
    """
    try:
        saved_count = 0
        skipped_count = 0
        
        for mapping in mappings:
            # 检查必要字段
            qwen_name = mapping.get('qwen_model_name')
            doubao_input = mapping.get('doubao_input_model_name')
            doubao_output = mapping.get('doubao_output_model_name')
            
            if not all([qwen_name, doubao_input, doubao_output]):
                skipped_count += 1
                continue
            
            # 检查是否已存在相同映射
            exist_query = select(DebateList).where(
                DebateList.qwen_model_name == qwen_name,
                DebateList.doubao_input_model_name == doubao_input,
                DebateList.doubao_output_model_name == doubao_output,
                DebateList.is_active == True
            )
            exist_result = await db.execute(exist_query)
            if exist_result.scalars().first():
                skipped_count += 1
                continue
            
            # 创建新映射
            new_mapping = DebateList(
                qwen_model_name=qwen_name,
                qwen_display_name=mapping.get('qwen_display_name', qwen_name),
                doubao_input_model_name=doubao_input,
                doubao_output_model_name=doubao_output
            )
            db.add(new_mapping)
            saved_count += 1
        
        await db.commit()
        
        return {
            "success": True,
            "saved_count": saved_count,
            "skipped_count": skipped_count,
            "message": f"成功保存 {saved_count} 条映射关系，跳过 {skipped_count} 条（已存在或数据不完整）"
        }
    except Exception as e:
        await db.rollback()
        logger.error(f"批量保存映射关系失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"保存失败: {str(e)}")


@router.delete("/debate-list/{mapping_id}")
async def delete_debate_mapping(
    mapping_id: int,
    db: AsyncSession = Depends(get_db)
):
    """
    删除指定的模型映射关系
    """
    try:
        query = select(DebateList).where(DebateList.id == mapping_id)
        result = await db.execute(query)
        mapping = result.scalars().first()
        
        if not mapping:
            raise HTTPException(status_code=404, detail=f"映射关系不存在: {mapping_id}")
        
        # 软删除
        mapping.is_active = False
        await db.commit()
        
        return {"success": True, "message": "删除成功"}
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"删除映射关系失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"删除失败: {str(e)}")
