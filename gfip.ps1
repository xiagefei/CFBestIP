param(
    [int]$DN_COUNT = 10,                # 默认测试 10 个 IP
    [string]$CFCOLO = "",               # 默认不限制区域
    [string]$BaseDir = "D:\CF优选IP"    # 默认目录
)

# 定义路径
$CFSPEED_EXEC   = Join-Path $BaseDir "CloudflareSpeedtest.exe"
$CLOUDFLARE_IP_FILE = Join-Path $BaseDir "Cloudflare.txt"
$CLO_FILE       = Join-Path $BaseDir "COLO"
$RESULT_FILE    = Join-Path $BaseDir "result.csv"

# 确保目录存在
if (-Not (Test-Path $BaseDir)) {
    New-Item -ItemType Directory -Path $BaseDir | Out-Null
}

# 获取操作系统和架构
$OS_TYPE = [System.Environment]::OSVersion.Platform
$ARCH_TYPE = (Get-WmiObject -Class Win32_Processor).AddressWidth

# 检查并下载 CloudflareSpeedTest
if (-Not (Test-Path $CFSPEED_EXEC)) {
    Write-Output "CloudflareSpeedTest 不存在，开始下载..."

    if ($OS_TYPE -eq [System.PlatformID]::Win32NT) {
        if ($ARCH_TYPE -eq 64) {
            $DOWNLOAD_URL = "https://github.com/ShadowObj/CloudflareSpeedTest/releases/download/v2.2.6/CloudflareSpeedtest_win_amd64.exe"
        } else {
            $DOWNLOAD_URL = "https://github.com/ShadowObj/CloudflareSpeedTest/releases/download/v2.2.6/CloudflareSpeedtest_win_arm64.exe"
        }
    } elseif ($OS_TYPE -eq [System.PlatformID]::Unix) {
        if ($ARCH_TYPE -eq 64) {
            $DOWNLOAD_URL = "https://github.com/ShadowObj/CloudflareSpeedTest/releases/download/v2.2.6/CloudflareSpeedtest_linux_amd64"
        } else {
            $DOWNLOAD_URL = "https://github.com/ShadowObj/CloudflareSpeedTest/releases/download/v2.2.6/CloudflareSpeedtest_linux_arm64"
        }
    } else {
        Write-Output "不支持的操作系统或架构: $OS_TYPE $ARCH_TYPE"
        exit 1
    }

    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $CFSPEED_EXEC -UseBasicParsing
    Write-Output "下载完成: $CFSPEED_EXEC"
}

# 检查 Cloudflare IP 列表
if (-Not (Test-Path $CLOUDFLARE_IP_FILE)) {
    Write-Output "本地未找到 Cloudflare IP 列表，开始下载..."
    Invoke-WebRequest -Uri "https://www.cloudflare.com/ips-v4/" -OutFile $CLOUDFLARE_IP_FILE -UseBasicParsing
}

if (-Not (Test-Path $CLOUDFLARE_IP_FILE) -or (Get-Item $CLOUDFLARE_IP_FILE).Length -eq 0) {
    Write-Output "Cloudflare IP 列表不可用。"
    exit 1
}
Write-Output "使用的 Cloudflare IP 列表: $CLOUDFLARE_IP_FILE"

# 如果存在 COLO 文件，优先读取
if (Test-Path $CLO_FILE) {
    $CFCOLO = Get-Content $CLO_FILE | Select-Object -First 1
    Write-Output "从 COLO 文件读取区域: $CFCOLO"
}

# 构建参数
$ARGS = "-dn $DN_COUNT -sl 1 -tl 300 -f $CLOUDFLARE_IP_FILE -o $RESULT_FILE"
if ($CFCOLO -and $CFCOLO.Trim() -ne "") {
    $ARGS += " -cfcolo $CFCOLO"
}

# 运行 CloudflareSpeedTest
Write-Output "运行 CloudflareSpeedTest..."
Start-Process -FilePath $CFSPEED_EXEC -ArgumentList $ARGS -Wait

Write-Output "任务完成！结果已保存到 $RESULT_FILE"
