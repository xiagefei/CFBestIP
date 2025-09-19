param(
    [int]$DN_COUNT = 10,                # Ĭ�ϲ��� 10 �� IP
    [string]$CFCOLO = "",               # Ĭ�ϲ���������
    [string]$BaseDir = "D:\CF��ѡIP"    # Ĭ��Ŀ¼
)

# ����·��
$CFSPEED_EXEC   = Join-Path $BaseDir "CloudflareSpeedtest.exe"
$CLOUDFLARE_IP_FILE = Join-Path $BaseDir "Cloudflare.txt"
$CLO_FILE       = Join-Path $BaseDir "COLO"
$RESULT_FILE    = Join-Path $BaseDir "result.csv"

# ȷ��Ŀ¼����
if (-Not (Test-Path $BaseDir)) {
    New-Item -ItemType Directory -Path $BaseDir | Out-Null
}

# ��ȡ����ϵͳ�ͼܹ�
$OS_TYPE = [System.Environment]::OSVersion.Platform
$ARCH_TYPE = (Get-WmiObject -Class Win32_Processor).AddressWidth

# ��鲢���� CloudflareSpeedTest
if (-Not (Test-Path $CFSPEED_EXEC)) {
    Write-Output "CloudflareSpeedTest �����ڣ���ʼ����..."

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
        Write-Output "��֧�ֵĲ���ϵͳ��ܹ�: $OS_TYPE $ARCH_TYPE"
        exit 1
    }

    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $CFSPEED_EXEC -UseBasicParsing
    Write-Output "�������: $CFSPEED_EXEC"
}

# ��� Cloudflare IP �б�
if (-Not (Test-Path $CLOUDFLARE_IP_FILE)) {
    Write-Output "����δ�ҵ� Cloudflare IP �б���ʼ����..."
    Invoke-WebRequest -Uri "https://www.cloudflare.com/ips-v4/" -OutFile $CLOUDFLARE_IP_FILE -UseBasicParsing
}

if (-Not (Test-Path $CLOUDFLARE_IP_FILE) -or (Get-Item $CLOUDFLARE_IP_FILE).Length -eq 0) {
    Write-Output "Cloudflare IP �б����á�"
    exit 1
}
Write-Output "ʹ�õ� Cloudflare IP �б�: $CLOUDFLARE_IP_FILE"

# ������� COLO �ļ������ȶ�ȡ
if (Test-Path $CLO_FILE) {
    $CFCOLO = Get-Content $CLO_FILE | Select-Object -First 1
    Write-Output "�� COLO �ļ���ȡ����: $CFCOLO"
}

# ��������
$ARGS = "-dn $DN_COUNT -sl 1 -tl 300 -f $CLOUDFLARE_IP_FILE -o $RESULT_FILE"
if ($CFCOLO -and $CFCOLO.Trim() -ne "") {
    $ARGS += " -cfcolo $CFCOLO"
}

# ���� CloudflareSpeedTest
Write-Output "���� CloudflareSpeedTest..."
Start-Process -FilePath $CFSPEED_EXEC -ArgumentList $ARGS -Wait

Write-Output "������ɣ�����ѱ��浽 $RESULT_FILE"
