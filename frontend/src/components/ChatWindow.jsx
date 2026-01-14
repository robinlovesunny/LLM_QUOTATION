import { useState, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { sendChatMessage } from '../api';
import { useQuote } from '../context/QuoteContext';

/**
 * AI 智能报价助手聊天窗口（增强版）
 * @description 支持完整报价流程的AI助手窗口
 */
export default function ChatWindow({ isOpen, onClose }) {
  const navigate = useNavigate();
  const { quoteItems, addQuoteItem, removeQuoteItem, getQuoteSummary, clearQuote, syncToTraditionalFlow } = useQuote();
  
  const [messages, setMessages] = useState([
    {
      role: 'assistant',
      content: '👋 你好！我是报价侠小助手，可以帮你完成整个报价流程：\n\n• 了解需求并推荐模型\n• 计算费用估算\n• 生成报价单\n\n请告诉我您的需求，比如"我需要一个做智能客服的模型"',
      options: ['智能客服方案', '内容创作方案', '代码助手方案', '查看已有模型']
    }
  ]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [sessionId, setSessionId] = useState(null);
  const [showQuotePanel, setShowQuotePanel] = useState(false);
  const messagesEndRef = useRef(null);
  const inputRef = useRef(null);

  // 自动滚动到底部
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  useEffect(() => {
    if (isOpen && inputRef.current) {
      inputRef.current.focus();
    }
  }, [isOpen]);

  // 发送消息
  const handleSend = async (text = null) => {
    const userMessage = (text || input).trim();
    if (!userMessage || loading) return;

    setInput('');
    
    // 添加用户消息
    setMessages(prev => [...prev, { role: 'user', content: userMessage }]);
    setLoading(true);

    try {
      const response = await sendChatMessage(userMessage, sessionId);
      
      if (response.data.success) {
        setSessionId(response.data.session_id);
        
        // 处理 AI 响应
        const aiMessage = {
          role: 'assistant',
          content: response.data.response || '抱歉，我没有理解您的问题。'
        };
        
        // 处理报价项添加动作
        if (response.data.action === 'add_to_quote' && response.data.quote_item) {
          const item = response.data.quote_item;
          addQuoteItem(item);
          
          // 添加成功提示和后续选项
          aiMessage.quoteItem = item;
          aiMessage.options = ['继续添加产品', '查看报价单', '生成报价单'];
        } else if (response.data.action === 'show_quote_summary') {
          aiMessage.quoteSummary = response.data.quote_summary;
          aiMessage.options = ['导出报价单', '继续添加产品', '清空重新开始'];
        } else {
          // 根据响应内容添加快捷选项
          aiMessage.options = getContextualOptions(response.data.response, userMessage);
        }
        
        setMessages(prev => [...prev, aiMessage]);
      } else {
        setMessages(prev => [...prev, {
          role: 'assistant',
          content: `抱歉，处理出错了：${response.data.error || '未知错误'}`
        }]);
      }
    } catch (error) {
      console.error('Chat error:', error);
      setMessages(prev => [...prev, {
        role: 'assistant',
        content: '抱歉，网络连接出现问题，请稍后重试。'
      }]);
    } finally {
      setLoading(false);
    }
  };

  // 根据上下文生成快捷选项
  const getContextualOptions = (response, userMessage) => {
    const lowerResponse = response.toLowerCase();
    const lowerMessage = userMessage.toLowerCase();
    
    if (lowerResponse.includes('推荐') || lowerResponse.includes('场景')) {
      return ['qwen-max (高质量)', 'qwen-plus (均衡)', 'qwen-turbo (经济)'];
    }
    if (lowerResponse.includes('价格') || lowerResponse.includes('费用')) {
      return ['每天100次', '每天1000次', '每天1万次', '添加到报价单'];
    }
    if (lowerResponse.includes('模型') && !lowerResponse.includes('报价')) {
      return ['查看价格', '计算费用', '添加到报价单'];
    }
    return null;
  };

  // 处理回车发送
  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  // 处理快捷选项点击
  const handleOptionClick = (option) => {
    if (option === '查看报价单') {
      setShowQuotePanel(true);
    } else if (option === '生成报价单' || option === '导出报价单') {
      handleExportQuote();
    } else if (option === '清空重新开始') {
      clearQuote();
      setMessages([{
        role: 'assistant',
        content: '报价单已清空，让我们重新开始。请告诉我您的需求？',
        options: ['智能客服方案', '内容创作方案', '代码助手方案']
      }]);
    } else {
      handleSend(option);
    }
  };

  // 导出报价单
  const handleExportQuote = () => {
    if (quoteItems.length === 0) {
      setMessages(prev => [...prev, {
        role: 'assistant',
        content: '报价单为空，请先添加产品到报价单。',
        options: ['智能客服方案', '内容创作方案', '代码助手方案']
      }]);
      return;
    }
    
    // 同步到传统报价流程
    syncToTraditionalFlow();
    
    // 关闭聊天窗口，导航到报价单页面
    onClose();
    navigate('/quote/step3');
  };

  // 删除报价项
  const handleRemoveItem = (itemId) => {
    removeQuoteItem(itemId);
  };

  if (!isOpen) return null;

  const summary = getQuoteSummary();

  return (
    <div className="fixed bottom-24 right-6 w-[420px] h-[650px] bg-white rounded-2xl shadow-2xl flex flex-col z-50 border border-gray-200 overflow-hidden">
      {/* 头部 */}
      <div className="bg-gradient-to-r from-blue-600 to-purple-600 text-white px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 bg-white/20 rounded-full flex items-center justify-center">
            <span className="text-lg">🤖</span>
          </div>
          <div>
            <h3 className="font-semibold text-sm">报价侠小助手</h3>
            <p className="text-xs text-white/70">AI 智能报价 · 一站式服务</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {/* 报价单按钮 */}
          <button 
            onClick={() => setShowQuotePanel(!showQuotePanel)}
            className={`relative px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${
              showQuotePanel ? 'bg-white text-blue-600' : 'bg-white/20 hover:bg-white/30'
            }`}
          >
            📋 报价单
            {quoteItems.length > 0 && (
              <span className="absolute -top-1 -right-1 w-4 h-4 bg-red-500 text-white text-xs rounded-full flex items-center justify-center">
                {quoteItems.length}
              </span>
            )}
          </button>
          <button 
            onClick={onClose}
            className="w-8 h-8 rounded-full hover:bg-white/20 flex items-center justify-center transition-colors"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>

      {/* 报价单面板（可折叠） */}
      {showQuotePanel && quoteItems.length > 0 && (
        <div className="bg-blue-50 border-b border-blue-100 p-3 max-h-48 overflow-y-auto">
          <div className="flex justify-between items-center mb-2">
            <span className="text-sm font-medium text-gray-700">当前报价单</span>
            <span className="text-sm font-bold text-blue-600">总计: ¥{summary.totalMonthly.toFixed(2)}/月</span>
          </div>
          <div className="space-y-2">
            {quoteItems.map((item) => (
              <div key={item.id} className="bg-white rounded-lg p-2 flex justify-between items-center shadow-sm">
                <div className="flex-1">
                  <div className="text-sm font-medium text-gray-800">{item.model_name}</div>
                  <div className="text-xs text-gray-500">
                    {item.config?.daily_calls?.toLocaleString() || 0}次/天 · ¥{item.monthly_cost?.toFixed(2)}/月
                  </div>
                </div>
                <button 
                  onClick={() => handleRemoveItem(item.id)}
                  className="text-gray-400 hover:text-red-500 p-1"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            ))}
          </div>
          <button 
            onClick={handleExportQuote}
            className="w-full mt-2 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors"
          >
            生成报价单 →
          </button>
        </div>
      )}

      {/* 消息列表 */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-gray-50">
        {messages.map((msg, idx) => (
          <div key={idx}>
            <div className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
              <div
                className={`max-w-[85%] rounded-2xl px-4 py-2.5 ${
                  msg.role === 'user'
                    ? 'bg-blue-600 text-white rounded-br-md'
                    : 'bg-white text-gray-800 shadow-sm border border-gray-100 rounded-bl-md'
                }`}
              >
                <div className="text-sm whitespace-pre-wrap leading-relaxed">
                  {msg.content}
                </div>
              </div>
            </div>
            
            {/* 添加成功的报价项卡片 */}
            {msg.quoteItem && (
              <div className="mt-2 ml-2 bg-green-50 border border-green-200 rounded-xl p-3">
                <div className="flex items-center gap-2 mb-2">
                  <span className="text-green-600">✅</span>
                  <span className="text-sm font-medium text-green-800">已添加到报价单</span>
                </div>
                <div className="bg-white rounded-lg p-2 text-sm">
                  <div className="font-medium text-gray-800">{msg.quoteItem.model_name}</div>
                  <div className="text-gray-500 text-xs mt-1">
                    日调用: {msg.quoteItem.config?.daily_calls?.toLocaleString()}次 | 
                    月费用: ¥{msg.quoteItem.monthly_cost?.toFixed(2)}
                  </div>
                </div>
              </div>
            )}
            
            {/* 快捷选项按钮 */}
            {msg.role === 'assistant' && msg.options && (
              <div className="mt-2 ml-2 flex flex-wrap gap-2">
                {msg.options.map((option, optIdx) => (
                  <button
                    key={optIdx}
                    onClick={() => handleOptionClick(option)}
                    className="text-xs px-3 py-1.5 bg-white border border-blue-200 text-blue-600 rounded-full hover:bg-blue-50 hover:border-blue-300 transition-colors shadow-sm"
                  >
                    {option}
                  </button>
                ))}
              </div>
            )}
          </div>
        ))}
        
        {loading && (
          <div className="flex justify-start">
            <div className="bg-white text-gray-800 rounded-2xl rounded-bl-md px-4 py-3 shadow-sm border border-gray-100">
              <div className="flex items-center gap-2">
                <div className="flex gap-1">
                  <div className="w-2 h-2 bg-blue-400 rounded-full animate-bounce" style={{ animationDelay: '0ms' }}></div>
                  <div className="w-2 h-2 bg-blue-400 rounded-full animate-bounce" style={{ animationDelay: '150ms' }}></div>
                  <div className="w-2 h-2 bg-blue-400 rounded-full animate-bounce" style={{ animationDelay: '300ms' }}></div>
                </div>
                <span className="text-sm text-gray-500">思考中...</span>
              </div>
            </div>
          </div>
        )}
        
        <div ref={messagesEndRef} />
      </div>

      {/* 底部状态栏（当有报价项时显示） */}
      {quoteItems.length > 0 && !showQuotePanel && (
        <div 
          className="px-4 py-2 bg-blue-50 border-t border-blue-100 cursor-pointer hover:bg-blue-100 transition-colors"
          onClick={() => setShowQuotePanel(true)}
        >
          <div className="flex justify-between items-center text-sm">
            <span className="text-gray-600">
              📋 已添加 <span className="font-medium text-blue-600">{quoteItems.length}</span> 个产品
            </span>
            <span className="font-medium text-blue-600">
              ¥{summary.totalMonthly.toFixed(2)}/月 →
            </span>
          </div>
        </div>
      )}

      {/* 输入区域 */}
      <div className="p-4 border-t border-gray-200 bg-white">
        <div className="flex items-end gap-2">
          <div className="flex-1 relative">
            <textarea
              ref={inputRef}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyPress={handleKeyPress}
              placeholder="描述您的需求，如：我需要一个智能客服..."
              rows={1}
              className="w-full px-4 py-2.5 pr-12 border border-gray-200 rounded-xl resize-none focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
              style={{ maxHeight: '100px' }}
            />
          </div>
          <button
            onClick={() => handleSend()}
            disabled={!input.trim() || loading}
            className={`p-2.5 rounded-xl transition-all ${
              input.trim() && !loading
                ? 'bg-blue-600 hover:bg-blue-700 text-white shadow-lg hover:shadow-xl'
                : 'bg-gray-100 text-gray-400 cursor-not-allowed'
            }`}
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
            </svg>
          </button>
        </div>
      </div>
    </div>
  );
}
