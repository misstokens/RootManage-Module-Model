# 可选文件
# 这个脚本将会在 post-fs-data 模式下运行
# 
# 说明:
# post-fs-data.sh 是一个可选的启动脚本文件，它将在 post-fs-data 模式下运行。
# 在这个模式下，脚本会在任何模块被挂载之前执行，这使得模块开发者可以在模块被挂载之前动态地调整它们的模块。
# 这个阶段发生在 Zygote 启动之前，并且是阻塞的，在执行完成之前或者 10 秒钟之后，启动过程会暂停。
# 请注意，使用 setprop 会导致启动过程死锁，建议使用 resetprop -n <prop_name> <prop_value> 代替。

#!/system/bin/sh
set -euo pipefail

# ======================
# 核心配置 - 属性伪装目标
# ======================
readonly TARGET_PROPS=(
    "ro.boot.mode=normal"
    "ro.bootmode=normal"
    "ro.recovery.boot=false"    # 额外防御恢复模式检测
    "ro.debuggable=0"          # 隐藏调试模式
)

# ======================
# 环境准备 - 安全初始化
# ======================
# 临时挂载系统分区（部分设备需要）
mount -o remount,rw /system 2>/dev/null || true

# 定义安全执行函数（带超时控制）
safe_resetprop() {
    local prop="$1" value="$2"
    timeout 1s resetprop -n "$prop" "$value" 2>/dev/null
    # 双重校验（防止属性被其他进程覆盖）
    [ "$(getprop -n "$prop")" != "$value" ] && \
        resetprop -n "$prop" "$value"
}

# ======================
# 属性伪装核心逻辑
# ======================
for prop in "${TARGET_PROPS[@]}"; do
    local prop_name="${prop%%=*}"
    local prop_value="${prop#*=}"
    
    # 防御性检查：仅在非normal时强制设置
    if [ "$(getprop -n "$prop_name")" != "$prop_value" ]; then
        safe_resetprop "$prop_name" "$prop_value"
        log -t PropHider "Set $prop_name to $prop_value"
    fi
done

# ======================
# 深度伪装 - 防止属性回溯
# ======================
# 1. 清除属性修改痕迹（针对检测工具读取/proc/self/environ）
unset $(getprop -n | grep -E 'ro\.boot\.mode|ro\.bootmode' | cut -d'=' -f1)

# 2. 内存级属性欺骗（需要配合内核模块）
# （此处可调用内核提供的属性过滤接口）

# ======================
# 恢复系统只读并清理
# ======================
mount -o remount,ro /system 2>/dev/null || true
rm -f /cache/bootprops.log  # 清除属性修改日志

# 输出伪装状态（调试用，正式环境建议移除）
log -t BootHider "Boot properties masked successfully"
log -t BootHider "ro.boot.mode=$(getprop -n ro.boot.mode)"
log -t BootHider "ro.bootmode=$(getprop -n ro.bootmode)"
