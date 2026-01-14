import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { getCategories } from '../api';

function SelectCategory() {
  const navigate = useNavigate();
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadCategories();
  }, []);

  const loadCategories = async () => {
    try {
      const response = await getCategories();
      setCategories(response.data.categories);
    } catch (error) {
      console.error('加载类目失败:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="text-center py-12">加载中...</div>;
  }

  return (
    <div>
      <h2 className="text-3xl font-semibold text-text-primary mb-8">选择场景</h2>
      
      <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 gap-6">
        {categories.map((category) => (
          <button
            key={category.id}
            onClick={() => navigate(`/select-model/${category.code}`)}
            className="p-6 bg-white border border-border rounded-xl hover:shadow-lg hover:border-primary transition-all text-left"
          >
            <div className="text-lg font-medium text-text-primary mb-2">
              {category.name}
            </div>
            <div className="text-sm text-text-secondary">
              {category.code}
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}

export default SelectCategory;
