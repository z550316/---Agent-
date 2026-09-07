# 智能管家软件 - 部署指南

## 目录

- [快速开始：本地部署（推荐，无需 Docker）](#快速开始本地部署推荐无需-docker)
- [切换到云端 Supabase 部署](#切换到云端-supabase-部署)
- [系统架构](#系统架构)
- [环境要求](#环境要求)
- [阶段一：Supabase 后端部署](#阶段一supabase-后端部署)
- [阶段二：前端构建与部署](#阶段二前端构建与部署)
- [阶段三：本地网关部署](#阶段三本地网关部署)
- [阶段四：硬件设备接入](#阶段四硬件设备接入)
- [阶段五：视频转码网关（可选）](#阶段五视频转码网关可选)
- [验证与测试](#验证与测试)
- [常见问题排查](#常见问题排查)

---

## 快速开始：本地部署（推荐，无需 Docker）

本地部署使用 Express + JSON 文件存储替代 Supabase，无需安装 Docker、PostgreSQL 或任何数据库。整个过程只需 Node.js。

### 环境要求

- Node.js 18+（[下载地址](https://nodejs.org/)）
- 无需 Docker、无需 PostgreSQL、无需 Supabase CLI

### 一键启动

**Windows 用户**：双击项目根目录下的 `start-local.bat`，脚本会自动启动后端和前端。

**手动启动**（两个终端）：

```bash
# 终端 1：启动本地后端服务器（端口 8081）
cd server
npm install
npm start

# 终端 2：启动前端开发服务器（端口 5173）
npm install
npx vite --host --port 5173
```

### 访问系统

- 前端界面：http://localhost:5173
- 后端 API：http://localhost:8081/api/health
- **默认账号**：`admin` / `admin123`

### 配置说明

在 `.env` 文件中控制部署模式：

```env
# true = 本地 Express 服务器（无需 Docker/Supabase）
# false = Supabase 云后端（适合在线部署）
VITE_USE_LOCAL_BACKEND=true
VITE_LOCAL_API_URL=http://localhost:8081
```

### 本地后端功能

| 功能 | 支持状态 | 说明 |
|------|---------|------|
| 用户认证 | 完整 | 注册/登录/登出，Token 认证 |
| 家庭管理 | 完整 | 创建家庭、成员管理 |
| 设备管理 | 完整 | CRUD + 设备控制 |
| 摄像头管理 | 完整 | CRUD + 连接测试 |
| 人员库 | 完整 | CRUD + 陌生人检测 |
| 大模型配置 | 完整 | CRUD，API Key 明文存储 |
| AI 对话 | 代理 | 读取模型配置代理到 LLM API |
| 订阅订单 | 完整 | 订阅管理 + 订单创建 |
| 天气/新闻/股票 | Mock | 返回模拟数据 |
| 人脸识别 | Mock | 返回模拟结果 |
| 文件存储 | 完整 | 本地文件系统存储 |

### 数据存储

所有数据存储在 `server/data.json` 文件中。删除该文件可重置为初始状态。

### 生产构建

```bash
# 构建前端
npx vite build

# 启动后端服务器
cd server && npm start

# 使用 Vite 预览构建产物
npx vite preview --host --port 4173
```

---

## 切换到云端 Supabase 部署

如果需要在线部署，切换回 Supabase 云后端：

1. 修改 `.env` 文件：
   ```env
   VITE_USE_LOCAL_BACKEND=false
   VITE_SUPABASE_URL=https://your-project.supabase.co
   VITE_SUPABASE_ANON_KEY=your-anon-key
   ```

2. 按 Supabase 部署流程操作（见下方各阶段）

---

## 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                    云端 SaaS 层 (Supabase)                    │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────────────┐  │
│  │ Postgres │  │   Auth   │  │    Edge Functions (Deno)   │  │
│  │  数据库   │  │  用户认证 │  │ ai-chat / device-control   │  │
│  │  + RLS   │  │          │  │ mqtt-bridge / camera-test  │  │
│  └──────────┘  └──────────┘  │ weather / news / stock     │  │
│  ┌──────────┐  ┌──────────┐  │ face-search / transcode    │  │
│  │ Storage  │  │ Realtime │  └───────────────────────────┘  │
│  │ 录像存储  │  │ 实时推送  │                                │
│  └──────────┘  └──────────┘                                │
└─────────────────────────┬───────────────────────────────────┘
                          │ HTTPS / WebSocket
┌─────────────────────────┴───────────────────────────────────┐
│                    前端 Web 应用 (React)                      │
│         桌面端 / 平板端 / 手机端 响应式自适应                   │
└─────────────────────────┬───────────────────────────────────┘
                          │ HTTP API
┌─────────────────────────┴───────────────────────────────────┐
│                  本地网关层 (Node.js Gateway)                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐ │
│  │   MQTT   │  │  Serial  │  │  Modbus  │  │ RTSP 转码     │ │
│  │  Broker  │  │  串口控制 │  │  工业设备 │  │ (ffmpeg)     │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └──────────────┘ │
└───────┼─────────────┼─────────────┼─────────────────────────┘
        │             │             │
┌───────┴─────────────┴─────────────┴─────────────────────────┐
│                    设备协议层 (硬件设备)                       │
│   ESP32 智能灯  │  ESP32 环境传感器  │  IP 摄像头  │  继电器   │
└─────────────────────────────────────────────────────────────┘
```

### 协议路由规则

| 设备协议 | 控制路径 | 适用设备 |
|---------|---------|---------|
| HTTP | 前端 → Edge Function `device-control` → 设备 HTTP API | WiFi 智能设备 |
| MQTT | 前端 → Edge Function `mqtt-bridge` → MQTT Broker → 设备 | ESP32/智能设备 |
| Serial | 前端 → 本地网关 `/api/serial/write` → 串口 → 设备 | Arduino/单片机 |
| Modbus | 前端 → 本地网关 `/api/modbus/write` → Modbus → 设备 | 工业设备 |
| RTSP/ONVIF | 前端 → 转码网关 (MediaMTX) → 浏览器播放 | IP 摄像头 |
| MJPEG | 前端 → 直接 HTTP 拉流 | 简易摄像头 |

---

## 环境要求

### 必需环境

| 组件 | 版本要求 | 说明 |
|------|---------|------|
| Node.js | >= 20 | 前端构建 + 网关运行 |
| npm | >= 10 | 包管理 |
| Supabase | 官方托管或自托管 | 后端数据库 + Edge Functions |

### 可选环境（按需）

| 组件 | 用途 | 安装方式 |
|------|------|---------|
| Docker | 网关容器化部署 | https://docker.com |
| Supabase CLI | 部署 Edge Functions | `npm i -g supabase` |
| Arduino IDE | 烧录 ESP32 固件 | https://arduino.cc |
| ffmpeg | RTSP 视频转码 | 系统包管理器安装 |
| MediaMTX | RTSP 转 WebRTC/HLS | https://github.com/bluenviron/mediamtx |
| Mosquitto | MQTT Broker | Docker 或系统包管理器 |

---

## 阶段一：Supabase 后端部署

### 1.1 创建 Supabase 项目

**方式 A：使用 Supabase 官方托管（推荐）**

1. 访问 https://supabase.com 注册账号
2. 点击「New Project」创建新项目
3. 记录以下信息：
   - Project URL: `https://xxxxx.supabase.co`
   - Anon Key: `eyJhbGci...`（公开密钥）
   - Service Role Key: `eyJhbGci...`（服务端密钥，**切勿泄露**）

**方式 B：使用现有项目**

如果已有 Supabase 项目（如秒达平台提供的），跳到 1.3 配置环境变量。

### 1.2 执行数据库迁移

在 Supabase Dashboard 中，进入 `SQL Editor`，依次执行 `supabase/migrations/` 目录下的 SQL 文件：

```
00001_create_people_and_stranger_detections.sql
00002_create_profiles_and_homes.sql
00003_create_devices_cameras_subscriptions.sql
00004_fix_home_rls_chicken_egg.sql
00005_fix_profiles_auto_trigger.sql
00006_add_transcode_gateways_and_info_cache.sql
00007_create_model_configs.sql
```

> 按编号顺序执行，每个文件执行完毕后再执行下一个。

### 1.3 配置 Edge Function 环境变量

在 Supabase Dashboard → `Edge Functions` → `Secrets` 中添加：

| Secret 名称 | 值 | 说明 |
|-------------|---|------|
| `SUPABASE_URL` | `https://xxxxx.supabase.co` | 项目 URL |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJhbGci...` | 服务端密钥 |

### 1.4 部署 Edge Functions

**方式 A：通过 Supabase CLI（推荐）**

```bash
# 安装 Supabase CLI
npm install -g supabase

# 登录
supabase login

# 关联项目（使用你的 Project ID）
cd 项目根目录
supabase link --project-ref your-project-id

# 部署所有 Edge Functions
supabase functions deploy ai-chat
supabase functions deploy device-control
supabase functions deploy device-test
supabase functions deploy mqtt-bridge
supabase functions deploy camera-test
supabase functions deploy transcode-proxy
supabase functions deploy face-search
supabase functions deploy face-user-add
supabase functions deploy face-user-delete
supabase functions deploy weather-query
supabase functions deploy news-query
supabase functions deploy stock-query
```

**方式 B：通过 Supabase Dashboard 手动创建**

在 Dashboard → `Edge Functions` → `New Function`，逐一创建函数，将 `supabase/functions/*/index.ts` 的内容粘贴进去。

### 1.5 验证后端

```bash
# 测试 Edge Function 是否正常
curl -X POST https://your-project.supabase.co/functions/v1/weather-query \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"city":"北京"}'
```

预期返回天气 JSON 数据。

---

## 阶段二：前端构建与部署

### 2.1 配置环境变量

编辑项目根目录 `.env` 文件：

```bash
# Supabase 配置
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key

# 应用 ID（可选）
VITE_APP_ID=your-app-id

# Sentry 错误监控（可选）
VITE_SENTRY_DSN=
```

### 2.2 安装依赖并构建

```bash
# 安装依赖
npm install --legacy-peer-deps

# 构建生产版本
npm run build
```

构建产物输出到 `dist/` 目录。

### 2.3 本地预览

```bash
# 启动预览服务器
npm run preview
```

访问 http://localhost:4173 即可使用。

### 2.4 生产部署

**方式 A：Nginx 静态托管（推荐）**

```nginx
server {
    listen 80;
    server_name smart-home.example.com;
    root /var/www/smart-home/dist;
    index index.html;

    # SPA 路由回退
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 静态资源缓存
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # gzip 压缩
    gzip on;
    gzip_types text/css application/javascript application/json;
}
```

```bash
# 将构建产物上传到服务器
scp -r dist/* user@server:/var/www/smart-home/dist/
```

**方式 B：Vercel 部署**

```bash
# 安装 Vercel CLI
npm i -g vercel

# 部署
vercel --prod
```

**方式 C：Docker 部署**

创建 `Dockerfile.frontend`：

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --legacy-peer-deps
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

```bash
docker build -f Dockerfile.frontend -t smart-home-web .
docker run -d -p 80:80 smart-home-web
```

---

## 阶段三：本地网关部署

本地网关负责对接无法通过云端直接控制的设备（串口、Modbus、TCP 协议）以及 RTSP 视频流转码。

### 3.1 Docker 一键部署（推荐）

```bash
cd gateway

# 复制环境变量配置
cp .env.example .env
# 编辑 .env 配置 MQTT Broker 地址等

# 启动网关 + MQTT Broker
docker-compose up -d
```

服务启动后：
- 网关 API: http://localhost:8080
- MQTT Broker: tcp://localhost:1883
- MQTT WebSocket: ws://localhost:9001

### 3.2 手动部署

```bash
cd gateway

# 安装依赖
npm install

# 配置环境变量
cp .env.example .env
# 编辑 .env

# 启动
npm start
```

### 3.3 网关配置说明

编辑 `gateway/.env`：

```bash
# HTTP 服务器
PORT=8080

# MQTT Broker
MQTT_BROKER_URL=mqtt://localhost:1883
MQTT_USERNAME=your-mqtt-user
MQTT_PASSWORD=your-mqtt-pass

# Supabase（用于上报设备状态）
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-key

# 转码配置
FFMPEG_PATH=/usr/bin/ffmpeg
```

### 3.4 验证网关

```bash
# 健康检查
curl http://localhost:8080/api/health

# 列出可用串口
curl http://localhost:8080/api/serial/ports
```

### 3.5 在前端配置网关地址

在应用的「设置」→「硬件接口配置」中，将本地网关地址填写为：
```
http://网关IP:8080
```

---

## 阶段四：硬件设备接入

### 4.1 ESP32 智能灯接入

#### 硬件清单

| 部件 | 型号 | 数量 |
|------|------|------|
| ESP32 开发板 | ESP32-DevKitC / NodeMCU-32S | 1 |
| 继电器模块 | 5V 单路继电器 | 1 |
| RGB LED 灯带 | WS2812B / SK6812 | 1 |
| 杜邦线 | 公母头 | 若干 |

#### 接线

```
ESP32 GPIO 23 → 继电器 IN 引脚
ESP32 GPIO 2  → PWM LED（白光调光）
ESP32 GPIO 4  → WS2812B DIN（RGB）
ESP32 3.3V    → 继电器 VCC
ESP32 GND     → 继电器 GND / LED GND
```

#### 烧录固件

1. 安装 [Arduino IDE](https://arduino.cc)
2. 添加 ESP32 开发板支持：
   - 文件 → 首选项 → 附加开发板管理器 URL
   - 添加: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
3. 安装库：`PubSubClient`、`ArduinoJson`、`Adafruit_NeoPixel`
4. 编辑 `firmware/esp32_smart_light/config.h`：
   ```cpp
   #define WIFI_SSID "your-wifi"
   #define WIFI_PASSWORD "your-password"
   #define MQTT_BROKER "192.168.1.100"  // MQTT Broker IP
   #define MQTT_PORT 1883
   #define HOME_ID "your-home-id"
   #define DEVICE_ID "esp32-light-001"
   ```
5. 选板型 → 上传

#### 在应用中注册设备

1. 登录智能管家 → 设置 → 设备管理 → 添加设备
2. 填写：
   - 设备名称：客厅灯
   - 协议：MQTT
   - Broker 地址：`mqtt://Broker-IP:1883`
   - 控制 Topic：`smart_home/your-home-id/devices/esp32-light-001/command`
   - 状态 Topic：`smart_home/your-home-id/devices/esp32-light-001/status`
3. 点击「测试连接」→ 保存

### 4.2 ESP32 环境传感器接入

参照 `firmware/esp32_environment_sensor/README.md` 中的接线说明和烧录步骤。

### 4.3 IP 摄像头接入

#### MJPEG 摄像头（直接接入）

1. 设置 → 摄像头管理 → 添加摄像头
2. 协议选择 `HTTP-MJPEG`
3. 填写 MJPEG 地址（如 `http://192.168.1.50:8080/video`）
4. 测试连接 → 保存

#### RTSP 摄像头（需转码网关）

1. 先部署转码网关（见阶段五）
2. 设置 → 摄像头管理 → 添加摄像头
3. 协议选择 `RTSP`
4. 填写 RTSP 地址（如 `rtsp://admin:pass@192.168.1.60:554/stream1`）
5. 填写转码网关地址
6. 测试连接 → 保存

---

## 阶段五：视频转码网关（可选）

用于将 RTSP/ONVIF/GB28181 视频流转换为浏览器可播放的格式。

### 5.1 使用 MediaMTX（推荐）

```bash
# 下载 MediaMTX
wget https://github.com/bluenviron/mediamtx/releases/latest/download/mediamtx_linux_amd64.tar.gz
tar xzf mediamtx_linux_amd64.tar.gz

# 启动
./mediamtx
```

默认端口：
- RTSP: 8554
- HLS: 8888
- WebRTC: 8889
- API: 9997

### 5.2 使用本地网关内置转码

本地网关已内置 ffmpeg 转码功能，通过 API 启动转码：

```bash
curl -X POST http://localhost:8080/api/transcode/start \
  -H "Content-Type: application/json" \
  -d '{
    "source_url": "rtsp://admin:pass@192.168.1.60:554/stream1",
    "name": "camera-001"
  }'
```

转码后的 MJPEG 流通过 WebSocket 推送：
```
ws://localhost:8080/ws/stream?name=camera-001
```

---

## 验证与测试

### 1. 后端验证

```bash
# 测试天气查询
curl -X POST https://your-project.supabase.co/functions/v1/weather-query \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"city":"北京"}'

# 测试设备控制（HTTP 协议）
curl -X POST https://your-project.supabase.co/functions/v1/device-control \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"device_id":"DEVICE_UUID","command":{"on":true}}'
```

### 2. 前端验证

1. 访问应用 URL
2. 注册账号 → 创建家庭 → 进入控制中心
3. 在「设置」中添加设备 → 测试连接 → 控制设备
4. 在「对话」中输入「打开客厅灯」→ 验证 AI 对话 + 设备控制联动

### 3. 网关验证

```bash
# 健康检查
curl http://localhost:8080/api/health

# MQTT 状态
curl http://localhost:8080/api/mqtt/status

# 串口列表
curl http://localhost:8080/api/serial/ports
```

### 4. 硬件验证

1. ESP32 上电后，串口监视器应显示 WiFi 和 MQTT 连接成功
2. 在应用中点击设备开关，ESP32 继电器应有动作
3. ESP32 状态上报后，应用中设备状态应实时更新

---

## 常见问题排查

### 前端无法访问 Supabase

- 检查 `.env` 中的 `VITE_SUPABASE_URL` 和 `VITE_SUPABASE_ANON_KEY` 是否正确
- 确认 Supabase 项目状态为 Active
- 检查浏览器控制台是否有 CORS 错误

### Edge Function 返回 500

- 检查 Supabase Secrets 中 `SUPABASE_URL` 和 `SUPABASE_SERVICE_ROLE_KEY` 是否配置
- 在 Supabase Dashboard → Edge Functions → Logs 查看错误日志

### MQTT 设备控制无响应

- 确认 MQTT Broker 已启动且 ESP32 已连接
- 检查 MQTT Topic 是否匹配（`smart_home/{home_id}/devices/{device_id}/command`）
- 用 MQTT 客户端（如 MQTTX）订阅 Topic 验证消息是否到达
- 确认 `mqtt-bridge` Edge Function 中传入的 `broker_url` 正确

### 串口/Modbus 设备无法控制

- 确认本地网关服务已启动（`curl http://网关IP:8080/api/health`）
- 确认前端已配置网关地址（设置 → 硬件接口配置）
- 检查网关日志是否有串口连接错误
- 确认串口参数（波特率、数据位、校验位）与设备一致

### 摄像头无法显示画面

- MJPEG：检查地址是否可访问，浏览器直接打开 MJPEG URL 验证
- RTSP：确认转码网关已部署且可达
- 检查摄像头用户名密码是否正确
- 确认摄像头与网关在同一网段

### ESP32 无法连接 WiFi

- 确认 SSID 和密码正确（注意大小写）
- 2.4GHz 网络（ESP32 不支持 5GHz）
- 串口监视器查看连接日志

### ESP32 无法连接 MQTT

- 确认 Broker 地址和端口正确
- 确认 Broker 允许该客户端连接（检查认证配置）
- 确认 ESP32 和 Broker 在同一网络（或 Broker 有公网 IP）
- 检查防火墙是否放行 1883 端口

---

## 项目目录结构

```
smart-home/
├── src/                    # 前端源码
│   ├── api/               # API 调用层（调用 Edge Functions）
│   ├── components/         # React 组件
│   ├── contexts/          # React Context（状态管理）
│   ├── pages/             # 页面组件
│   ├── services/          # 服务层（硬件适配器、Agent、LLM）
│   ├── types/             # TypeScript 类型定义
│   └── db/                # Supabase 客户端
├── supabase/              # Supabase 后端
│   ├── functions/         # Edge Functions (Deno)
│   └── migrations/        # 数据库迁移 SQL
├── gateway/               # 本地网关服务 (Node.js)
│   ├── src/               # 网关源码
│   ├── Dockerfile         # Docker 部署
│   └── docker-compose.yml # 容器编排
├── firmware/              # 硬件固件 (Arduino)
│   ├── esp32_smart_light/ # 智能灯固件
│   └── esp32_environment_sensor/ # 环境传感器固件
├── dist/                  # 前端构建产物
├── .env                   # 环境变量
├── .env.example           # 环境变量模板
├── package.json           # 项目依赖
└── vite.config.ts         # Vite 构建配置
```
