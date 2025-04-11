#!/system/bin/sh

# =================================
# Android 初始化脚本：post-fs-data阶段执行
# 功能：清理异常系统属性，伪装正常手机
# 注意：需放置于/system/etc/init/并赋予755权限
# =================================

# 目标文件（系统启动时/data已挂载，可写入）
TARGET_FILE="/data/property/persistent_properties"

# 需删除的异常属性（核心：数据隔离+调试+分区验证）
DELETE_PROPS=(
    "persist.sys.vold_app_data_isolation_enabled"
    "persist.zygote.app_data_isolation"
    "debug.sf.auto_latch_unsignaled"
    "debug.sf.latch_unsignaled"
    "partition.system_dlkm.verified"
    "partition.vendor_dlkm.verified.root_digest"
)

# 需恢复的默认厂商配置（示例）
SET_PROPS=(
    "persist.device_config.aconfig_flags.netd_native.doh=0"
)


# =================================
# 核心操作函数（系统启动环境专用）
# =================================
# 安全删除属性（直接操作，无需额外权限）
delete_prop() {
    local prop="$1"
    resetprop --delete "$prop"
    sed -i '' "/^$prop=/d" "$TARGET_FILE"
}

# 设置默认属性（先删后写）
set_default_prop() {
    local prop="$1" value="$2"
    resetprop "$prop" "$value"
    sed -i '' "/^$prop=/d" "$TARGET_FILE" && echo "$prop=$value" >> "$TARGET_FILE"
}


# =================================
# 主逻辑（系统启动时自动执行）
# =================================
# 1. 检查目标文件存在（启动阶段已生成）
if [ ! -f "$TARGET_FILE" ]; then
    exit 0  # 无文件时跳过（罕见情况）
fi

# 2. 清理数据隔离属性（核心伪装步骤）
for prop in "${DELETE_PROPS[@]}"; do
    delete_prop "$prop"
已完成

# 3. 恢复厂商调试配置（避免异常暴露）
for pair in "${SET_PROPS[@]}"; do
    set_default_prop "${pair%%=*}" "${pair#*=}"
已完成

# 4. 可选：禁止属性重建（针对init脚本硬编码）
# （示例：删除init脚本中的setprop语句，需根据系统定制调整）
# find /system/etc/init/ -name "*.rc" -exec sed -i '/setprop persist.sys.vold_app_data_isolation_enabled/d' {} +

# 5. 无需重启，属性修改即时生效（系统启动后续阶段会读取persistent_properties）
