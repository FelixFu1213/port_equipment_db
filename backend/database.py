import os
from urllib.parse import quote_plus

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

load_dotenv()

# 数据库连接信息（优先使用环境变量，便于 Docker / 生产环境部署）
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")
DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "port_equipment_db")
SQL_ECHO = os.getenv("DB_ECHO", "false").lower() in ("1", "true", "yes", "on")

# 对用户名和密码进行 URL 编码，处理特殊字符
encoded_user = quote_plus(DB_USER)
encoded_password = quote_plus(DB_PASSWORD)

# 创建数据库连接 URL（PostgreSQL）
DATABASE_URL = os.getenv("DATABASE_URL") or (
    f"postgresql+psycopg2://{encoded_user}:{encoded_password}"
    f"@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

# 创建引擎
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    pool_recycle=3600,
    echo=SQL_ECHO,  # 开发环境可通过 DB_ECHO=true 打印 SQL
)

# 创建会话
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 创建基类
Base = declarative_base()


# 依赖注入：获取数据库会话
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
