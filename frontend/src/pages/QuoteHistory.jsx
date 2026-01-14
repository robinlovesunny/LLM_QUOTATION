/**
 * 报价历史页面
 * @description 展示报价统计数据、搜索筛选和报价列表
 */
import React, { useState, useEffect, useCallback } from 'react';
import { getQuotes, getQuoteStatistics, getQuoteDetail, getCategories, exportQuote, downloadExport } from '../api';

/**
 * 统计卡片组件
 * @param {Object} props - 组件属性
 * @param {string} props.title - 卡片标题
 * @param {string|number} props.value - 显示的值
 * @param {string} props.icon - 图标类型
 * @param {string} props.color - 颜色主题
 */
function StatCard({ title, value, icon, color = 'blue' }) {
  const colorClasses = {
    blue: 'bg-blue-50 text-primary',
    green: 'bg-green-50 text-green-600',
    purple: 'bg-purple-50 text-purple-600',
    orange: 'bg-orange-50 text-orange-600'
  };

  const icons = {
    document: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
      </svg>
    ),
    currency: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    ),
    calendar: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
      </svg>
    ),
    chart: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
      </svg>
    )
  };

  return (
    <div className="p-6 bg-white border border-border rounded-xl hover:shadow-md transition-all">
      <div className="flex items-center gap-4">
        <div className={`p-3 rounded-lg ${colorClasses[color]}`}>
          {icons[icon]}
        </div>
        <div>
          <p className="text-sm text-text-secondary">{title}</p>
          <p className="text-2xl font-semibold text-text-primary mt-1">{value}</p>
        </div>
      </div>
    </div>
  );
}

/**
 * 报价详情弹窗组件
 */
function QuoteDetailModal({ quote, onClose, onExport }) {
  if (!quote) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50" onClick={onClose}>
      <div className="bg-white rounded-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
        {/* 头部 */}
        <div className="p-6 border-b border-border flex items-center justify-between">
          <div>
            <h3 className="text-xl font-semibold text-text-primary">报价详情</h3>
            <p className="text-sm text-text-secondary mt-1">单号：{quote.quote_no}</p>
          </div>
          <button onClick={onClose} className="text-text-secondary hover:text-text-primary transition-all">
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* 内容 */}
        <div className="p-6 space-y-6">
          {/* 基本信息 */}
          <div className="grid grid-cols-2 gap-4">
            <div className="p-4 bg-secondary rounded-lg">
              <p className="text-xs text-text-secondary">模型</p>
              <p className="text-sm font-medium text-text-primary mt-1">{quote.model_name}</p>
            </div>
            <div className="p-4 bg-secondary rounded-lg">
              <p className="text-xs text-text-secondary">场景</p>
              <p className="text-sm font-medium text-text-primary mt-1">{quote.category_name}</p>
            </div>
            <div className="p-4 bg-secondary rounded-lg">
              <p className="text-xs text-text-secondary">项目名称</p>
              <p className="text-sm font-medium text-text-primary mt-1">{quote.project_name || '-'}</p>
            </div>
            <div className="p-4 bg-secondary rounded-lg">
              <p className="text-xs text-text-secondary">客户名称</p>
              <p className="text-sm font-medium text-text-primary mt-1">{quote.customer_name || '-'}</p>
            </div>
            <div className="p-4 bg-secondary rounded-lg">
              <p className="text-xs text-text-secondary">计费周期</p>
              <p className="text-sm font-medium text-text-primary mt-1">
                {quote.billing_cycle === 'daily' ? '按天' : '按月'}
              </p>
            </div>
            <div className="p-4 bg-secondary rounded-lg">
              <p className="text-xs text-text-secondary">报价人</p>
              <p className="text-sm font-medium text-text-primary mt-1">{quote.created_by}</p>
            </div>
          </div>

          {/* 费用明细 */}
          <div>
            <h4 className="text-sm font-medium text-text-primary mb-3">费用明细</h4>
            <div className="bg-secondary rounded-lg overflow-hidden">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border">
                    <th className="px-4 py-3 text-left text-xs font-medium text-text-secondary">维度</th>
                    <th className="px-4 py-3 text-right text-xs font-medium text-text-secondary">用量</th>
                    <th className="px-4 py-3 text-right text-xs font-medium text-text-secondary">单价</th>
                    <th className="px-4 py-3 text-right text-xs font-medium text-text-secondary">小计</th>
                  </tr>
                </thead>
                <tbody>
                  {quote.details?.map((detail, index) => (
                    <tr key={index} className="border-b border-border last:border-0">
                      <td className="px-4 py-3 text-sm text-text-primary">{detail.dimension_name}</td>
                      <td className="px-4 py-3 text-sm text-text-secondary text-right">
                        {detail.usage.toLocaleString()} {detail.unit}
                      </td>
                      <td className="px-4 py-3 text-sm text-text-secondary text-right">
                        ¥{detail.unit_price}
                      </td>
                      <td className="px-4 py-3 text-sm font-medium text-text-primary text-right">
                        ¥{detail.subtotal.toFixed(2)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          {/* 总计 */}
          <div className="flex items-center justify-between p-4 bg-primary/5 rounded-lg border border-primary/20">
            <span className="text-sm font-medium text-text-primary">报价总计</span>
            <span className="text-2xl font-semibold text-primary">¥{quote.total?.toFixed(2)}</span>
          </div>
        </div>

        {/* 底部操作 */}
        <div className="p-6 border-t border-border flex gap-4 justify-end">
          <button
            onClick={onClose}
            className="px-6 py-2 border border-border rounded-lg text-text-primary hover:bg-secondary transition-all"
          >
            关闭
          </button>
          <button
            onClick={() => onExport(quote.quote_id)}
            className="px-6 py-2 bg-primary text-white rounded-lg hover:bg-opacity-90 transition-all"
          >
            导出Excel
          </button>
        </div>
      </div>
    </div>
  );
}

function QuoteHistory() {
  // 页面状态
  const [quotes, setQuotes] = useState([]);           // 报价列表
  const [statistics, setStatistics] = useState(null); // 统计数据
  const [categories, setCategories] = useState([]);   // 类目列表
  const [loading, setLoading] = useState(true);       // 加载状态
  const [selectedQuote, setSelectedQuote] = useState(null); // 选中的报价详情
  
  // 筛选条件
  const [keyword, setKeyword] = useState('');
  const [categoryCode, setCategoryCode] = useState('');
  
  // 分页
  const [pagination, setPagination] = useState({ page: 1, page_size: 10, total: 0 });

  // 加载报价列表
  const loadQuotes = useCallback(async () => {
    try {
      setLoading(true);
      const response = await getQuotes(
        pagination.page, 
        pagination.page_size, 
        keyword, 
        categoryCode
      );
      setQuotes(response.data.quotes);
      setPagination(prev => ({ ...prev, total: response.data.total }));
    } catch (error) {
      console.error('加载报价历史失败:', error);
    } finally {
      setLoading(false);
    }
  }, [pagination.page, pagination.page_size, keyword, categoryCode]);

  // 加载统计数据
  const loadStatistics = async () => {
    try {
      const response = await getQuoteStatistics();
      setStatistics(response.data);
    } catch (error) {
      console.error('加载统计数据失败:', error);
    }
  };

  // 加载类目列表
  const loadCategories = async () => {
    try {
      const response = await getCategories();
      // API返回的是 {categories: [...]}
      setCategories(response.data.categories || []);
    } catch (error) {
      console.error('加载类目失败:', error);
    }
  };

  // 初始化加载
  useEffect(() => {
    loadStatistics();
    loadCategories();
  }, []);

  // 筛选条件变化时重新加载
  useEffect(() => {
    loadQuotes();
  }, [loadQuotes]);

  // 查看报价详情
  const handleViewDetail = async (quoteId) => {
    try {
      const response = await getQuoteDetail(quoteId);
      setSelectedQuote(response.data);
    } catch (error) {
      console.error('加载报价详情失败:', error);
    }
  };

  // 导出报价
  const handleExport = async (quoteId) => {
    try {
      const response = await exportQuote(quoteId);
      if (response.data.filename) {
        window.open(downloadExport(response.data.filename), '_blank');
      }
    } catch (error) {
      console.error('导出失败:', error);
      alert('导出失败，请重试');
    }
  };

  // 搜索处理
  const handleSearch = () => {
    setPagination(prev => ({ ...prev, page: 1 }));
  };

  // 重置筛选
  const handleReset = () => {
    setKeyword('');
    setCategoryCode('');
    setPagination(prev => ({ ...prev, page: 1 }));
  };

  // 格式化日期
  const formatDate = (dateStr) => {
    const date = new Date(dateStr);
    return date.toLocaleDateString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  return (
    <div>
      {/* 页面标题 */}
      <h2 className="text-3xl font-semibold text-text-primary mb-8">报价历史</h2>

      {/* 统计卡片 */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <StatCard
          title="总报价数"
          value={statistics?.total_count || 0}
          icon="document"
          color="blue"
        />
        <StatCard
          title="总报价金额"
          value={`¥${(statistics?.total_amount || 0).toLocaleString()}`}
          icon="currency"
          color="green"
        />
        <StatCard
          title="本月报价"
          value={statistics?.month_count || 0}
          icon="calendar"
          color="purple"
        />
        <StatCard
          title="本月金额"
          value={`¥${(statistics?.month_amount || 0).toLocaleString()}`}
          icon="chart"
          color="orange"
        />
      </div>

      {/* 搜索筛选栏 */}
      <div className="p-6 bg-white border border-border rounded-xl mb-6">
        <div className="flex flex-wrap gap-4 items-end">
          {/* 关键词搜索 */}
          <div className="flex-1 min-w-[200px]">
            <label className="block text-sm font-medium text-text-primary mb-2">搜索</label>
            <input
              type="text"
              value={keyword}
              onChange={(e) => setKeyword(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
              placeholder="搜索项目名、客户名、报价单号..."
              className="w-full px-4 py-2 border border-border rounded-lg text-sm focus:outline-none focus:border-primary transition-all"
            />
          </div>

          {/* 类目筛选 */}
          <div className="w-48">
            <label className="block text-sm font-medium text-text-primary mb-2">场景类目</label>
            <select
              value={categoryCode}
              onChange={(e) => setCategoryCode(e.target.value)}
              className="w-full px-4 py-2 border border-border rounded-lg text-sm focus:outline-none focus:border-primary transition-all bg-white"
            >
              <option value="">全部场景</option>
              {categories.map((cat) => (
                <option key={cat.code} value={cat.code}>{cat.name}</option>
              ))}
            </select>
          </div>

          {/* 操作按钮 */}
          <div className="flex gap-2">
            <button
              onClick={handleSearch}
              className="px-6 py-2 bg-primary text-white rounded-lg hover:bg-opacity-90 transition-all"
            >
              搜索
            </button>
            <button
              onClick={handleReset}
              className="px-6 py-2 border border-border text-text-secondary rounded-lg hover:bg-secondary transition-all"
            >
              重置
            </button>
          </div>
        </div>
      </div>

      {/* 报价列表 */}
      <div className="bg-white border border-border rounded-xl overflow-hidden">
        {loading ? (
          <div className="text-center py-12 text-text-secondary">加载中...</div>
        ) : quotes.length === 0 ? (
          <div className="text-center py-12">
            <svg className="w-16 h-16 mx-auto text-border mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            <p className="text-text-secondary">暂无报价记录</p>
            <p className="text-sm text-text-secondary mt-1">开始创建您的第一份报价吧</p>
          </div>
        ) : (
          <>
            {/* 报价卡片列表 */}
            <div className="divide-y divide-border">
              {quotes.map((quote) => (
                <div
                  key={quote.quote_id}
                  className="p-6 hover:bg-secondary/30 transition-all"
                >
                  <div className="flex items-start justify-between">
                    {/* 左侧信息 */}
                    <div className="flex-1">
                      {/* 第一行：报价单号 + 标签 */}
                      <div className="flex items-center gap-3 mb-2">
                        <span className="text-lg font-medium text-text-primary">
                          {quote.quote_no}
                        </span>
                        <span className="px-2 py-0.5 bg-blue-50 text-primary text-xs rounded">
                          {quote.category_name}
                        </span>
                        <span className="px-2 py-0.5 bg-secondary text-text-secondary text-xs rounded">
                          {quote.billing_cycle === 'daily' ? '按天' : '按月'}
                        </span>
                      </div>

                      {/* 第二行：模型 */}
                      <p className="text-sm text-text-primary mb-2">
                        <span className="text-text-secondary">模型：</span>
                        {quote.model_name}
                      </p>

                      {/* 第三行：项目/客户 */}
                      <div className="flex gap-6 text-sm text-text-secondary">
                        {quote.project_name && (
                          <span>
                            <span className="text-text-secondary">项目：</span>
                            {quote.project_name}
                          </span>
                        )}
                        {quote.customer_name && (
                          <span>
                            <span className="text-text-secondary">客户：</span>
                            {quote.customer_name}
                          </span>
                        )}
                      </div>

                      {/* 第四行：报价人 + 时间 */}
                      <div className="flex gap-6 text-xs text-text-secondary mt-3">
                        <span>报价人：{quote.created_by}</span>
                        <span>{formatDate(quote.created_at)}</span>
                      </div>
                    </div>

                    {/* 右侧：金额 + 操作 */}
                    <div className="text-right ml-6">
                      <p className="text-2xl font-semibold text-primary mb-4">
                        ¥{quote.total.toLocaleString(undefined, { minimumFractionDigits: 2 })}
                      </p>
                      <div className="flex gap-2">
                        <button
                          onClick={() => handleViewDetail(quote.quote_id)}
                          className="px-4 py-1.5 text-sm border border-border text-text-primary rounded-lg hover:bg-secondary transition-all"
                        >
                          查看详情
                        </button>
                        <button
                          onClick={() => handleExport(quote.quote_id)}
                          className="px-4 py-1.5 text-sm bg-primary text-white rounded-lg hover:bg-opacity-90 transition-all"
                        >
                          导出
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            {/* 分页 */}
            {pagination.total > pagination.page_size && (
              <div className="flex items-center justify-between px-6 py-4 bg-secondary/50 border-t border-border">
                <span className="text-sm text-text-secondary">
                  共 {pagination.total} 条记录
                </span>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setPagination(prev => ({ ...prev, page: Math.max(1, prev.page - 1) }))}
                    disabled={pagination.page === 1}
                    className="px-4 py-2 border border-border rounded-lg text-text-primary hover:bg-white disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                  >
                    上一页
                  </button>
                  <span className="px-4 py-2 text-sm text-text-secondary">
                    {pagination.page} / {Math.ceil(pagination.total / pagination.page_size)}
                  </span>
                  <button
                    onClick={() => setPagination(prev => ({ ...prev, page: prev.page + 1 }))}
                    disabled={pagination.page >= Math.ceil(pagination.total / pagination.page_size)}
                    className="px-4 py-2 border border-border rounded-lg text-text-primary hover:bg-white disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                  >
                    下一页
                  </button>
                </div>
              </div>
            )}
          </>
        )}
      </div>

      {/* 报价详情弹窗 */}
      {selectedQuote && (
        <QuoteDetailModal
          quote={selectedQuote}
          onClose={() => setSelectedQuote(null)}
          onExport={handleExport}
        />
      )}
    </div>
  );
}

export default QuoteHistory;
