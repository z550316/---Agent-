# 智能管家软件 - 智能家居 Agent 控制中心

一款上位机软件，作为智能家居系统的核心控制与调度中枢，同时作为 Agent 智能体运行平台。通过摄像头情景感知、多类大模型协同、硬件设备对接，实现智能家居设备的自动联动控制。

## 核心功能

- **设备控制**：支持 MQTT / HTTP / 串口 / Modbus 多协议设备接入与真实控制
- **摄像头接入**：支持 RTSP / ONVIF / GB28181 / MJPEG 通用协议摄像头
- **AI 对话**：接入文心大模型，支持自然语言控制设备、查询资讯
- **情景感知**：人脸识别、行为分析、环境感知、安全告警
- **语音交互**：语音识别（ASR）+ 语音合成（TTS）
- **资讯查询**：天气 / 新闻 / 股票实时查询与语音播报
- **平面图管理**：可视化设备布置与状态监控
- **多端适配**：桌面端 / 平板端 / 手机端响应式自适应

## 技术栈

| 层级 | 技术 |
|------|------|
| 前端 | React 18 + Vite 5 + TypeScript + Tailwind CSS + shadcn/ui |
| 后端 | Supabase（Postgres + Edge Functions + Auth + Storage + Realtime） |
| 网关 | Node.js + Express（MQTT / Serial / Modbus / RTSP 转码） |
| 固件 | Arduino（ESP32 + PubSubClient + ArduinoJson） |

## 快速开始

```bash
# 1. 安装依赖
npm install --legacy-peer-deps

# 2. 配置环境变量
cp .env.example .env
# 编辑 .env 填入 Supabase URL 和 Anon Key

# 3. 启动开发服务器
npm run dev

# 4. 构建生产版本
npm run build

# 5. 预览生产版本
npm run preview
```

## 项目结构

```
├── src/                    # 前端源码（React）
├── supabase/              # 后端（Edge Functions + 数据库迁移）
├── gateway/               # 本地网关服务（Node.js）
├── firmware/              # ESP32 硬件固件（Arduino）
├── docs/                  # 设计文档与需求文档
├── dist/                  # 构建产物
├── .env                   # 环境变量
├── DEPLOYMENT.md          # 完整部署指南
└── package.json
```

## 部署

详细部署步骤请参考 [DEPLOYMENT.md](./DEPLOYMENT.md)。

## 硬件对接

### 支持的设备协议

| 协议 | 控制路径 | 适用设备 |
|------|---------|---------|
| HTTP | Edge Function 直连 | WiFi 智能设备 |
| MQTT | Edge Function → MQTT Broker | ESP32 / 智能设备 |
| Serial | 本地网关 → 串口 | Arduino / 单片机 |
| Modbus | 本地网关 → Modbus | 工业设备 |
| RTSP | 转码网关 → 浏览器 | IP 摄像头 |

### ESP32 固件示例

项目提供两套 ESP32 固件：
- `firmware/esp32_smart_light/` - 智能灯（继电器开关 + PWM 调光 + RGB）
- `firmware/esp32_environment_sensor/` - 环境传感器（温湿度 + 光照 + 烟雾检测）

详见 `firmware/README.md`。
