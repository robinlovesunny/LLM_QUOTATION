import React, { useState, useEffect, useCallback } from 'react';
import axios from 'axios';

/**
 * 竞品对比页面
 * 左侧展示 Qwen（阿里云）规格，右侧展示 Doubao（豆包）规格
 */

const API_BASE = '/api/v1';

// 局部样式
const styles = {
  container: {
    minHeight: '100vh',
    backgroundColor: '#f8fafc',
    padding: '24px',
  },
  header: {
    textAlign: 'center',
    marginBottom: '32px',
  },
  title: {
    fontSize: '28px',
    fontWeight: '700',
    color: '#1e293b',
    marginBottom: '8px',
  },
  subtitle: {
    fontSize: '14px',
    color: '#64748b',
  },
  mainGrid: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '24px',
    maxWidth: '1600px',
    margin: '0 auto',
  },
  panel: {
    backgroundColor: '#ffffff',
    borderRadius: '12px',
    boxShadow: '0 1px 3px rgba(0, 0, 0, 0.1)',
    overflow: 'hidden',
  },
  panelHeader: {
    padding: '16px 20px',
    borderBottom: '1px solid #e2e8f0',
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
  },
  panelTitle: {
    fontSize: '16px',
    fontWeight: '600',
    color: '#1e293b',
  },
  badge: {
    fontSize: '12px',
    padding: '2px 8px',
    borderRadius: '9999px',
    fontWeight: '500',
  },
  qwenBadge: {
    backgroundColor: '#fef3c7',
    color: '#92400e',
  },
  doubaoBadge: {
    backgroundColor: '#dbeafe',
    color: '#1e40af',
  },
  searchBox: {
    padding: '16px 20px',
    borderBottom: '1px solid #e2e8f0',
  },
  searchInput: {
    width: '100%',
    padding: '10px 14px',
    border: '1px solid #e2e8f0',
    borderRadius: '8px',
    fontSize: '14px',
    outline: 'none',
    transition: 'border-color 0.2s',
  },
  filterRow: {
    padding: '12px 20px',
    borderBottom: '1px solid #e2e8f0',
    display: 'flex',
    gap: '12px',
    flexWrap: 'wrap',
  },
  filterSelect: {
    padding: '6px 12px',
    border: '1px solid #e2e8f0',
    borderRadius: '6px',
    fontSize: '13px',
    backgroundColor: '#ffffff',
    cursor: 'pointer',
  },
  listContainer: {
    maxHeight: '500px',
    overflowY: 'auto',
  },
  listItem: {
    padding: '14px 20px',
    borderBottom: '1px solid #f1f5f9',
    cursor: 'pointer',
    transition: 'background-color 0.15s',
  },
  listItemHover: {
    backgroundColor: '#f8fafc',
  },
  listItemSelected: {
    backgroundColor: '#eff6ff',
    borderLeft: '3px solid #3b82f6',
  },
  modelName: {
    fontSize: '14px',
    fontWeight: '500',
    color: '#1e293b',
    marginBottom: '4px',
  },
  modelMeta: {
    fontSize: '12px',
    color: '#64748b',
    display: 'flex',
    gap: '12px',
    flexWrap: 'wrap',
  },
  priceTag: {
    color: '#059669',
    fontWeight: '600',
  },
  emptyState: {
    padding: '40px 20px',
    textAlign: 'center',
    color: '#94a3b8',
  },
  loadingState: {
    padding: '40px 20px',
    textAlign: 'center',
    color: '#64748b',
  },
  selectedPanel: {
    marginTop: '24px',
    backgroundColor: '#ffffff',
    borderRadius: '12px',
    boxShadow: '0 1px 3px rgba(0, 0, 0, 0.1)',
    padding: '20px',
  },
  selectedTitle: {
    fontSize: '16px',
    fontWeight: '600',
    color: '#1e293b',
    marginBottom: '16px',
  },
  compareGrid: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '20px',
  },
  compareCard: {
    padding: '16px',
    backgroundColor: '#f8fafc',
    borderRadius: '8px',
  },
  compareLabel: {
    fontSize: '12px',
    color: '#64748b',
    marginBottom: '4px',
  },
  compareValue: {
    fontSize: '14px',
    color: '#1e293b',
    fontWeight: '500',
  },
  noSelection: {
    color: '#94a3b8',
    fontSize: '14px',
    textAlign: 'center',
    padding: '20px',
  },
  // 参数标签样式
  tagContainer: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '6px',
    marginTop: '6px',
    marginBottom: '6px',
  },
  tag: {
    fontSize: '11px',
    padding: '2px 6px',
    borderRadius: '4px',
    fontWeight: '500',
  },
  tagMode: {
    backgroundColor: '#fef3c7',
    color: '#92400e',
  },
  tagToken: {
    backgroundColor: '#dbeafe',
    color: '#1e40af',
  },
  tagBatch: {
    backgroundColor: '#d1fae5',
    color: '#065f46',
  },
  tagCache: {
    backgroundColor: '#ffedd5',
    color: '#9a3412',
  },
  tagResolution: {
    backgroundColor: '#f3e8ff',
    color: '#7c3aed',
  },
  // 豆包双选择模式切换
  selectModeToggle: {
    display: 'flex',
    gap: '8px',
    padding: '12px 20px',
    borderBottom: '1px solid #e2e8f0',
    backgroundColor: '#f8fafc',
  },
  selectModeBtn: {
    flex: 1,
    padding: '8px 12px',
    border: '1px solid #e2e8f0',
    borderRadius: '6px',
    fontSize: '13px',
    cursor: 'pointer',
    transition: 'all 0.2s',
    backgroundColor: '#ffffff',
    color: '#64748b',
  },
  selectModeBtnActive: {
    backgroundColor: '#3b82f6',
    borderColor: '#3b82f6',
    color: '#ffffff',
  },
  // 建立关联按钮
  linkButton: {
    marginTop: '16px',
    padding: '12px 24px',
    backgroundColor: '#3b82f6',
    color: '#ffffff',
    border: 'none',
    borderRadius: '8px',
    fontSize: '14px',
    fontWeight: '500',
    cursor: 'pointer',
    width: '100%',
    transition: 'background-color 0.2s',
  },
  linkButtonDisabled: {
    backgroundColor: '#94a3b8',
    cursor: 'not-allowed',
  },
  // 映射列表模块
  mappingPanel: {
    marginTop: '24px',
    backgroundColor: '#ffffff',
    borderRadius: '12px',
    boxShadow: '0 1px 3px rgba(0, 0, 0, 0.1)',
    padding: '20px',
    maxWidth: '1600px',
    marginLeft: 'auto',
    marginRight: 'auto',
  },
  mappingTitle: {
    fontSize: '16px',
    fontWeight: '600',
    color: '#1e293b',
    marginBottom: '16px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  mappingTable: {
    width: '100%',
    borderCollapse: 'collapse',
  },
  mappingTh: {
    padding: '12px',
    textAlign: 'left',
    backgroundColor: '#f8fafc',
    borderBottom: '2px solid #e2e8f0',
    fontSize: '13px',
    fontWeight: '600',
    color: '#475569',
  },
  mappingTd: {
    padding: '12px',
    borderBottom: '1px solid #e2e8f0',
    fontSize: '13px',
    color: '#1e293b',
  },
  deleteBtn: {
    padding: '6px 12px',
    backgroundColor: '#fee2e2',
    color: '#dc2626',
    border: 'none',
    borderRadius: '4px',
    fontSize: '12px',
    cursor: 'pointer',
    transition: 'background-color 0.2s',
  },
  emptyMapping: {
    padding: '40px 20px',
    textAlign: 'center',
    color: '#94a3b8',
    fontSize: '14px',
  },
  selectedModelBadge: {
    fontSize: '11px',
    padding: '2px 6px',
    borderRadius: '4px',
    marginLeft: '8px',
    fontWeight: '500',
  },
  inputBadge: {
    backgroundColor: '#dcfce7',
    color: '#166534',
  },
  outputBadge: {
    backgroundColor: '#fef3c7',
    color: '#92400e',
  },
  // 一键保存按钮
  saveAllButton: {
    padding: '10px 20px',
    backgroundColor: '#059669',
    color: '#ffffff',
    border: 'none',
    borderRadius: '6px',
    fontSize: '13px',
    fontWeight: '500',
    cursor: 'pointer',
    transition: 'background-color 0.2s',
  },
  saveAllButtonDisabled: {
    backgroundColor: '#94a3b8',
    cursor: 'not-allowed',
  },
  // 已保存标记
  savedBadge: {
    fontSize: '11px',
    padding: '2px 8px',
    borderRadius: '9999px',
    backgroundColor: '#dcfce7',
    color: '#166534',
    marginLeft: '8px',
  },
  unsavedBadge: {
    fontSize: '11px',
    padding: '2px 8px',
    borderRadius: '9999px',
    backgroundColor: '#fef3c7',
    color: '#92400e',
    marginLeft: '8px',
  },
};

function DebatePage() {
  // Qwen（阿里云）状态
  const [qwenModels, setQwenModels] = useState([]);
  const [qwenFilters, setQwenFilters] = useState({ categories: [], vendors: [] });
  const [qwenSearch, setQwenSearch] = useState('');
  const [qwenCategory, setQwenCategory] = useState('');
  const [qwenLoading, setQwenLoading] = useState(false);
  const [selectedQwen, setSelectedQwen] = useState(null);

  // Doubao（豆包）状态
  const [doubaoModels, setDoubaoModels] = useState([]);
  const [doubaoFilters, setDoubaoFilters] = useState({ categories: [], providers: [], service_types: [] });
  const [doubaoSearch, setDoubaoSearch] = useState('');
  const [doubaoCategory, setDoubaoCategory] = useState('');
  const [doubaoProvider, setDoubaoProvider] = useState('');
  const [doubaoLoading, setDoubaoLoading] = useState(false);
  // 豆包支持选择两个模型（输入价格模型、输出价格模型）
  const [selectedDoubaoInput, setSelectedDoubaoInput] = useState(null);
  const [selectedDoubaoOutput, setSelectedDoubaoOutput] = useState(null);
  // 当前选择模式：'input' 或 'output'
  const [doubaoSelectMode, setDoubaoSelectMode] = useState('input');

  // 映射关系列表
  const [mappings, setMappings] = useState([]);
  // 保存状态
  const [isSaving, setIsSaving] = useState(false);
  // 已保存到数据库的映射（从数据库加载）
  const [savedMappings, setSavedMappings] = useState([]);

  // 加载已保存的映射关系（先从 localStorage，再从数据库）
  useEffect(() => {
    // 从 localStorage 加载本地映射
    const localMappings = localStorage.getItem('model_mappings');
    if (localMappings) {
      try {
        setMappings(JSON.parse(localMappings));
      } catch (e) {
        console.error('加载本地映射关系失败:', e);
      }
    }
    
    // 从数据库加载已保存的映射
    const loadSavedMappings = async () => {
      try {
        const response = await axios.get(`${API_BASE}/doubao/debate-list`);
        if (response.data && response.data.data) {
          setSavedMappings(response.data.data);
        }
      } catch (error) {
        console.error('加载数据库映射关系失败:', error);
      }
    };
    loadSavedMappings();
  }, []);

  // 一键保存到数据库
  const saveAllToDatabase = async () => {
    if (mappings.length === 0) {
      alert('没有需要保存的映射关系');
      return;
    }
    
    setIsSaving(true);
    try {
      const response = await axios.post(`${API_BASE}/doubao/debate-list/batch-save`, mappings);
      if (response.data && response.data.success) {
        alert(response.data.message);
        // 清空本地映射
        setMappings([]);
        localStorage.removeItem('model_mappings');
        // 重新加载数据库映射
        const reloadResponse = await axios.get(`${API_BASE}/doubao/debate-list`);
        if (reloadResponse.data && reloadResponse.data.data) {
          setSavedMappings(reloadResponse.data.data);
        }
      }
    } catch (error) {
      console.error('保存到数据库失败:', error);
      alert('保存失败: ' + (error.response?.data?.detail || error.message));
    } finally {
      setIsSaving(false);
    }
  };

  // 从数据库删除映射
  const deleteFromDatabase = async (mappingId) => {
    if (!window.confirm('确定要删除这条映射关系吗？')) return;
    
    try {
      await axios.delete(`${API_BASE}/doubao/debate-list/${mappingId}`);
      setSavedMappings(savedMappings.filter(m => m.id !== mappingId));
    } catch (error) {
      console.error('删除失败:', error);
      alert('删除失败: ' + (error.response?.data?.detail || error.message));
    }
  };

  // 加载 Qwen 筛选选项
  useEffect(() => {
    const loadQwenFilters = async () => {
      try {
        const response = await axios.get(`${API_BASE}/products/pricing/filters`);
        if (response.data) {
          setQwenFilters({
            categories: response.data.categories || [],
            vendors: response.data.vendors || [],
          });
        }
      } catch (error) {
        console.error('加载Qwen筛选选项失败:', error);
      }
    };
    loadQwenFilters();
  }, []);

  // 加载 Doubao 筛选选项
  useEffect(() => {
    const loadDoubaoFilters = async () => {
      try {
        const response = await axios.get(`${API_BASE}/doubao/filters`);
        if (response.data) {
          setDoubaoFilters({
            categories: response.data.categories || [],
            providers: response.data.providers || [],
            service_types: response.data.service_types || [],
          });
        }
      } catch (error) {
        console.error('加载Doubao筛选选项失败:', error);
      }
    };
    loadDoubaoFilters();
  }, []);

  // 搜索 Qwen 模型
  const searchQwenModels = useCallback(async () => {
    setQwenLoading(true);
    try {
      const params = new URLSearchParams();
      if (qwenSearch) params.append('keyword', qwenSearch);
      if (qwenCategory) params.append('category', qwenCategory);
      params.append('page_size', '100');

      const response = await axios.get(`${API_BASE}/products/pricing/models?${params.toString()}`);
      if (response.data && response.data.data) {
        setQwenModels(response.data.data);
      } else {
        setQwenModels([]);
      }
    } catch (error) {
      console.error('搜索Qwen模型失败:', error);
      setQwenModels([]);
    } finally {
      setQwenLoading(false);
    }
  }, [qwenSearch, qwenCategory]);

  // 搜索 Doubao 模型
  const searchDoubaoModels = useCallback(async () => {
    setDoubaoLoading(true);
    try {
      const params = new URLSearchParams();
      if (doubaoSearch) params.append('keyword', doubaoSearch);
      if (doubaoCategory) params.append('category', doubaoCategory);
      if (doubaoProvider) params.append('provider', doubaoProvider);
      params.append('page_size', '100');

      const response = await axios.get(`${API_BASE}/doubao/models?${params.toString()}`);
      if (response.data && response.data.data) {
        setDoubaoModels(response.data.data);
      } else {
        setDoubaoModels([]);
      }
    } catch (error) {
      console.error('搜索Doubao模型失败:', error);
      setDoubaoModels([]);
    } finally {
      setDoubaoLoading(false);
    }
  }, [doubaoSearch, doubaoCategory, doubaoProvider]);

  // 初始加载和筛选变化时搜索
  useEffect(() => {
    searchQwenModels();
  }, [searchQwenModels]);

  useEffect(() => {
    searchDoubaoModels();
  }, [searchDoubaoModels]);

  // 处理搜索输入（带防抖）
  const [qwenSearchTimeout, setQwenSearchTimeout] = useState(null);
  const [doubaoSearchTimeout, setDoubaoSearchTimeout] = useState(null);

  const handleQwenSearchChange = (e) => {
    const value = e.target.value;
    if (qwenSearchTimeout) clearTimeout(qwenSearchTimeout);
    setQwenSearchTimeout(
      setTimeout(() => {
        setQwenSearch(value);
      }, 300)
    );
  };

  const handleDoubaoSearchChange = (e) => {
    const value = e.target.value;
    if (doubaoSearchTimeout) clearTimeout(doubaoSearchTimeout);
    setDoubaoSearchTimeout(
      setTimeout(() => {
        setDoubaoSearch(value);
      }, 300)
    );
  };

  // 获取价格显示（参考 QuoteStep2）
  const getPriceDisplay = (prices) => {
    if (!prices || prices.length === 0) return null;
    const input = prices.find(p => p.dimension_code === 'input' || p.dimension_code === 'input_token');
    const output = prices.find(p => p.dimension_code === 'output' || p.dimension_code === 'output_token' || p.dimension_code === 'output_token_thinking');
    
    if (input && output && input.unit_price && output.unit_price) {
      return `输入¥${input.unit_price} / 输出¥${output.unit_price}`;
    } else if (output && output.unit_price) {
      return `¥${output.unit_price}/${output.unit || '元'}`;
    } else if (input && input.unit_price) {
      return `¥${input.unit_price}/${input.unit || '元'}`;
    } else if (prices[0] && prices[0].unit_price) {
      return `¥${prices[0].unit_price}/${prices[0].unit || '元'}`;
    }
    return null;
  };

  return (
    <div style={styles.container}>
      {/* 页面标题 */}
      <div style={styles.header}>
        <h1 style={styles.title}>竞品定价对比平台</h1>
        <p style={styles.subtitle}>比较阿里云通义千问与火山引擎豆包大模型的定价方案</p>
      </div>

      {/* 主体内容：左右两栏 */}
      <div style={styles.mainGrid}>
        {/* 左侧：Qwen（阿里云） */}
        <div style={styles.panel}>
          <div style={styles.panelHeader}>
            <span style={styles.panelTitle}>阿里云 · 通义千问</span>
          </div>

          {/* 搜索框 */}
          <div style={styles.searchBox}>
            <input
              type="text"
              placeholder="搜索模型名称..."
              style={styles.searchInput}
              onChange={handleQwenSearchChange}
            />
          </div>

          {/* 筛选条件 */}
          <div style={styles.filterRow}>
            <select
              style={styles.filterSelect}
              value={qwenCategory}
              onChange={(e) => setQwenCategory(e.target.value)}
            >
              <option value="">全部分类</option>
              {qwenFilters.categories.map((cat) => (
                <option key={cat.code || cat} value={cat.code || cat}>
                  {cat.name || cat}
                </option>
              ))}
            </select>
          </div>

          {/* 模型列表 */}
          <div style={styles.listContainer}>
            {qwenLoading ? (
              <div style={styles.loadingState}>加载中...</div>
            ) : qwenModels.length === 0 ? (
              <div style={styles.emptyState}>暂无数据</div>
            ) : (
              qwenModels.map((model, index) => {
                const priceText = getPriceDisplay(model.prices);
                return (
                  <div
                    key={model.id || index}
                    style={{
                      ...styles.listItem,
                      ...(selectedQwen?.id === model.id ? styles.listItemSelected : {}),
                    }}
                    onClick={() => setSelectedQwen(model)}
                    onMouseEnter={(e) => {
                      if (selectedQwen?.id !== model.id) {
                        e.currentTarget.style.backgroundColor = '#f8fafc';
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (selectedQwen?.id !== model.id) {
                        e.currentTarget.style.backgroundColor = '';
                      }
                    }}
                  >
                    <div style={styles.modelName}>{model.display_name || model.model_name}</div>
                    {/* 参数标签 */}
                    <div style={styles.tagContainer}>
                      {model.mode && (
                        <span style={{ ...styles.tag, ...styles.tagMode }}>{model.mode}</span>
                      )}
                      {model.token_tier && (
                        <span style={{ ...styles.tag, ...styles.tagToken }}>{model.token_tier}</span>
                      )}
                      {model.resolution && (
                        <span style={{ ...styles.tag, ...styles.tagResolution }}>{model.resolution}</span>
                      )}
                      {model.supports_batch && (
                        <span style={{ ...styles.tag, ...styles.tagBatch }}>Batch半价</span>
                      )}
                      {model.supports_cache && (
                        <span style={{ ...styles.tag, ...styles.tagCache }}>支持缓存</span>
                      )}
                    </div>
                    {/* 价格 */}
                    {priceText && (
                      <div style={styles.priceTag}>{priceText}</div>
                    )}
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* 右侧：Doubao（豆包） */}
        <div style={styles.panel}>
          <div style={styles.panelHeader}>
            <span style={styles.panelTitle}>火山引擎 · 豆包</span>
          </div>

          {/* 搜索框 */}
          <div style={styles.searchBox}>
            <input
              type="text"
              placeholder="搜索模型名称..."
              style={styles.searchInput}
              onChange={handleDoubaoSearchChange}
            />
          </div>

          {/* 筛选条件 */}
          <div style={styles.filterRow}>
            <select
              style={styles.filterSelect}
              value={doubaoCategory}
              onChange={(e) => setDoubaoCategory(e.target.value)}
            >
              <option value="">全部分类</option>
              {doubaoFilters.categories.map((cat) => (
                <option key={cat} value={cat}>
                  {cat}
                </option>
              ))}
            </select>
            <select
              style={styles.filterSelect}
              value={doubaoProvider}
              onChange={(e) => setDoubaoProvider(e.target.value)}
            >
              <option value="">全部供应商</option>
              {doubaoFilters.providers.map((provider) => (
                <option key={provider} value={provider}>
                  {provider}
                </option>
              ))}
            </select>
          </div>

          {/* 豆包选择模式切换 */}
          <div style={styles.selectModeToggle}>
            <button
              style={{
                ...styles.selectModeBtn,
                ...(doubaoSelectMode === 'input' ? styles.selectModeBtnActive : {}),
              }}
              onClick={() => setDoubaoSelectMode('input')}
            >
              选择输入价格模型
            </button>
            <button
              style={{
                ...styles.selectModeBtn,
                ...(doubaoSelectMode === 'output' ? styles.selectModeBtnActive : {}),
              }}
              onClick={() => setDoubaoSelectMode('output')}
            >
              选择输出价格模型
            </button>
          </div>

          {/* 模型列表 */}
          <div style={styles.listContainer}>
            {doubaoLoading ? (
              <div style={styles.loadingState}>加载中...</div>
            ) : doubaoModels.length === 0 ? (
              <div style={styles.emptyState}>暂无数据，请先导入豆包定价数据</div>
            ) : (
              doubaoModels.map((model, index) => {
                const isSelectedInput = selectedDoubaoInput?.id === model.id;
                const isSelectedOutput = selectedDoubaoOutput?.id === model.id;
                const isSelected = isSelectedInput || isSelectedOutput;
                return (
                  <div
                    key={model.id || index}
                    style={{
                      ...styles.listItem,
                      ...(isSelected ? styles.listItemSelected : {}),
                    }}
                    onClick={() => {
                      if (doubaoSelectMode === 'input') {
                        setSelectedDoubaoInput(model);
                      } else {
                        setSelectedDoubaoOutput(model);
                      }
                    }}
                    onMouseEnter={(e) => {
                      if (!isSelected) {
                        e.currentTarget.style.backgroundColor = '#f8fafc';
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (!isSelected) {
                        e.currentTarget.style.backgroundColor = '';
                      }
                    }}
                  >
                    <div style={styles.modelName}>
                      {model.model_name}
                      {isSelectedInput && (
                        <span style={{ ...styles.selectedModelBadge, ...styles.inputBadge }}>输入</span>
                      )}
                      {isSelectedOutput && (
                        <span style={{ ...styles.selectedModelBadge, ...styles.outputBadge }}>输出</span>
                      )}
                    </div>
                    <div style={styles.modelMeta}>
                      <span>{model.provider}</span>
                      <span>{model.category}</span>
                      {model.service_type && <span>{model.service_type}</span>}
                      {model.price && (
                        <span style={styles.priceTag}>
                          {model.price} {model.unit}
                        </span>
                      )}
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      </div>

      {/* 选中对比区域 */}
      {(selectedQwen || selectedDoubaoInput || selectedDoubaoOutput) && (
        <div style={styles.selectedPanel}>
          <h3 style={styles.selectedTitle}>已选择模型对比</h3>
          <div style={styles.compareGrid}>
            {/* Qwen 选中信息 */}
            <div style={styles.compareCard}>
              <div style={styles.compareLabel}>阿里云 · 通义千问</div>
              {selectedQwen ? (
                <>
                  <div style={styles.compareValue}>{selectedQwen.display_name || selectedQwen.model_name}</div>
                  {/* 参数标签 */}
                  <div style={styles.tagContainer}>
                    {selectedQwen.mode && (
                      <span style={{ ...styles.tag, ...styles.tagMode }}>{selectedQwen.mode}</span>
                    )}
                    {selectedQwen.token_tier && (
                      <span style={{ ...styles.tag, ...styles.tagToken }}>{selectedQwen.token_tier}</span>
                    )}
                    {selectedQwen.supports_batch && (
                      <span style={{ ...styles.tag, ...styles.tagBatch }}>Batch半价</span>
                    )}
                    {selectedQwen.supports_cache && (
                      <span style={{ ...styles.tag, ...styles.tagCache }}>支持缓存</span>
                    )}
                  </div>
                  {/* 价格 */}
                  {getPriceDisplay(selectedQwen.prices) && (
                    <div style={{ ...styles.priceTag, marginTop: '8px' }}>
                      {getPriceDisplay(selectedQwen.prices)}
                    </div>
                  )}
                </>
              ) : (
                <div style={styles.noSelection}>请从左侧选择模型</div>
              )}
            </div>

            {/* Doubao 选中信息 - 输入和输出两个模型 */}
            <div style={styles.compareCard}>
              <div style={styles.compareLabel}>火山引擎 · 豆包</div>
              {/* 输入价格模型 */}
              <div style={{ marginBottom: '12px' }}>
                <div style={{ fontSize: '12px', color: '#166534', fontWeight: '500', marginBottom: '4px' }}>
                  输入价格模型:
                </div>
                {selectedDoubaoInput ? (
                  <div style={styles.compareValue}>
                    {selectedDoubaoInput.model_name}
                    {selectedDoubaoInput.price && (
                      <span style={{ ...styles.priceTag, marginLeft: '8px' }}>
                        {selectedDoubaoInput.price} {selectedDoubaoInput.unit}
                      </span>
                    )}
                  </div>
                ) : (
                  <div style={{ color: '#94a3b8', fontSize: '13px' }}>未选择</div>
                )}
              </div>
              {/* 输出价格模型 */}
              <div>
                <div style={{ fontSize: '12px', color: '#92400e', fontWeight: '500', marginBottom: '4px' }}>
                  输出价格模型:
                </div>
                {selectedDoubaoOutput ? (
                  <div style={styles.compareValue}>
                    {selectedDoubaoOutput.model_name}
                    {selectedDoubaoOutput.price && (
                      <span style={{ ...styles.priceTag, marginLeft: '8px' }}>
                        {selectedDoubaoOutput.price} {selectedDoubaoOutput.unit}
                      </span>
                    )}
                  </div>
                ) : (
                  <div style={{ color: '#94a3b8', fontSize: '13px' }}>未选择</div>
                )}
              </div>
            </div>
          </div>

          {/* 建立关联按钮 */}
          <button
            style={{
              ...styles.linkButton,
              ...(!selectedQwen || !selectedDoubaoInput || !selectedDoubaoOutput ? styles.linkButtonDisabled : {}),
            }}
            disabled={!selectedQwen || !selectedDoubaoInput || !selectedDoubaoOutput}
            onClick={() => {
              if (selectedQwen && selectedDoubaoInput && selectedDoubaoOutput) {
                const newMapping = {
                  id: Date.now(),
                  qwen_model_name: selectedQwen.model_name || selectedQwen.display_name,
                  qwen_display_name: selectedQwen.display_name || selectedQwen.model_name,
                  doubao_input_model_name: selectedDoubaoInput.model_name,
                  doubao_output_model_name: selectedDoubaoOutput.model_name,
                  created_at: new Date().toISOString(),
                };
                const updatedMappings = [...mappings, newMapping];
                setMappings(updatedMappings);
                localStorage.setItem('model_mappings', JSON.stringify(updatedMappings));
                // 清空选择
                setSelectedQwen(null);
                setSelectedDoubaoInput(null);
                setSelectedDoubaoOutput(null);
                alert('映射关系已添加到列表！');
              }
            }}
          >
            建立关联
          </button>
        </div>
      )}

      {/* 映射列表模块 */}
      <div style={styles.mappingPanel}>
        {/* 本地未保存的映射 */}
        <div style={styles.mappingTitle}>
          <span>
            待保存的映射关系
            <span style={styles.unsavedBadge}>本地</span>
          </span>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <span style={{ fontSize: '13px', color: '#64748b', fontWeight: '400' }}>
              共 {mappings.length} 条
            </span>
            <button
              style={{
                ...styles.saveAllButton,
                ...(mappings.length === 0 || isSaving ? styles.saveAllButtonDisabled : {}),
              }}
              disabled={mappings.length === 0 || isSaving}
              onClick={saveAllToDatabase}
            >
              {isSaving ? '保存中...' : '一键保存到数据库'}
            </button>
          </div>
        </div>
        {mappings.length === 0 ? (
          <div style={styles.emptyMapping}>暂无待保存的映射关系，请在上方选择模型并点击"建立关联"</div>
        ) : (
          <table style={styles.mappingTable}>
            <thead>
              <tr>
                <th style={styles.mappingTh}>阿里云模型</th>
                <th style={styles.mappingTh}>豆包输入价格模型</th>
                <th style={styles.mappingTh}>豆包输出价格模型</th>
                <th style={styles.mappingTh}>创建时间</th>
                <th style={{ ...styles.mappingTh, width: '80px' }}>操作</th>
              </tr>
            </thead>
            <tbody>
              {mappings.map((mapping) => (
                <tr key={mapping.id}>
                  <td style={styles.mappingTd}>{mapping.qwen_display_name}</td>
                  <td style={styles.mappingTd}>{mapping.doubao_input_model_name}</td>
                  <td style={styles.mappingTd}>{mapping.doubao_output_model_name}</td>
                  <td style={styles.mappingTd}>
                    {new Date(mapping.created_at).toLocaleString('zh-CN')}
                  </td>
                  <td style={styles.mappingTd}>
                    <button
                      style={styles.deleteBtn}
                      onClick={() => {
                        if (window.confirm('确定要删除这条映射关系吗？')) {
                          const updatedMappings = mappings.filter((m) => m.id !== mapping.id);
                          setMappings(updatedMappings);
                          localStorage.setItem('model_mappings', JSON.stringify(updatedMappings));
                        }
                      }}
                    >
                      删除
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* 已保存到数据库的映射 */}
      <div style={styles.mappingPanel}>
        <div style={styles.mappingTitle}>
          <span>
            已保存的映射关系
            <span style={styles.savedBadge}>数据库</span>
          </span>
          <span style={{ fontSize: '13px', color: '#64748b', fontWeight: '400' }}>
            共 {savedMappings.length} 条
          </span>
        </div>
        {savedMappings.length === 0 ? (
          <div style={styles.emptyMapping}>数据库中暂无映射关系</div>
        ) : (
          <table style={styles.mappingTable}>
            <thead>
              <tr>
                <th style={styles.mappingTh}>阿里云模型</th>
                <th style={styles.mappingTh}>豆包输入价格模型</th>
                <th style={styles.mappingTh}>豆包输出价格模型</th>
                <th style={styles.mappingTh}>创建时间</th>
                <th style={{ ...styles.mappingTh, width: '80px' }}>操作</th>
              </tr>
            </thead>
            <tbody>
              {savedMappings.map((mapping) => (
                <tr key={mapping.id}>
                  <td style={styles.mappingTd}>{mapping.qwen_display_name}</td>
                  <td style={styles.mappingTd}>{mapping.doubao_input_model_name}</td>
                  <td style={styles.mappingTd}>{mapping.doubao_output_model_name}</td>
                  <td style={styles.mappingTd}>
                    {mapping.created_at ? new Date(mapping.created_at).toLocaleString('zh-CN') : '-'}
                  </td>
                  <td style={styles.mappingTd}>
                    <button
                      style={styles.deleteBtn}
                      onClick={() => deleteFromDatabase(mapping.id)}
                    >
                      删除
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

export default DebatePage;
