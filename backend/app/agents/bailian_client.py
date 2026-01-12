"""
百炼API客户端封装
"""
import dashscope
import time
from typing import Dict, Any, List, Optional
from loguru import logger

from app.core.config import settings

# 配置API Key
dashscope.api_key = settings.DASHSCOPE_API_KEY

# Retry configuration
MAX_RETRIES = 3
RETRY_DELAY = 1  # seconds


class BailianClient:
    """百炼API客户端"""
    
    def __init__(self, model: str = None):
        self.model = model or settings.BAILIAN_MODEL
    
    async def chat(
        self,
        messages: List[Dict[str, str]],
        functions: Optional[List[Dict[str, Any]]] = None,
        stream: bool = False
    ) -> Dict[str, Any]:
        """
        对话接口
        
        Args:
            messages: 对话消息列表
            functions: Function Calling工具定义
            stream: 是否流式返回
        
        Returns:
            模型响应
        """
        from dashscope import Generation
        
        kwargs = {
            "model": self.model,
            "messages": messages,
            "result_format": "message"
        }
        
        if functions:
            kwargs["tools"] = [{
                "type": "function",
                "function": func
            } for func in functions]
        
        if stream:
            return await self._chat_stream(**kwargs)
        
        # Retry logic for non-stream calls
        last_error = None
        for attempt in range(MAX_RETRIES):
            try:
                response = Generation.call(**kwargs)
                return self._parse_response(response)
            except Exception as e:
                last_error = e
                error_str = str(e)
                # Retry on SSL/network errors
                if "SSL" in error_str or "Connection" in error_str or "timeout" in error_str.lower():
                    logger.warning(f"百炼API网络错误 (attempt {attempt + 1}/{MAX_RETRIES}): {e}")
                    if attempt < MAX_RETRIES - 1:
                        time.sleep(RETRY_DELAY * (attempt + 1))
                        continue
                # Don't retry on other errors
                logger.error(f"百炼API调用失败: {e}")
                raise
        
        logger.error(f"百炼API调用失败 (已重试{MAX_RETRIES}次): {last_error}")
        raise last_error
    
    async def _chat_stream(self, **kwargs):
        """流式对话"""
        from dashscope import Generation
        
        responses = Generation.call(stream=True, **kwargs)
        for response in responses:
            if response.status_code == 200:
                yield self._parse_response(response)
            else:
                logger.error(f"流式响应错误: {response}")
                break
    
    def _parse_response(self, response) -> Dict[str, Any]:
        """解析响应"""
        if response.status_code != 200:
            raise Exception(f"API调用失败: {response.message}")
        
        result = {
            "content": "",
            "function_call": None,
            "finish_reason": None
        }
        
        if hasattr(response, "output"):
            output = response.output
            
            if hasattr(output, "choices") and output.choices:
                choice = output.choices[0]
                message = choice.message
                
                # 普通文本响应
                if hasattr(message, "content") and message.content:
                    result["content"] = message.content
                elif isinstance(message, dict) and message.get("content"):
                    result["content"] = message["content"]
                
                # Function Call响应 - handle both object and dict formats
                tool_calls = None
                if hasattr(message, "tool_calls"):
                    tool_calls = message.tool_calls
                elif isinstance(message, dict) and message.get("tool_calls"):
                    tool_calls = message["tool_calls"]
                
                if tool_calls:
                    tool_call = tool_calls[0]
                    # Handle object format
                    if hasattr(tool_call, "function"):
                        result["function_call"] = {
                            "name": tool_call.function.name,
                            "arguments": tool_call.function.arguments
                        }
                    # Handle dict format
                    elif isinstance(tool_call, dict) and "function" in tool_call:
                        func = tool_call["function"]
                        result["function_call"] = {
                            "name": func.get("name", ""),
                            "arguments": func.get("arguments", "{}")
                        }
                
                if hasattr(choice, "finish_reason"):
                    result["finish_reason"] = choice.finish_reason
        
        return result
    
    async def embed_text(self, text: str) -> List[float]:
        """
        文本向量化
        
        Args:
            text: 输入文本
        
        Returns:
            向量表示
        """
        try:
            from dashscope import TextEmbedding
            
            response = TextEmbedding.call(
                model=TextEmbedding.Models.text_embedding_v1,
                input=text
            )
            
            if response.status_code == 200:
                return response.output.embeddings[0].embedding
            else:
                raise Exception(f"向量化失败: {response.message}")
        
        except Exception as e:
            logger.error(f"文本向量化失败: {e}")
            raise


# 创建全局客户端实例
bailian_client = BailianClient()
