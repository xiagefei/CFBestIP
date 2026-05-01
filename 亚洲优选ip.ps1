param(
    # 默认测试 10 个 IP
    [int]$DN_COUNT = 10,
    # 【已硬编码】默认优先选择香港(HKG), 新加坡(SIN), 日本(NRT), 韩国(ICN), 台湾(TPE)
    [string]$CFCOLO = "HKG,SIN,NRT,ICN,TPE",
    # 默认工作目录
    [string]$BaseDir = "D:\CF优选IP"
)

# 定义路径
$CFSPEED_EXEC   = Join-Path $BaseDir "CloudflareSpeedtest.exe"
$CLOUDFLARE_IP_FILE = Join-Path $BaseDir "Cloudflare.txt"
$RESULT_FILE    = Join-Path $BaseDir "result.csv"
$FILTERED_FILE  = Join-Path $BaseDir "filtered_result.csv"   # 地区筛选结果
$PURE_FILE      = Join-Path $BaseDir "pure_result.csv"       # 纯净度筛选结果

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

# 构建参数
$ARGS = "-dn $DN_COUNT -sl 1 -tl 300 -f $CLOUDFLARE_IP_FILE -o $RESULT_FILE"
if ($CFCOLO -and $CFCOLO.Trim() -ne "") {
    $ARGS += " -cfcolo $CFCOLO"
    Write-Output "将优先选择区域: $CFCOLO"
}

# 运行 CloudflareSpeedTest
Write-Output "运行 CloudflareSpeedTest..."
Start-Process -FilePath $CFSPEED_EXEC -ArgumentList $ARGS -Wait

# ====================== 地区IP筛选功能 ======================
function Filter-IPByRegion {
    param(
        [string]$InputFile,
        [string]$OutputFile
    )
    
    $targetColos = @("HKG", "SIN", "NRT", "ICN", "TPE")
    
    if (-not (Test-Path $InputFile)) {
        Write-Output "⚠️  测速结果文件不存在，跳过筛选: $InputFile"
        return $false
    }
    
    $csvContent = Get-Content $InputFile -Encoding UTF8
    if ($csvContent.Count -eq 0) {
        Write-Output "⚠️  测速结果文件为空，跳过筛选"
        return $false
    }
    
    $filteredContent = @()
    $filteredContent += $csvContent[0]
    
    for ($i = 1; $i -lt $csvContent.Count; $i++) {
        $line = $csvContent[$i].Trim()
        if ([string]::IsNullOrEmpty($line)) { continue }
        
        $fields = $line -split ','
        if ($fields.Count -ge 6) {
            $coloCode = $fields[5].Trim()
            if ($targetColos -contains $coloCode) {
                $filteredContent += $line
            }
        }
    }
    
    $filteredContent | Out-File -FilePath $OutputFile -Encoding UTF8 -Force
    
    $totalCount = $csvContent.Count - 1
    $filteredCount = $filteredContent.Count - 1
    
    Write-Output "`n📊 地区筛选完成："
    Write-Output "   原始测试结果数: $totalCount 个"
    Write-Output "   筛选后结果数: $filteredCount 个（仅保留香港/新加坡/日本/韩国/台湾）"
    Write-Output "   筛选结果已保存到: $OutputFile"
    
    return $true
}

# ====================== 纯净度IP筛选功能 ======================
function Filter-IPByPurity {
    param(
        [string]$InputFile,
        [string]$OutputFile,
        [int]$MaxLatency = 200,   # 最大延迟阈值 (ms)
        [int]$MaxLoss = 0         # 最大丢包率阈值 (%)
    )
    
    if (-not (Test-Path $InputFile)) {
        Write-Output "⚠️  输入文件不存在，跳过纯净度筛选: $InputFile"
        return $false
    }
    
    $csvContent = Get-Content $InputFile -Encoding UTF8
    if ($csvContent.Count -eq 0) {
        Write-Output "⚠️  输入文件为空，跳过纯净度筛选"
        return $false
    }
    
    $filteredContent = @()
    $filteredContent += $csvContent[0]
    
    for ($i = 1; $i -lt $csvContent.Count; $i++) {
        $line = $csvContent[$i].Trim()
        if ([string]::IsNullOrEmpty($line)) { continue }
        
        $fields = $line -split ','
        if ($fields.Count -ge 6) {
            $latency = [int]$fields[1]
            $loss    = [int]$fields[4]
            
            if ($latency -le $MaxLatency -and $loss -le $MaxLoss) {
                $filteredContent += $line
            }
        }
    }
    
    $filteredContent | Out-File -FilePath $OutputFile -Encoding UTF8 -Force
    
    $totalCount = $csvContent.Count - 1
    $filteredCount = $filteredContent.Count - 1
    
    Write-Output "`n✨ 纯净度筛选完成："
    Write-Output "   原始结果数: $totalCount 个"
    Write-Output "   筛选后结果数: $filteredCount 个（延迟 ≤ $MaxLatency ms，丢包率 ≤ $MaxLoss%）"
    Write-Output "   筛选结果已保存到: $OutputFile"
    
    return $true
}

# 执行地区筛选
Write-Output "`n开始筛选指定地区IP..."
Filter-IPByRegion -InputFile $RESULT_FILE -OutputFile $FILTERED_FILE

# 执行纯净度筛选
Write-Output "`n开始筛选纯净度IP..."
Filter-IPByPurity -InputFile $FILTERED_FILE -OutputFile $PURE_FILE -MaxLatency 200 -MaxLoss 0

# ====================== 完成 ======================
Write-Output "`n任务完成！"
Write-Output "完整结果已保存到: $RESULT_FILE"
Write-Output "地区筛选结果已保存到: $FILTERED_FILE"
Write-Output "纯净度筛"