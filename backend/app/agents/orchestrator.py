"""
Agent Orchestrator
Coordinates AI agents for intelligent quotation workflow
"""
import json
from typing import Dict, Any, List, Optional
from loguru import logger

from app.agents.bailian_client import bailian_client
from app.agents.tools import function_tools
from app.services.session_storage import session_storage


# System prompt for the AI assistant
SYSTEM_PROMPT = """You are an intelligent quotation assistant for Aliyun (Alibaba Cloud) products.

Your role is to:
1. Understand user's product requirements from natural language
2. Extract key entities: product name, type, quantity, duration, usage scenario
3. Estimate usage and calculate prices
4. Provide clear quotation recommendations

When user describes their needs, use the extract_and_respond function to:
- Extract all relevant information
- Calculate estimated costs
- Provide a helpful response

Supported products:
- LLM Models: qwen-max, qwen-plus, qwen-turbo, qwen-long, qwen-vl-max, qwen-vl-plus
- GPU Instances: A10, V100, A100

Always be helpful, professional, and provide accurate pricing information.
"""


class AgentOrchestrator:
    """Agent Orchestrator - coordinates AI workflow for quotation"""
    
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
        # In-memory fallback when Redis is unavailable
        self._memory_fallback: Dict[str, List[Dict]] = {}
    
    async def _get_session_history(self, session_id: str) -> List[Dict[str, str]]:
        """Get session history from Redis or memory fallback"""
        # Try Redis first
        messages = await session_storage.get_session(session_id)
        if messages is not None:
            return messages
        
        # Fallback to memory
        if session_id in self._memory_fallback:
            return self._memory_fallback[session_id]
        
        # New session - initialize with system prompt
        return [{"role": "system", "content": SYSTEM_PROMPT}]
    
    async def _save_session_history(self, session_id: str, messages: List[Dict[str, str]]) -> None:
        """Save session history to Redis with memory fallback"""
        # Try Redis first
        saved = await session_storage.save_session(session_id, messages)
        
        if not saved:
            # Fallback to memory
            self._memory_fallback[session_id] = messages
            logger.warning(f"[Orchestrator] Redis unavailable, using memory fallback for {session_id}")
    
    async def process_user_message(
        self,
        message: str,
        session_id: str
    ) -> Dict[str, Any]:
        """
        Process user message through AI pipeline.
        
        Flow:
        1. Requirement understanding - Extract entities
        2. Product recommendation - Based on requirements
        3. Configuration generation - Generate config params
        4. Price calculation - Calculate final price
        5. Return results
        
        Args:
            message: User input message
            session_id: Session ID for conversation continuity
        
        Returns:
            {
                "response": str,  # AI response
                "entities": dict,  # Extracted entities
                "usage_estimation": dict,  # Usage estimation
                "price_calculation": dict,  # Price calculation
                "error": str  # Error message if any
            }
        """
        logger.info(f"[Orchestrator] Processing message [session={session_id}]: {message[:100]}...")
        
        # Get session history (from Redis or memory)
        messages = await self._get_session_history(session_id)
        
        # Add user message to history
        messages.append({
            "role": "user",
            "content": message
        })
        
        try:
            # Process through AI
            response = await self._process_with_ai(messages, session_id)
            
            # Add AI response to history
            messages.append({
                "role": "assistant",
                "content": response.get("response", "")
            })
            
            # Save updated history
            await self._save_session_history(session_id, messages)
            
            return response
        
        except Exception as e:
            logger.error(f"[Orchestrator] Error processing message: {e}")
            # Still save the user message
            await self._save_session_history(session_id, messages)
            return {
                "response": f"Sorry, an error occurred while processing your request: {str(e)}",
                "error": str(e)
            }
    
    async def _process_with_ai(
        self,
        messages: List[Dict[str, str]],
        session_id: str
    ) -> Dict[str, Any]:
        """Process message through AI with function calling"""
        
        # Get tool definitions
        tools = function_tools.get_tool_definitions()
        
        # Call AI API
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
        
        # Handle Function Call response
        if ai_response.get("function_call"):
            function_call = ai_response["function_call"]
            function_name = function_call["name"]
            
            try:
                arguments = json.loads(function_call["arguments"])
            except json.JSONDecodeError as e:
                logger.error(f"[Orchestrator] Failed to parse function arguments: {e}")
                result["response"] = "Failed to parse AI response. Please try again."
                return result
            
            logger.info(f"[Orchestrator] Executing function: {function_name}")
            
            # Execute the function
            function_result = await function_tools.execute_function(
                function_name,
                arguments
            )
            
            # Process function result based on function type
            if function_name == "extract_and_respond":
                result["entities"] = function_result.get("entities")
                result["price_calculation"] = function_result.get("price_calculation")
                result["response"] = self._generate_quotation_response(function_result)
            
            elif function_name == "extract_entities":
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
        
        # Regular text response (no function call)
        else:
            result["response"] = ai_response.get("content", "")
        
        return result
    
    def _generate_quotation_response(self, function_result: Dict[str, Any]) -> str:
        """Generate response from extract_and_respond result"""
        entities = function_result.get("entities", {})
        price_calc = function_result.get("price_calculation", {})
        
        parts = ["Based on your requirements, here is the quotation:\n"]
        
        # Product info
        if entities.get("product_name"):
            parts.append(f"**Product**: {entities['product_name']}")
        if entities.get("use_case"):
            parts.append(f"**Use Case**: {entities['use_case']}")
        
        # Price info
        parts.append("\n**Pricing**:")
        if price_calc.get("final_price"):
            parts.append(f"- Estimated Price: \u00a5{price_calc['final_price']:,.2f}")
        
        parts.append("\nWould you like to generate a formal quotation document?")
        
        return "\n".join(parts)
    
    def _generate_entity_response(self, entities: Dict[str, Any]) -> str:
        """Generate response after entity extraction"""
        parts = ["I understand your requirements as follows:\n"]
        
        if entities.get("product_name"):
            parts.append(f"- **Product**: {entities['product_name']}")
        
        if entities.get("product_type"):
            parts.append(f"- **Type**: {entities['product_type']}")
        
        if entities.get("quantity"):
            parts.append(f"- **Quantity**: {entities['quantity']}")
        
        if entities.get("duration_months"):
            parts.append(f"- **Duration**: {entities['duration_months']} months")
        
        if entities.get("use_case"):
            parts.append(f"- **Use Case**: {entities['use_case']}")
        
        if entities.get("call_frequency"):
            parts.append(f"- **Monthly Calls**: {entities['call_frequency']:,}")
        
        parts.append("\nPlease confirm if this is correct. I can then provide a detailed quotation.")
        
        return "\n".join(parts)
    
    def _generate_price_response(self, price_result: Dict[str, Any]) -> str:
        """Generate response after price calculation"""
        original = price_result.get("original_price", 0)
        final = price_result.get("final_price", 0)
        
        response = [
            "Based on your requirements, here is the price calculation:",
            f"**Original Price**: \u00a5{original:,.2f}",
            f"**Final Price**: \u00a5{final:,.2f}",
        ]
        
        if price_result.get("discount_details"):
            response.append("\n**Applied Discounts**:")
            for detail in price_result["discount_details"]:
                response.append(f"  - {detail}")
        
        response.append("\nWould you like to generate a formal quotation document?")
        
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
        """Clear session conversation history"""
        import asyncio
        
        # Try to delete from Redis
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.create_task(session_storage.delete_session(session_id))
            else:
                loop.run_until_complete(session_storage.delete_session(session_id))
        except Exception as e:
            logger.warning(f"[Orchestrator] Failed to delete Redis session: {e}")
        
        # Also clear from memory fallback
        if session_id in self._memory_fallback:
            del self._memory_fallback[session_id]
        
        logger.info(f"[Orchestrator] Session cleared: {session_id}")
    
    async def clear_session_async(self, session_id: str):
        """Clear session conversation history (async version)"""
        await session_storage.delete_session(session_id)
        
        if session_id in self._memory_fallback:
            del self._memory_fallback[session_id]
        
        logger.info(f"[Orchestrator] Session cleared: {session_id}")


# 创建全局编排器实例
agent_orchestrator = AgentOrchestrator()
