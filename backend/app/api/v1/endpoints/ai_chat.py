"""
AI Chat API Endpoints
Provides intelligent quotation dialogue interface with multimodal support
"""
import uuid
from typing import Optional, Dict, Any, List
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException, UploadFile, File
from pydantic import BaseModel, Field
from loguru import logger

from app.agents.orchestrator import agent_orchestrator
from app.services.multimodal_extractor import multimodal_extractor

router = APIRouter()


# ========== Request/Response Schemas ==========
class ChatRequest(BaseModel):
    """Chat request model"""
    message: str = Field(..., description="User message", min_length=1, max_length=2000)
    session_id: Optional[str] = Field(None, description="Session ID for conversation continuity")


class ChatResponse(BaseModel):
    """Chat response model"""
    response: str = Field(..., description="AI response text")
    session_id: str = Field(..., description="Session ID")
    entities: Optional[Dict[str, Any]] = Field(None, description="Extracted entities")
    usage_estimation: Optional[Dict[str, Any]] = Field(None, description="Usage estimation")
    price_calculation: Optional[Dict[str, Any]] = Field(None, description="Price calculation result")
    error: Optional[str] = Field(None, description="Error message if any")


class ClearSessionRequest(BaseModel):
    """Clear session request"""
    session_id: str = Field(..., description="Session ID to clear")


# ========== API Endpoints ==========
@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Intelligent quotation dialogue interface
    
    Process user requirements through AI and return:
    - Natural language response
    - Extracted entities (product, quantity, duration, etc.)
    - Usage estimation for LLM products
    - Price calculation results
    """
    # Generate session_id if not provided
    session_id = request.session_id or f"session_{uuid.uuid4().hex[:12]}"
    
    logger.info(f"[AI Chat] Received message: session={session_id}, message={request.message[:100]}...")
    
    try:
        # Process message through orchestrator
        result = await agent_orchestrator.process_user_message(
            message=request.message,
            session_id=session_id
        )
        
        logger.info(f"[AI Chat] Response generated: session={session_id}")
        
        return ChatResponse(
            response=result.get("response", ""),
            session_id=session_id,
            entities=result.get("entities"),
            usage_estimation=result.get("usage_estimation"),
            price_calculation=result.get("price_calculation"),
            error=result.get("error")
        )
        
    except Exception as e:
        logger.error(f"[AI Chat] Error processing message: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to process message: {str(e)}"
        )


@router.post("/clear-session")
async def clear_session(request: ClearSessionRequest):
    """
    Clear conversation history for a session
    """
    logger.info(f"[AI Chat] Clearing session: {request.session_id}")
    
    await agent_orchestrator.clear_session_async(request.session_id)
    
    return {"message": "Session cleared successfully", "session_id": request.session_id}


@router.websocket("/ws")
async def websocket_chat(websocket: WebSocket):
    """
    WebSocket connection for streaming chat (reserved for future use)
    """
    await websocket.accept()
    session_id = f"ws_{uuid.uuid4().hex[:12]}"
    logger.info(f"[AI Chat] WebSocket connected: {session_id}")
    
    try:
        while True:
            data = await websocket.receive_text()
            logger.info(f"[AI Chat] WebSocket message: {data[:100]}...")
            
            # Process through orchestrator
            result = await agent_orchestrator.process_user_message(
                message=data,
                session_id=session_id
            )
            
            await websocket.send_json({
                "response": result.get("response", ""),
                "session_id": session_id,
                "entities": result.get("entities"),
                "price_calculation": result.get("price_calculation")
            })
            
    except WebSocketDisconnect:
        logger.info(f"[AI Chat] WebSocket disconnected: {session_id}")
        agent_orchestrator.clear_session(session_id)


@router.post("/parse-requirement")
async def parse_requirement(requirement_text: str):
    """
    Parse requirement text and extract entities (standalone endpoint)
    """
    from app.agents.tools import function_tools
    
    logger.info(f"[AI Chat] Parsing requirement: {requirement_text[:100]}...")
    
    try:
        entities = await function_tools.extract_entities(requirement_text)
        return {
            "entities": entities,
            "message": "Requirement parsed successfully"
        }
    except Exception as e:
        logger.error(f"[AI Chat] Parse error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ========== Multimodal Extraction Endpoints ==========
class ExtractResponse(BaseModel):
    """File extraction response model"""
    success: bool
    filename: str
    source_type: Optional[str] = None
    extracted_data: Optional[Dict[str, Any]] = None
    raw_text: Optional[str] = None
    error: Optional[str] = None


@router.post("/extract", response_model=ExtractResponse)
async def extract_from_file(file: UploadFile = File(...)):
    """
    Extract quotation-related information from uploaded file.
    
    Supported file types:
    - Images: PNG, JPG, JPEG, GIF, WEBP, BMP
    - Documents: PDF, DOC, DOCX, TXT
    - Spreadsheets: XLS, XLSX, CSV
    
    Returns extracted structured data including:
    - Products (name, quantity, price)
    - Customer information
    - Dates and validity
    - Total amounts
    """
    logger.info(f"[AI Chat] Extracting from file: {file.filename}, type: {file.content_type}")
    
    try:
        # Read file content
        content = await file.read()
        
        # Extract information
        result = await multimodal_extractor.extract_from_file(
            file_content=content,
            filename=file.filename,
            mime_type=file.content_type
        )
        
        return ExtractResponse(
            success=result.get("success", False),
            filename=file.filename,
            source_type=result.get("source_type"),
            extracted_data=result.get("extracted_data"),
            raw_text=result.get("raw_text"),
            error=result.get("error")
        )
        
    except Exception as e:
        logger.error(f"[AI Chat] Extraction error: {e}")
        return ExtractResponse(
            success=False,
            filename=file.filename,
            error=str(e)
        )


@router.post("/extract-multiple")
async def extract_from_multiple_files(files: List[UploadFile] = File(...)):
    """
    Extract information from multiple files at once.
    
    Returns a list of extraction results, one per file.
    """
    logger.info(f"[AI Chat] Extracting from {len(files)} files")
    
    results = []
    for file in files:
        try:
            content = await file.read()
            result = await multimodal_extractor.extract_from_file(
                file_content=content,
                filename=file.filename,
                mime_type=file.content_type
            )
            results.append(result)
        except Exception as e:
            results.append({
                "success": False,
                "filename": file.filename,
                "error": str(e)
            })
    
    return {
        "total": len(files),
        "successful": sum(1 for r in results if r.get("success")),
        "results": results
    }


@router.get("/supported-types")
async def get_supported_file_types():
    """
    Get list of supported file types for extraction.
    """
    return multimodal_extractor.get_supported_types()
