# 港口设备租赁与仓储管理系统

> 一个现代化的港口设备管理系统，提供设备租赁、仓储管理、订单处理等全流程解决方案。

## 项目概述

本项目是一个基于 Vue3 + FastAPI + MySQL 的港口设备租赁与仓储管理系统，旨在为港口作业设备提供高效的租赁、存储、维护和订单管理服务。

## 主要功能

### 设备管理
- **设备信息管理**: 设备档案、分类、规格参数管理
- **设备状态跟踪**: 在库、已出库、维修中、已报废等状态管理
- **库存管理**: 实时库存监控、出入库记录
- **维护保养**: 维修记录、保养计划、质保管理

### 租赁管理
- **客户管理**: 客户信息、信用评级管理
- **租赁订单**: 订单创建、状态跟踪、费用计算
- **租赁合同**: 合同管理、期限提醒、续租处理
- **设备调度**: 设备分配、调度优化、资源利用率分析

### 财务管理
- **计费管理**: 租金计算、费用明细、账单生成
- **收款管理**: 收款记录、欠款提醒、财务报表
- **成本分析**: 设备成本分析、收益统计

### 数据统计
- **设备统计**: 设备利用率、故障率分析
- **业务统计**: 租赁收入、客户分析、趋势预测
- **可视化报表**: ECharts 图表展示、数据导出

![images](/Images/img1.png)

![images](/Images/img2.png)

## 技术栈

### 后端
- **框架**: FastAPI 0.124+
- **数据库**: MySQL 8.0+
- **ORM**: SQLAlchemy 2.0+
- **认证**: JWT (python-jose)
- **密码加密**: Passlib (bcrypt)
- **API文档**: Swagger/OpenAPI (自动生成)

### 前端
- **框架**: Vue 3.5+ (Composition API)
- **UI组件**: Arco Design Vue 2.44+
- **构建工具**: Vite 3.2+
- **状态管理**: Pinia 2.0+
- **路由**: Vue Router 4.0+
- **类型检查**: TypeScript 4.9+
- **图表库**: ECharts 5.4+ (vue-echarts)
- **HTTP客户端**: Axios 0.24+

### 开发工具
- **包管理**: pnpm (前端) / uv (后端)
- **代码规范**: ESLint + Prettier + Stylelint
- **Git钩子**: Husky + lint-staged
- **提交规范**: Commitlint

## 快速开始

### 环境要求
- Node.js >= 14.0.0
- Python >= 3.12
- MySQL >= 8.0
- pnpm >= 8.0
- uv >= 0.5

### 1. 克隆项目
```bash
git clone https://github.com/your-username/port_equipment_db.git
cd port_equipment_db
```

### 2. 数据库配置
```bash
# 创建数据库
mysql -u root -p
CREATE DATABASE port_equipment_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# 更新数据库配置 (backend/database.py)
DB_USER = 'root'
DB_PASSWORD = 'your_password'
DB_HOST = '127.0.0.1'
DB_PORT = 3306
```

### 3. 后端启动
```bash
cd backend

# 安装依赖
uv sync

# 启动开发服务器
uv run python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 4. 前端启动
```bash
cd web

# 安装依赖
pnpm install

# 启动开发服务器
pnpm dev
```

### 5. 访问应用
- 前端: http://localhost:5173
- 后端API: http://localhost:8000
- API文档: http://localhost:8000/docs

## 项目结构

```
port_equipment_db/
├── backend/                 # 后端代码
│   ├── main.py             # FastAPI 应用入口
│   ├── crud.py             # 数据库操作
│   ├── models.py           # 数据库模型
│   ├── schemas.py          # Pydantic 模型
│   ├── database.py         # 数据库配置
│   └── pyproject.toml      # Python 项目配置
├── web/                    # 前端代码
│   ├── src/
│   │   ├── components/     # 组件
│   │   ├── views/          # 页面
│   │   ├── api/            # API 接口
│   │   ├── stores/         # Pinia 状态管理
│   │   ├── utils/          # 工具函数
│   │   └── assets/         # 静态资源
│   ├── config/             # Vite 配置
│   └── package.json        # 前端项目配置
├── docs/                   # 项目文档
└── README.md              # 项目说明
```

## 配置说明

### 数据库配置
在 `backend/database.py` 中配置数据库连接信息：

```python
DB_USER = 'root'
DB_PASSWORD = 'your_password'
DB_HOST = '127.0.0.1'
DB_PORT = 3306
DB_NAME = 'port_equipment_db'
```

### API 配置
API 配置文件位于 `web/src/api/` 目录，包含所有后端接口定义。

### 环境变量
可通过 `.env` 文件配置环境变量：

```bash
# 开发环境
NODE_ENV=development
VITE_API_BASE_URL=http://localhost:8000/api

# 生产环境
NODE_ENV=production
VITE_API_BASE_URL=https://your-domain.com/api
```

## API 文档

启动后端服务后，访问 http://localhost:8000/docs 可查看完整的 API 文档。

### 主要API端点
- `GET /api/equipment` - 获取设备列表
- `POST /api/equipment` - 创建新设备
- `PUT /api/equipment/{id}` - 更新设备信息
- `DELETE /api/equipment/{id}` - 删除设备
- `GET /api/orders` - 获取订单列表
- `POST /api/orders` - 创建新订单
- `GET /api/customers` - 获取客户列表
- `POST /api/customers` - 创建新客户

## 测试

### 后端测试
```bash
cd backend
uv run pytest
```

### 前端测试
```bash
cd web
pnpm test
```

## 部署

### 后端部署
```bash
# 生产环境启动
cd backend
uv run gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker
```

### 前端部署
```bash
# 构建生产版本
cd web
pnpm build

# 部署到 dist/ 目录
```

## 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 提交规范
项目使用 [Conventional Commits](https://conventionalcommits.org/) 规范：

- `feat:` 新功能
- `fix:` 修复bug
- `docs:` 文档更新
- `style:` 代码格式化
- `refactor:` 代码重构
- `test:` 测试相关
- `chore:` 构建工具或辅助工具的变动

## 许可证

本项目基于 [MIT License](LICENSE) 开源。

## 致谢

- [Arco Design Vue](https://arco.design/vue/component/overview) - 优秀的 Vue3 组件库
- [FastAPI](https://fastapi.tiangolo.com/) - 现代化的 Python Web 框架
- [Vue.js](https://vuejs.org/) - 渐进式 JavaScript 框架
- [SQLAlchemy](https://www.sqlalchemy.org/) - Python SQL 工具包

## 联系方式

如有问题或建议，请通过以下方式联系：

- 项目地址: https://github.com/your-username/port_equipment_db
- 问题反馈: https://github.com/your-username/port_equipment_db/issues
- 邮箱: your-email@example.com

---

如果这个项目对你有帮助，请给个 Star！
