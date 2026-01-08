"""
AI交互API端点
"""
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

router = APIRouter()


class ChatMessage(BaseModel):
    """对话消息"""
    message: str
    session_id: str = None


@router.post("/chat")
async def chat(message: ChatMessage):
    """对话式报价交互"""
    # TODO: 实现AI对话功能
    return {
        "response": "AI对话功能开发中",
        "session_id": message.session_id or "new_session"
    }


@router.websocket("/ws")
async def websocket_chat(websocket: WebSocket):
    """WebSocket对话连接"""
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            # TODO: 实现WebSocket流式响应
            await websocket.send_text(f"收到消息: {data}")
    except WebSocketDisconnect:
        pass


@router.post("/parse-requirement")
async def parse_requirement(requirement_text: str):
    """解析需求文本"""
    # TODO: 实现需求解析逻辑
    return {"entities": {}, "message": "需求解析功能开发中"}
