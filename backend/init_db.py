"""
数据库初始化脚本（PostgreSQL）
运行此脚本以创建数据库表、视图、触发器，并插入初始数据。

该脚本可以重复执行：
- 表和列不会被破坏；
- 视图和触发器会被重建；
- 仅在用户表为空时插入初始数据。
"""
import os
import time
from pathlib import Path
import hashlib

from sqlalchemy import text

from database import engine, SessionLocal
from models import Base, User, Equipment, Customer, EquipmentStatus

SQL_DIR = Path(__file__).resolve().parent / "sql"
INIT_SQL_FILE = SQL_DIR / "init_pg.sql"

# 等待数据库就绪的最大秒数（Docker 启动时数据库可能尚未准备好）
DB_WAIT_SECONDS = int(os.getenv("DB_WAIT_SECONDS", "60"))


def hash_password(password: str) -> str:
    """使用 SHA256 哈希密码（简单实现，生产环境建议使用 bcrypt）"""
    return hashlib.sha256(password.encode()).hexdigest()


def wait_for_database() -> None:
    """等待 PostgreSQL 可连接"""
    deadline = time.time() + DB_WAIT_SECONDS
    last_error = None

    while time.time() < deadline:
        try:
            with engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            print("数据库连接成功")
            return
        except Exception as exc:  # noqa: BLE001 - 启动阶段需要捕获所有连接异常
            last_error = exc
            print("等待数据库连接...")
            time.sleep(2)

    raise RuntimeError(f"数据库连接超时：{last_error}")


def create_tables() -> None:
    print("正在创建数据库表...")
    Base.metadata.create_all(bind=engine)
    print("数据库表创建完成！")


def create_views_and_triggers() -> None:
    """执行 PostgreSQL 视图与触发器脚本（可重复执行）"""
    if not INIT_SQL_FILE.exists():
        print(f"未找到 {INIT_SQL_FILE}，跳过视图与触发器创建")
        return

    print("正在创建/更新数据库视图与触发器...")
    sql = INIT_SQL_FILE.read_text(encoding="utf-8")
    with engine.begin() as conn:
        # psycopg2 支持一次执行多条 SQL（脚本内均为无参数语句）
        conn.exec_driver_sql(sql)
    print("视图与触发器创建完成！")


def seed_data() -> None:
    """插入初始数据（仅当没有用户时）"""
    db = SessionLocal()
    try:
        existing_user = db.query(User).first()
        if existing_user:
            print("数据库已初始化，跳过初始数据插入")
            return

        print("正在插入初始数据...")

        # 创建管理员用户
        admin = User(
            username="admin",
            password_hash=hash_password("admin123"),
            real_name="系统管理员",
            role="admin",
            phone="13800138000",
            email="admin@example.com",
            status="active",
        )
        db.add(admin)

        # 创建操作员用户
        operator = User(
            username="zhanggong",
            password_hash=hash_password("123456"),
            real_name="张工",
            role="operator",
            phone="13800138001",
            status="active",
        )
        db.add(operator)

        # 创建初始设备（状态使用枚举成员，避免 PostgreSQL 枚举写入失败）
        equipments = [
            Equipment(
                equipment_code="CR-5001",
                equipment_name="门座式起重机配件包",
                category="起重配件",
                storage_location="A区-01-04",
                purchase_price=50000.0,
                daily_rental_rate=800.0,
                status=EquipmentStatus.IN_STOCK,
                specifications="适用于10-50吨门座式起重机",
            ),
            Equipment(
                equipment_code="FL-2002",
                equipment_name="重油输送泵",
                category="流体设备",
                storage_location="B区-02-11",
                purchase_price=35000.0,
                daily_rental_rate=600.0,
                status=EquipmentStatus.MAINTENANCE,
                specifications="流量200L/min，压力10MPa",
            ),
            Equipment(
                equipment_code="CN-1022",
                equipment_name="绑扎杆 (100根/组)",
                category="固缚索具",
                storage_location="C区-03-08",
                purchase_price=8000.0,
                daily_rental_rate=120.0,
                status=EquipmentStatus.IN_STOCK,
                specifications="长度2-4米可调",
            ),
            Equipment(
                equipment_code="HY-3305",
                equipment_name="液压千斤顶 (50T)",
                category="液压工具",
                storage_location="A区-02-05",
                purchase_price=18000.0,
                daily_rental_rate=300.0,
                status=EquipmentStatus.IN_STOCK,
                specifications="最大承载50吨",
            ),
            Equipment(
                equipment_code="FB-8801",
                equipment_name="钢丝绳索 (100米)",
                category="固缚索具",
                storage_location="B区-05-12",
                purchase_price=12000.0,
                daily_rental_rate=200.0,
                status=EquipmentStatus.IN_STOCK,
                specifications="直径20mm，破断力150KN",
            ),
        ]
        db.add_all(equipments)

        # 创建初始客户
        customers = [
            Customer(
                customer_name="长宏海运",
                contact_person="王船长",
                phone="13900139001",
                email="changhong@example.com",
                address="上海市浦东新区港务大道123号",
                credit_rating="A",
            ),
            Customer(
                customer_name="远洋荣耀",
                contact_person="李经理",
                phone="13900139002",
                email="ocean@example.com",
                address="宁波市北仑区港口路456号",
                credit_rating="A",
            ),
            Customer(
                customer_name="太平洋航运",
                contact_person="赵总",
                phone="13900139003",
                email="pacific@example.com",
                address="深圳市盐田区海港路789号",
                credit_rating="B",
            ),
            Customer(
                customer_name="马士基物流",
                contact_person="陈主管",
                phone="13900139004",
                email="maersk@example.com",
                address="广州市南沙区港湾路321号",
                credit_rating="A",
            ),
        ]
        db.add_all(customers)

        db.commit()
        print("初始数据插入完成！")
        print("\n默认账户信息：")
        print("管理员 - 用户名: admin, 密码: admin123")
        print("操作员 - 用户名: zhanggong, 密码: 123456")
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def init_database() -> None:
    wait_for_database()
    create_tables()
    create_views_and_triggers()
    seed_data()


if __name__ == "__main__":
    init_database()
