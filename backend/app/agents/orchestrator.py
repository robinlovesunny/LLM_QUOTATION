"""
Agent编排器
协调多个Agent完成智能报价流程
"""
import json
from typing import Dict, Any, List
from loguru import logger

from app.agents.bailian_client import bailian_client
from app.agents.tools import function_tools


class AgentOrchestrator:
    """Agent编排器"""
    
    def __init__(self):
        self.conversation_history: Dict[str, List[Dict]] = {}
    
    async def process_user_message(
        self,
        message: str,
        session_id: str
    ) -> Dict[str, Any]:
        """
        处理用户消息
        
        流程:
        1. 需求理解 - 提取实体信息
        2. 产品推荐 - 根据需求推荐产品
        3. 配置生成 - 生成配置参数
        4. 价格计算 - 计算价格
        5. 返回结果
        
        Args:
            message: 用户输入消息
            session_id: 会话ID
        
        Returns:
            {
                "response": str,  # AI回复
                "entities": dict,  # 提取的实体
                "products": list,  # 推荐的产品
                "price_estimation": dict,  # 价格估算
                "next_step": str  # 下一步操作建议
            }
        """
        logger.info(f"处理用户消息 [session={session_id}]: {message}")
        
        # 初始化会话历史
        if session_id not in self.conversation_history:
            self.conversation_history[session_id] = []
        
        # 添加用户消息到历史
        self.conversation_history[session_id].append({
            "role": "user",
            "content": message
        })
        
        try:
            # Step 1: 调用AI进行需求理解
            response = await self._understand_requirement(message, session_id)
            
            # 添加AI响应到历史
            self.conversation_history[session_id].append({
                "role": "assistant",
                "content": response["response"]
            })
            
            return response
        
        except Exception as e:
            logger.error(f"处理消息失败: {e}")
            return {
                "response": f"抱歉,处理您的请求时出现错误: {str(e)}",
                "error": str(e)
            }
    
    async def _understand_requirement(
        self,
        message: str,
        session_id: str
    ) -> Dict[str, Any]:
        """需求理解阶段"""
        
        # 准备对话消息
        messages = self.conversation_history[session_id]
        
        # 获取Function Calling工具定义
        tools = function_tools.get_tool_definitions()
        
        # 调用百炼API
        ai_response = await bailian_client.chat(
            messages=messages,
            functions=tools
        )
        
        result = {
            "response": "",
            "entities": None,
            "usage_estimation": None,
            "price_calculation": None
        }
        
        # 处理Function Call
        if ai_response.get("function_call"):
            function_call = ai_response["function_call"]
            function_name = function_call["name"]
            arguments = json.loads(function_call["arguments"])
            
            logger.info(f"执行Function: {function_name}({arguments})")
            
            # 执行工具函数
            function_result = await function_tools.execute_function(
                function_name,
                arguments
            )
            
            # 根据不同的工具调用,填充结果
            if function_name == "extract_entities":
                result["entities"] = function_result
                result["response"] = self._generate_entity_response(function_result)
            
            elif function_name == "estimate_llm_usage":
                result["usage_estimation"] = function_result
                result["response"] = function_result.get("recommendation", "")
            
            elif function_name == "calculate_price":
                result["price_calculation"] = function_result
                result["response"] = self._generate_price_response(function_result)
        
        # 普通对话响应
        else:
            result["response"] = ai_response.get("content", "")
        
        return result
    
    def _generate_entity_response(self, entities: Dict[str, Any]) -> str:
        """生成实体提取后的响应"""
        parts = ["我理解您的需求如下:"]
        
        if entities.get("product"):
            parts.append(f"- 产品类型: {entities['product']}")
        
        if entities.get("quantity"):
            parts.append(f"- 数量: {entities['quantity']}")
        
        if entities.get("duration"):
            parts.append(f"- 使用时长: {entities['duration']}个月")
        
        if entities.get("usage_pattern"):
            parts.append(f"- 使用场景: {entities['usage_pattern']}")
        
        parts.append("\n请确认以上信息是否正确?我将为您推荐合适的产品配置。")
        
        return "\n".join(parts)
    
    def _generate_price_response(self, price_result: Dict[str, Any]) -> str:
        """生成价格计算后的响应"""
        original = price_result.get("original_price", 0)
        final = price_result.get("final_price", 0)
        
        response = [
            f"根据您的需求,我为您计算的价格如下:",
            f"原始价格: ¥{original:,.2f}",
            f"最终价格: ¥{final:,.2f}",
        ]
        
        if price_result.get("discount_details"):
            response.append("\n应用的优惠:")
            for detail in price_result["discount_details"]:
                response.append(f"  - {detail}")
        
        response.append("\n是否需要生成完整的报价单?")
        
        return "\n".join(response)
    
    def clear_session(self, session_id: str):
        """清除会话历史"""
        if session_id in self.conversation_history:
            del self.conversation_history[session_id]
            logger.info(f"已清除会话: {session_id}")


# 创建全局编排器实例
agent_orchestrator = AgentOrchestrator()
