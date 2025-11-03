# Two-Tower 推荐模型训练环境

## 📋 概述

这个目录包含了 Two-Tower 推荐模型的完整训练环境，包括：
- 数据导出脚本
- PyTorch 模型定义
- 训练脚本
- Core ML 转换
- 评估工具

## 🚀 快速开始

### 1. 安装依赖

```bash
# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# 或
venv\Scripts\activate  # Windows

# 安装依赖
pip install -r requirements.txt
```

### 2. 配置环境变量

创建 `.env` 文件：

```bash
# Supabase 连接配置
SUPABASE_HOST=jcxvdolcdifdghaibspy.supabase.co
SUPABASE_DB=postgres
SUPABASE_USER=postgres
SUPABASE_PASSWORD=your_password_here
SUPABASE_PORT=5432
```

### 3. 导出数据

```bash
python export_data.py
```

这将会：
- 导出用户交互数据到 `data/interactions.json`
- 导出用户特征到 `data/user_features.json`
- 生成特征词汇表到 `data/vocab.json`

### 4. 训练模型

```bash
python train_model.py --epochs 100 --batch-size 64
```

### 5. 转换为 Core ML

```bash
python convert_to_coreml.py --checkpoint checkpoints/two_tower_v1.pth
```

### 6. 评估模型

```bash
python evaluate.py --model checkpoints/two_tower_v1.pth --data data/test.json
```

## 📁 目录结构

```
two_tower_model/
├── README.md                 # 本文件
├── requirements.txt          # Python 依赖
├── .env.example             # 环境变量模板
│
├── export_data.py           # 数据导出脚本
├── train_model.py           # 训练脚本
├── convert_to_coreml.py     # Core ML 转换
├── evaluate.py              # 模型评估
│
├── model/
│   ├── __init__.py
│   ├── two_tower.py         # Two-Tower 模型定义
│   ├── dataset.py           # 数据加载器
│   └── vocab.py             # 特征词汇表
│
├── data/                    # 数据目录
│   ├── interactions.json    # 交互数据
│   ├── user_features.json   # 用户特征
│   └── vocab.json          # 词汇表
│
├── checkpoints/             # 模型检查点
│   └── two_tower_v1.pth    # 训练好的模型
│
├── mlmodels/               # Core ML 模型
│   └── TwoTower.mlmodel    # iOS 使用的模型
│
└── logs/                   # 训练日志
    └── train.log
```

## 🔧 配置说明

### 模型配置

编辑 `model/two_tower.py` 中的配置：

```python
MODEL_CONFIG = {
    'user_feature_dim': 512,   # 用户特征维度（自动计算）
    'item_feature_dim': 512,   # 物品特征维度（相同）
    'embedding_dim': 64,       # Embedding 维度
    'hidden_dims': [128, 64],  # 隐藏层维度
    'dropout': 0.2,           # Dropout 率
}
```

### 训练配置

编辑 `train_model.py` 中的配置：

```python
TRAIN_CONFIG = {
    'epochs': 100,            # 训练轮数
    'batch_size': 64,         # 批次大小
    'learning_rate': 0.001,   # 学习率
    'weight_decay': 1e-5,    # 权重衰减
    'device': 'cuda',        # 'cuda' 或 'cpu'
}
```

## 📊 评估指标

模型训练完成后，会计算以下指标：

- **AUC (AUC-ROC)**: 二分类准确率
- **Hit Rate @ 10/20/50**: Top-K 命中率
- **NDCG @ 10/20/50**: 归一化折损累积增益
- **Precision @ 10**: Top 10 精确率
- **Recall @ 10**: Top 10 召回率

## 🚀 部署到 iOS

1. 转换模型为 Core ML
2. 将 `TwoTower.mlmodel` 添加到 Xcode 项目
3. 使用 `CoreMLTwoTowerEncoder` 加载模型
4. 集成到 `RecommendationService`

## 📝 训练日志

训练日志保存在 `logs/train.log`，包含：
- 每轮次的损失值
- 验证集指标
- 训练时间
- 最佳模型检查点

## 🐛 故障排除

### 常见问题

1. **CUDA 不可用**
   - 解决方案：设置 `device='cpu'` 或安装 CUDA 版本的 PyTorch

2. **内存不足**
   - 解决方案：减小 `batch_size` 或 `embedding_dim`

3. **数据不足**
   - 解决方案：Phase 1 和 2 已有基础实现，等积累足够数据后再训练

## 🔗 相关文档

- [Phase 1 完成总结](../BrewNet/PHASE1_COMPLETION_SUMMARY.md)
- [Phase 2 完成总结](../BrewNet/PHASE2_COMPLETION_SUMMARY.md)
- [Two-Tower 架构设计](../BrewNet/TWO_TOWER_IMPLEMENTATION.md)

## 📞 支持

如有问题，请参考主项目文档或提交 Issue。

