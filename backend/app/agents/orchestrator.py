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
