"""
Python补充图表生成脚本
用于生成更专业的对比图表（可选，如果MATLAB图不够漂亮）
需要安装: pip install matplotlib numpy scipy
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np
from matplotlib import rcParams

# 设置中文字体（Windows）
rcParams['font.sans-serif'] = ['SimHei']
rcParams['axes.unicode_minus'] = False
rcParams['font.size'] = 12

# ==================== 图表1: 定量对比柱状图 ====================
def generate_quantitative_bar_chart():
    """生成定量对比柱状图（用于PPT展示）"""
    
    # 数据（归一化到0-1，越大越好）
    values_4step = [0.65, 0.70, 0.60, 0.75, 1.00]    # 4步：快但质量一般
    values_12step = [0.80, 0.75, 0.73, 0.80, 0.70]   # 12步：平衡
    values_proposed = [0.95, 0.88, 0.92, 0.85, 0.65] # 本文：质量最优
    
    # 闭合雷达图
    values_4step += values_4step[:1]
    values_12step += values_12step[:1]
    values_proposed += values_proposed[:1]
    
    angles = [n / float(N) * 2 * pi for n in range(N)]
    angles += angles[:1]
    
    fig, ax = plt.subplots(figsize=(8, 8), subplot_kw=dict(projection='polar'))
    
    ax.plot(angles, values_4step, 'o-', linewidth=2, label='4步相移', color='#E74C3C')
    ax.fill(angles, values_4step, alpha=0.15, color='#E74C3C')
    
    ax.plot(angles, values_12step, 's-', linewidth=2, label='12步相移', color='#3498DB')
    ax.fill(angles, values_12step, alpha=0.15, color='#3498DB')
    
    ax.plot(angles, values_proposed, '^-', linewidth=2.5, label='本文方法', color='#2ECC71')
    ax.fill(angles, values_proposed, alpha=0.25, color='#2ECC71')
    
    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(categories, fontsize=13)
    ax.set_ylim(0, 1)
    ax.set_yticks([0.2, 0.4, 0.6, 0.8, 1.0])
    ax.set_yticklabels(['0.2', '0.4', '0.6', '0.8', '1.0'], fontsize=10)
    ax.grid(True, linestyle='--', alpha=0.7)
    ax.legend(loc='upper right', bbox_to_anchor=(1.3, 1.1), fontsize=12)
    ax.set_title('图：综合性能雷达图', fontsize=16, fontweight='bold', pad=20)
    
    plt.tight_layout()
    plt.savefig('paper_figures/Radar_Chart.png', dpi=300, bbox_inches='tight')
    plt.savefig('paper_figures/Radar_Chart.pdf')
    plt.close()
    
    print("✓ 雷达图已生成")

# ==================== 图表3: 改进率趋势图 ====================
def generate_improvement_trend():
    """生成改进率趋势图（突出本文方法优势）"""
    
    metrics = ['相位噪声↓', '平均质量↑', '边缘锐度↑\n(核心)', '点云数↑', '完整性↑']
    
    # 改进率（vs 4步基线）
    improvement_12step = [23.9, 7.5, 21.2, 6.6, 6.6]
    improvement_proposed = [39.3, 15.5, 48.1, 13.0, 13.2]  # 本文方法
    
    x = np.arange(len(metrics))
    width = 0.35
    
    fig, ax = plt.subplots(figsize=(12, 7))
    
    bars1 = ax.bar(x - width/2, improvement_12step, width, 
                   label='12步相移', color='#3498DB', alpha=0.8)
    bars2 = ax.bar(x + width/2, improvement_proposed, width, 
                   label='本文方法', color='#2ECC71', alpha=0.9)
    
    # 添加数值标签
    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                    f'{height:.1f}%',
                    ha='center', va='bottom', fontsize=11, fontweight='bold')
    
    # 特殊标注核心指标
    ax.annotate('核心优势！', xy=(2, 48.1), xytext=(2.5, 55),
                arrowprops=dict(arrowstyle='->', color='red', lw=2),
                fontsize=13, color='red', fontweight='bold')
    
    ax.set_ylabel('改进率（%）', fontsize=14, fontweight='bold')
    ax.set_title('图：相对于4步相移的改进率对比', fontsize=16, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(metrics, fontsize=12)
    ax.legend(fontsize=13, loc='upper left')
    ax.grid(axis='y', alpha=0.3)
    ax.set_ylim([0, 60])
    
    plt.tight_layout()
    plt.savefig('paper_figures/Improvement_Trend.png', dpi=300, bbox_inches='tight')
    plt.savefig('paper_figures/Improvement_Trend.pdf')
    plt.close()
    
    print("✓ 改进率趋势图已生成")

# ==================== 图表4: 参数敏感性分析 ====================
def generate_parameter_sensitivity():
    """生成参数敏感性曲线（alpha的影响）"""
    
    alpha_values = np.array([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9])
    
    # 模拟数据（请替换为实际实验结果）
    edge_sharpness = np.array([0.0175, 0.0195, 0.0210, 0.0225, 0.0231, 0.0230, 0.0228, 0.0223, 0.0215])
    point_counts = np.array([885, 910, 935, 955, 967, 972, 970, 968, 960]) / 1000  # 单位：千
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))
    
    # 左图：边缘锐度
    ax1.plot(alpha_values, edge_sharpness, 'o-', linewidth=2.5, markersize=8, color='#2ECC71')
    ax1.axvline(x=0.5, color='red', linestyle='--', linewidth=2, label='最优值 α=0.5')
    ax1.axhline(y=0.0231, color='red', linestyle='--', linewidth=1.5, alpha=0.5)
    ax1.fill_between(alpha_values, 0.0225, 0.0235, alpha=0.2, color='green', label='最优区间')
    ax1.set_xlabel('边缘增强系数 α', fontsize=13, fontweight='bold')
    ax1.set_ylabel('边缘锐度', fontsize=13, fontweight='bold')
    ax1.set_title('(a) α对边缘锐度的影响', fontsize=14, fontweight='bold')
    ax1.grid(True, alpha=0.3)
    ax1.legend(fontsize=11)
    ax1.set_xlim([0, 1])
    
    # 右图：点云数量
    ax2.plot(alpha_values, point_counts, 's-', linewidth=2.5, markersize=8, color='#3498DB')
    ax2.axvline(x=0.5, color='red', linestyle='--', linewidth=2, label='最优值 α=0.5')
    ax2.axhline(y=0.967, color='red', linestyle='--', linewidth=1.5, alpha=0.5)
    ax2.fill_between(alpha_values, 0.960, 0.975, alpha=0.2, color='blue', label='稳定区间')
    ax2.set_xlabel('边缘增强系数 α', fontsize=13, fontweight='bold')
    ax2.set_ylabel('点云数量 (×10³)', fontsize=13, fontweight='bold')
    ax2.set_title('(b) α对点云数量的影响', fontsize=14, fontweight='bold')
    ax2.grid(True, alpha=0.3)
    ax2.legend(fontsize=11)
    ax2.set_xlim([0, 1])
    
    plt.suptitle('图：参数α的敏感性分析', fontsize=16, fontweight='bold')
    plt.tight_layout()
    plt.savefig('paper_figures/Parameter_Sensitivity.png', dpi=300, bbox_inches='tight')
    plt.savefig('paper_figures/Parameter_Sensitivity.pdf')
    plt.close()
    
    print("✓ 参数敏感性分析图已生成")

# ==================== 主函数 ====================
if __name__ == '__main__':
    import os
    
    # 创建输出文件夹
    if not os.path.exists('paper_figures'):
        os.makedirs('paper_figures')
    
    print("========== 开始生成Python图表 ==========\n")
    
    try:
        generate_quantitative_bar_chart()
        generate_radar_chart()
        generate_improvement_trend()
        generate_parameter_sensitivity()
        
        print("\n========== 所有Python图表生成完成！ ==========")
        print("文件保存在 paper_figures/ 文件夹")
        print("  - PNG格式：300 DPI，适合打印")
        print("  - PDF格式：矢量图，LaTeX首选")
        print("\n提示：这些图表可用于PPT展示或论文补充")
        
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        print("请确保已安装: pip install matplotlib numpy scipy")
请替换为您的实际数据）
    methods = ['4步相移', '12步相移', '本文方法']
    
    # 归一化数据（以4步为基准100%）
    phase_noise = [100, 76, 61]  # 噪声越低越好，显示为降低率
    quality = [100, 107, 116]     # 质量提升
    edge_sharp = [100, 121, 148]  # 边缘锐度提升（核心卖点）
    point_count = [100, 107, 113] # 点云数量提升
    
    x = np.arange(len(methods))
    width = 0.2
    
    fig, ax = plt.subplots(figsize=(12, 6))
    
    bars1 = ax.bar(x - 1.5*width, phase_noise, width, label='噪声水平', color='#E74C3C')
    bars2 = ax.bar(x - 0.5*width, quality, width, label='平均质量', color='#3498DB')
    bars3 = ax.bar(x + 0.5*width, edge_sharp, width, label='边缘锐度⭐', color='#2ECC71')
    bars4 = ax.bar(x + 1.5*width, point_count, width, label='点云数量', color='#F39C12')
    
    # 添加数值标签
    for bars in [bars1, bars2, bars3, bars4]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                    f'{height:.0f}%',
                    ha='center', va='bottom', fontsize=10, fontweight='bold')
    
    # 添加基准线
    ax.axhline(y=100, color='gray', linestyle='--', linewidth=1.5, alpha=0.7, label='基准线')
    
    ax.set_ylabel('相对性能（%）', fontsize=14, fontweight='bold')
    ax.set_title('图：三种方法定量对比（归一化）', fontsize=16, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(methods, fontsize=13)
    ax.legend(fontsize=11, loc='upper left')
    ax.grid(axis='y', alpha=0.3)
    ax.set_ylim([50, 160])
    
    plt.tight_layout()
    plt.savefig('paper_figures/Quantitative_Bar_Chart.png', dpi=300, bbox_inches='tight')
    plt.savefig('paper_figures/Quantitative_Bar_Chart.pdf')
    plt.close()
    
    print("✓ 定量对比柱状图已生成")

# ==================== 图表2: 改进率雷达图 ====================
def generate_radar_chart():
    """生成性能雷达图（展示综合优势）"""
    
    from math import pi
    
    categories = ['低噪声', '高质量', '边缘锐度', '点云完整性', '计算效率']
    N = len(categories)
    
    # 数据（