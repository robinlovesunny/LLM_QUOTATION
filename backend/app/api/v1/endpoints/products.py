"""
产品数据API端点
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Body
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.schemas.product import ProductResponse, ProductPriceResponse, PaginatedProductListResponse
from app.schemas.quote import (
    FilterOptionsResponse, PaginatedModelListResponse,
    ModelDetailResponse, ProductSearchRequest, ProductSearchResponse
)
from app.services.product_filter_service import product_filter_service

router = APIRouter()

# 中文显示名称到数据库product_code的映射
MODEL_NAME_MAPPING = {
    # 通义千问系列
    '通义千问Max': 'qwen-max',
    '通义千问Plus': 'qwen-plus',
    '通义千问Turbo': 'qwen-turbo',
    '通义千问Long': 'qwen-long',
    '通义千问Flash': 'qwen-flash',
    'QwQ': 'qwq-plus',
    'QVQ': 'qvq-max',
    '通义千问数学模型': 'qwen-math-plus',
    '通义千问Coder': 'qwen-coder-plus',
    '通义千问翻译模型': 'qwen-mt-turbo',
    '通义千问数据挖掘模型': 'qwen-doc-turbo',
    '通义千问深入研究模型': 'qwen-plus',
    '通义法睿': 'farui-plus',
    # 行业模型
    '意图理解': 'tongyi-intent-detect-v3',
    '角色扮演': 'qwen-plus-character',
    '界面交互': 'gui-plus',
    # 开源版模型
    'Qwen3': 'qwen3-',
    'QwQ-开源版': 'qwq-32b',
    'QwQ-Preview': 'qwq-32b-preview',
    'Qwen2.5': 'qwen2.5-',
    'Qwen2': 'qwen2-',
    'Qwen1.5': 'qwen1.5-',
    'Qwen-Math': 'qwen-math-',
    'Qwen-Coder': 'qwen-coder-',
    # 向量模型
    '通用文本向量': 'text-embedding-v3',
    '文本向量': 'text-embedding-',
    '多模态向量': 'multimodal-embedding-one-peace-v1',
    'OpenNLU': 'opennlu-',
    '文本排序模型': 'gte-rerank-',
    # 语音模型 - 语音合成
    'CosyVoice': 'cosyvoice-',
    'Qwen-TTS': 'qwen-tts-',
    'Qwen-TTS-RealTime': 'qwen-tts-realtime',
    'Qwen-TTS声音复刻': 'cosyvoice-clone',
    'Qwen-TTS声音设计': 'cosyvoice-',
    # 语音模型 - 语音识别
    '通义千问ASR': 'qwen3-asr-flash',
    '通义千问ASR-Realtime': 'qwen3-asr-flash-realtime',
    'Paraformer': 'paraformer-',
    'SenseVoice': 'sensevoice-',
    'Fun-ASR': 'fun-asr',
    'Gummy语音识别/翻译': 'gummy-',
    # Omni多模态
    '通义千问Omni': 'qwen3-omni-flash',
    '通义千问Omni-Realtime': 'qwen3-omni-flash-realtime',
    'Qwen-Omni(开源)': 'qwen-omni-',
    'Qwen3-Omni-Captioner(开源)': 'qwen3-omni-',
    '通义千问3-LiveTranslate-Flash-Realtime': 'qwen3-livetranslate-flash-realtime',
    # 视觉理解
    '通义千问VL': 'qwen-vl-',
    '通义千问OCR': 'qwen-vl-ocr',
    'Qwen-VL(开源)': 'qwen2-vl-',
    # 图像生成
    '通义千问文生图': 'qwen-image-',
    '通义千问图像编辑': 'qwen-image-edit',
    '通义千问图像翻译': 'qwen-vl-translate',
    '通义-文生图-Z-Image': 'z-image-',
    '通义万相文生图': 'wanx-v1',
    '通义万相': 'wanx-',
    '通义万相图像生成与编辑': 'wanx-',
    '通义万相通用图像编辑': 'wanx2.1-imageedit',
    '通义万相涂鸦作画': 'wanx-sketch-',
    '人像风格重绘': 'wanx-style-repaint-',
    '图像背景生成': 'image-background-generation',
    '图像画面扩展': 'image-outpainting',
    '人物写真生成-FaceChain': 'facechain-',
    '创意文字生成-WordArt锦书': 'wordart-',
    'FLUX': 'flux-',
    # 视频生成
    '通义万相-文生视频': 'wanx2.1-t2v-',
    '文生视频': 'wanx2.1-t2v-',
    '通义万相-图生视频-基于首帧': 'wanx2.1-i2v-',
    '通义万相-图生视频-基于首尾帧': 'wanx2.1-i2v-plus',
    '图生视频': 'wanx2.1-i2v-',
    '通义万相-参考生视频': 'wanx-ref2v',
    '通义万相-通用视频编辑': 'wanx-video-',
    '通义万相-数字人': 'wanx-digital-human',
    '通义万相-图生动作': 'wanx-motion-',
    '通义万相-视频换人': 'wanx-video-faceswap',
    '舞动人像AnimateAnyone': 'animate-anyone',
    '灵动人像LivePortrait': 'liveportrait-',
}


@router.get("/filters", response_model=FilterOptionsResponse)
async def get_filter_options(
    db: AsyncSession = Depends(get_db)
):
    """
    获取筛选条件选项
    
    返回所有可用的筛选维度及其选项
    """
    try:
        return await product_filter_service.get_filter_options(db)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取筛选选项失败: {str(e)}")


@router.get("/models", response_model=PaginatedModelListResponse)
async def get_models(
    region: Optional[str] = Query(None, description="地域筛选"),
    modality: Optional[str] = Query(None, description="模态筛选（多选逗号分隔）"),
    capability: Optional[str] = Query(None, description="能力筛选"),
    model_type: Optional[str] = Query(None, description="类型筛选"),
    vendor: Optional[str] = Query(None, description="厂商筛选"),
    keyword: Optional[str] = Query(None, description="关键词搜索"),
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=100, description="每页数量"),
    db: AsyncSession = Depends(get_db)
):
    """
    获取大模型商品列表
    
    支持多条件筛选和关键词搜索
    """
    try:
        return await product_filter_service.filter_models(
            db=db,
            region=region,
            modality=modality,
            capability=capability,
            model_type=model_type,
            vendor=vendor,
            keyword=keyword,
            page=page,
            page_size=page_size
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"查询模型列表失败: {str(e)}")


@router.post("/search", response_model=ProductSearchResponse)
async def search_products(
    request: ProductSearchRequest = Body(...),
    db: AsyncSession = Depends(get_db)
):
    """
    批量名称搜索
    
    支持精确匹配和模糊匹配
    """
    try:
        return await product_filter_service.search_by_names(
            db=db,
            names=request.names,
            region=request.region
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"搜索产品失败: {str(e)}")


@router.get("/models/{model_id}", response_model=ModelDetailResponse)
async def get_model_detail(
    model_id: str,
    region: Optional[str] = Query("cn-beijing", description="地域"),
    db: AsyncSession = Depends(get_db)
):
    """
    获取模型详情
    
    返回模型的完整信息，包括规格和价格
    """
    try:
        return await product_filter_service.get_model_detail(
            db=db,
            model_id=model_id,
            region=region
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取模型详情失败: {str(e)}")


@router.get("/", response_model=PaginatedProductListResponse)
async def get_products(
    category: Optional[str] = Query(None, description="产品类别"),
    vendor: Optional[str] = Query(None, description="厂商筛选"),
    keyword: Optional[str] = Query(None, description="搜索关键词"),
    status: Optional[str] = Query("active", description="状态"),
    page: int = Query(1, ge=1, description="页码"),
    size: int = Query(20, ge=1, le=100, description="每页数量"),
    db: AsyncSession = Depends(get_db)
):
    """
    获取产品列表
    
    支持按类别、厂商和关键词搜索，返回分页结果
    """
    try:
        from sqlalchemy import select, func, or_
        from app.models.product import Product
        
        # 构建查询
        query = select(Product)
        
        if status:
            query = query.where(Product.status == status)
        if category:
            query = query.where(Product.category == category)
        if vendor:
            query = query.where(Product.vendor == vendor)
        if keyword:
            query = query.where(
                or_(
                    Product.product_name.ilike(f"%{keyword}%"),
                    Product.product_code.ilike(f"%{keyword}%"),
                    Product.description.ilike(f"%{keyword}%")
                )
            )
        
        # 计算总数
        count_query = select(func.count()).select_from(query.subquery())
        total_result = await db.execute(count_query)
        total = total_result.scalar() or 0
        
        # 分页
        offset = (page - 1) * size
        query = query.order_by(Product.vendor, Product.product_name)
        query = query.offset(offset).limit(size)
        
        result = await db.execute(query)
        products = result.scalars().all()
        
        # 转换为响应格式
        data = [
            ProductResponse(
                product_code=p.product_code,
                product_name=p.product_name,
                category=p.category,
                vendor=p.vendor,
                description=p.description,
                status=p.status,
                created_at=p.created_at,
                updated_at=p.updated_at
            )
            for p in products
        ]
        
        return PaginatedProductListResponse(
            total=total,
            page=page,
            page_size=size,
            data=data
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取产品列表失败: {str(e)}")


@router.get("/specs")
async def get_model_specs_by_name(
    model_name: str = Query(..., description="模型名称"),
    db: AsyncSession = Depends(get_db)
):
    """
    根据模型名称获取规格配置
    
    返回模型的所有可用规格和价格配置
    支持中文显示名称自动映射到数据库product_code
    """
    try:
        from sqlalchemy import select, or_, text
        from app.models.product import Product, ProductPrice, ProductSpec
        
        # 首先尝试映射中文名称到product_code
        mapped_code = MODEL_NAME_MAPPING.get(model_name)
        
        # 构建查询条件
        if mapped_code:
            # 如果有映射，优先使用映射的code查询
            query = select(Product).where(
                or_(
                    Product.product_code == mapped_code,
                    Product.product_code.ilike(f"{mapped_code}%")
                )
            )
        else:
            # 否则使用原有的名称匹配逻辑
            query = select(Product).where(
                or_(
                    Product.product_name == model_name,
                    Product.product_name.ilike(f"%{model_name}%"),
                    Product.product_code.ilike(f"%{model_name}%")
                )
            )
        
        result = await db.execute(query)
        products = result.scalars().all()
        
        # 如果在products表找不到，尝试从pricing_model表查询
        if not products:
            pricing_query = text("""
                SELECT pm.id, pm.model_code, pm.model_name, pm.display_name,
                       pmp.dimension_code, pmp.unit_price, pmp.unit, pmp.rule_text,
                       pc.name as category_name
                FROM pricing_model pm
                JOIN pricing_model_price pmp ON pm.id = pmp.model_id
                JOIN pricing_category pc ON pm.category_id = pc.id
                WHERE pm.display_name ILIKE :search_pattern
                   OR pm.model_name ILIKE :search_pattern
                   OR pm.model_code ILIKE :code_pattern
                ORDER BY pm.model_name, pmp.dimension_code
            """)
            
            code_pattern = f"{mapped_code}%" if mapped_code else f"%{model_name}%"
            pricing_result = await db.execute(
                pricing_query, 
                {"search_pattern": f"%{model_name}%", "code_pattern": code_pattern}
            )
            pricing_rows = pricing_result.fetchall()
            
            if pricing_rows:
                # 按模型分组价格
                model_prices = {}
                for row in pricing_rows:
                    model_key = row.model_code or row.model_name
                    if model_key not in model_prices:
                        model_prices[model_key] = {
                            'model_name': row.display_name or row.model_name,
                            'model_code': row.model_code,
                            'category': row.category_name,
                            'prices': {}
                        }
                    model_prices[model_key]['prices'][row.dimension_code] = {
                        'unit_price': float(row.unit_price) if row.unit_price else None,
                        'unit': row.unit,
                        'rule_text': row.rule_text
                    }
                
                specs_list = []
                for idx, (model_key, model_data) in enumerate(model_prices.items()):
                    prices = model_data['prices']
                    spec_item = {
                        "id": f"pricing_{model_key}_{idx}",
                        "product_code": model_data['model_code'],
                        "model_name": model_data['model_name'],
                        "region": "中国内地",
                        "mode": "标准",
                        "token_range": prices.get('input_token', {}).get('rule_text') or "无阶梯计价",
                        "input_price": prices.get('input_token', {}).get('unit_price'),
                        "output_price": prices.get('output_token', {}).get('unit_price'),
                        "unit": prices.get('input_token', {}).get('unit') or "千Token",
                        "billing_mode": "token",
                        "remark": "",
                        "display_config": {
                            "show_mode": True,
                            "show_token_range": True,
                            "price_unit": f"/{prices.get('input_token', {}).get('unit') or '千Token'}"
                        }
                    }
                    specs_list.append(spec_item)
                
                return {"specs": specs_list}
        
        if not products:
            return {"specs": [], "message": f"未找到模型: {model_name}"}
        
        specs_list = []
        for product in products:
            # 获取价格信息
            price_query = select(ProductPrice).where(
                ProductPrice.product_code == product.product_code
            )
            price_result = await db.execute(price_query)
            prices = price_result.scalars().all()
            
            for price in prices:
                pricing_vars = price.pricing_variables or {}
                
                # 构建规格配置
                spec_item = {
                    "id": str(price.price_id),
                    "product_code": product.product_code,
                    "model_name": product.product_name,
                    "region": price.region,
                    "mode": pricing_vars.get("mode", "标准"),
                    "token_range": pricing_vars.get("token_range", "无阶梯计价"),
                    "input_price": pricing_vars.get("input_price"),
                    "output_price": pricing_vars.get("output_price"),
                    "unit": price.unit or "千Token",
                    "billing_mode": price.billing_mode,
                    "remark": pricing_vars.get("remark", ""),
                    "display_config": {
                        "show_mode": pricing_vars.get("mode") is not None,
                        "show_token_range": pricing_vars.get("token_range") is not None,
                        "price_unit": f"/{price.unit or '千Token'}"
                    }
                }
                specs_list.append(spec_item)
        
        return {"specs": specs_list}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取模型规格失败: {str(e)}")


@router.get("/{product_code}", response_model=ProductResponse)
async def get_product(
    product_code: str,
    db: AsyncSession = Depends(get_db)
):
    """
    获取产品详情
    
    根据产品代码获取完整的产品信息
    """
    try:
        from sqlalchemy import select
        from app.models.product import Product
        
        query = select(Product).where(Product.product_code == product_code)
        result = await db.execute(query)
        product = result.scalars().first()
        
        if not product:
            raise HTTPException(status_code=404, detail=f"产品不存在: {product_code}")
        
        return ProductResponse(
            product_code=product.product_code,
            product_name=product.product_name,
            category=product.category,
            vendor=product.vendor,
            description=product.description,
            status=product.status,
            created_at=product.created_at,
            updated_at=product.updated_at
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取产品详情失败: {str(e)}")


@router.get("/{product_code}/price", response_model=ProductPriceResponse)
async def get_product_price(
    product_code: str,
    region: Optional[str] = Query("cn-beijing", description="地域"),
    spec_type: Optional[str] = Query(None, description="规格类型"),
    db: AsyncSession = Depends(get_db)
):
    """
    获取产品价格信息
    
    根据产品代码和地域获取价格详情
    """
    try:
        from sqlalchemy import select, and_, or_
        from datetime import datetime
        from app.models.product import ProductPrice
        
        # 构建查询
        query = select(ProductPrice).where(
            ProductPrice.product_code == product_code
        )
        
        if region:
            query = query.where(ProductPrice.region == region)
        
        if spec_type:
            query = query.where(ProductPrice.spec_type == spec_type)
        
        # 获取有效期内的价格
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
        price = result.scalars().first()
        
        if not price:
            raise HTTPException(
                status_code=404, 
                detail=f"产品 {product_code} 在地域 {region} 的价格信息不存在"
            )
        
        return ProductPriceResponse(
            price_id=str(price.price_id),
            product_code=price.product_code,
            region=price.region,
            spec_type=price.spec_type,
            billing_mode=price.billing_mode,
            unit_price=float(price.unit_price),
            unit=price.unit or "千Token",
            pricing_variables=price.pricing_variables,
            effective_date=price.effective_date
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取价格信息失败: {str(e)}")


@router.get("/{product_code}/prices", response_model=List[ProductPriceResponse])
async def get_product_prices(
    product_code: str,
    db: AsyncSession = Depends(get_db)
):
    """
    获取产品所有地域的价格信息
    
    返回产品在各个地域的价格列表
    """
    try:
        from sqlalchemy import select, and_, or_
        from datetime import datetime
        from app.models.product import ProductPrice
        
        query = select(ProductPrice).where(
            and_(
                ProductPrice.product_code == product_code,
                ProductPrice.effective_date <= datetime.now(),
                or_(
                    ProductPrice.expire_date.is_(None),
                    ProductPrice.expire_date > datetime.now()
                )
            )
        ).order_by(ProductPrice.region)
        
        result = await db.execute(query)
        prices = result.scalars().all()
        
        return [
            ProductPriceResponse(
                price_id=str(p.price_id),
                product_code=p.product_code,
                region=p.region,
                spec_type=p.spec_type,
                billing_mode=p.billing_mode,
                unit_price=float(p.unit_price),
                unit=p.unit or "千Token",
                pricing_variables=p.pricing_variables,
                effective_date=p.effective_date
            )
            for p in prices
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取价格列表失败: {str(e)}")


@router.get("/categories/list")
async def get_product_categories(
    db: AsyncSession = Depends(get_db)
):
    """
    获取所有产品类别
    
    返回系统中所有产品类别的列表
    """
    try:
        from sqlalchemy import select
        from app.models.product import Product
        
        query = select(Product.category).distinct()
        result = await db.execute(query)
        categories = result.scalars().all()
        
        return {
            "categories": [
                {"code": cat, "name": cat}
                for cat in sorted(categories) if cat
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取类别列表失败: {str(e)}")


@router.get("/vendors/list")
async def get_product_vendors(
    db: AsyncSession = Depends(get_db)
):
    """
    获取所有厂商列表
    
    返回系统中所有产品厂商的列表
    """
    try:
        from sqlalchemy import select
        from app.models.product import Product
        
        query = select(Product.vendor).distinct()
        result = await db.execute(query)
        vendors = result.scalars().all()
        
        return {
            "vendors": sorted(vendors)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取厂商列表失败: {str(e)}")


# =====================================================
# 定价数据API（基于pricing_*表，提供多维度定价查询）
# =====================================================

@router.get("/pricing/filters")
async def get_pricing_filter_options(
    db: AsyncSession = Depends(get_db)
):
    """
    获取定价筛选选项（多维度）
    
    返回所有可用的定价筛选维度：分类、模式、Token阶梯、分辨率等
    """
    try:
        from app.services.pricing_data_service import pricing_data_service
        return await pricing_data_service.get_filter_options(db)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取定价筛选选项失败: {str(e)}")


@router.get("/pricing/models")
async def get_pricing_models(
    category: Optional[str] = Query(None, description="分类代码"),
    mode: Optional[str] = Query(None, description="模式（仅非思考模式/非思考和思考模式/仅思考模式）"),
    token_tier: Optional[str] = Query(None, description="Token阶梯"),
    resolution: Optional[str] = Query(None, description="分辨率（视频模型）"),
    supports_batch: Optional[bool] = Query(None, description="是否支持Batch半价"),
    supports_cache: Optional[bool] = Query(None, description="是否支持上下文缓存"),
    keyword: Optional[str] = Query(None, description="关键词搜索"),
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(50, ge=1, le=200, description="每页数量"),
    db: AsyncSession = Depends(get_db)
):
    """
    获取定价模型列表（多维度筛选）
    
    支持按模式、Token阶梯、分辨率、Batch支持、缓存支持等多维度筛选
    """
    try:
        from app.services.pricing_data_service import pricing_data_service
        return await pricing_data_service.filter_models(
            db=db,
            category=category,
            mode=mode,
            token_tier=token_tier,
            resolution=resolution,
            supports_batch=supports_batch,
            supports_cache=supports_cache,
            keyword=keyword,
            page=page,
            page_size=page_size
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"查询定价模型失败: {str(e)}")


@router.get("/pricing/model/{model_code}")
async def get_model_pricing_detail(
    model_code: str,
    db: AsyncSession = Depends(get_db)
):
    """
    获取模型完整定价信息
    
    返回指定模型的所有定价变体（不同模式、Token阶梯、分辨率等）
    """
    try:
        from app.services.pricing_data_service import pricing_data_service
        result = await pricing_data_service.get_model_pricing(db, model_code)
        if not result.get('found'):
            raise HTTPException(status_code=404, detail=f"模型不存在: {model_code}")
        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取模型定价失败: {str(e)}")


@router.get("/pricing/summary/{model_code}")
async def get_pricing_summary(
    model_code: str,
    db: AsyncSession = Depends(get_db)
):
    """
    获取模型定价摘要
    
    返回模型的定价概览信息，包括变体数量、价格范围等
    """
    try:
        from app.services.pricing_data_service import pricing_data_service
        return await pricing_data_service.get_pricing_summary(db, model_code)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取定价摘要失败: {str(e)}")


@router.get("/pricing/search")
async def search_pricing_models(
    keyword: str = Query(..., description="搜索关键词"),
    limit: int = Query(20, ge=1, le=100, description="返回数量"),
    db: AsyncSession = Depends(get_db)
):
    """
    搜索模型（用于自动完成）
    
    根据关键词搜索模型，返回简要信息
    """
    try:
        from app.services.pricing_data_service import pricing_data_service
        return await pricing_data_service.search_models(db, keyword, limit)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"搜索模型失败: {str(e)}")


@router.get("/pricing/categories")
async def get_pricing_categories_tree(
    db: AsyncSession = Depends(get_db)
):
    """
    获取分类及模型树
    
    返回分类-模型的树形结构数据
    """
    try:
        from app.services.pricing_data_service import pricing_data_service
        return await pricing_data_service.get_categories_with_models(db)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取分类树失败: {str(e)}")

