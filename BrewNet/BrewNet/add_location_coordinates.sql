-- 可选：添加经纬度字段到 users 表，用于距离计算
-- 如果不需要计算距离，可以跳过此配置

-- 方案1：在 users 表添加经纬度字段（简单方案，不需要 PostGIS）
-- 注意：这个方案使用普通的 B-tree 索引，距离计算在应用层完成
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- 创建普通索引以优化地理位置查询（用于范围查询，如查找某个经纬度范围内的用户）
CREATE INDEX IF NOT EXISTS idx_users_latitude ON users(latitude) WHERE latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_longitude ON users(longitude) WHERE longitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_location_composite ON users(latitude, longitude) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- 方案2：使用 PostGIS 扩展（更强大的地理空间功能，需要先启用 PostGIS 扩展）
-- 步骤1：首先需要启用 PostGIS 扩展（需要在 Supabase Dashboard 的 Database → Extensions 中启用）
-- 或者使用 SQL：
-- CREATE EXTENSION IF NOT EXISTS postgis;

-- 步骤2：添加地理位置字段（使用 geography 类型）
-- ALTER TABLE users 
-- ADD COLUMN IF NOT EXISTS location_point geography(POINT, 4326);

-- 步骤3：创建空间索引（PostGIS 会自动使用 GIST 索引）
-- CREATE INDEX IF NOT EXISTS idx_users_location_point ON users USING GIST (location_point);

-- 注意：
-- 1. 方案1（推荐）：简单，不需要 PostGIS，距离计算在应用层完成
-- 2. 方案2：需要启用 PostGIS 扩展，但支持更强大的地理空间查询
-- 3. 当前实现（只存储地址字符串）已经可以工作，不需要立即配置
-- 4. 如果使用方案1，应用层可以使用 LocationService.calculateDistance() 计算距离

