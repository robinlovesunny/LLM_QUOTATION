"""
百炼API客户端封装
"""
import dashscope
from typing import Dict, Any, List, Optional
from loguru import logger

from app.core.config import settings

# 配置API Key
dashscope.api_key = settings.DASHSCOPE_API_KEY


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
        try:
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
            else:
                response = Generation.call(**kwargs)
                return self._parse_response(response)
        
        except Exception as e:
            logger.error(f"百炼API调用失败: {e}")
            raise
    
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
        
        try:
            output = getattr(response, "output", None)
            if output is None:
                return result
            
            logger.debug(f"Output type: {type(output)}")
            
            # 获取choices
            choices = getattr(output, "choices", None)
            if choices is None and isinstance(output, dict):
                choices = output.get("choices")
            
            if not choices:
                # 检查是否有直接的text响应
                text = getattr(output, "text", None)
                if text:
                    result["content"] = text
                return result
            
            choice = choices[0]
            logger.debug(f"Choice type: {type(choice)}")
            
            # 安全获取message
            message = getattr(choice, "message", None)
            if message is None and isinstance(choice, dict):
                message = choice.get("message", {})
            if message is None:
                message = {}
            
            logger.debug(f"Message type: {type(message)}")
            
            # 获取content - 使用getattr和get的组合
            content = getattr(message, "content", None)
            if content is None and isinstance(message, dict):
                content = message.get("content")
            if content:
                result["content"] = content
            
            # 获取tool_calls - 使用安全方式
            tool_calls = None
            try:
                tool_calls = getattr(message, "tool_calls", None)
            except (KeyError, AttributeError):
                pass
            
            if tool_calls is None and isinstance(message, dict):
                tool_calls = message.get("tool_calls")
            
            if tool_calls:
                tool_call = tool_calls[0]
                logger.debug(f"Tool call type: {type(tool_call)}")
                
                # 获取function
                func = getattr(tool_call, "function", None)
                if func is None and isinstance(tool_call, dict):
                    func = tool_call.get("function", {})
                
                if func:
                    func_name = getattr(func, "name", None)
                    if func_name is None and isinstance(func, dict):
                        func_name = func.get("name")
                    
                    func_args = getattr(func, "arguments", None)
                    if func_args is None and isinstance(func, dict):
                        func_args = func.get("arguments")
                    
                    if func_name:
                        result["function_call"] = {
                            "name": func_name,
                            "arguments": func_args
                        }
            
            # 获取finish_reason
            finish_reason = getattr(choice, "finish_reason", None)
            if finish_reason is None and isinstance(choice, dict):
                finish_reason = choice.get("finish_reason")
            result["finish_reason"] = finish_reason
        
        except Exception as e:
            logger.error(f"Error parsing response: {e}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            raise
        
        logger.debug(f"Parsed response: content_len={len(result.get('content') or '')}, has_function_call={result.get('function_call') is not None}")
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
