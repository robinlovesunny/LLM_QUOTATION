"""
Integration tests for AI Chat API endpoints
"""
import pytest
from httpx import AsyncClient, ASGITransport
from unittest.mock import AsyncMock, patch, MagicMock

# Import the FastAPI app
import sys
sys.path.insert(0, "/Users/chengpeng/MyProject/LLM_QUOTATION/backend")


class TestAIChatAPIIntegration:
    """Integration tests for AI Chat API"""
    
    @pytest.fixture
    def mock_bailian_response(self):
        """Mock response from Bailian API"""
        return {
            "content": "",
            "function_call": {
                "name": "extract_and_respond",
                "arguments": '{"product_name": "qwen-max", "product_type": "llm", "use_case": "customer service", "call_frequency": 100000}'
            },
            "finish_reason": "function_call"
        }
    
    @pytest.fixture
    def mock_bailian_text_response(self):
        """Mock text response from Bailian API"""
        return {
            "content": "Hello! How can I help you with your quotation needs?",
            "function_call": None,
            "finish_reason": "stop"
        }
    
    @pytest.mark.asyncio
    async def test_chat_endpoint_with_function_call(self, mock_bailian_response):
        """Test chat endpoint with function calling"""
        from main import app
        
        with patch('app.agents.bailian_client.bailian_client.chat', new_callable=AsyncMock) as mock_chat:
            mock_chat.return_value = mock_bailian_response
            
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post(
                    "/api/v1/ai/chat",
                    json={
                        "message": "I need qwen-max for customer service, about 100k calls per month",
                        "session_id": "test_integration_001"
                    }
                )
                
                assert response.status_code == 200
                data = response.json()
                
                assert "response" in data
                assert "session_id" in data
                assert data["session_id"] == "test_integration_001"
                
                # Should have entities and price calculation
                assert data.get("entities") is not None or data.get("price_calculation") is not None
    
    @pytest.mark.asyncio
    async def test_chat_endpoint_text_response(self, mock_bailian_text_response):
        """Test chat endpoint with regular text response"""
        from main import app
        
        with patch('app.agents.bailian_client.bailian_client.chat', new_callable=AsyncMock) as mock_chat:
            mock_chat.return_value = mock_bailian_text_response
            
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post(
                    "/api/v1/ai/chat",
                    json={
                        "message": "Hello",
                        "session_id": "test_integration_002"
                    }
                )
                
                assert response.status_code == 200
                data = response.json()
                
                assert data["response"] == "Hello! How can I help you with your quotation needs?"
    
    @pytest.mark.asyncio
    async def test_chat_endpoint_generates_session_id(self, mock_bailian_text_response):
        """Test that chat endpoint generates session_id if not provided"""
        from main import app
        
        with patch('app.agents.bailian_client.bailian_client.chat', new_callable=AsyncMock) as mock_chat:
            mock_chat.return_value = mock_bailian_text_response
            
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post(
                    "/api/v1/ai/chat",
                    json={"message": "Hello"}
                )
                
                assert response.status_code == 200
                data = response.json()
                
                # Should have auto-generated session_id
                assert "session_id" in data
                assert data["session_id"].startswith("session_")
    
    @pytest.mark.asyncio
    async def test_chat_endpoint_validation_error(self):
        """Test chat endpoint with invalid input"""
        from main import app
        
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            # Empty message should fail validation
            response = await client.post(
                "/api/v1/ai/chat",
                json={"message": ""}
            )
            
            assert response.status_code == 422  # Validation error
    
    @pytest.mark.asyncio
    async def test_clear_session_endpoint(self):
        """Test clear session endpoint"""
        from main import app
        
        with patch('app.services.session_storage.session_storage.delete_session', new_callable=AsyncMock) as mock_delete:
            mock_delete.return_value = True
            
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post(
                    "/api/v1/ai/clear-session",
                    json={"session_id": "test_session_to_clear"}
                )
                
                assert response.status_code == 200
                data = response.json()
                
                assert data["message"] == "Session cleared successfully"
                assert data["session_id"] == "test_session_to_clear"
    
    @pytest.mark.asyncio
    async def test_parse_requirement_endpoint(self):
        """Test parse requirement endpoint"""
        from main import app
        
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/api/v1/ai/parse-requirement",
                params={"requirement_text": "需要100张A10卡训练3个月"}
            )
            
            assert response.status_code == 200
            data = response.json()
            
            assert "entities" in data
            assert data["message"] == "Requirement parsed successfully"
            
            entities = data["entities"]
            assert entities["product_name"] == "a10"
            assert entities["product_type"] == "gpu"
            assert entities["quantity"] == 100
            assert entities["duration_months"] == 3


class TestOrchestratorIntegration:
    """Integration tests for AgentOrchestrator"""
    
    @pytest.mark.asyncio
    async def test_orchestrator_full_flow(self):
        """Test full orchestrator flow with mocked AI"""
        from app.agents.orchestrator import AgentOrchestrator
        
        orchestrator = AgentOrchestrator()
        
        mock_response = {
            "content": "",
            "function_call": {
                "name": "extract_and_respond",
                "arguments": '{"product_name": "qwen-plus", "product_type": "llm", "call_frequency": 50000}'
            }
        }
        
        with patch('app.agents.bailian_client.bailian_client.chat', new_callable=AsyncMock) as mock_chat:
            mock_chat.return_value = mock_response
            
            result = await orchestrator.process_user_message(
                message="I need qwen-plus for about 50k monthly calls",
                session_id="test_orch_001"
            )
            
            assert "response" in result
            assert result.get("entities") is not None
            assert result["entities"]["product_name"] == "qwen-plus"
    
    @pytest.mark.asyncio
    async def test_orchestrator_session_continuity(self):
        """Test session continuity across messages"""
        from app.agents.orchestrator import AgentOrchestrator
        
        orchestrator = AgentOrchestrator()
        session_id = "test_continuity_002"  # Use unique session ID
        
        mock_response = {
            "content": "I understand you need qwen-max.",
            "function_call": None
        }
        
        with patch('app.agents.bailian_client.bailian_client.chat', new_callable=AsyncMock) as mock_chat:
            mock_chat.return_value = mock_response
            
            # First message
            await orchestrator.process_user_message(
                message="I need qwen-max",
                session_id=session_id
            )
            
            # Second message - should include history
            await orchestrator.process_user_message(
                message="For customer service",
                session_id=session_id
            )
            
            # Check that chat was called twice
            assert mock_chat.call_count == 2
            
            # Get messages from last call - should contain full history
            last_call_messages = mock_chat.call_args_list[-1][1]["messages"]
            
            # Should have: system + user1 + assistant1 + user2 = 4 messages
            # (The assistant response from first call should be in history)
            assert len(last_call_messages) >= 4
            
            # Verify message types in history
            roles = [m["role"] for m in last_call_messages]
            assert "system" in roles
            assert roles.count("user") >= 2  # At least 2 user messages
            assert "assistant" in roles  # Should have previous assistant response
    
    @pytest.mark.asyncio
    async def test_orchestrator_error_handling(self):
        """Test error handling in orchestrator"""
        from app.agents.orchestrator import AgentOrchestrator
        
        orchestrator = AgentOrchestrator()
        
        with patch('app.agents.bailian_client.bailian_client.chat', new_callable=AsyncMock) as mock_chat:
            mock_chat.side_effect = Exception("API connection failed")
            
            result = await orchestrator.process_user_message(
                message="Test message",
                session_id="test_error_001"
            )
            
            assert "error" in result
            assert "API connection failed" in result["response"]
