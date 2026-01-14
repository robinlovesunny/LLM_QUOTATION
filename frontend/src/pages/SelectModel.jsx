import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { getModels } from '../api';
import StepIndicator from '../components/StepIndicator';

function SelectModel() {
  const navigate = useNavigate();
  const { categoryCode } = useParams();
  const [models, setModels] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadModels();
  }, [categoryCode]);

  const loadModels = async () => {
    try {
      const response = await getModels(categoryCode);
      setModels(response.data.models);
    } catch (error) {
      console.error('加载模型失败:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="text-center py-12">加载中...</div>;
  }

  return (
    <div>
      {/* 步骤指示器 */}
      <StepIndicator currentStep="model" categoryCode={categoryCode} />
      
      <div className="mb-8">
        <button
          onClick={() => navigate('/select-category')}
          className="text-text-secondary hover:text-text-primary mb-4 flex items-center gap-1"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
          返回选择场景
        </button>
        <h2 className="text-3xl font-semibold text-text-primary">选择模型</h2>
      </div>

      {models.length === 0 ? (
        <div className="text-center py-12 text-text-secondary">
          该场景暂无可用模型
        </div>
      ) : (
        <div className="space-y-4">
          {models.map((model) => (
            <div
              key={model.id}
              className="p-6 bg-white border border-border rounded-xl hover:shadow-md transition-all"
            >
              <div className="flex justify-between items-start">
                <div className="flex-1">
                  <h3 className="text-xl font-medium text-text-primary mb-2">
                    {model.model_name}
                  </h3>
                  <p className="text-sm text-text-secondary mb-3">
                    {model.model_name}
                  </p>
                  <div className="flex flex-wrap gap-2">
                    {model.billing_dimensions.map((dim, idx) => (
                      <span
                        key={idx}
                        className="px-3 py-1 bg-secondary text-text-secondary text-xs rounded-full"
                      >
                        {dim}
                      </span>
                    ))}
                  </div>
                </div>
                <button
                  onClick={() => navigate(`/configure/${model.id}`)}
                  className="px-6 py-2 bg-primary text-white rounded-lg hover:bg-opacity-90 transition-all ml-4"
                >
                  选择此模型
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default SelectModel;
