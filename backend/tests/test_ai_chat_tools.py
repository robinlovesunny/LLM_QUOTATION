"""
Unit tests for AI Chat tools and orchestrator
"""
import pytest
from decimal import Decimal
from unittest.mock import AsyncMock, patch, MagicMock

from app.agents.tools import FunctionTools, function_tools
from app.services.pricing_engine import pricing_engine


class TestFunctionTools:
    """Tests for FunctionTools class"""
    
    def test_get_tool_definitions(self):
        """Test that tool definitions are properly formatted"""
        tools = FunctionTools.get_tool_definitions()
        
        assert isinstance(tools, list)
        assert len(tools) == 3
        
        # Check tool names
        tool_names = [t["name"] for t in tools]
        assert "extract_and_respond" in tool_names
        assert "estimate_llm_usage" in tool_names
        assert "calculate_price" in tool_names
        
        # Check each tool has required fields
        for tool in tools:
            assert "name" in tool
            assert "description" in tool
            assert "parameters" in tool
            assert "properties" in tool["parameters"]
    
    @pytest.mark.asyncio
    async def test_extract_entities_llm_product(self):
        """Test entity extraction for LLM products"""
        text = "我需要用qwen-max做客服对话，预计每月100万次调用"
        entities = await FunctionTools.extract_entities(text)
        
        assert entities["product_name"] == "qwen-max"
        assert entities["product_type"] == "llm"
        assert entities["call_frequency"] == 1000000
        assert entities["use_case"] == "customer_service"
    
    @pytest.mark.asyncio
    async def test_extract_entities_gpu_product(self):
        """Test entity extraction for GPU products"""
        text = "需要100张A10卡训练3个月"
        entities = await FunctionTools.extract_entities(text)
        
        assert entities["product_name"] == "a10"
        assert entities["product_type"] == "gpu"
        assert entities["quantity"] == 100
        assert entities["duration_months"] == 3
        assert entities["use_case"] == "training"
    
    @pytest.mark.asyncio
    async def test_extract_entities_partial_info(self):
        """Test entity extraction with partial information"""
        text = "我想了解qwen-plus的价格"
        entities = await FunctionTools.extract_entities(text)
        
        assert entities["product_name"] == "qwen-plus"
        assert entities["product_type"] == "llm"
    
    def test_get_product_price_llm(self):
        """Test getting LLM product prices"""
        price = FunctionTools._get_product_price("qwen-max", "llm")
        
        assert "input_price" in price
        assert "output_price" in price
        assert price["input_price"] == 0.02
        assert price["output_price"] == 0.06
    
    def test_get_product_price_gpu(self):
        """Test getting GPU product prices"""
        price = FunctionTools._get_product_price("a10", "gpu")
        
        assert "unit_price" in price
        assert price["unit_price"] == 15.0
    
    def test_get_product_price_unknown(self):
        """Test getting price for unknown product"""
        price = FunctionTools._get_product_price("unknown-product", "llm")
        
        # Should return default price
        assert "input_price" in price
    
    @pytest.mark.asyncio
    async def test_estimate_llm_usage_customer_service(self):
        """Test usage estimation for customer service scenario"""
        usage = await FunctionTools.estimate_llm_usage("客服对话", "normal")
        
        assert usage["recommended_model"] == "qwen-turbo"
        assert usage["thinking_mode_ratio"] == 0.0
        assert "recommendation" in usage
    
    @pytest.mark.asyncio
    async def test_estimate_llm_usage_content_generation(self):
        """Test usage estimation for content generation"""
        usage = await FunctionTools.estimate_llm_usage("content generation", "high frequency")
        
        assert usage["recommended_model"] == "qwen-plus"
        assert usage["thinking_mode_ratio"] > 0
    
    @pytest.mark.asyncio
    async def test_estimate_llm_usage_high_workload(self):
        """Test that high workload increases call frequency"""
        normal = await FunctionTools.estimate_llm_usage("客服", "normal")
        high = await FunctionTools.estimate_llm_usage("客服", "高频")
        
        assert high["call_frequency"] > normal["call_frequency"]
    
    @pytest.mark.asyncio
    async def test_extract_and_respond_llm(self):
        """Test extract_and_respond for LLM product"""
        result = await FunctionTools.extract_and_respond(
            product_name="qwen-max",
            product_type="llm",
            use_case="content generation",
            call_frequency=10000,
            duration_months=1
        )
        
        assert "entities" in result
        assert "price_calculation" in result
        assert "summary" in result
        assert result["entities"]["product_name"] == "qwen-max"
    
    @pytest.mark.asyncio
    async def test_extract_and_respond_gpu(self):
        """Test extract_and_respond for GPU product"""
        result = await FunctionTools.extract_and_respond(
            product_name="a10",
            product_type="gpu",
            quantity=10,
            duration_months=3
        )
        
        assert "entities" in result
        assert "price_calculation" in result
        assert result["entities"]["quantity"] == 10
    
    @pytest.mark.asyncio
    async def test_calculate_price_llm(self):
        """Test price calculation for LLM product"""
        result = await FunctionTools.calculate_price(
            product_type="llm",
            product_name="qwen-max",
            context={
                "input_tokens": 700000,
                "output_tokens": 300000
            }
        )
        
        assert "final_price" in result
        assert "original_price" in result
        assert result["product_name"] == "qwen-max"
    
    @pytest.mark.asyncio
    async def test_calculate_price_standard(self):
        """Test price calculation for standard product"""
        result = await FunctionTools.calculate_price(
            product_type="standard",
            product_name="a10",
            context={
                "quantity": 10,
                "duration_months": 1
            }
        )
        
        assert "final_price" in result
        assert result["final_price"] > 0
    
    @pytest.mark.asyncio
    async def test_execute_function_valid(self):
        """Test executing a valid function"""
        result = await FunctionTools.execute_function(
            "extract_entities",
            {"text": "需要qwen-max"}
        )
        
        assert isinstance(result, dict)
    
    @pytest.mark.asyncio
    async def test_execute_function_invalid(self):
        """Test executing an invalid function"""
        with pytest.raises(ValueError, match="Unknown function"):
            await FunctionTools.execute_function(
                "nonexistent_function",
                {}
            )


class TestPricingEngineIntegration:
    """Tests for pricing engine integration"""
    
    def test_llm_token_pricing(self):
        """Test LLM token-based pricing"""
        result = pricing_engine.calculate(
            Decimal("0.02"),
            {
                "product_type": "llm",
                "input_token_price": 0.02,
                "output_token_price": 0.06,
                "input_tokens": 700000,
                "output_tokens": 300000
            }
        )
        
        assert "final_price" in result
        assert result["final_price"] > 0
    
    def test_standard_pricing(self):
        """Test standard quantity-based pricing"""
        result = pricing_engine.calculate(
            Decimal("100"),
            {
                "product_type": "standard",
                "quantity": 10,
                "duration_months": 3
            }
        )
        
        # 100 * 10 * 3 = 3000
        assert result["final_price"] == 3000.0
    
    def test_pricing_with_thinking_mode(self):
        """Test pricing with thinking mode multiplier"""
        base_result = pricing_engine.calculate(
            Decimal("0.01"),
            {
                "product_type": "llm",
                "input_token_price": 0.01,
                "output_token_price": 0.03,
                "input_tokens": 1000,
                "output_tokens": 1000,
                "thinking_mode_ratio": 0.0
            }
        )
        
        thinking_result = pricing_engine.calculate(
            Decimal("0.01"),
            {
                "product_type": "llm",
                "input_token_price": 0.01,
                "output_token_price": 0.03,
                "input_tokens": 1000,
                "output_tokens": 1000,
                "thinking_mode_ratio": 0.5,
                "thinking_mode_multiplier": 1.5
            }
        )
        
        # Thinking mode should increase price
        assert thinking_result["final_price"] > base_result["final_price"]
