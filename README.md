# HAProxy for Pterodactyl

這是一個可直接匯入 Pterodactyl Panel 的 HAProxy egg，搭配專為 Wings 執行環境建立的 HAProxy 3.2 LTS 映像。支援 `linux/amd64` 與 `linux/arm64`。

## 使用方式

1. 從 repository 下載 [`egg-haproxy.json`](./egg-haproxy.json)。
2. 在 Panel 管理後台進入 **Nests -> Import Egg**，選擇該檔案並指定任一 Nest。
3. 建立伺服器，選擇 `HAProxy 3.2 LTS` 映像，配置至少 128 MiB 記憶體及一個 allocation。
4. 將 `Backend host` 與 `Backend port` 改成真正的後端服務位址，啟動伺服器。

HAProxy 會監聽伺服器的主要 allocation (`SERVER_PORT`)。不需要上傳或手動產生設定檔。

> `127.0.0.1` 指向 HAProxy 容器本身，而非 Wings 主機。若後端位於同一台主機，請填寫容器可連線的主機 LAN IP，或使用兩個容器都能解析的 Docker 網路名稱。

## 常用設定

| 變數 | 預設值 | 用途 |
| --- | --- | --- |
| `BACKEND_HOST` | `127.0.0.1` | 後端 DNS 名稱、IPv4 或 IPv6 位址 |
| `BACKEND_PORT` | `25565` | 後端連接埠 |
| `PROXY_MODE` | `tcp` | `tcp` 適用遊戲與一般 TCP；`http` 適用 HTTP |
| `HEALTH_CHECK` | `true` | 主動檢查後端 TCP 連線 |
| `BACKEND_TLS` | `false` | 對後端使用 TLS；私人服務相容性優先，因此不驗證憑證 |
| `PROXY_PROTOCOL` | `none` | 可設為 `v1` 或 `v2`，但後端必須支援 |
| `CONFIG_MODE` | `generated` | 設為 `custom` 後可自行管理 `haproxy.cfg` |

其餘連線上限與 timeout 都已提供保守預設值，可直接使用。

## 自訂設定

需要多個 backend、ACL、TLS termination 或其他進階功能時：

1. 先讓伺服器以 `generated` 模式啟動一次，產生 `/home/container/haproxy.cfg`。
2. 將 `CONFIG_MODE` 改成 `custom`。
3. 透過 Panel 檔案管理器修改 `haproxy.cfg`，重新啟動。

啟動器每次都會先執行 `haproxy -c`。設定無效時會輸出明確錯誤並停止，不會以錯誤設定繼續執行。

## 發布映像

推送到 `main` 後，[GitHub Actions](./.github/workflows/publish.yml) 會驗證 egg、建置並測試映像，接著發布：

```text
ghcr.io/apple050620312/haproxy-pterodactyl:latest
```

第一次發布 package 後，請在 GitHub package settings 將可見性設為 **Public**，否則 Wings 無法匿名拉取映像。之後更新只需推送 `main`，無須更改 egg。

## 安全注意事項

- 請在 Wings 主機防火牆只開放實際使用的 allocation。
- `BACKEND_TLS=true` 目前使用 `verify none`，只加密、不驗證後端身分；需要憑證驗證時請使用 `custom` 模式。
- 僅在後端已設定 PROXY protocol 時啟用 `PROXY_PROTOCOL`，否則後端會把 header 當成應用資料。
