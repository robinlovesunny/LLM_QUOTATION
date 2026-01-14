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
    
    SYSTEM_PROMPT = """You are "报价侠小助手", an intelligent AI assistant for cloud product quotation.

You help users complete the entire quotation process through conversation:
1. Understand user needs (use case, scale, budget)
2. Recommend suitable models (recommend_model)
3. Calculate costs (calculate_monthly_cost)
4. Generate quote items (generate_quote_item)
5. Create quote summary (create_quote_summary)

**CONVERSATION FLOW:**
1. First, ask about their use case if not clear
2. Then recommend models based on their needs
3. Ask about expected usage volume (daily calls)
4. Calculate and show costs
5. When user confirms, generate quote item
6. Ask if they want to add more products or finalize

**IMPORTANT RULES:**
- Always respond in Chinese
- Be proactive in guiding the conversation
- When user says "添加", "加入报价单", "就这个", use generate_quote_item tool
- When user asks "查看报价单", "总价", use create_quote_summary tool
- Provide specific numbers and options
- Keep responses concise but informative

**QUICK OPTIONS (suggest these to user):**
- When asking use case: "智能客服", "内容创作", "代码助手", "数据分析"
- When asking volume: "每天100次", "每天1000次", "每天1万次", "每天10万次"
- After showing cost: "添加到报价单", "换个模型", "调整用量"

**MODEL PRICING:**
- qwen-max: Best quality. Input: 0.02元/千token, Output: 0.06元/千token
- qwen-plus: Balanced. Input: 0.008元/千token, Output: 0.024元/千token  
- qwen-turbo: Economical. Input: 0.0003元/千token, Output: 0.003元/千token
"""
    
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
            self.conversation_history[session_id] = [
                {"role": "system", "content": self.SYSTEM_PROMPT}
            ]
        
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
            
            elif function_name in ["search_models", "get_model_price", "calculate_monthly_cost", "recommend_model", "generate_quote_item", "create_quote_summary"]:
                # 产品查询和报价工具
                result["response"] = self._generate_tool_response(function_name, function_result)
                logger.info(f"Function result for {function_name}: success={function_result.get('success')}, has_quote_item={function_result.get('quote_item') is not None}")
                # 保留原始数据给前端处理
                if function_name == "generate_quote_item" and function_result.get("success"):
                    result["quote_item"] = function_result.get("quote_item")
                    result["action"] = "add_to_quote"
                    logger.info(f"Added quote_item to result: {result.get('quote_item') is not None}")
                elif function_name == "create_quote_summary" and function_result.get("success"):
                    result["quote_summary"] = function_result.get("quote")
                    result["action"] = "show_quote_summary"
        
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
    
    def _generate_tool_response(self, function_name: str, result: Dict[str, Any]) -> str:
        """生成工具调用结果的响应"""
        if function_name == "search_models":
            if not result.get("models"):
                return "未找到匹配的模型，请尝试其他关键词。"
            
            parts = [f"找到 {result['found']} 个模型："]
            for m in result["models"]:
                price_info = ""
                if m.get("input_price"):
                    price_info = f"，输入: {m['input_price']}元/{m['unit']}"
                    if m.get("output_price"):
                        price_info += f"，输出: {m['output_price']}元/{m['unit']}"
                parts.append(f"- **{m['model_name']}** ({m['category']}){price_info}")
            return "\n".join(parts)
        
        elif function_name == "get_model_price":
            if not result.get("found"):
                return result.get("message", "未找到该模型")
            return result.get("message", "")
        
        elif function_name == "calculate_monthly_cost":
            if "error" in result:
                return f"计算失败: {result.get('message', result.get('error'))}"
            return (
                f"💰 **月费用估算**\n\n"
                f"模型: {result['model_name']}\n"
                f"日调用量: {result['daily_calls']:,} 次\n"
                f"月调用量: {result['monthly_calls']:,} 次\n"
                f"平均输入: {result['avg_input_tokens']} tokens\n"
                f"平均输出: {result['avg_output_tokens']} tokens\n\n"
                f"输入费用: ¥{result['input_cost']:,.2f}\n"
                f"输出费用: ¥{result['output_cost']:,.2f}\n"
                f"**总计: ¥{result['total_monthly_cost']:,.2f}/月**"
            )
        
        elif function_name == "recommend_model":
            if not result.get("recommendations"):
                return f"暂无针对'{result['use_case']}'场景的推荐模型"
            
            parts = [f"🌟 **针对'{result['use_case']}'场景的推荐**\n"]
            for i, m in enumerate(result["recommendations"], 1):
                pricing = m.get("pricing", {})
                parts.append(
                    f"{i}. **{m['model_name']}**\n"
                    f"   - 输入价格: {pricing.get('input_price', 'N/A')}元/{pricing.get('unit', '千Token')}\n"
                    f"   - 输出价格: {pricing.get('output_price', 'N/A')}元/{pricing.get('unit', '千Token')}\n"
                    f"   - 推荐理由: {m.get('recommendation_reason', '')}"
                )
            parts.append("\n需要我帮您计算具体费用吗？")
            return "\n".join(parts)
        
        elif function_name == "generate_quote_item":
            if not result.get("success"):
                return f"生成报价项失败: {result.get('error', '未知错误')}"
            return result.get("message", "") + "\n\n要继续添加其他产品，还是查看报价单？"
        
        elif function_name == "create_quote_summary":
            if not result.get("success"):
                return result.get("message", "报价单为空")
            return result.get("message", "") + "\n\n是否确认并导出报价单？"
        
        return json.dumps(result, ensure_ascii=False, indent=2)
    
    def clear_session(self, session_id: str):
        """清除会话历史"""
        if session_id in self.conversation_history:
            del self.conversation_history[session_id]
            logger.info(f"已清除会话: {session_id}")


# 创建全局编排器实例
agent_orchestrator = AgentOrchestrator()
