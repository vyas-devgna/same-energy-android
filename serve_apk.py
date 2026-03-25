import socket
import qrcode
import http.server
import socketserver
import os
import sys

os.chdir("build/app/outputs/flutter-apk/")
PORT = 8080

def get_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

ip = get_ip()
url = f"http://{ip}:{PORT}/app-release.apk"

print("\n" + "="*60)
print(f"📡 Wireless APK Installer")
print("="*60)
print(f"1. Connect your phone to the same Wi-Fi network.")
print(f"2. Scan this QR code with your phone's camera:")
print(f"URL: {url}\n")

qr = qrcode.QRCode()
qr.add_data(url)
qr.print_ascii(invert=True)

print("\nServer is running... You can now download and install the universal APK!")
print("Don't close this terminal until the download finishes.\n")

Handler = http.server.SimpleHTTPRequestHandler
try:
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        httpd.serve_forever()
except KeyboardInterrupt:
    print("\nShutting down server.")
    sys.exit(0)
