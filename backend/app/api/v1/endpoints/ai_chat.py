"""
AI交互API端点
支持智能对话、实体提取、价格计算等功能
"""
import uuid
from typing import Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from loguru import logger

from app.agents.orchestrator import agent_orchestrator
from app.agents.tools import function_tools

router = APIRouter()


class ChatMessage(BaseModel):
    """对话消息"""
    message: str
    session_id: Optional[str] = None


class ExtractRequest(BaseModel):
    """提取请求"""
    text: str
    extract_type: str = "entities"  # entities, usage, price


@router.post("/chat")
async def chat(request: ChatMessage):
    """
    智能对话接口
    
    支持:
    - 需求理解和实体提取
    - 用量预估
    - 价格计算
    - 多轮对话上下文
    """
    session_id = request.session_id or str(uuid.uuid4())
    
    try:
        result = await agent_orchestrator.process_user_message(
            message=request.message,
            session_id=session_id
        )
        
        return {
            "success": True,
            "session_id": session_id,
            "response": result.get("response", ""),
            "entities": result.get("entities"),
            "usage_estimation": result.get("usage_estimation"),
            "price_calculation": result.get("price_calculation"),
            "quote_item": result.get("quote_item"),
            "quote_summary": result.get("quote_summary"),
            "action": result.get("action")
        }
    except Exception as e:
        logger.error(f"AI对话失败: {e}")
        return {
            "success": False,
            "session_id": session_id,
            "error": str(e)
        }


@router.post("/extract")
async def extract_entities(request: ExtractRequest):
    """
    实体提取接口
    
    从文本中提取产品需求信息:
    - 产品类型
    - 数量
    - 时长
    - 使用场景
    """
    try:
        entities = await function_tools.extract_entities(request.text)
        return {
            "success": True,
            "entities": entities
        }
    except Exception as e:
        logger.error(f"实体提取失败: {e}")
        return {
            "success": False,
            "error": str(e)
        }


@router.post("/estimate-usage")
async def estimate_usage(use_case: str, workload: str):
    """
    用量预估接口
    
    根据使用场景预估:
    - Token消耗量
    - 调用频率
    - 思考模式占比
    - Batch调用占比
    """
    try:
        estimation = await function_tools.estimate_llm_usage(use_case, workload)
        return {
            "success": True,
            "estimation": estimation
        }
    except Exception as e:
        logger.error(f"用量预估失败: {e}")
        return {
            "success": False,
            "error": str(e)
        }


@router.post("/calculate-price")
async def calculate_price(product_type: str, base_price: float, context: dict):
    """
    价格计算接口
    
    支持多种计费模式:
    - LLM Token计费
    - 思考模式加价
    - Batch折扣
    - 标准产品计费
    """
    try:
        result = await function_tools.calculate_price(product_type, base_price, context)
        return {
            "success": True,
            "price": result
        }
    except Exception as e:
        logger.error(f"价格计算失败: {e}")
        return {
            "success": False,
            "error": str(e)
        }


@router.delete("/session/{session_id}")
async def clear_session(session_id: str):
    """清除会话历史"""
    agent_orchestrator.clear_session(session_id)
    return {"success": True, "message": f"会话 {session_id} 已清除"}


@router.websocket("/ws")
async def websocket_chat(websocket: WebSocket):
    """
    WebSocket流式对话
    
    消息格式:
    发送: {"message": "用户消息", "session_id": "xxx"}
    接收: {"type": "response", "content": "...", "done": false}
    """
    await websocket.accept()
    session_id = str(uuid.uuid4())
    
    try:
        while True:
            data = await websocket.receive_json()
            message = data.get("message", "")
            session_id = data.get("session_id", session_id)
            
            # 处理消息
            result = await agent_orchestrator.process_user_message(
                message=message,
                session_id=session_id
            )
            
            # 发送响应
            await websocket.send_json({
                "type": "response",
                "session_id": session_id,
                "content": result.get("response", ""),
                "entities": result.get("entities"),
                "done": True
            })
            
    except WebSocketDisconnect:
        logger.info(f"WebSocket断开: {session_id}")
    except Exception as e:
        logger.error(f"WebSocket错误: {e}")
        await websocket.close()
