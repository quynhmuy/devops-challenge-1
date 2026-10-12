# DevOps Challenge 1: Từ triển khai thủ công đến triển khai tự động

## 1. Tổng quan dự án

| Thông tin | Nội dung |
|---|---|
| Tên nhóm | **Ngọc Lam Mỹ** |
| Thành viên | Nguyễn Ánh Ngọc |
| | Trương Thủy Lam |
| | Nguyễn Thị Quỳnh Mỹ |
| Môi trường | WSL2 Ubuntu (đã bật systemd) trên Windows |
| Repo | https://github.com/quynhmuy/devops-challenge-1 |
| Video demo |  |

**Mục tiêu:** Triển khai một ứng dụng web Flask trên Ubuntu và từng bước cải tiến quy trình triển khai:

> Thủ công → Chạy bằng systemd → Nginx reverse proxy → Tách cấu hình → Script tự động → Health check

Kết quả hướng đến là quy trình triển khai nhất quán, có thể lặp lại, dễ quản lý và thuận tiện trong việc chẩn đoán sự cố.

---

## 2. Kiến trúc hệ thống

```
Trình duyệt --HTTP :80--> Nginx --proxy_pass--> Flask (127.0.0.1:5000)
                                                   ^
                            systemd (devops-app) --+-- đọc /etc/devops-app.env

GitHub --git pull--> /opt/devops-app <-- scripts/deploy.sh
```

![Sơ đồ kiến trúc](docs/architecture.png)

- **Nginx** Nhận request tại cổng 80 và chuyển tiếp đến ứng dụng Flask.
- **Flask** Lắng nghe tại 127.0.0.1:5000; người dùng truy cập thông qua Nginx.
- **systemd** Quản lý ứng dụng, hỗ trợ tự khởi động khi hệ thống khởi động và khởi động lại khi gặp lỗi theo cấu hình.
- **Cấu hình** Lưu tại /etc/devops-app.env, tách biệt với mã nguồn.

| Thư mục | Vai trò | Chức  |
|---|---|---|
| `~/devops-challenge-1` | Bản **phát triển** | Chỉnh sửa code, commit và push lên GitHub |
| `/opt/devops-app` | Bản **triển khai** | Lưu mã nguồn triển khai và cập nhật thông qua deploy.sh |

---

## 3. Cấu trúc thư mục

```
devops-challenge-1/
├── app.py                  # Ứng dụng Flask
├── requirements.txt        # Thư viện Python
├── README.md               # Tài liệu này
├── scripts/
│   └── deploy.sh           # Script triển khai tự động
├── nginx/
│   └── devops-app.conf     # Cấu hình Nginx
├── systemd/
│   └── devops-app.service  # File service systemd
└── docs/
    └── architecture.png    # Sơ đồ kiến trúc
```

---

## 4. Cài đặt thủ công

**Bước 1: Cài các gói cần thiết**
```bash
sudo apt update
sudo apt install -y git python3 python3-venv python3-pip nginx curl
```

**Bước 2: Lấy mã nguồn và cài thư viện**
```bash
sudo mkdir -p /opt/devops-app
sudo chown $USER:$USER /opt/devops-app
git clone https://github.com/quynhmuy/devops-challenge-1.git /opt/devops-app
cd /opt/devops-app
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**Bước 3: Chạy thử**
```bash
python app.py
curl http://127.0.0.1:5000
```

**Phần phản ánh:** Quy trình thủ công gồm tải mã nguồn, tạo và kích hoạt môi trường ảo, cài đặt thư viện, chạy ứng dụng và kiểm tra phản hồi. Hầu hết các bước này đều có thể tự động hóa bằng script; thời điểm triển khai vẫn do người thực hiện quyết định.

**Bước 4: Tạo file biến môi trường** 
File cấu hình được đặt bên ngoài Git để tách biệt cấu hình với mã nguồn.

```bash
sudo tee /etc/devops-app.env > /dev/null <<'EOF'
APP_NAME=DevOps Challenge 1
APP_ENV=production
APP_PORT=5000
EOF
```

**Bước 5: Cài service systemd**

> Dòng `User=` trong `systemd/devops-app.service` phải được thay bằng **username Linux của máy triển khai** (kiểm tra bằng `whoami`).

```bash
sudo cp systemd/devops-app.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now devops-app
```

**Bước 6: Cài Nginx**
```bash
sudo cp nginx/devops-app.conf /etc/nginx/sites-available/devops-app
sudo ln -sf /etc/nginx/sites-available/devops-app /etc/nginx/sites-enabled/devops-app
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

---

## 5. Cách chạy ứng dụng

| Mục đích | Lệnh |
|---|---|
| Chạy trực tiếp (phát triển) | `python app.py` |
| Chạy bằng service | `sudo systemctl start devops-app` |
| Truy cập qua Nginx | `curl http://localhost` |

---

## 6. Cách triển khai

```bash
/opt/devops-app/scripts/deploy.sh
```

Script có thể chạy từ bất kỳ thư mục làm việc nào và thực hiện 5 bước:

| Bước | Việc làm |
|---|---|
| 1 | `git pull origin main`: cập nhật mã nguồn |
| 2 | `pip install -r requirements.txt`: cài thư viện |
| 3 | `sudo systemctl restart devops-app`: khởi động lại ứng dụng |
| 4 | Kiểm tra service đang `active` |
| 5 | Health check `http://localhost/health` (thử lại tối đa 5 lần) |

**Quy trình đầy đủ:**  Chỉnh sửa code tại `~/devops-challenge-1` → `git add` → `git commit` → `git push` → chạy `deploy.sh` → `curl http://localhost` để thấy thay đổi.

---

## 7. Health check

Endpoint `GET /health` trả về:
```json
{"status": "ok"}
```

```bash
curl --fail http://localhost/health
```

**Health check thất bại đồng nghĩa với triển khai thất bại**. Nếu kiểm tra không thành công sau số lần thử lại được quy định, deploy.sh hiển thị Deployment FAILED và kết thúc với mã thoát 1.

Nhóm đã kiểm chứng cơ chế này bằng cách tạm đổi URL kiểm tra thành /healthx. Script thử lại 5 lần, thông báo thất bại và trả về mã thoát 1, có thể xác nhận bằng lệnh echo $?.

---

## 8. Quản lý service

| Việc | Lệnh |
|---|---|
| Khởi động / dừng / restart | `sudo systemctl start\|stop\|restart devops-app` |
| Bật / tắt tự chạy khi boot | `sudo systemctl enable\|disable devops-app` |
| Xem trạng thái | `systemctl status devops-app --no-pager` |
| Kiểm tra đã enable chưa | `systemctl is-enabled devops-app` |
| Xem log | `journalctl -u devops-app -n 30 --no-pager` |

**Vì sao dùng service thay vì chạy trong terminal?**
- Không phụ thuộc vào cửa sổ terminal đang mở.
- Hỗ trợ tự khởi động lại khi lỗi theo cấu hình (`Restart=always`).
- Tự chạy khi bật máy (`enable`).
- Có log tập trung (`journalctl`).
- Quản lý thống nhất bằng `systemctl`.

**Vì sao tách cấu hình khỏi mã nguồn?**
- Cho phép sử dụng giá trị khác nhau giữa môi trường development và production.
- Hạn chế đưa thông tin bảo mật và cá nhân vào Git.
- Có thể thay đổi cấu hình mà không cần chỉnh sửa hoặc commit lại mã nguồn.

---

## 9. Git workflow

Nhánh tính năng: `feature/ngoc-lam-my`. Nhóm đã chỉnh sửa `app.py`, commit và merge thay đổi vào `main`.

```
Working directory --git add--> Staging area --git commit--> Local repository --git push--> GitHub
```

---

## 10. Ghi chú xử lý sự cố

### Sự cố A: 502 Bad Gateway
| Mục | Nội dung |
|---|---|
| Triệu chứng | `curl http://localhost` trả về 502 |
| Chẩn đoán | `systemctl status devops-app` (inactive); `journalctl -u devops-app`; `sudo tail /var/log/nginx/error.log` (Connection refused tới 127.0.0.1:5000); `ss -tlnp \| grep 5000` (trống) |
| Nguyên nhân | Service Flask không chạy, khiến Nginx không thể kết nối đến backend tại 127.0.0.1:5000. |
| Cách sửa | `sudo systemctl start devops-app` |

### Sự cố B: Port 5000 chạy nhưng port 80 lỗi
| Mục | Nội dung |
|---|---|
| Triệu chứng | `curl 127.0.0.1:5000` được, `curl localhost` bị từ chối kết nối |
| Chẩn đoán | `systemctl status nginx`; `sudo nginx -t`; `ss -tlnp \| grep -E ':80\|:5000'` |
| Nguyên nhân 1 | Nginx bị dừng dù cấu hình vẫn hợp lệ. Cách sửa: `sudo systemctl start nginx`. |
| Nguyên nhân 2 | Cấu hình sai cú pháp, thiếu dấu ; trong chỉ thị `proxy_pass`, khiến Nginx không thể restart |
| Cách sửa | Khôi phục cấu hình đúng từ repository, chạy ` sudo nginx -t`, sau đó restart Nginx. |
| Bài học | **Luôn chạy `sudo nginx -t` trước khi restart** |

### Sự cố C: Ứng dụng không tự chạy sau khi reboot
| Mục | Nội dung |
|---|---|
| Triệu chứng | Sau khi khởi động lại, `curl localhost` trả về 502 |
| Chẩn đoán | `systemctl status devops-app` (inactive); `systemctl is-enabled devops-app` (disabled); `ss -tlnp` (không có port 5000) |
| Nguyên nhân | Service chưa được `enable` nên không tự chạy khi boot |
| Cách sửa | `sudo systemctl enable --now devops-app` |
| Ghi chú | `start` chỉ chạy ngay lúc đó; `enable` mới giúp tự chạy mỗi lần khởi động |

### Sự cố D: Vẫn hiện phiên bản cũ
| Mục | Nội dung |
|---|---|
| Triệu chứng | `deploy.sh` báo thành công nhưng `curl` vẫn hiện v2 |
| Chẩn đoán | `deploy.sh` in "Already up to date"; `git log --oneline` và `git status` ở bản dev cho thấy commit v3 và "ahead of 'origin/main' by 1 commit"; `/opt/devops-app` ở nhánh `main` nhưng thiếu commit mới |
| Nguyên nhân | Commit chưa được push lên GitHub |
| Cách sửa | `git push origin main`, rồi chạy lại `deploy.sh` |

### Sự cố E: deploy.sh chỉ chạy được từ một thư mục
| Mục | Nội dung |
|---|---|
| Triệu chứng | Script dùng `cd ../` chạy được từ `scripts/` nhưng lỗi từ `~` (`fatal: not a git repository`, mã thoát 128) |
| Nguyên nhân | Dùng đường dẫn tương đối, phụ thuộc thư mục đang đứng |
| Cách sửa | Tính đường dẫn từ vị trí của chính script |

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"
```

---

## 11. So sánh: thủ công và tự động

| Tiêu chí | Thủ công | Tự động (`deploy.sh`) |
|---|---|---|
| Số lệnh phải gõ | Nhiều, dễ quên bước | 1 lệnh |
| Độ lặp lại | Phụ thuộc người làm | Giống nhau mỗi lần |
| Phát hiện lỗi | Phải tự kiểm tra | Health check tự động, lỗi thì `exit 1` |
| Khi máy khởi động lại | Phải chạy lại tay | systemd tự chạy |
| Chẩn đoán sự cố | Khó | Có log, status, quy trình rõ ràng |