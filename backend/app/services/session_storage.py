"""
Session Storage Service
Provides Redis-based persistent storage for conversation sessions
"""
import json
from typing import Dict, Any, List, Optional
from loguru import logger

from app.core.redis_client import get_redis


# Session configuration
SESSION_TTL = 1800  # 30 minutes TTL
SESSION_PREFIX = "chat_session:"


class SessionStorage:
    """Redis-based session storage for conversation history"""
    
    @staticmethod
    async def get_session(session_id: str) -> Optional[List[Dict[str, str]]]:
        """
        Get conversation history for a session.
        
        Args:
            session_id: Session identifier
            
        Returns:
            List of message dicts or None if not found
        """
        try:
            redis = await get_redis()
            if redis is None:
                logger.warning("[SessionStorage] Redis not available, returning None")
                return None
            
            key = f"{SESSION_PREFIX}{session_id}"
            data = await redis.get(key)
            
            if data:
                messages = json.loads(data)
                logger.debug(f"[SessionStorage] Retrieved session {session_id}: {len(messages)} messages")
                return messages
            
            return None
            
        except Exception as e:
            logger.error(f"[SessionStorage] Error getting session {session_id}: {e}")
            return None
    
    @staticmethod
    async def save_session(session_id: str, messages: List[Dict[str, str]]) -> bool:
        """
        Save conversation history for a session.
        
        Args:
            session_id: Session identifier
            messages: List of message dicts
            
        Returns:
            True if saved successfully
        """
        try:
            redis = await get_redis()
            if redis is None:
                logger.warning("[SessionStorage] Redis not available, cannot save")
                return False
            
            key = f"{SESSION_PREFIX}{session_id}"
            data = json.dumps(messages, ensure_ascii=False)
            
            await redis.set(key, data, ex=SESSION_TTL)
            logger.debug(f"[SessionStorage] Saved session {session_id}: {len(messages)} messages")
            return True
            
        except Exception as e:
            logger.error(f"[SessionStorage] Error saving session {session_id}: {e}")
            return False
    
    @staticmethod
    async def append_message(session_id: str, message: Dict[str, str]) -> bool:
        """
        Append a single message to session history.
        
        Args:
            session_id: Session identifier
            message: Message dict with 'role' and 'content'
            
        Returns:
            True if appended successfully
        """
        try:
            messages = await SessionStorage.get_session(session_id)
            if messages is None:
                messages = []
            
            messages.append(message)
            return await SessionStorage.save_session(session_id, messages)
            
        except Exception as e:
            logger.error(f"[SessionStorage] Error appending message to {session_id}: {e}")
            return False
    
    @staticmethod
    async def delete_session(session_id: str) -> bool:
        """
        Delete a session.
        
        Args:
            session_id: Session identifier
            
        Returns:
            True if deleted successfully
        """
        try:
            redis = await get_redis()
            if redis is None:
                logger.warning("[SessionStorage] Redis not available, cannot delete")
                return False
            
            key = f"{SESSION_PREFIX}{session_id}"
            await redis.delete(key)
            logger.info(f"[SessionStorage] Deleted session {session_id}")
            return True
            
        except Exception as e:
            logger.error(f"[SessionStorage] Error deleting session {session_id}: {e}")
            return False
    
    @staticmethod
    async def extend_session(session_id: str) -> bool:
        """
        Extend session TTL.
        
        Args:
            session_id: Session identifier
            
        Returns:
            True if extended successfully
        """
        try:
            redis = await get_redis()
            if redis is None:
                return False
            
            key = f"{SESSION_PREFIX}{session_id}"
            await redis.expire(key, SESSION_TTL)
            return True
            
        except Exception as e:
            logger.error(f"[SessionStorage] Error extending session {session_id}: {e}")
            return False
    
    @staticmethod
    async def session_exists(session_id: str) -> bool:
        """
        Check if a session exists.
        
        Args:
            session_id: Session identifier
            
        Returns:
            True if session exists
        """
        try:
            redis = await get_redis()
            if redis is None:
                return False
            
            key = f"{SESSION_PREFIX}{session_id}"
            return await redis.exists(key) > 0
            
        except Exception as e:
            logger.error(f"[SessionStorage] Error checking session {session_id}: {e}")
            return False


# Global session storage instance
session_storage = SessionStorage()
