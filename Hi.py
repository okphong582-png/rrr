import sys
import os
import io
import time
import traceback
import ctypes

# Initialize crash log path next to the executable
CRASH_LOG_PATH = os.path.join(os.path.dirname(sys.executable), "crash_log.txt") if getattr(sys, 'frozen', False) else "crash_log.txt"

def write_log(msg):
    try:
        with open(CRASH_LOG_PATH, "a", encoding="utf-8") as f:
            f.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}\n")
    except:
        pass

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

if not is_admin():
    try:
        if getattr(sys, 'frozen', False):
            ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, "", None, 1)
        else:
            ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, f'"{os.path.abspath(__file__)}"', None, 1)
        sys.exit(0)
    except Exception:
        pass

def show_fatal_error(title, message):
    write_log(f"FATAL ERROR: {title} - {message}")
    try:
        ctypes.windll.user32.MessageBoxW(0, str(message), str(title), 0x10) # 0x10 is MB_ICONERROR
    except Exception as e:
        write_log(f"Failed to show message box: {e}")
    sys.exit(1)

# Setup Working Directory, WinDivert DLL Paths, and Qt Plugin Paths for PyInstaller EXE execution
if getattr(sys, 'frozen', False):
    exe_dir = os.path.dirname(sys.executable)
    try:
        os.chdir(exe_dir)
    except Exception as e:
        write_log(f"Failed to change CWD: {e}")
    if hasattr(sys, '_MEIPASS'):
        # Check PyQt5 platform plugin path variants
        plugin_path1 = os.path.join(sys._MEIPASS, 'PyQt5', 'Qt5', 'plugins', 'platforms')
        plugin_path2 = os.path.join(sys._MEIPASS, 'platforms')
        if os.path.exists(plugin_path1):
            os.environ['QT_QPA_PLATFORM_PLUGIN_PATH'] = plugin_path1
            write_log(f"Qt platforms plugin path set to: {plugin_path1}")
        elif os.path.exists(plugin_path2):
            os.environ['QT_QPA_PLATFORM_PLUGIN_PATH'] = plugin_path2
            write_log(f"Qt platforms plugin path set to: {plugin_path2}")
        else:
            write_log("WARNING: PyQt5 platforms directory not found in _MEIPASS")
        
        pydivert_dll_path = os.path.join(sys._MEIPASS, 'pydivert', 'windivert_dll')
        os.environ['PATH'] = sys._MEIPASS + os.pathsep + pydivert_dll_path + os.pathsep + os.environ.get('PATH', '')
        if hasattr(os, 'add_dll_directory'):
            try:
                os.add_dll_directory(sys._MEIPASS)
                if os.path.exists(pydivert_dll_path):
                    os.add_dll_directory(pydivert_dll_path)
            except Exception as e:
                write_log(f"Failed add_dll_directory: {e}")

def get_asset_path(filename):
    if hasattr(sys, '_MEIPASS'):
        p1 = os.path.join(sys._MEIPASS, filename)
        if os.path.exists(p1): return p1
    if getattr(sys, 'frozen', False):
        p2 = os.path.join(os.path.dirname(sys.executable), filename)
        if os.path.exists(p2): return p2
    return os.path.join(os.path.abspath("."), filename)

# === EMBEDDED ENCRYPTED LOGO ASSET LOADER (IN-MEMORY RAM DECRYPTION) ===
try:
    import logo_asset
    HAS_LOGO_ASSET = True
except Exception:
    HAS_LOGO_ASSET = False

def get_app_logo_pixmap():
    if HAS_LOGO_ASSET:
        try:
            pix = logo_asset.get_logo_pixmap()
            if not pix.isNull():
                return pix
        except Exception:
            pass
    for fname in ["Logo.png", "logo.png", "app_logo.png", "hoangha_vip.png"]:
        p = get_asset_path(fname)
        if os.path.exists(p):
            return QPixmap(p)
    return QPixmap()

def get_app_logo_icon():
    pix = get_app_logo_pixmap()
    if not pix.isNull():
        return QIcon(pix)
    return QIcon()

# === NEXT-GEN MULTI-LAYER ANTI-CRACK & ANTI-REVERSE-ENGINEERING ENGINE (v4.0 PRO) ===
BLACK_LIST_PROCESSES = [
    "x64dbg.exe", "x32dbg.exe", "x96dbg.exe", "cheatengine-x86_64.exe", "Cheat Engine.exe",
    "HTTPDebuggerUI.exe", "HTTPDebuggerSvc.exe", "Wireshark.exe", "ProcessHacker.exe",
    "dnSpy.exe", "dnSpy-x86.exe", "ILSpy.exe", "Fiddler.exe", "procmon.exe", "procmon64.exe",
    "ida.exe", "ida64.exe", "idag.exe", "idag64.exe", "ghidra.exe",
    "scylla_x64.exe", "scylla_x86.exe", "reclass.exe", "reclass64.exe", "pestudio.exe",
    "ollydbg.exe", "windbg.exe", "MegaDumper.exe", "ExtremeDumper.exe", "KsDumper.exe",
    "hxd.exe", "systeminformer.exe", "pe-bear.exe", "die.exe", "cutter.exe"
]

BLACK_LIST_WINDOW_TITLES = [
    "x64dbg", "x32dbg", "cheat engine", "http debugger", "wireshark", "process hacker",
    "dnspy", "ilspy", "ida pro", "ghidra", "scylla", "reclass", "ollydbg", "windbg",
    "megadumper", "system informer", "memory viewer", "disassembly", "fiddler"
]

def hide_current_thread():
    """Win32 NTAPI: Hide current thread from any debugger attachment (ThreadHideFromDebugger 0x11)."""
    try:
        if sys.platform == 'win32':
            ntdll = ctypes.windll.ntdll
            thread_handle = ctypes.windll.kernel32.GetCurrentThread()
            status = ntdll.NtSetInformationThread(thread_handle, 0x11, 0, 0)
            return status == 0
    except Exception:
        pass
    return False

def check_hardware_breakpoints():
    """Inspects DR0-DR7 debug registers via GetThreadContext to detect hardware breakpoints."""
    try:
        if sys.platform == 'win32':
            class CONTEXT64(ctypes.Structure):
                _pack_ = 16
                _fields_ = [
                    ("P1Home", ctypes.c_uint64), ("P2Home", ctypes.c_uint64),
                    ("P3Home", ctypes.c_uint64), ("P4Home", ctypes.c_uint64),
                    ("P5Home", ctypes.c_uint64), ("P6Home", ctypes.c_uint64),
                    ("ContextFlags", ctypes.c_uint32), ("MxCsr", ctypes.c_uint32),
                    ("SegCs", ctypes.c_uint16), ("SegDs", ctypes.c_uint16),
                    ("SegEs", ctypes.c_uint16), ("SegFs", ctypes.c_uint16),
                    ("SegGs", ctypes.c_uint16), ("SegSs", ctypes.c_uint16),
                    ("EFlags", ctypes.c_uint32),
                    ("Dr0", ctypes.c_uint64), ("Dr1", ctypes.c_uint64),
                    ("Dr2", ctypes.c_uint64), ("Dr3", ctypes.c_uint64),
                    ("Dr6", ctypes.c_uint64), ("Dr7", ctypes.c_uint64),
                ]
            CONTEXT_DEBUG_REGISTERS = 0x00100010
            ctx = CONTEXT64()
            ctx.ContextFlags = CONTEXT_DEBUG_REGISTERS
            thread_handle = ctypes.windll.kernel32.GetCurrentThread()
            if ctypes.windll.kernel32.GetThreadContext(thread_handle, ctypes.byref(ctx)):
                if ctx.Dr0 != 0 or ctx.Dr1 != 0 or ctx.Dr2 != 0 or ctx.Dr3 != 0:
                    return True
    except Exception:
        pass
    return False

def check_peb_being_debugged():
    """Inspects direct Process Environment Block (PEB) BeingDebugged flag and ProcessDebugPort."""
    try:
        if sys.platform == 'win32':
            if ctypes.windll.kernel32.IsDebuggerPresent():
                return True
            port = ctypes.c_uint64(0)
            status = ctypes.windll.ntdll.NtQueryInformationProcess(
                ctypes.windll.kernel32.GetCurrentProcess(),
                7, # ProcessDebugPort
                ctypes.byref(port),
                ctypes.sizeof(port),
                0
            )
            if status == 0 and port.value != 0:
                return True
    except Exception:
        pass
    return False

def scan_window_titles():
    """Enumerates top level windows to detect active cracking tool windows."""
    try:
        if sys.platform == 'win32':
            user32 = ctypes.windll.user32
            WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
            detected_tool = []

            def enum_windows_callback(hwnd, extra):
                if user32.IsWindowVisible(hwnd):
                    length = user32.GetWindowTextLengthW(hwnd)
                    if length > 0:
                        buff = ctypes.create_unicode_buffer(length + 1)
                        user32.GetWindowTextW(hwnd, buff, length + 1)
                        title_low = buff.value.lower()
                        for bl in BLACK_LIST_WINDOW_TITLES:
                            if bl in title_low:
                                detected_tool.append(buff.value)
                                return False
                return True

            user32.EnumWindows(WNDENUMPROC(enum_windows_callback), 0)
            if detected_tool:
                show_fatal_error(
                    "NETWORKING HOTSPOT // SECURITY INTEGRITY VIOLATION",
                    f"Disallowed Reverse Engineering Window Detected: [{detected_tool[0]}]\n"
                    "Execution halted immediately to protect runtime memory."
                )
    except Exception:
        pass

def scan_disallowed_processes():
    try:
        import psutil
        for proc in psutil.process_iter(['name']):
            p_name = proc.info.get('name')
            if p_name and p_name.lower() in [b.lower() for b in BLACK_LIST_PROCESSES]:
                show_fatal_error(
                    "NETWORKING HOTSPOT // SECURITY INTEGRITY VIOLATION", 
                    f"Reverse Engineering Tool Detected: [{p_name}]\n"
                    "Process terminated immediately to protect application integrity."
                )
    except Exception:
        pass

def check_anti_debug():
    try:
        # 1. Hide Thread from Debugger
        hide_current_thread()

        # 2. Native Win32 Kernel Debugger API
        if ctypes.windll.kernel32.IsDebuggerPresent():
            show_fatal_error("NETWORKING HOTSPOT ANTI-CRACK SECURITY", 
                             "User/Kernel Debugger Detected!\nProcess memory dump blocked.")
        
        is_remote = ctypes.c_bool(False)
        ctypes.windll.kernel32.CheckRemoteDebuggerPresent(
            ctypes.windll.kernel32.GetCurrentProcess(),
            ctypes.byref(is_remote)
        )
        if is_remote.value:
            show_fatal_error("NETWORKING HOTSPOT ANTI-CRACK SECURITY", 
                             "Remote Debugger attachment detected!\nExecution terminated.")

        # 3. Direct PEB & ProcessDebugPort Check
        if check_peb_being_debugged():
            show_fatal_error("NETWORKING HOTSPOT ANTI-CRACK SECURITY",
                             "PEB / ProcessDebugPort Integrity Check Failed!\nExecution terminated.")

        # 4. Hardware Breakpoints DR0-DR7
        if check_hardware_breakpoints():
            show_fatal_error("NETWORKING HOTSPOT ANTI-CRACK SECURITY",
                             "Hardware Breakpoint (DRx Register) Detected!\nMemory inspection blocked.")

        # 5. Blacklisted Processes Scan
        scan_disallowed_processes()

        # 6. Cracking Window Titles Scan
        scan_window_titles()
    except Exception:
        pass

def start_continuous_security_guard():
    def _guard_loop():
        hide_current_thread()
        while True:
            time.sleep(3)
            check_anti_debug()
    t = threading.Thread(target=_guard_loop, daemon=True)
    t.start()


if hasattr(sys.stdout, 'reconfigure'):
    try: sys.stdout.reconfigure(encoding='utf-8', errors='ignore')
    except: pass
if hasattr(sys.stderr, 'reconfigure'):
    try: sys.stderr.reconfigure(encoding='utf-8', errors='ignore')
    except: pass

import subprocess
import threading
import random
import math
import json
import urllib.request
import ssl
import ctypes.wintypes
import socket
import re
import shutil
from http.server import HTTPServer, BaseHTTPRequestHandler

# Kích hoạt DPI Awareness
try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
except:
    try:
        ctypes.windll.user32.SetProcessDPIAware()
    except:
        pass

# Bỏ qua xác thực SSL
ssl_context = ssl._create_unverified_context()

# === DEPENDENCIES INSTALLER ===
write_log("Starting imports...")

# Import PyQt5
try:
    from PyQt5.QtCore import Qt, QTimer, QPropertyAnimation, pyqtProperty, pyqtSignal, QObject, QEasingCurve, pyqtSlot, QMetaObject, Q_ARG, QPoint, QSize, QRect, QPointF
    from PyQt5.QtGui import QPainter, QColor, QBrush, QPen, QLinearGradient, QFont, QPixmap, QTransform, QPainterPath, QIcon, QImage
    from PyQt5.QtWidgets import QApplication, QWidget, QLabel, QHBoxLayout, QVBoxLayout, QFrame, QPushButton, QLineEdit, QMessageBox, QDialog, QCheckBox, QSpinBox, QScrollArea, QScrollBar, QComboBox, QGraphicsDropShadowEffect, QStackedWidget, QMenu, QSystemTrayIcon
    write_log("PyQt5 imported successfully.")
except Exception as e:
    tb = traceback.format_exc()
    if getattr(sys, 'frozen', False):
        show_fatal_error("PyQt5 Import Error", f"PyQt5 is not bundled properly in frozen EXE: {e}\n\nTraceback:\n{tb}")
    else:
        write_log(f"PyQt5 import failed, attempting pip install: {e}")
        subprocess.run([sys.executable, "-m", "pip", "install", "PyQt5", "--quiet"])
        try:
            from PyQt5.QtCore import Qt, QTimer, QPropertyAnimation, pyqtProperty, pyqtSignal, QObject, QEasingCurve, pyqtSlot, QMetaObject, Q_ARG, QPoint, QSize, QRect, QPointF
            from PyQt5.QtGui import QPainter, QColor, QBrush, QPen, QLinearGradient, QFont, QPixmap, QTransform, QPainterPath, QIcon, QImage
            from PyQt5.QtWidgets import QApplication, QWidget, QLabel, QHBoxLayout, QVBoxLayout, QFrame, QPushButton, QLineEdit, QMessageBox, QDialog, QCheckBox, QSpinBox, QScrollArea, QScrollBar, QComboBox, QGraphicsDropShadowEffect, QStackedWidget, QMenu, QSystemTrayIcon
            write_log("PyQt5 imported successfully after pip install.")
        except Exception as e2:
            tb2 = traceback.format_exc()
            show_fatal_error("PyQt5 Post-Install Import Error", f"Failed to import PyQt5 even after pip install: {e2}\n\nTraceback:\n{tb2}")

# Import qrcode (Pure Python QR Generator)
try:
    import qrcode
    write_log("qrcode imported successfully.")
except Exception as e:
    tb = traceback.format_exc()
    if getattr(sys, 'frozen', False):
        show_fatal_error("QR Import Error", f"qrcode is not bundled properly in frozen EXE: {e}\n\nTraceback:\n{tb}")
    else:
        write_log(f"qrcode import failed, attempting pip install: {e}")
        subprocess.run([sys.executable, "-m", "pip", "install", "qrcode", "--quiet"])
        try:
            import qrcode
            write_log("qrcode imported successfully after pip install.")
        except Exception as e2:
            tb2 = traceback.format_exc()
            show_fatal_error("QR Post-Install Import Error", f"Failed to import qrcode even after pip install: {e2}\n\nTraceback:\n{tb2}")

# Import psutil, pydivert, keyboard, winsound
try:
    import psutil
    import pydivert
    import keyboard
    import winsound
    write_log("psutil, pydivert, keyboard, winsound imported successfully.")
except Exception as e:
    tb = traceback.format_exc()
    if getattr(sys, 'frozen', False):
        show_fatal_error("Engine Deps Import Error", f"Engine dependencies (psutil/pydivert/keyboard) are not bundled properly in frozen EXE: {e}\n\nTraceback:\n{tb}")
    else:
        write_log(f"Engine deps import failed, attempting pip install: {e}")
        subprocess.run([sys.executable, "-m", "pip", "install", "pydivert", "psutil", "keyboard", "--quiet"])
        try:
            import psutil
            import pydivert
            import keyboard
            import winsound
            write_log("Engine deps imported successfully after pip install.")
        except Exception as e2:
            tb2 = traceback.format_exc()
            show_fatal_error("Engine Deps Post-Install Import Error", f"Failed to import engine deps even after pip install: {e2}\n\nTraceback:\n{tb2}")

# ============================================================
# CẤU HÌNH & BIẾN TOÀN CỤC (HI_BACKUP_V1 FULL ARCHITECTURE)
# ============================================================
DB_URL = "https://htgh-cbfa3-default-rtdb.firebaseio.com/keys"

FILTER_O = '(udp.DstPort >= 10010 and udp.DstPort <= 10020) and udp.PayloadLength >= 43'
FILTER_I = '(udp.SrcPort >= 10011 and udp.SrcPort <= 10019) and ip and ip.Protocol == 17 and ip.Length >= 58 and ip.Length <= 1107 and not udp.DstPort == 53 and not udp.SrcPort == 123 and not udp.SrcPort == 1900'
FILTER_F = '(udp.DstPort >= 10011 and udp.DstPort <= 10020) and udp.PayloadLength >= 55 and udp.PayloadLength <= 300'

mode_e = False
divert_threads = []
stop_event = threading.Event()
game_pid = None
game_ports = []
w_handles = []
w_handles_by_layer = {}
handles_lock = threading.Lock()

packet_count  = [0]
dropped_count = [0]

fakelag_drop_in = True
fakelag_drop_out = False
socks5_proxy_port = 10808

current_key = "hoangha123"
is_authenticated = True
target_device_info = {"os": "Mobile / PC", "name": "Hotspot / Wi-Fi"}

# === QUẢN LÝ KHÁCH HÀNG (SINGLE-CLIENT TARGETED FAKE LAG) ===
class ClientConfig:
    def __init__(self, index, socks_port):
        self.index = index
        self.socks_port = socks_port
        self.client_ip = None
        self.fake_lag_active = False
        self.flushing = 0  # Counter: >0 khi đang xả buffer → worker KHÔNG drop gói tin mới
        self.packet_count = 0
        self.dropped_count = 0
        self.fake_lag_until = 0.0
        
        self.tele_active = False    # ⚡ TeleKill
        self.freeze_active = False  # 🧊 Freeze (Địch đơ)
        self.ghost_active = False   # 👻 Ghost Lag
        self.lag_mode = "tele"     # Mode tiêu điểm hiện tại
        
        self.tele_buffer = []
        self.freeze_buffer = []
        self.ghost_buffer = []
        self.tele_flushing = False
        self.freeze_flushing = False
        self.ghost_flushing = False

num_clients = 4
clients = [
    ClientConfig(1, 10808),
    ClientConfig(2, 10809),
    ClientConfig(3, 10810),
    ClientConfig(4, 10811)
]
clients_lock = threading.Lock()

# === XẢ TÚI TIN CHUẨN 2.PY (TELEKILL BURST 4 PACKETS / 5MS) ===
def send_bursts_tele(to_send):
    """Xả burst 4 packets / 5ms theo đúng chuẩn 2.py.
    Tái tạo pydivert.Packet(raw, interface, direction) và phát lại trên đúng layer (Layer 0 / Layer 1).
    """
    if not to_send: return
    try:
        burst_size = 4
        delay_per_packet = 0.005
        delay_per_burst  = 0.005

        for i in range(0, len(to_send), burst_size):
            burst = to_send[i:i + burst_size]
            for item in burst:
                try:
                    if isinstance(item, tuple):
                        pkt, l_val = item
                    else:
                        pkt, l_val = item, 0

                    pkt_rebuilt = pydivert.Packet(pkt.raw, pkt.interface, pkt.direction)
                    h_send = None
                    with handles_lock:
                        h_send = w_handles_by_layer.get(l_val) or (w_handles[0] if w_handles else None)

                    if h_send:
                        h_send.send(pkt_rebuilt)
                    else:
                        with pydivert.WinDivert(FILTER_O, layer=l_val) as sender:
                            sender.send(pkt_rebuilt)
                    time.sleep(delay_per_packet)
                except Exception as e:
                    pass
            time.sleep(delay_per_burst)
    except Exception as e:
        print("[TeleBurst Error]", e)

def send_packets_generic(to_send, filter_str):
    if not to_send: return
    try:
        with pydivert.WinDivert(filter_str, layer=pydivert.Layer.NETWORK) as sender:
            for item in to_send:
                try:
                    if isinstance(item, tuple):
                        pkt, l_val = item
                    else:
                        pkt = item
                    pkt_rebuilt = pydivert.Packet(pkt.raw, pkt.interface, pkt.direction)
                    sender.send(pkt_rebuilt)
                except Exception: pass
    except Exception as e:
        print("[Send Packets Generic Error]", e)

def _do_flush_tele(client, to_send):
    client.tele_flushing = True
    try:
        send_bursts_tele(to_send)
        time.sleep(0.05)
    finally:
        client.tele_flushing = False

def _do_flush_generic(client, to_send, filter_str):
    try:
        send_packets_generic(to_send, filter_str)
    except Exception: pass

def flush_tele_buffer(client):
    if hasattr(client, 'tele_buffer') and client.tele_buffer:
        to_send = list(client.tele_buffer)
        client.tele_buffer.clear()
        threading.Thread(target=_do_flush_tele, args=(client, to_send), daemon=True).start()

def flush_freeze_buffer(client):
    if hasattr(client, 'freeze_buffer') and client.freeze_buffer:
        to_send = list(client.freeze_buffer)
        client.freeze_buffer.clear()
        threading.Thread(target=_do_flush_generic, args=(client, to_send, FILTER_I), daemon=True).start()

def flush_ghost_buffer(client):
    if hasattr(client, 'ghost_buffer') and client.ghost_buffer:
        to_send = list(client.ghost_buffer)
        client.ghost_buffer.clear()
        threading.Thread(target=_do_flush_generic, args=(client, to_send, FILTER_F), daemon=True).start()

def flush_client_buffers(client):
    """Xả toàn bộ túi tin đang lưu trong client chuẩn 2.py"""
    flush_tele_buffer(client)
    flush_freeze_buffer(client)
    flush_ghost_buffer(client)

# === HELPER IP & QR CODE ===
def get_all_host_ips():
    host_ips = set()
    try:
        for iface, addrs in psutil.net_if_addrs().items():
            for addr in addrs:
                if addr.family == socket.AF_INET:
                    host_ips.add(addr.address)
    except: pass
    try:
        hostname = socket.gethostname()
        for info in socket.getaddrinfo(hostname, None):
            ip = info[4][0]
            if "." in ip: host_ips.add(ip)
    except: pass
    for gw in ["127.0.0.1", "0.0.0.0", "192.168.137.1", "192.168.1.1", "192.168.0.1", "192.168.30.1", "172.20.10.1", "255.255.255.255"]:
        host_ips.add(gw)
    return host_ips

HOST_IPS = get_all_host_ips()

def get_local_ip():
    try:
        for iface, addrs in psutil.net_if_addrs().items():
            for addr in addrs:
                if addr.family == socket.AF_INET and addr.address.startswith("100."):
                    return addr.address
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "192.168.1.100"

def generate_qr_pixmap(data_str):
    try:
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=1,
            border=2
        )
        qr.add_data(data_str)
        qr.make(fit=True)
        matrix = qr.get_matrix()
        dim = len(matrix)
        img = QImage(dim, dim, QImage.Format_Mono)
        img.setColor(0, 0xFFFFFFFF) # White background
        img.setColor(1, 0xFF000000) # Black foreground
        for r_idx, row in enumerate(matrix):
            for c_idx, val in enumerate(row):
                img.setPixel(c_idx, r_idx, 1 if val else 0)
        
        pixmap = QPixmap.fromImage(img).scaled(200, 200, Qt.KeepAspectRatio, Qt.FastTransformation)
        return pixmap
    except Exception:
        pixmap = QPixmap(175, 175)
        pixmap.fill(QColor("#ffffff"))
        return pixmap

def get_hwid():
    try:
        cmd = 'powershell -NoProfile -Command "(Get-CimInstance Win32_ComputerSystemProduct).UUID"'
        output = subprocess.check_output(cmd, shell=True, startupinfo=subprocess.STARTUPINFO())
        uuid_str = output.decode().strip()
        if uuid_str and len(uuid_str) > 10: return uuid_str
    except: pass
    try:
        import winreg
        registry_key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Cryptography")
        value, regtype = winreg.QueryValueEx(registry_key, "MachineGuid")
        winreg.CloseKey(registry_key)
        if value: return str(value).strip()
    except: pass
    return "DEFAULT_HWID"

def beep_async(freq, duration):
    try:
        threading.Thread(target=winsound.Beep, args=(freq, duration), daemon=True).start()
    except: pass

class HotkeyBridge(QObject):
    toggle_e = pyqtSignal()
    toggle_tele = pyqtSignal()
    toggle_freeze = pyqtSignal()
    toggle_ghost = pyqtSignal()

hotkey_bridge = HotkeyBridge()

class RemoteControlBridge(QObject):
    fakelag_signal = pyqtSignal(int, bool)
    toggle_signal = pyqtSignal()
    update_tunnel_url = pyqtSignal(str)
    divert_error = pyqtSignal(str)

remote_bridge = RemoteControlBridge()

class WindowVisibilityBridge(QObject):
    toggle_visible = pyqtSignal(bool)

vis_bridge = WindowVisibilityBridge()

class FastRemoteControlHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args): pass

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS, HEAD")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        try:
            global current_key, clients
            from urllib.parse import urlparse, parse_qs
            parsed_url = urlparse(self.path)
            path = parsed_url.path.lower()
            query_params = parse_qs(parsed_url.query)

            if path in ["/favicon.ico", "/apple-touch-icon.png", "/apple-touch-icon-precomposed.png"]:
                self.send_response(204)
                self.end_headers()
                return

            slot_param = query_params.get("slot", query_params.get("id", ["1"]))[0]
            try:
                slot_idx = int(slot_param) - 1
                if not (0 <= slot_idx < len(clients)): slot_idx = 0
            except: slot_idx = 0

            target_client = clients[slot_idx]

            if path in ["", "/"]:
                cur_m = getattr(target_client, 'lag_mode', 'tele')
                is_on = getattr(target_client, 'fake_lag_active', False)
                html_content = f"""<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Networking Hotspot // VIP Remote</title>
    <style>
        * {{ box-sizing: border-box; -webkit-tap-highlight-color: transparent; }}
        body {{ background: #090c14; color: #ffffff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; padding: 16px; }}
        .card {{ background: rgba(15, 23, 42, 0.95); border: 1.5px solid rgba(0, 242, 254, 0.35); border-radius: 20px; padding: 24px 20px; text-align: center; box-shadow: 0 10px 40px rgba(0, 0, 0, 0.6); width: 100%; max-width: 360px; }}
        h2 {{ margin: 0 0 4px 0; color: #00f2fe; font-size: 20px; letter-spacing: 0.5px; font-weight: 800; }}
        .sub-header {{ color: #64748b; font-size: 11px; font-weight: 600; letter-spacing: 1px; margin-bottom: 18px; }}
        .action-card {{ background: rgba(30, 41, 59, 0.6); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 12px; padding: 14px 16px; margin-bottom: 12px; display: flex; align-items: center; justify-content: space-between; text-align: left; }}
        .action-title {{ font-size: 14px; font-weight: 700; }}
        .action-desc {{ font-size: 10px; color: #94a3b8; margin-top: 2px; }}
        .btn-act {{ padding: 10px 16px; border: none; border-radius: 8px; font-size: 12px; font-weight: 800; color: #ffffff; cursor: pointer; transition: all 0.15s; }}
        .btn-act:active {{ transform: scale(0.95); }}
        .btn-tele {{ background: #ff4500; box-shadow: 0 4px 14px rgba(255, 69, 0, 0.4); }}
        .btn-freeze {{ background: #00aaff; box-shadow: 0 4px 14px rgba(0, 170, 255, 0.4); }}
        .btn-ghost {{ background: #c084fc; color: #090c14; box-shadow: 0 4px 14px rgba(192, 132, 252, 0.4); }}
        .btn-off-all {{ width: 100%; padding: 14px; margin-top: 10px; border: 1px solid rgba(239, 68, 68, 0.4); background: rgba(239, 68, 68, 0.15); color: #ef4444; border-radius: 10px; font-size: 13px; font-weight: 800; cursor: pointer; }}
        .btn-off-all:active {{ background: #ef4444; color: #ffffff; }}
        #toast {{ margin-top: 14px; font-size: 12px; font-weight: 700; color: #00f2fe; min-height: 18px; }}
    </style>
</head>
<body>
    <div class="card">
        <h2>⚡ NETWORKING HOTSPOT</h2>
        <div class="sub-header">VIP C++ PRO CORE REMOTE</div>

        <div class="action-card">
            <div>
                <div class="action-title" style="color: #ff4500;">⚡ TELEKILL</div>
                <div class="action-desc">Di chuyển tức thời, xả dồn</div>
            </div>
            <button class="btn-act btn-tele" onclick="triggerMode('tele')">TOGGLE</button>
        </div>

        <div class="action-card">
            <div>
                <div class="action-title" style="color: #00aaff;">🧊 FREEZE TARGET</div>
                <div class="action-desc">Đóng băng đối phương</div>
            </div>
            <button class="btn-act btn-freeze" onclick="triggerMode('freeze')">TOGGLE</button>
        </div>

        <div class="action-card">
            <div>
                <div class="action-title" style="color: #c084fc;">👻 GHOST LAG</div>
                <div class="action-desc">Lệch hitbox, tàng hình</div>
            </div>
            <button class="btn-act btn-ghost" onclick="triggerMode('ghost')">TOGGLE</button>
        </div>

        <button class="btn-off-all" onclick="triggerMode('off')">🔴 TẮT TẤT CẢ (XẢ GÓI TIN)</button>
        <div id="toast"></div>
    </div>
    <script>
        function triggerMode(m) {{
            const url = m === 'off' ? '/off' : '/' + m;
            fetch(url).then(r=>r.text()).then(txt=>{{
                document.getElementById('toast').innerText = '✅ ' + (m === 'off' ? 'ĐÃ TẮT TOÀN BỘ' : m.toUpperCase() + ' ĐÃ KÍCH HOẠT');
                setTimeout(()=>document.getElementById('toast').innerText='', 2000);
            }}).catch(()=>{{
                document.getElementById('toast').innerText = '❌ Lỗi kết nối';
            }});
        }}
    </script>
</body>
</html>"""
                body = html_content.encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(body)
                return

            req_ip = self.client_address[0].strip()
            cf_ip = self.headers.get("CF-Connecting-IP", "").strip()

            action = query_params.get("action", [""])[0]
            mode_param = query_params.get("mode", [""])[0].lower()

            # Lấy IP thiết bị: ưu tiên ?ip= param (iOS Shortcut truyền IP LAN), rồi req_ip, rồi CF-IP
            ip_param = query_params.get("ip", [""])[0].strip()
            with clients_lock:
                check_ip = ip_param if ip_param else (req_ip if not req_ip.startswith("127.") else cf_ip)
                # Chấp nhận cả IP nội bộ LAN/VPN lẫn IP bất kỳ khi truyền qua ?ip= param
                if check_ip and (ip_param or check_ip.startswith("100.") or check_ip.startswith("192.168.") or check_ip.startswith("10.") or check_ip.startswith("172.")):
                    if not any(c.client_ip == check_ip for c in clients if c != target_client):
                        target_client.client_ip = check_ip

            response_text = "OK"
            if action == "set_mode":
                with clients_lock:
                    target_client.lag_mode = mode_param
                body = json.dumps({"status": "ok", "mode": mode_param}).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return

            # Phân loại các đường dẫn Shortcut / Web (URL endpoints):
            # /tele -> Toggle TeleKill (⚡)
            # /freeze -> Toggle Freeze Địch (🧊)
            # /ghost -> Toggle Ghost Lag (👻)
            # /switch hoặc /cycle -> Xoay vòng chế độ
            # /on -> Bật chế độ hiện tại
            # /off -> Tắt toàn bộ
            # /toggle -> Toggle chế độ hiện tại

            def send_action_response(title_name, is_active, mode_code):
                accept_hdr = self.headers.get("Accept", "")
                user_agent = self.headers.get("User-Agent", "")
                if "text/html" in accept_hdr or "Mozilla" in user_agent:
                    badge_class = "badge-on" if is_active else "badge-off"
                    state_txt = "BẬT (ON)" if is_active else "TẮT (OFF)"
                    html_badge = f"""<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HOANGHA VIP — {title_name}</title>
    <style>
        body {{ background: #08090d; color: #ffffff; font-family: 'Segoe UI', sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; }}
        .card {{ background: rgba(15, 23, 42, 0.95); border: 1px solid rgba(0, 255, 210, 0.3); border-radius: 16px; padding: 28px 36px; text-align: center; box-shadow: 0 10px 30px rgba(0, 255, 210, 0.15); width: 85%; max-width: 380px; }}
        .title {{ font-size: 18px; font-weight: bold; color: #00ffd2; margin-bottom: 12px; letter-spacing: 1px; }}
        .badge {{ display: inline-block; padding: 12px 24px; border-radius: 20px; font-size: 15px; font-weight: bold; text-transform: uppercase; margin-top: 8px; }}
        .badge-on {{ background: rgba(0, 230, 118, 0.15); color: #00e676; border: 1px solid #00e676; box-shadow: 0 0 15px rgba(0, 230, 118, 0.3); }}
        .badge-off {{ background: rgba(255, 68, 68, 0.15); color: #ff4444; border: 1px solid #ff4444; }}
        .sub {{ font-size: 11px; color: #94a3b8; margin-top: 14px; }}
    </style>
</head>
<body>
    <div class="card">
        <div class="title">⚡ HOANGHA VIP REMOTE</div>
        <div class="badge {badge_class}">{title_name} — {state_txt}</div>
        <div class="sub">Lệnh đã được thực thi thành công!</div>
    </div>
</body>
</html>"""
                    b = html_badge.encode("utf-8")
                    self.send_response(200)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.send_header("Content-Length", str(len(b)))
                    self.send_header("Access-Control-Allow-Origin", "*")
                    self.end_headers()
                    self.wfile.write(b)
                else:
                    b = json.dumps({
                        "status": "ok",
                        "mode": mode_code,
                        "active": is_active,
                        "message": f"{title_name} [{'BẬT' if is_active else 'TẮT'}]"
                    }).encode("utf-8")
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json; charset=utf-8")
                    self.send_header("Content-Length", str(len(b)))
                    self.send_header("Access-Control-Allow-Origin", "*")
                    self.end_headers()
                    self.wfile.write(b)

            if path in ["/tele", "/telekill"]:
                if main_window_instance:
                    QMetaObject.invokeMethod(main_window_instance, "toggle_mode_hotkey", Qt.QueuedConnection, Q_ARG(str, "tele"))
                with clients_lock:
                    is_active = bool(target_client.tele_active)
                send_action_response("TeleKill ⚡", is_active, "tele")
                return

            elif path in ["/freeze", "/freeze_mode"]:
                if main_window_instance:
                    QMetaObject.invokeMethod(main_window_instance, "toggle_mode_hotkey", Qt.QueuedConnection, Q_ARG(str, "freeze"))
                with clients_lock:
                    is_active = bool(target_client.freeze_active)
                send_action_response("Freeze Địch 🧊", is_active, "freeze")
                return

            elif path in ["/ghost", "/ghost_lag", "/ghost_mode"]:
                if main_window_instance:
                    QMetaObject.invokeMethod(main_window_instance, "toggle_mode_hotkey", Qt.QueuedConnection, Q_ARG(str, "ghost_lag"))
                with clients_lock:
                    is_active = bool(target_client.ghost_active)
                send_action_response("Ghost Lag 👻", is_active, "ghost_lag")
                return

            elif path in ["/switch", "/cycle"]:
                cur = getattr(target_client, 'lag_mode', 'tele')
                if cur == "tele": next_mode = "freeze"
                elif cur == "freeze": next_mode = "ghost_lag"
                else: next_mode = "tele"
                
                if main_window_instance:
                    QMetaObject.invokeMethod(main_window_instance, "toggle_mode_hotkey", Qt.QueuedConnection, Q_ARG(str, next_mode))
                send_action_response(f"XOAY VÒNG: [{next_mode.upper()}]", target_client.fake_lag_active, next_mode)
                return

            elif path == "/on" or path.startswith("/on?") or path.startswith("/on/"):
                target_mode = mode_param if mode_param in ["tele", "freeze", "ghost", "ghost_lag"] else getattr(target_client, 'lag_mode', 'tele')
                if target_mode in ["ghost", "ghost_lag"]: target_mode = "ghost_lag"
                
                if main_window_instance:
                    QMetaObject.invokeMethod(main_window_instance, "toggle_mode_hotkey", Qt.QueuedConnection, Q_ARG(str, target_mode))

                send_json({
                    "status": "ok",
                    "action": "on",
                    "mode": target_mode,
                    "active": target_client.fake_lag_active,
                    "slot": target_client.index,
                    "message": f"Fake Lag BẬT [{target_mode.upper()}]"
                })
                return

            elif path == "/off" or path.startswith("/off?") or path.startswith("/off/"):
                with clients_lock:
                    target_client.fake_lag_active = False
                    flush_client_buffers(target_client)

                if main_window_instance:
                    QMetaObject.invokeMethod(main_window_instance, "update_ui_status_slot", Qt.QueuedConnection, Q_ARG(str, "tele"))

                send_json({
                    "status": "ok",
                    "action": "off",
                    "active": False,
                    "slot": target_client.index,
                    "message": "Fake Lag TẮT (Đã xả toàn bộ gói)"
                })
                return

            elif path == "/toggle" or path.startswith("/toggle?") or path.startswith("/toggle/"):
                cur_m = getattr(target_client, 'lag_mode', 'tele')
                # Chuyển mode nội bộ (ghost_lag) thành từ khóa hotkey (ghost) nếu cần
                if cur_m == "ghost_lag": cur_m = "ghost"
                if main_window_instance:
                    QMetaObject.invokeMethod(main_window_instance, "toggle_mode_hotkey", Qt.QueuedConnection, Q_ARG(str, cur_m))
                
                send_json({
                    "status": "ok",
                    "action": "toggle",
                    "mode": cur_m,
                    "active": target_client.fake_lag_active,
                    "slot": target_client.index,
                    "message": f"Toggle [{cur_m.upper()}]"
                })
                return

            elif path in ["/api/register_device", "/api/bind"]:
                hwid_val = query_params.get("hwid", ["UNKNOWN_HWID"])[0].strip()
                dev_ip = ip_param if ip_param else (req_ip if not req_ip.startswith("127.") else cf_ip)
                
                with clients_lock:
                    if dev_ip and not dev_ip.startswith("127."):
                        target_client.client_ip = dev_ip
                
                tunnel_url_val = main_window_instance.tunnel_url if (main_window_instance and hasattr(main_window_instance, 'tunnel_url')) else ""
                send_json({
                    "status": "ok",
                    "registered_ip": dev_ip,
                    "hwid": hwid_val,
                    "slot": target_client.index,
                    "server_tunnel": tunnel_url_val,
                    "message": "Thiết bị iOS đã kết nối & đồng bộ luồng thành công!"
                })
                return

            elif path in ["/vpn.mobileconfig", "/download_vpn"]:
                server_host = req_ip if not req_ip.startswith("127.") else "127.0.0.1"
                mobileconfig_xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>IPSec</key>
            <dict>
                <key>AuthenticationMethod</key>
                <string>SharedSecret</string>
                <key>SharedSecret</key>
                <string>hoanghavip</string>
            </dict>
            <key>IPv4</key>
            <dict>
                <key>OverridePrimary</key>
                <integer>1</integer>
            </dict>
            <key>L2TP</key>
            <dict>
                <key>AuthName</key>
                <string>hoangha</string>
                <key>AuthPassword</key>
                <string>hoangha</string>
            </dict>
            <key>PayloadDescription</key>
            <string>Cấu hình VPN định tuyến luồng Server PC HoangHa VIP</string>
            <key>PayloadDisplayName</key>
            <string>HoangHa VIP PC VPN</string>
            <key>PayloadIdentifier</key>
            <string>com.hoanghamod.vpn</string>
            <key>PayloadType</key>
            <string>com.apple.vpn.managed</string>
            <key>PayloadUUID</key>
            <string>98765432-1234-5678-9012-345678901234</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>UserDefinedName</key>
            <string>HoangHa VIP PC Server</string>
            <key>VPNType</key>
            <string>L2TP</string>
            <key>ServerAddress</key>
            <string>{server_host}</string>
        </dict>
    </array>
    <key>PayloadDisplayName</key>
    <string>HoangHa VIP Server VPN Profile</string>
    <key>PayloadIdentifier</key>
    <string>com.hoanghamod.profile</string>
    <key>PayloadRemovalDisallowed</key>
    <false/>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>12345678-1234-5678-9012-123456789012</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>'''
                body = mobileconfig_xml.encode('utf-8')
                self.send_response(200)
                self.send_header("Content-Type", "application/x-apple-aspen-config; charset=utf-8")
                self.send_header("Content-Disposition", 'attachment; filename="HoangHaVIP.mobileconfig"')
                self.send_header("Content-Length", str(len(body)))
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(body)
                return
            elif path in ["/api/verify_key", "/api/key_status"]:
                key_param = query_params.get("key", [""])[0].strip()
                rem_sec = 604800  # Default 7 days (7 * 86400)
                
                # Check key naming conventions or query Firebase
                key_lower = key_param.lower()
                if "1d" in key_lower or "1day" in key_lower:
                    rem_sec = 86400
                elif "7d" in key_lower or "7day" in key_lower or "hoang" in key_lower:
                    rem_sec = 604800
                elif "30d" in key_lower or "30day" in key_lower or "month" in key_lower:
                    rem_sec = 2592000
                
                try:
                    fb_url = "https://htgh-cbfa3-default-rtdb.firebaseio.com/keys.json"
                    req = urllib.request.Request(fb_url, headers={"User-Agent": "Mozilla/5.0"})
                    with urllib.request.urlopen(req, timeout=3, context=ssl_context) as resp:
                        keys_data = json.loads(resp.read().decode('utf-8'))
                        if keys_data and isinstance(keys_data, dict):
                            for k_id, k_info in keys_data.items():
                                if isinstance(k_info, dict) and k_info.get("key", "").strip().lower() == key_param.lower():
                                    exp_ts = k_info.get("expiry_time", k_info.get("expires_at", 0))
                                    if exp_ts > 0:
                                        now_ts = int(time.time() * 1000)
                                        rem_sec = max(0, int((exp_ts - now_ts) / 1000))
                                    break
                except Exception:
                    pass

                send_json({
                    "status": "ok",
                    "valid": True,
                    "key": key_param,
                    "remaining_seconds": rem_sec,
                    "message": "Xác thực Key thành công!"
                })
                return

            elif path == "/status" or path.startswith("/status?") or path.startswith("/status/"):
                # Endpoint kiểm tra trạng thái hiện tại (cho iOS Shortcut và web)
                body = json.dumps({
                    "slot": target_client.index,
                    "active": bool(target_client.fake_lag_active),
                    "mode": getattr(target_client, 'lag_mode', 'ghost'),
                    "status": "ON" if target_client.fake_lag_active else "OFF"
                }).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(body)
                return

            body = response_text.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Connection", "close")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body)
            self.wfile.flush()
        except Exception as e:
            print("[Remote HTTP Server Error]", e)

http_server_port = 20000

def start_http_server():
    global http_server_port
    from http.server import ThreadingHTTPServer
    for port in range(20000, 20050):
        try:
            server = ThreadingHTTPServer(("0.0.0.0", port), FastRemoteControlHandler)
            http_server_port = port
            threading.Thread(target=server.serve_forever, daemon=True).start()
            print(f"[*] Multi-Threaded Remote HTTP Server listening on http://127.0.0.1:{http_server_port}")
            return
        except Exception as e:
            continue

# === BUILT-IN SOCKS5 PROXY SERVER (PORT 10808) ===
def start_socks5_proxy():
    global clients
    def handle_socks_client(client_sock, client_obj):
        try:
            try:
                client_ip = client_sock.getpeername()[0]
                with clients_lock:
                    client_obj.client_ip = client_ip
                    client_obj.last_active = time.time()
                print(f"[SOCKS5] Thiết bị {client_obj.index} đã kết nối từ IP: {client_ip}")
            except: pass
            client_sock.settimeout(15)
            data = client_sock.recv(2)
            if not data or len(data) < 2:
                client_sock.close()
                return
            ver, nmethods = data[0], data[1]
            methods = client_sock.recv(nmethods)
            client_sock.sendall(b"\x05\x00")
            
            req_head = client_sock.recv(4)
            if len(req_head) < 4:
                client_sock.close()
                return
            ver, cmd, rsv, atyp = req_head
            if cmd != 1:
                client_sock.close()
                return
                
            if atyp == 1:
                dest_bytes = client_sock.recv(4)
                dest_ip = socket.inet_ntoa(dest_bytes)
            elif atyp == 3:
                domain_len = client_sock.recv(1)[0]
                dest_ip = client_sock.recv(domain_len).decode('utf-8')
            elif atyp == 4:
                dest_bytes = client_sock.recv(16)
                dest_ip = socket.inet_ntop(socket.AF_INET6, dest_bytes)
            else:
                client_sock.close()
                return
                
            dest_port = int.from_bytes(client_sock.recv(2), 'big')
            
            try:
                target_sock = socket.create_connection((dest_ip, dest_port), timeout=10)
                client_sock.sendall(b"\x05\x00\x00\x01\x00\x00\x00\x00\x00\x00")
            except Exception as e:
                client_sock.sendall(b"\x05\x05\x00\x01\x00\x00\x00\x00\x00\x00")
                client_sock.close()
                return
                
            client_sock.settimeout(None)
            target_sock.settimeout(None)
            
            def pipe_stream(src, dst):
                try:
                    while True:
                        buf = src.recv(16384)
                        if not buf: break
                        dst.sendall(buf)
                except: pass
                finally:
                    try: src.close()
                    except: pass
                    try: dst.close()
                    except: pass
                    
            t1 = threading.Thread(target=pipe_stream, args=(client_sock, target_sock), daemon=True)
            t2 = threading.Thread(target=pipe_stream, args=(target_sock, client_sock), daemon=True)
            t1.start()
            t2.start()
        except:
            try: client_sock.close()
            except: pass

    def proxy_server_loop(client_obj):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            s.bind(("0.0.0.0", client_obj.socks_port))
            s.listen(100)
            print(f"[*] Built-in SOCKS5 Remote Proxy Server listening on port {client_obj.socks_port}")
            while True:
                cli, _ = s.accept()
                threading.Thread(target=handle_socks_client, args=(cli, client_obj), daemon=True).start()
        except Exception as e:
            print(f"[SOCKS5 Proxy Server Error] Port {client_obj.socks_port}: {e}")

    with clients_lock:
        for client in clients:
            threading.Thread(target=proxy_server_loop, args=(client,), daemon=True).start()

cloudflare_tunnel_url = ""

def cloudflare_monitor_loop():
    global cloudflare_tunnel_url, http_server_port
    try:
        subprocess.run("taskkill /f /im cloudflared.exe", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=0x08000000)
    except: pass
    
    cf_exe = get_asset_path("cloudflared.exe")
    if not os.path.exists(cf_exe):
        cf_exe = os.path.join(os.getcwd(), "cloudflared.exe")
    
    if os.path.exists(cf_exe):
        print("[*] Đang khởi tạo Cloudflare Tunnel cho kết nối từ xa...", flush=True)
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = subprocess.SW_HIDE
        
        try:
            proc = subprocess.Popen(
                [cf_exe, "tunnel", "--url", f"http://127.0.0.1:{http_server_port}"],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.PIPE,
                text=True, startupinfo=startupinfo, creationflags=0x08000000, encoding='utf-8', errors='ignore', bufsize=1
            )
            
            found_url = False
            start_time = time.time()
            output_buffer = []

            def reader():
                try:
                    for line in iter(proc.stdout.readline, ''):
                        if not line: break
                        output_buffer.append(line)
                except: pass

            t_read = threading.Thread(target=reader, daemon=True)
            t_read.start()

            while time.time() - start_time < 15:
                full_text = "".join(output_buffer)
                if proc.poll() is not None and not full_text: break
                match = re.search(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com", full_text)
                if match and "api.trycloudflare.com" not in match.group(0):
                    cloudflare_tunnel_url = match.group(0)
                    print(f"\n============================================================", flush=True)
                    print(f" [+] Khởi tạo thành công Cloudflare Tunnel URL: {cloudflare_tunnel_url}", flush=True)
                    print("------------------------------------------------------------", flush=True)
                    print(f" [+] LINK TELEKILL (ON/OFF):  {cloudflare_tunnel_url}/tele?slot=1&key={current_key}", flush=True)
                    print(f" [+] LINK FREEZE   (ON/OFF):  {cloudflare_tunnel_url}/freeze?slot=1&key={current_key}", flush=True)
                    print(f" [+] LINK GHOST    (ON/OFF):  {cloudflare_tunnel_url}/ghost?slot=1&key={current_key}", flush=True)
                    print(f" [+] LINK WEB REMOTE CONTROL: {cloudflare_tunnel_url}/?slot=1&key={current_key}", flush=True)
                    print("============================================================\n", flush=True)
                    remote_bridge.update_tunnel_url.emit(cloudflare_tunnel_url)
                    push_tunnel_url_to_firebase(cloudflare_tunnel_url)
                    found_url = True
                    break
                time.sleep(0.3)
            
            if found_url:
                return
            else:
                try: proc.kill()
                except: pass
        except Exception as e:
            print(f"[!] Lỗi Cloudflare Tunnel: {e}", flush=True)

    print("[*] Cloudflare Tunnel thất bại. Đang thử localhost.run làm phương án dự phòng...", flush=True)
    startupinfo = subprocess.STARTUPINFO()
    startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startupinfo.wShowWindow = subprocess.SW_HIDE
    
    try:
        proc = subprocess.Popen(
            ["ssh", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-R", f"80:127.0.0.1:{http_server_port}", "nokey@localhost.run"],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.PIPE,
            text=True, startupinfo=startupinfo, encoding='utf-8', errors='ignore'
        )
        
        output_buffer_lh = []
        def reader_lh():
            try:
                for line in iter(proc.stdout.readline, ''):
                    if not line: break
                    output_buffer_lh.append(line)
            except: pass

        t_read_lh = threading.Thread(target=reader_lh, daemon=True)
        t_read_lh.start()

        found_url = False
        start_time = time.time()
        while time.time() - start_time < 15:
            if proc.poll() is not None and not output_buffer_lh: break
            full_text = "".join(output_buffer_lh)
            match = re.search(r"https://[a-zA-Z0-9-]+\.lhr\.life", full_text)
            if match:
                cloudflare_tunnel_url = match.group(0)
                print(f"\n[+] Khởi tạo thành công localhost.run Tunnel URL: {cloudflare_tunnel_url}", flush=True)
                remote_bridge.update_tunnel_url.emit(cloudflare_tunnel_url)
                push_tunnel_url_to_firebase(cloudflare_tunnel_url)
                found_url = True
                break
            time.sleep(0.3)
        
        if found_url:
            return
        else:
            try: proc.kill()
            except: pass
    except Exception as e:
        print(f"[!] Lỗi localhost.run Tunnel: {e}", flush=True)

FIREBASE_DB_URL = "https://htgh-cbfa3-default-rtdb.firebaseio.com"

def push_tunnel_url_to_firebase(url):
    """Không đồng bộ Tunnel URL lên Firebase"""
    return

last_firebase_timestamp = int(time.time() * 1000)

def update_firebase_remote_status(status_str, mode_str=None):
    """Cập nhật trạng thái ON/OFF/MODE lên Firebase khi bật/tắt cục bộ"""
    global last_firebase_timestamp
    now_ms = int(time.time() * 1000)
    last_firebase_timestamp = now_ms
    try:
        req_url = f"{FIREBASE_DB_URL}/remote_control.json"
        payload_data = {
            "status": status_str.upper(),
            "timestamp": now_ms
        }
        if mode_str:
            payload_data["mode"] = mode_str.lower()
        payload = json.dumps(payload_data).encode("utf-8")
        req = urllib.request.Request(req_url, data=payload, headers={"Content-Type": "application/json"}, method="PUT")
        ctx = ssl._create_unverified_context()
        with urllib.request.urlopen(req, context=ctx, timeout=3) as resp:
            pass
    except Exception:
        pass

def firebase_control_listener_loop():
    """Cơ chế Firebase đã được loại bỏ hoàn toàn theo yêu cầu."""
    return

def start_cloudflare_tunnel():
    cf_exe = get_asset_path("cloudflared.exe")
    if not os.path.exists(cf_exe):
        cf_exe = os.path.join(os.getcwd(), "cloudflared.exe")
    if not os.path.exists(cf_exe):
        print("[*] Downloading cloudflared.exe từ GitHub...")
        try:
            url = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
            ctx = ssl._create_unverified_context()
            with urllib.request.urlopen(url, context=ctx) as response, open(cf_exe, 'wb') as out_file:
                shutil.copyfileobj(response, out_file)
            print("[*] Tải thành công cloudflared.exe!")
        except Exception as e:
            print("Lỗi tải cloudflared.exe:", e)

    threading.Thread(target=cloudflare_monitor_loop, daemon=True).start()

# === GAME FINDER ENGINE ===
game_pid = None
game_ports = []
game_ports_lock = threading.Lock()

def find_game_background():
    global game_pid, game_ports
    emulators = ['hd-player', 'dnplayer', 'bluestacks', 'nox', 'ldplayer']
    while True:
        try:
            found_pid = None
            for proc in psutil.process_iter(['pid', 'name']):
                name = proc.info['name'].lower() if proc.info['name'] else ''
                if any(e in name for e in emulators):
                    found_pid = proc.info['pid']
                    break
            if found_pid:
                ports = []
                for conn in psutil.net_connections(kind='udp'):
                    if conn.pid == found_pid and conn.laddr and conn.laddr.port > 0:
                        ports.append(conn.laddr.port)
                ports = list(set(ports))
                with game_ports_lock:
                    game_pid = found_pid
                    game_ports = ports
            else:
                with game_ports_lock:
                    game_pid = None
                    game_ports = []
        except Exception: pass
        time.sleep(3)

# === BỘ LỌC CỔNG GAME CHUẨN 1:1 THEO 2.PY ===
FILTER_O = '(udp.DstPort >= 10010 and udp.DstPort <= 10020) and udp.PayloadLength >= 43'
FILTER_I = '(udp.SrcPort >= 10011 and udp.SrcPort <= 10019) and ip and ip.Protocol == 17 and ip.Length >= 58 and ip.Length <= 1107 and not udp.DstPort == 53 and not udp.SrcPort == 123 and not udp.SrcPort == 1900'
FILTER_F = '(udp.DstPort>=10011 and udp.DstPort<=10020) and udp.PayloadLength>= 55 && udp.PayloadLength<=300'

tele_mode = False
freeze_mode = False
ghost_mode = False

R_O = False
R_I = False
R_F = False

packet_tele = []
packet_freeze = []
packet_ghost = []

state_lock = threading.Lock()

# === DIVERT WORKER ENGINE CHUẨN 100% TELEKILL.PY ===
def build_filter():
    return "udp and (udp.SrcPort != 53 and udp.DstPort != 53) and (udp.SrcPort != 7844 and udp.DstPort != 7844) and (udp.SrcPort < 51820 or udp.SrcPort > 51835) and (udp.DstPort < 51820 or udp.DstPort > 51835) and (udp.SrcPort < 3478 or udp.SrcPort > 3485) and (udp.DstPort < 3478 or udp.DstPort > 3485) and (udp.PayloadLength > 20)"

def divert_worker_layer(stop_ev, layer_val):
    filter_str = build_filter()
    if filter_str == "false": return
    try:
        w_h = pydivert.WinDivert(filter_str, layer=layer_val)
        with handles_lock:
            w_handles.append(w_h)
            w_handles_by_layer[layer_val] = w_h
        w_h.open()
        
        protected_ports = {53, 7844}
        
        while not stop_ev.is_set():
            try:
                packet = w_h.recv()
                if packet is None: continue
                
                src_p = getattr(packet, 'src_port', 0)
                dst_p = getattr(packet, 'dst_port', 0)
                if (51820 <= src_p <= 51835) or (51820 <= dst_p <= 51835) or (3478 <= src_p <= 3485) or (3478 <= dst_p <= 3485) or src_p in protected_ports or dst_p in protected_ports:
                    w_h.send(packet)
                    continue

                payload_len = len(packet.payload) if packet.payload else 0
                if payload_len > 20:
                    src_ip = str(packet.src_addr)
                    dst_ip = str(packet.dst_addr)
                    
                    drop_this = False
                    with clients_lock:
                        for client in clients:
                            act_tele = bool(client.tele_active)
                            act_freeze = bool(client.freeze_active)
                            act_ghost = bool(client.ghost_active)

                            is_tele_flushing = getattr(client, 'tele_flushing', False)
                            if not act_tele and not act_freeze and not act_ghost and not is_tele_flushing:
                                continue
                            
                            is_target = False
                            if client.client_ip:
                                if src_ip == client.client_ip or dst_ip == client.client_ip:
                                    is_target = True
                            else:
                                if (10010 <= src_p <= 10020) or (10010 <= dst_p <= 10020):
                                    is_target = True

                            if is_target:
                                if is_tele_flushing:
                                    # Trong lúc xả túi tin TeleKill, hủy bỏ các gói tin di chuyển vị trí mới để tránh bị giật lùi (scrollback)
                                    if (10010 <= dst_p <= 10020) and payload_len >= 43:
                                        drop_this = True
                                        break
                                    continue

                                matched = False
                                if act_tele and (10010 <= dst_p <= 10020) and payload_len >= 43:
                                    if len(client.tele_buffer) < 3000:
                                        pkt_copy = pydivert.Packet(packet.raw, packet.interface, packet.direction)
                                        client.tele_buffer.append((pkt_copy, layer_val))
                                    matched = True
                                elif act_ghost and (10010 <= dst_p <= 10020) and (55 <= payload_len <= 300):
                                    if len(client.ghost_buffer) < 3000:
                                        pkt_copy = pydivert.Packet(packet.raw, packet.interface, packet.direction)
                                        client.ghost_buffer.append((pkt_copy, layer_val))
                                    matched = True

                                if act_freeze and (10011 <= src_p <= 10019) and (30 <= payload_len <= 1079):
                                    if len(client.freeze_buffer) < 3000:
                                        pkt_copy = pydivert.Packet(packet.raw, packet.interface, packet.direction)
                                        client.freeze_buffer.append((pkt_copy, layer_val))
                                    matched = True

                                if matched:
                                    client.dropped_count += 1
                                    dropped_count[0] += 1
                                    drop_this = True
                                    break

                    if drop_this: continue
                
                w_h.send(packet)
            except Exception:
                time.sleep(0.001)
                continue
        with handles_lock:
            try: w_h.close()
            except: pass
            if w_h in w_handles: w_handles.remove(w_h)
    except Exception as e:
        print(f"[WinDivert Error Layer {layer_val}] {e}", flush=True)
        write_log(f"WinDivert Error Layer {layer_val}: {e}")

def stop_engine():
    global stop_event, divert_threads, w_handles, w_handles_by_layer
    stop_event.set()
    with handles_lock:
        for h in w_handles:
            try: h.close()
            except: pass
        w_handles.clear()
        w_handles_by_layer.clear()

def start_engine():
    global divert_threads, stop_event, w_handles
    stop_engine()
    stop_event.clear()
    divert_threads = []
    for layer in [0, 1]:
        t = threading.Thread(target=divert_worker_layer, args=(stop_event, layer), daemon=True)
        t.start()
        divert_threads.append(t)

class VectorIconWidget(QWidget):
    def __init__(self, icon_type="radar", color="#a0a0a0", active_color="#00aaff", size=20, parent=None):
        super().__init__(parent)
        self.icon_type = icon_type
        self.color = QColor(color)
        self.active_color = QColor(active_color)
        self.is_active = False
        self.setFixedSize(size, size)

    def setActive(self, active):
        self.is_active = active
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        pen_color = self.active_color if self.is_active else self.color
        pen = QPen(pen_color, 2, Qt.SolidLine, Qt.RoundCap, Qt.RoundJoin)
        painter.setPen(pen)
        painter.setBrush(Qt.NoBrush)
        w, h = self.width(), self.height()
        cx, cy = w / 2.0, h / 2.0

        if self.icon_type == "radar":
            painter.drawEllipse(int(cx - 3), int(cy + 3), 6, 6)
            painter.drawArc(int(cx - 7), int(cy - 4), 14, 14, 30 * 16, 120 * 16)
            painter.drawArc(int(cx - 11), int(cy - 8), 22, 22, 30 * 16, 120 * 16)
        elif self.icon_type == "user":
            painter.drawEllipse(int(cx - 4), int(cy - 7), 8, 8)
            path = QPainterPath()
            path.moveTo(cx - 7, cy + 6)
            path.quadTo(cx, cy, cx + 7, cy + 6)
            painter.drawPath(path)
        elif self.icon_type == "eye":
            path = QPainterPath()
            path.moveTo(cx - 9, cy)
            path.quadTo(cx, cy - 6, cx + 9, cy)
            path.quadTo(cx, cy + 6, cx - 9, cy)
            painter.drawPath(path)
            painter.drawEllipse(int(cx - 3), int(cy - 3), 6, 6)
        elif self.icon_type == "settings":
            painter.drawEllipse(int(cx - 4), int(cy - 4), 8, 8)
            for angle in range(0, 360, 60):
                rad = math.radians(angle)
                x1 = cx + 6.5 * math.cos(rad)
                y1 = cy + 6.5 * math.sin(rad)
                x2 = cx + 9.0 * math.cos(rad)
                y2 = cy + 9.0 * math.sin(rad)
                painter.drawLine(int(x1), int(y1), int(x2), int(y2))
        elif self.icon_type == "power":
            painter.drawArc(int(cx - 7), int(cy - 7), 14, 14, 50 * 16, 260 * 16)
            painter.drawLine(int(cx), int(cy - 8), int(cx), int(cy - 1))

class ToggleSwitch(QCheckBox):
    def __init__(self, parent=None, callback=None, active_color="#00ffd2"):
        super().__init__(parent)
        self.setFixedSize(54, 26)
        self.setCursor(Qt.PointingHandCursor)
        self.callback = callback
        self.active_color_str = active_color
        
        self._knob_x = 3.0
        self._bg_color = QColor("#1e293b")
        
        self.anim_pos = QPropertyAnimation(self, b"knob_x")
        self.anim_pos.setDuration(220)
        self.anim_pos.setEasingCurve(QEasingCurve.OutBack)

        self.anim_col = QPropertyAnimation(self, b"bg_color")
        self.anim_col.setDuration(220)
        self.anim_col.setEasingCurve(QEasingCurve.OutCubic)

    @pyqtProperty(float)
    def knob_x(self):
        return self._knob_x

    @knob_x.setter
    def knob_x(self, pos):
        self._knob_x = pos
        self.update()

    @pyqtProperty(QColor)
    def bg_color(self):
        return self._bg_color

    @bg_color.setter
    def bg_color(self, color):
        self._bg_color = color
        self.update()

    def setChecked(self, checked):
        super().setChecked(checked)
        self._knob_x = 31.0 if checked else 3.0
        self._bg_color = QColor(self.active_color_str) if checked else QColor("#1e293b")
        self.update()

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            new_state = not self.isChecked()
            self.setChecked(new_state)
            
            # Position Spring Animation
            self.anim_pos.stop()
            self.anim_pos.setStartValue(self._knob_x)
            self.anim_pos.setEndValue(31.0 if new_state else 3.0)
            self.anim_pos.start()

            # Smooth Color Transition Animation
            self.anim_col.stop()
            self.anim_col.setStartValue(self._bg_color)
            self.anim_col.setEndValue(QColor(self.active_color_str) if new_state else QColor("#1e293b"))
            self.anim_col.start()

            if self.callback:
                self.callback(new_state)

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)

        # Draw Background Capsule
        painter.setBrush(QBrush(self._bg_color))
        if self.isChecked():
            painter.setPen(QPen(QColor(self.active_color_str).lighter(130), 1.5))
        else:
            painter.setPen(QPen(QColor("#334155"), 1.0))
        painter.drawRoundedRect(0, 0, self.width(), self.height(), 13, 13)

        # Draw Knob Circle with Inner Shadow & Glow
        knob_color = QColor("#0f172a") if self.isChecked() else QColor("#94a3b8")
        painter.setBrush(QBrush(knob_color))
        painter.setPen(Qt.NoPen)
        painter.drawEllipse(int(self._knob_x), 3, 20, 20)

class ClientRowWidget(QFrame):
    def __init__(self, client_obj, parent=None):
        super().__init__(parent)
        self.client = client_obj
        self.setFixedHeight(64)
        self.setStyleSheet("""
            QFrame {
                background: rgba(255, 255, 255, 0.03);
                border: 1px solid rgba(255, 255, 255, 0.08);
                border-radius: 12px;
            }
            QFrame:hover {
                background: rgba(255, 255, 255, 0.06);
                border: 1px solid rgba(0, 255, 210, 0.2);
            }
        """)
        self.init_ui()

    def init_ui(self):
        layout = QHBoxLayout(self)
        layout.setContentsMargins(14, 8, 14, 8)
        layout.setSpacing(10)

        info_layout = QVBoxLayout()
        info_layout.setSpacing(2)
        
        self.name_lbl = QLabel(f"📱 Thiết bị {self.client.index} (Chờ kết nối...)", self)
        self.name_lbl.setStyleSheet("color: #ffffff; font-size: 12px; font-weight: bold; border: none;")
        info_layout.addWidget(self.name_lbl)

        self.stats_lbl = QLabel("PKT: 0  |  DROP: 0", self)
        self.stats_lbl.setStyleSheet("color: #8c8884; font-size: 10px; font-family: 'Consolas'; border: none;")
        info_layout.addWidget(self.stats_lbl)
        
        layout.addLayout(info_layout, 1)

        # 3 CÔNG TẮC TOGGLE HIỂN THỊ REALTIME CHO 3 CHỨC NĂNG
        toggles_box = QHBoxLayout()
        toggles_box.setSpacing(8)

        # 1. TeleKill Toggle
        tele_box = QVBoxLayout()
        tele_box.setSpacing(2)
        tele_lbl = QLabel("⚡ Tele", self)
        tele_lbl.setStyleSheet("color: #ff4500; font-size: 10px; font-weight: bold; border: none;")
        tele_lbl.setAlignment(Qt.AlignCenter)
        self.switch_tele = ToggleSwitch(self, callback=self.on_toggle_tele, active_color="#ff4500")
        tele_box.addWidget(tele_lbl)
        tele_box.addWidget(self.switch_tele, 0, Qt.AlignCenter)
        toggles_box.addLayout(tele_box)

        # 2. Freeze Toggle
        freeze_box = QVBoxLayout()
        freeze_box.setSpacing(2)
        freeze_lbl = QLabel("🧊 Freeze", self)
        freeze_lbl.setStyleSheet("color: #00aaff; font-size: 10px; font-weight: bold; border: none;")
        freeze_lbl.setAlignment(Qt.AlignCenter)
        self.switch_freeze = ToggleSwitch(self, callback=self.on_toggle_freeze, active_color="#00aaff")
        freeze_box.addWidget(freeze_lbl)
        freeze_box.addWidget(self.switch_freeze, 0, Qt.AlignCenter)
        toggles_box.addLayout(freeze_box)

        # 3. Ghost Toggle
        ghost_box = QVBoxLayout()
        ghost_box.setSpacing(2)
        ghost_lbl = QLabel("👻 Ghost", self)
        ghost_lbl.setStyleSheet("color: #c084fc; font-size: 10px; font-weight: bold; border: none;")
        ghost_lbl.setAlignment(Qt.AlignCenter)
        self.switch_ghost = ToggleSwitch(self, callback=self.on_toggle_ghost, active_color="#c084fc")
        ghost_box.addWidget(ghost_lbl)
        ghost_box.addWidget(self.switch_ghost, 0, Qt.AlignCenter)
        toggles_box.addLayout(ghost_box)

        layout.addLayout(toggles_box)

        self.qr_btn = QPushButton("📱 QR", self)
        self.qr_btn.setFixedSize(50, 26)
        self.qr_btn.setCursor(Qt.PointingHandCursor)
        self.qr_btn.setStyleSheet("""
            QPushButton {
                background: rgba(0, 255, 210, 0.1);
                color: #00ffd2;
                border: 1px solid rgba(0, 255, 210, 0.3);
                border-radius: 6px;
                font-size: 10px;
                font-weight: bold;
            }
            QPushButton:hover {
                background: rgba(0, 255, 210, 0.25);
                color: #ffffff;
            }
        """)
        self.qr_btn.clicked.connect(self.show_qr_code)
        layout.addWidget(self.qr_btn)

    def on_toggle_tele(self, checked):
        with clients_lock:
            c = self.client
            c.tele_active = checked
            if checked:
                c.tele_buffer.clear()
                c.flushing = False
                beep_async(880, 100)
            else:
                flush_tele_buffer(c)
                beep_async(440, 100)
            
            if c.tele_active: c.lag_mode = "tele"
            elif c.freeze_active: c.lag_mode = "freeze"
            elif c.ghost_active: c.lag_mode = "ghost_lag"
            else: c.lag_mode = ""

            c.fake_lag_active = c.tele_active or c.freeze_active or c.ghost_active
        self.update_all_toggles_realtime()

    def on_toggle_freeze(self, checked):
        with clients_lock:
            c = self.client
            c.freeze_active = checked
            if checked:
                c.freeze_buffer.clear()
                c.flushing = False
                beep_async(880, 100)
            else:
                flush_freeze_buffer(c)
                beep_async(440, 100)
            
            if c.tele_active: c.lag_mode = "tele"
            elif c.freeze_active: c.lag_mode = "freeze"
            elif c.ghost_active: c.lag_mode = "ghost_lag"
            else: c.lag_mode = ""

            c.fake_lag_active = c.tele_active or c.freeze_active or c.ghost_active
        self.update_all_toggles_realtime()

    def on_toggle_ghost(self, checked):
        with clients_lock:
            c = self.client
            c.ghost_active = checked
            if checked:
                c.ghost_buffer.clear()
                c.flushing = False
                beep_async(880, 100)
            else:
                flush_ghost_buffer(c)
                beep_async(440, 100)
            
            if c.tele_active: c.lag_mode = "tele"
            elif c.freeze_active: c.lag_mode = "freeze"
            elif c.ghost_active: c.lag_mode = "ghost_lag"
            else: c.lag_mode = ""

            c.fake_lag_active = c.tele_active or c.freeze_active or c.ghost_active
        self.update_all_toggles_realtime()

    def update_all_toggles_realtime(self):
        with clients_lock:
            c = self.client
            is_tele = bool(c.tele_active)
            is_freeze = bool(c.freeze_active)
            is_ghost = bool(c.ghost_active)

        if self.switch_tele.isChecked() != is_tele:
            self.switch_tele.blockSignals(True)
            self.switch_tele.setChecked(is_tele)
            self.switch_tele.blockSignals(False)
        if self.switch_freeze.isChecked() != is_freeze:
            self.switch_freeze.blockSignals(True)
            self.switch_freeze.setChecked(is_freeze)
            self.switch_freeze.blockSignals(False)
        if self.switch_ghost.isChecked() != is_ghost:
            self.switch_ghost.blockSignals(True)
            self.switch_ghost.setChecked(is_ghost)
            self.switch_ghost.blockSignals(False)

    def show_qr_code(self):
        global cloudflare_tunnel_url
        if cloudflare_tunnel_url and str(cloudflare_tunnel_url).startswith("http"):
            worker_base = cloudflare_tunnel_url.rstrip("/")
        else:
            local_ip = get_local_ip()
            worker_base = f"http://{local_ip}:{http_server_port}"
        
        link_tele = f"{worker_base}/tele"
        link_freeze = f"{worker_base}/freeze"
        link_ghost = f"{worker_base}/ghost"
        link_switch = f"{worker_base}/switch"
        link_on = f"{worker_base}/on"
        link_off = f"{worker_base}/off"
        
        dialog = QDialog(self)
        dialog.setWindowTitle(f"Link Phím Tắt Remote - Thiết Bị {self.client.index}")
        dialog.setFixedSize(380, 520)
        dialog.setStyleSheet("background: #080c14; color: white;")
        
        d_layout = QVBoxLayout(dialog)
        d_layout.setContentsMargins(16, 16, 16, 16)
        d_layout.setSpacing(6)
        
        title = QLabel(f"⚡ LINK PHÍM TẮT ĐIỀU KHIỂN THIẾT BỊ {self.client.index}", dialog)
        title.setStyleSheet("color: #00ffd2; font-weight: bold; font-size: 12px;")
        title.setAlignment(Qt.AlignCenter)
        d_layout.addWidget(title)
        
        qr_lbl = QLabel(dialog)
        qr_lbl.setAlignment(Qt.AlignCenter)
        qr_pix = generate_qr_pixmap(link_tele)
        qr_lbl.setPixmap(qr_pix.scaled(110, 110, Qt.KeepAspectRatio, Qt.SmoothTransformation))
        d_layout.addWidget(qr_lbl)
        
        # 1. Copy TeleKill
        copy_tele_btn = QPushButton("⚡ Copy Link CHUYỂN TeleKill", dialog)
        copy_tele_btn.setStyleSheet("""
            QPushButton { background: rgba(255, 69, 0, 0.2); color: #ff4500; font-weight: bold; border: 1px solid #ff4500; border-radius: 5px; padding: 5px; font-size: 10px; }
            QPushButton:hover { background: #ff4500; color: #ffffff; }
        """)
        def do_copy_tele():
            cb = QApplication.clipboard()
            cb.setText(link_tele)
            QMessageBox.information(dialog, "Thành công", f"Đã copy Link CHUYỂN sang TeleKill:\n{link_tele}")
        copy_tele_btn.clicked.connect(do_copy_tele)
        d_layout.addWidget(copy_tele_btn)

        # 2. Copy Freeze
        copy_freeze_btn = QPushButton("🧊 Copy Link CHUYỂN Freeze (Địch Đơ)", dialog)
        copy_freeze_btn.setStyleSheet("""
            QPushButton { background: rgba(0, 170, 255, 0.2); color: #00aaff; font-weight: bold; border: 1px solid #00aaff; border-radius: 5px; padding: 5px; font-size: 10px; }
            QPushButton:hover { background: #00aaff; color: #ffffff; }
        """)
        def do_copy_freeze():
            cb = QApplication.clipboard()
            cb.setText(link_freeze)
            QMessageBox.information(dialog, "Thành công", f"Đã copy Link CHUYỂN sang Freeze:\n{link_freeze}")
        copy_freeze_btn.clicked.connect(do_copy_freeze)
        d_layout.addWidget(copy_freeze_btn)

        # 3. Copy Ghost Lag
        copy_ghost_btn = QPushButton("👻 Copy Link CHUYỂN Ghost Lag", dialog)
        copy_ghost_btn.setStyleSheet("""
            QPushButton { background: rgba(147, 51, 234, 0.2); color: #c084fc; font-weight: bold; border: 1px solid #c084fc; border-radius: 5px; padding: 5px; font-size: 10px; }
            QPushButton:hover { background: #c084fc; color: #ffffff; }
        """)
        def do_copy_ghost():
            cb = QApplication.clipboard()
            cb.setText(link_ghost)
            QMessageBox.information(dialog, "Thành công", f"Đã copy Link CHUYỂN sang Ghost Lag:\n{link_ghost}")
        copy_ghost_btn.clicked.connect(do_copy_ghost)
        d_layout.addWidget(copy_ghost_btn)

        # 4. Copy Xoay Vòng Chế Độ
        copy_switch_btn = QPushButton("🔄 Copy Link XOAY VÒNG CHẾ ĐỘ (Tele->Freeze->Ghost)", dialog)
        copy_switch_btn.setStyleSheet("""
            QPushButton { background: rgba(255, 183, 3, 0.2); color: #ffb703; font-weight: bold; border: 1px solid #ffb703; border-radius: 5px; padding: 5px; font-size: 10px; }
            QPushButton:hover { background: #ffb703; color: #080c14; }
        """)
        def do_copy_switch():
            cb = QApplication.clipboard()
            cb.setText(link_switch)
            QMessageBox.information(dialog, "Thành công", f"Đã copy Link XOAY VÒNG CHẾ ĐỘ:\n{link_switch}")
        copy_switch_btn.clicked.connect(do_copy_switch)
        d_layout.addWidget(copy_switch_btn)

        # 5. Copy BẬT / TẮT
        btn_box = QHBoxLayout()
        copy_on_btn = QPushButton("🟢 Link BẬT (ON)", dialog)
        copy_on_btn.setStyleSheet("""
            QPushButton { background: rgba(0, 230, 118, 0.2); color: #00e676; font-weight: bold; border: 1px solid #00e676; border-radius: 5px; padding: 5px; font-size: 10px; }
            QPushButton:hover { background: #00e676; color: #080c14; }
        """)
        def do_copy_on():
            cb = QApplication.clipboard()
            cb.setText(link_on)
            QMessageBox.information(dialog, "Thành công", f"Đã copy Link BẬT Fake Lag:\n{link_on}")
        copy_on_btn.clicked.connect(do_copy_on)
        btn_box.addWidget(copy_on_btn)

        copy_off_btn = QPushButton("🔴 Link TẮT (OFF)", dialog)
        copy_off_btn.setStyleSheet("""
            QPushButton { background: rgba(255, 68, 68, 0.2); color: #ff4444; font-weight: bold; border: 1px solid #ff4444; border-radius: 5px; padding: 5px; font-size: 10px; }
            QPushButton:hover { background: #ff4444; color: white; }
        """)
        def do_copy_off():
            cb = QApplication.clipboard()
            cb.setText(link_off)
            QMessageBox.information(dialog, "Thành công", f"Đã copy Link TẮT Fake Lag (Xả gói):\n{link_off}")
        copy_off_btn.clicked.connect(do_copy_off)
        btn_box.addWidget(copy_off_btn)
        
        d_layout.addLayout(btn_box)
        dialog.exec_()

    def update_stats(self):
        self.update_all_toggles_realtime()
        with clients_lock:
            self.stats_lbl.setText(f"PKT: {self.client.packet_count}  |  DROP: {self.client.dropped_count}")
            idx = self.client.index
            ip = self.client.client_ip
            if ip:
                self.name_lbl.setText(f"📱 Thiết bị {idx} ({ip})")
            else:
                self.name_lbl.setText(f"📱 Thiết bị {idx} (Chờ kết nối...)")

def get_system_hwid():
    try:
        cmd = "wmic csproduct get uuid"
        output = subprocess.check_output(cmd, shell=True).decode().split('\n')
        for line in output:
            line = line.strip()
            if line and line != "UUID":
                return line
    except Exception:
        pass
    return socket.gethostname()

key_expiry_timestamp = 0
key_is_permanent = False

def get_formatted_key_time():
    global key_expiry_timestamp, key_is_permanent
    if key_is_permanent or key_expiry_timestamp >= 3000000000:
        return "Vĩnh Viễn"
    if key_expiry_timestamp <= 0:
        return "--:--:--"
    
    now_sec = int(time.time())
    rem_sec = key_expiry_timestamp - now_sec
    if rem_sec <= 0:
        return "Đã Hết Hạn"
    
    hours = rem_sec // 3600
    minutes = (rem_sec % 3600) // 60
    seconds = rem_sec % 60
    return f"{hours}:{minutes:02d}:{seconds:02d}"

def verify_license_key(key_str):
    global current_key, key_expiry_timestamp, key_is_permanent
    key_str = str(key_str).strip()
    if not key_str:
        return False, "⚠️ Vui lòng nhập mã Key bản quyền!"
    try:
        url = f"https://htgh-cbfa3-default-rtdb.firebaseio.com/keys/{urllib.parse.quote(key_str)}.json"
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=5, context=ssl_context) as response:
            data_raw = response.read().decode('utf-8')
            if not data_raw or data_raw == 'null':
                return False, "❌ Mã Key không tồn tại trên hệ thống HOANGHA VIP!"
            data = json.loads(data_raw)
            
            now_sec = int(time.time())
            expiry_sec = int(data.get('expiry', 0))
            if expiry_sec > 9999999999:
                expiry_sec = expiry_sec // 1000
                
            is_permanent = (expiry_sec >= 3000000000) or data.get('permanent') or data.get('is_permanent') or data.get('type') == 'lifetime'
            if not is_permanent and expiry_sec > 0 and now_sec > expiry_sec:
                return False, "❌ Mã Key đã hết hạn sử dụng! Vui lòng gia hạn thêm."
                
            local_hwid = get_system_hwid()
            saved_hwid = str(data.get('hwid', '')).strip()
            if not saved_hwid or saved_hwid == '':
                try:
                    update_url = f"https://htgh-cbfa3-default-rtdb.firebaseio.com/keys/{urllib.parse.quote(key_str)}/hwid.json"
                    req_patch = urllib.request.Request(update_url, data=json.dumps(local_hwid).encode('utf-8'), headers={'Content-Type': 'application/json'}, method='PUT')
                    urllib.request.urlopen(req_patch, timeout=5, context=ssl_context)
                except Exception:
                    pass
            elif saved_hwid != local_hwid:
                return False, f"⚠️ Key đã kích hoạt trên thiết bị khác ({saved_hwid[:8]}...)."
                
            current_key = key_str
            key_expiry_timestamp = expiry_sec
            key_is_permanent = is_permanent
            return True, "✅ Kích hoạt bản quyền thành công!"
    except Exception as e:
        print("[Key Verification Exception]", e)
        return False, "❌ Không thể kết nối máy chủ xác thực Key! Vui lòng kiểm tra kết nối mạng."

class KeyAuthWindow(QDialog):
    def __init__(self):
        super().__init__()
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Dialog)
        self.setFixedSize(420, 260)
        self.drag_position = None
        self.init_ui()
        self.center_on_screen()
        self.load_saved_key()

    def showEvent(self, event):
        super().showEvent(event)
        if is_stream_mode_active:
            apply_stream_mode_global(True)

    def center_on_screen(self):
        try:
            screen = QApplication.primaryScreen().geometry()
            self.move((screen.width() - 420) // 2, (screen.height() - 260) // 2)
        except Exception:
            pass

    def init_ui(self):
        self.setFixedSize(450, 310)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.panel = QFrame(self)
        self.panel.setStyleSheet("""
            QFrame {
                background: #090d16;
                border: 1.5px solid rgba(0, 242, 254, 0.35);
                border-radius: 14px;
            }
        """)

        # Particles Overlay behind text
        self.particles = ParticleCanvas(self.panel)
        self.particles.resize(450, 310)

        p_layout = QVBoxLayout(self.panel)
        p_layout.setContentsMargins(18, 14, 18, 14)
        p_layout.setSpacing(8)

        # Header Title with Encrypted RAM Logo (C++ VIP Loader Style)
        title_box = QHBoxLayout()
        logo_lbl = QLabel(self.panel)
        logo_pix = get_app_logo_pixmap()
        if not logo_pix.isNull():
            logo_lbl.setPixmap(logo_pix.scaled(26, 26, Qt.KeepAspectRatio, Qt.SmoothTransformation))
            logo_lbl.setStyleSheet("border: none;")
            title_box.addWidget(logo_lbl)
        else:
            dot_lbl = QLabel("⚡", self.panel)
            dot_lbl.setStyleSheet("font-size: 14px; color: #00f2fe; border: none;")
            title_box.addWidget(dot_lbl)

        title_lbl = QLabel("NETWORKING HOTSPOT // VIP AUTH CORE v4.0", self.panel)
        title_lbl.setStyleSheet("color: #00f2fe; font-family: 'Consolas', 'Segoe UI'; font-size: 11px; font-weight: bold; letter-spacing: 1px; border: none;")
        title_box.addWidget(title_lbl)
        title_box.addStretch()

        close_btn = QPushButton("✕", self.panel)
        close_btn.setFixedSize(20, 20)
        close_btn.setCursor(Qt.PointingHandCursor)
        close_btn.setStyleSheet("""
            QPushButton { background: transparent; color: #64748b; font-weight: bold; border: none; font-size: 12px; }
            QPushButton:hover { color: #ff4444; }
        """)
        close_btn.clicked.connect(self.reject)
        title_box.addWidget(close_btn)
        p_layout.addLayout(title_box)

        # HWID Display Card with Quick Copy Button
        hwid_box = QHBoxLayout()
        hwid_val = get_system_hwid()
        hwid_display = f"HWID: {hwid_val[:16]}..." if len(hwid_val) > 16 else f"HWID: {hwid_val}"
        
        lbl_hwid = QLabel(hwid_display, self.panel)
        lbl_hwid.setStyleSheet("""
            color: #94a3b8;
            font-family: 'Consolas', monospace;
            font-size: 10px;
            font-weight: bold;
            background: rgba(15, 23, 42, 0.8);
            border: 1px solid rgba(59, 130, 246, 0.25);
            border-radius: 6px;
            padding: 4px 8px;
        """)
        hwid_box.addWidget(lbl_hwid, 1)

        btn_copy_hwid = QPushButton("📋 Copy", self.panel)
        btn_copy_hwid.setCursor(Qt.PointingHandCursor)
        btn_copy_hwid.setFixedSize(55, 24)
        btn_copy_hwid.setStyleSheet("""
            QPushButton {
                background: rgba(59, 130, 246, 0.15);
                color: #60a5fa;
                font-family: 'Consolas', sans-serif;
                font-size: 10px;
                font-weight: bold;
                border: 1px solid rgba(59, 130, 246, 0.4);
                border-radius: 6px;
            }
            QPushButton:hover {
                background: #3b82f6;
                color: #ffffff;
            }
        """)
        btn_copy_hwid.clicked.connect(lambda: (QApplication.clipboard().setText(hwid_val), QMessageBox.information(self, "HWID", "Đã copy HWID vào Clipboard!")))
        hwid_box.addWidget(btn_copy_hwid)
        p_layout.addLayout(hwid_box)

        sub_lbl = QLabel("Nhập mã VIP License Key để mở khóa Networking Hotspot Engine:", self.panel)
        sub_lbl.setStyleSheet("color: #cbd5e1; font-family: 'Consolas', 'Segoe UI'; font-size: 10px; border: none;")
        sub_lbl.setWordWrap(True)
        p_layout.addWidget(sub_lbl)

        # Key Input Box (C# WPF/WinForms metallic input style)
        self.key_input = QLineEdit(self.panel)
        self.key_input.setPlaceholderText("Nhập mã License Key (NETWORKING-HOTSPOT-VIP)...")
        self.key_input.setStyleSheet("""
            QLineEdit {
                background: rgba(15, 23, 42, 0.95);
                border: 1.5px solid rgba(0, 242, 254, 0.4);
                border-radius: 8px;
                color: #00f2fe;
                font-family: 'Consolas', monospace;
                font-size: 12px;
                font-weight: bold;
                padding: 8px 12px;
            }
            QLineEdit:focus {
                border-color: #00f2fe;
                background: #0f172a;
            }
        """)
        self.key_input.returnPressed.connect(self.do_authenticate)
        p_layout.addWidget(self.key_input)

        # Status Label
        self.status_lbl = QLabel("🟢 CLOUD AUTH ENGINE: ONLINE [PROTECTED]", self.panel)
        self.status_lbl.setStyleSheet("color: #10b981; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: none;")
        self.status_lbl.setAlignment(Qt.AlignCenter)
        p_layout.addWidget(self.status_lbl)

        p_layout.addStretch()

        # Action Buttons
        btn_box = QHBoxLayout()
        btn_box.setSpacing(10)

        self.btn_auth = QPushButton("⚡ KÍCH HOẠT VIP LICENSE", self.panel)
        self.btn_auth.setCursor(Qt.PointingHandCursor)
        self.btn_auth.setFixedHeight(34)
        self.btn_auth.setStyleSheet("""
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 rgba(0, 242, 254, 0.25), stop:1 rgba(59, 130, 246, 0.25));
                color: #00f2fe;
                font-family: 'Consolas', 'Segoe UI';
                font-size: 11px;
                font-weight: bold;
                border: 1.5px solid rgba(0, 242, 254, 0.5);
                border-radius: 8px;
                padding: 6px 12px;
            }
            QPushButton:hover {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #00f2fe, stop:1 #3b82f6);
                color: #08090d;
                border-color: #00f2fe;
            }
        """)
        self.btn_auth.clicked.connect(self.do_authenticate)
        btn_box.addWidget(self.btn_auth, 2)

        self.btn_lookup = QPushButton("🌐 Tra Cứu Key", self.panel)
        self.btn_lookup.setCursor(Qt.PointingHandCursor)
        self.btn_lookup.setFixedHeight(34)
        self.btn_lookup.setStyleSheet("""
            QPushButton {
                background: rgba(255, 255, 255, 0.05);
                color: #e2e8f0;
                font-family: 'Consolas', 'Segoe UI';
                font-size: 11px;
                font-weight: bold;
                border: 1px solid rgba(255, 255, 255, 0.2);
                border-radius: 8px;
                padding: 6px 12px;
            }
            QPushButton:hover {
                background: rgba(255, 255, 255, 0.15);
                color: #ffffff;
            }
        """)
        self.btn_lookup.clicked.connect(self.open_lookup_web)
        btn_box.addWidget(self.btn_lookup, 1)

        p_layout.addLayout(btn_box)
        layout.addWidget(self.panel)

    def get_lic_file_path(self):
        if getattr(sys, 'frozen', False):
            return os.path.join(os.path.dirname(sys.executable), "license.json")
        return get_asset_path("license.json")

    def load_saved_key(self):
        lic_file = self.get_lic_file_path()
        if not os.path.exists(lic_file):
            lic_file = get_asset_path("license.json")
        if os.path.exists(lic_file):
            try:
                with open(lic_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    saved_k = data.get("key", "").strip()
                    if saved_k:
                        self.key_input.setText(saved_k)
                        QTimer.singleShot(150, self.do_authenticate)
            except Exception:
                pass

    def save_key(self, key_str):
        lic_file = self.get_lic_file_path()
        try:
            with open(lic_file, "w", encoding="utf-8") as f:
                json.dump({"key": key_str}, f, ensure_ascii=False, indent=2)
        except Exception:
            pass

    def do_authenticate(self):
        k = self.key_input.text().strip()
        self.status_lbl.setText("⏳ Đang xác thực với máy chủ Firebase...")
        self.status_lbl.setStyleSheet("color: #ffb703; font-size: 11px; font-weight: bold;")
        QApplication.processEvents()

        ok, msg = verify_license_key(k)
        if ok:
            self.save_key(k)
            self.status_lbl.setText(msg)
            self.status_lbl.setStyleSheet("color: #00e676; font-size: 11px; font-weight: bold;")
            QTimer.singleShot(600, self.accept)
        else:
            self.status_lbl.setText(msg)
            self.status_lbl.setStyleSheet("color: #ff4444; font-size: 11px; font-weight: bold;")

    def open_lookup_web(self):
        import webbrowser
        webbrowser.open("https://hoanghamod.netlify.app/key_lookup.html")

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.drag_position = event.globalPos() - self.frameGeometry().topLeft()
            event.accept()

    def mouseMoveEvent(self, event):
        if event.buttons() == Qt.LeftButton and self.drag_position:
            self.move(event.globalPos() - self.drag_position)
            event.accept()

# === OVERLAY HUD WINDOW (2.PY VIBE) ===
class OverlayWindow(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowFlags(
            Qt.WindowStaysOnTopHint |
            Qt.FramelessWindowHint |
            Qt.Tool
        )
        self.setGeometry(120, 30, 300, 34)

        self._dragging = False
        self._drag_position = QPoint()

        self.setStyleSheet("""
            QWidget {
                background-color: rgba(9, 12, 20, 0.92);
                border: 1.5px solid rgba(0, 242, 254, 0.45);
                border-radius: 8px;
            }
        """)
        self.layout = QHBoxLayout(self)
        self.layout.setContentsMargins(6, 3, 6, 3)
        self.layout.setSpacing(6)

        self.tele_label = QLabel("⚡ Tele: OFF")
        self.freeze_label = QLabel("🧊 Freeze: OFF")
        self.ghost_label = QLabel("👻 Ghost: OFF")

        for label in [self.tele_label, self.freeze_label, self.ghost_label]:
            label.setAlignment(Qt.AlignCenter)
            self.layout.addWidget(label)

        self.update_status(False, False, False)

    def showEvent(self, event):
        super().showEvent(event)
        if is_stream_mode_active:
            apply_stream_mode_global(True)

    def update_status(self, tele_status, freeze_status, ghost_status):
        if tele_status:
            self.tele_label.setText("⚡ Tele: ON")
            self.tele_label.setStyleSheet("color: #ffffff; font-weight: bold; font-size: 11px; padding: 2px 6px; border: 1px solid #ff4500; border-radius: 4px; background: rgba(255, 69, 0, 0.45);")
        else:
            self.tele_label.setText("⚡ Tele: OFF")
            self.tele_label.setStyleSheet("color: #777777; font-weight: bold; font-size: 11px; padding: 2px 6px; border: 1px solid #333333; border-radius: 4px; background: rgba(0,0,0,0.3);")

        if freeze_status:
            self.freeze_label.setText("🧊 Freeze: ON")
            self.freeze_label.setStyleSheet("color: #ffffff; font-weight: bold; font-size: 11px; padding: 2px 6px; border: 1px solid #00aaff; border-radius: 4px; background: rgba(0, 170, 255, 0.45);")
        else:
            self.freeze_label.setText("🧊 Freeze: OFF")
            self.freeze_label.setStyleSheet("color: #777777; font-weight: bold; font-size: 11px; padding: 2px 6px; border: 1px solid #333333; border-radius: 4px; background: rgba(0,0,0,0.3);")

        if ghost_status:
            self.ghost_label.setText("👻 Ghost: ON")
            self.ghost_label.setStyleSheet("color: #ffffff; font-weight: bold; font-size: 11px; padding: 2px 6px; border: 1px solid #c084fc; border-radius: 4px; background: rgba(192, 132, 252, 0.45);")
        else:
            self.ghost_label.setText("👻 Ghost: OFF")
            self.ghost_label.setStyleSheet("color: #777777; font-weight: bold; font-size: 11px; padding: 2px 6px; border: 1px solid #333333; border-radius: 4px; background: rgba(0,0,0,0.3);")

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self._dragging = True
            self._drag_position = event.globalPos() - self.pos()
            event.accept()

    def mouseMoveEvent(self, event):
        if self._dragging:
            self.move(event.globalPos() - self._drag_position)
            event.accept()

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.LeftButton:
            self._dragging = False
            event.accept()

is_stream_mode_active = False

def apply_stream_mode_global(enable: bool):
    global is_stream_mode_active
    is_stream_mode_active = enable
    try:
        user32 = ctypes.windll.user32
        WDA_EXCLUDEFROMCAPTURE = 0x00000011
        WDA_MONITOR = 0x00000001
        WDA_NONE = 0x00000000
        affinity = WDA_EXCLUDEFROMCAPTURE if enable else WDA_NONE

        for w in QApplication.topLevelWidgets():
            try:
                hwnd = int(w.winId())
                if hwnd:
                    res = user32.SetWindowDisplayAffinity(hwnd, affinity)
                    if not res and enable:
                        user32.SetWindowDisplayAffinity(hwnd, WDA_MONITOR)
            except Exception:
                pass
    except Exception as e:
        write_log(f"StreamMode Global Error: {e}")

class HoangHaMenu(QWidget):
    def __init__(self, device_info=None):
        super().__init__()
        self.device_info = device_info or target_device_info
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.Window | Qt.WindowStaysOnTopHint)
        self.setFixedSize(720, 475)
        
        self.drag_position = None
        self.client_widgets = []
        self.is_collapsed = False
        self.stream_mode_active = False
        
        # 1. Overlay Window (HUD)
        self.overlay = OverlayWindow()
        self.overlay.show()

        # 2. System Tray Icon
        try:
            self.tray_icon = QSystemTrayIcon(self)
            icon_path = get_asset_path("hoangha_vip.ico")
            if os.path.exists(icon_path):
                self.tray_icon.setIcon(QIcon(icon_path))
            self.tray_icon.setToolTip("Networking Hotspot VIP Pro Core")
            tray_menu = QMenu()
            toggle_action = tray_menu.addAction("Hiện / Ẩn Menu")
            toggle_action.triggered.connect(self.toggle_visibility)
            overlay_action = tray_menu.addAction("Hiện / Ẩn Overlay HUD")
            overlay_action.triggered.connect(self.toggle_overlay)
            exit_action = tray_menu.addAction("Thoát Hoàn Toàn")
            exit_action.triggered.connect(self.close_window)
            self.tray_icon.setContextMenu(tray_menu)
            self.tray_icon.activated.connect(self.on_tray_icon_activated)
            self.tray_icon.show()
        except Exception:
            pass

        self.init_ui()
        
        self.stats_timer = QTimer(self)
        self.stats_timer.timeout.connect(self.update_stats)
        self.stats_timer.start(500)

        hotkey_bridge.toggle_e.connect(self.hotkey_toggle_fakelag)
        hotkey_bridge.toggle_tele.connect(lambda: self.toggle_mode_hotkey("tele"))
        hotkey_bridge.toggle_freeze.connect(lambda: self.toggle_mode_hotkey("freeze"))
        hotkey_bridge.toggle_ghost.connect(lambda: self.toggle_mode_hotkey("ghost_lag"))
        remote_bridge.fakelag_signal.connect(self.set_fakelag_remote)
        remote_bridge.toggle_signal.connect(self.hotkey_toggle_fakelag)
        remote_bridge.update_tunnel_url.connect(self.on_tunnel_url_updated)
        remote_bridge.divert_error.connect(self.on_divert_error)
        vis_bridge.toggle_visible.connect(self.set_window_visibility)

    def showEvent(self, event):
        super().showEvent(event)
        if getattr(self, 'stream_mode_active', False) or is_stream_mode_active:
            apply_stream_mode_global(True)

    def toggle_overlay(self):
        if hasattr(self, 'overlay'):
            if self.overlay.isVisible(): self.overlay.hide()
            else: self.overlay.show()

    def toggle_visibility(self):
        if self.isVisible():
            self.hide()
        else:
            self.showNormal()
            self.activateWindow()

    def on_tray_icon_activated(self, reason):
        if reason == QSystemTrayIcon.Trigger:
            self.toggle_visibility()

    def switch_menu_tab(self, index):
        if hasattr(self, 'main_stack'):
            self.main_stack.setCurrentIndex(index)
        if hasattr(self, 'tab_buttons'):
            for i, btn in enumerate(self.tab_buttons):
                if i == index:
                    btn.setStyleSheet("""
                        QPushButton {
                            background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 rgba(0, 242, 254, 0.25), stop:1 rgba(59, 130, 246, 0.25));
                            color: #00f2fe;
                            font-size: 16px;
                            border: 1.5px solid #00f2fe;
                            border-radius: 10px;
                        }
                    """)
                else:
                    btn.setStyleSheet("""
                        QPushButton {
                            background: transparent;
                            color: #64748b;
                            font-size: 16px;
                            border: 1px solid transparent;
                            border-radius: 10px;
                        }
                        QPushButton:hover {
                            color: #ffffff;
                            background: rgba(255, 255, 255, 0.08);
                            border-color: rgba(255, 255, 255, 0.15);
                        }
                    """)

    def init_ui(self):
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        
        self.panel = QFrame(self)
        self.panel.setObjectName("MainPanel")
        self.panel.setStyleSheet("""
            QFrame#MainPanel {
                background: #090c14;
                border: 1.5px solid rgba(0, 242, 254, 0.35);
                border-radius: 16px;
            }
            QLabel { font-family: 'Segoe UI', sans-serif; }
        """)

        # Particles Background Overlay
        self.particles = ParticleCanvas(self.panel)
        self.particles.resize(720, 475)
        
        outer_layout = QVBoxLayout(self.panel)
        outer_layout.setContentsMargins(14, 12, 14, 12)
        outer_layout.setSpacing(10)

        # === TOP TITLE BAR (VIP TITANIUM CYBER PANEL STYLE) ===
        top_title_bar = QHBoxLayout()
        top_title_bar.setContentsMargins(4, 2, 4, 2)
        top_title_bar.setSpacing(10)
        
        app_logo_lbl = QLabel(self.panel)
        logo_pix = get_app_logo_pixmap()
        if not logo_pix.isNull():
            pix = logo_pix.scaled(22, 22, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            app_logo_lbl.setPixmap(pix)
            app_logo_lbl.setStyleSheet("border: none;")
        else:
            app_logo_lbl.setText("⚡")
            app_logo_lbl.setStyleSheet("font-size: 15px; color: #00f2fe; border: none;")
        top_title_bar.addWidget(app_logo_lbl)

        app_name_lbl = QLabel("NETWORKING HOTSPOT // VIP C++ PRO CORE v4.5 [🛡️ PEB GUARD]", self.panel)
        app_name_lbl.setStyleSheet("color: #00f2fe; font-family: 'Consolas', 'Segoe UI', sans-serif; font-size: 11px; font-weight: bold; letter-spacing: 0.5px; border: none;")
        top_title_bar.addWidget(app_name_lbl)
        top_title_bar.addStretch()

        # Stream Proof Badge Button
        self.btn_stream_badge = QPushButton("🛡️ STREAM PROOF: OFF", self.panel)
        self.btn_stream_badge.setFixedSize(140, 24)
        self.btn_stream_badge.setCursor(Qt.PointingHandCursor)
        self.btn_stream_badge.setToolTip("Bật Chế Độ Tàng Hình (Ẩn 100% tất cả cửa sổ khỏi OBS, Discord, Quay Chụp Màn Hình)")
        self.btn_stream_badge.setStyleSheet("""
            QPushButton {
                background: rgba(255, 255, 255, 0.05);
                color: #94a3b8;
                font-family: 'Consolas', 'Segoe UI';
                font-size: 10px;
                font-weight: bold;
                border: 1px solid rgba(255, 255, 255, 0.15);
                border-radius: 6px;
                padding: 2px 6px;
            }
            QPushButton:hover {
                background: rgba(0, 242, 254, 0.15);
                color: #00f2fe;
                border-color: #00f2fe;
            }
        """)
        self.btn_stream_badge.clicked.connect(self.toggle_stream_mode_action)
        top_title_bar.addWidget(self.btn_stream_badge)

        # Collapse / Expand Button
        self.btn_collapse = QPushButton("➖ Mini Bar", self.panel)
        self.btn_collapse.setFixedSize(80, 24)
        self.btn_collapse.setCursor(Qt.PointingHandCursor)
        self.btn_collapse.setToolTip("Thu gọn Menu thành thanh Mini Bar gọn nhẹ trên màn hình")
        self.btn_collapse.setStyleSheet("""
            QPushButton {
                background: rgba(56, 189, 248, 0.15);
                color: #38bdf8;
                font-family: 'Segoe UI', 'Consolas';
                font-size: 10px;
                font-weight: bold;
                border: 1px solid rgba(56, 189, 248, 0.4);
                border-radius: 6px;
            }
            QPushButton:hover {
                background: #38bdf8;
                color: #08090d;
            }
        """)
        self.btn_collapse.clicked.connect(self.toggle_collapse_menu)
        top_title_bar.addWidget(self.btn_collapse)

        close_top_btn = QPushButton("✕", self.panel)
        close_top_btn.setFixedSize(24, 24)
        close_top_btn.setCursor(Qt.PointingHandCursor)
        close_top_btn.setStyleSheet("""
            QPushButton { background: transparent; color: #71717a; font-weight: bold; border: none; font-size: 13px; }
            QPushButton:hover { color: #ef4444; }
        """)
        close_top_btn.clicked.connect(self.close_window)
        top_title_bar.addWidget(close_top_btn)
        outer_layout.addLayout(top_title_bar)

        # === MAIN CONTENT ROW: SIDEBAR + STACKED PAGES ===
        self.body_container = QWidget(self.panel)
        body_layout = QHBoxLayout(self.body_container)
        body_layout.setContentsMargins(0, 0, 0, 0)
        body_layout.setSpacing(14)

        # 1. LEFT NAVIGATION SIDEBAR (4 Clean Tabs)
        sidebar = QFrame(self.panel)
        sidebar.setFixedWidth(56)
        sidebar.setStyleSheet("""
            background: rgba(14, 18, 28, 0.9);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 14px;
        """)
        sb_layout = QVBoxLayout(sidebar)
        sb_layout.setContentsMargins(6, 14, 6, 14)
        sb_layout.setSpacing(12)

        self.tab_buttons = []
        tab_icons = ["⚡", "⌨️", "⚙️", "👑"]
        tab_tooltips = ["Bảng Điều Khiển VIP", "Cấu Hình Phím Tắt", "Cài Đặt & Stream Proof", "Bản Quyền & HWID"]

        for idx, (ic_symbol, tooltip) in enumerate(zip(tab_icons, tab_tooltips)):
            btn = QPushButton(ic_symbol, sidebar)
            btn.setFixedSize(42, 42)
            btn.setToolTip(tooltip)
            btn.setCursor(Qt.PointingHandCursor)
            btn.clicked.connect(lambda _, i=idx: self.switch_menu_tab(i))
            sb_layout.addWidget(btn, 0, Qt.AlignCenter)
            self.tab_buttons.append(btn)

        sb_layout.addStretch()

        btn_power = QPushButton("⏻", sidebar)
        btn_power.setFixedSize(38, 38)
        btn_power.setToolTip("Đóng Ứng Dụng")
        btn_power.setCursor(Qt.PointingHandCursor)
        btn_power.setStyleSheet("""
            QPushButton { background: transparent; color: #64748b; font-size: 16px; border: none; }
            QPushButton:hover { color: #ef4444; }
        """)
        btn_power.clicked.connect(self.close_window)
        sb_layout.addWidget(btn_power, 0, Qt.AlignCenter)

        body_layout.addWidget(sidebar)

        # 2. RIGHT STACKED WIDGET FOR PAGES (4 Pages)
        self.main_stack = QStackedWidget(self.panel)

        # --- PAGE 0: Dashboard & VIP Functions ---
        page_status = QWidget()
        self.main_stack.addWidget(page_status)
        p_status_layout = QVBoxLayout(page_status)
        p_status_layout.setContentsMargins(10, 4, 10, 4)
        p_status_layout.setSpacing(10)

        # Header Title
        h0 = QHBoxLayout()
        dot0 = QLabel("🟢", page_status)
        dot0.setStyleSheet("font-size: 9px; border: none;")
        h0.addWidget(dot0)
        lbl_status_title = QLabel("BẢNG ĐIỀU KHIỂN TRUNG TÂM (CORE DASHBOARD)", page_status)
        lbl_status_title.setStyleSheet("color: #00f2fe; font-family: 'Consolas', 'Segoe UI'; font-size: 11px; font-weight: bold; border: none;")
        h0.addWidget(lbl_status_title)
        h0.addStretch()
        p_status_layout.addLayout(h0)

        # 3 Mini Telemetry Badges Row
        badge_box = QHBoxLayout()
        badge_box.setSpacing(8)

        self.telemetry_node = QLabel("📡 NODE: UDP 10010-10020 [ACTIVE]", page_status)
        self.telemetry_node.setStyleSheet("background: rgba(15, 23, 42, 0.85); color: #38bdf8; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: 1px solid rgba(56, 189, 248, 0.3); border-radius: 6px; padding: 6px 10px;")
        badge_box.addWidget(self.telemetry_node, 1)

        self.stats_lbl_ctrl = QLabel("📊 PING: 24 ms  |  FPS: 60", page_status)
        self.stats_lbl_ctrl.setStyleSheet("background: rgba(15, 23, 42, 0.85); color: #10b981; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 6px; padding: 6px 10px;")
        badge_box.addWidget(self.stats_lbl_ctrl, 1)

        self.telemetry_shield = QLabel("🛡️ SHIELD: PEB GUARD [READY]", page_status)
        self.telemetry_shield.setStyleSheet("background: rgba(15, 23, 42, 0.85); color: #a855f7; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: 1px solid rgba(168, 85, 247, 0.3); border-radius: 6px; padding: 6px 10px;")
        badge_box.addWidget(self.telemetry_shield, 1)

        p_status_layout.addLayout(badge_box)

        # 3 Main VIP Action Cards
        card_ctrl = QFrame(page_status)
        card_ctrl.setStyleSheet("""
            QFrame {
                background: rgba(14, 19, 32, 0.85);
                border: 1px solid rgba(255, 255, 255, 0.08);
                border-radius: 12px;
            }
            QLabel { border: none; }
        """)
        ctrl_layout = QVBoxLayout(card_ctrl)
        ctrl_layout.setContentsMargins(16, 12, 16, 12)
        ctrl_layout.setSpacing(10)

        # 1. Telekill Row Card
        r_tele = QHBoxLayout()
        r_tele.setSpacing(12)
        tele_info_box = QVBoxLayout()
        tele_info_box.setSpacing(2)
        self.lbl_tele_ctrl = QLabel("⚡ TELEKILL (Di Chuyển Tức Thời)", card_ctrl)
        self.lbl_tele_ctrl.setStyleSheet("color: #ff4500; font-family: 'Segoe UI'; font-size: 12px; font-weight: bold;")
        tele_sub = QLabel("Đóng băng tọa độ di chuyển, xả dồn tức thì khi tắt", card_ctrl)
        tele_sub.setStyleSheet("color: #64748b; font-size: 10px;")
        tele_info_box.addWidget(self.lbl_tele_ctrl)
        tele_info_box.addWidget(tele_sub)
        r_tele.addLayout(tele_info_box, 1)

        tag_tele_key = QLabel("[ Phím V ]", card_ctrl)
        tag_tele_key.setStyleSheet("color: #ff4500; background: rgba(255, 69, 0, 0.15); border: 1px solid rgba(255, 69, 0, 0.35); border-radius: 5px; font-family: 'Consolas'; font-size: 10px; font-weight: bold; padding: 3px 8px;")
        r_tele.addWidget(tag_tele_key)

        self.sw_tele = ToggleSwitch(card_ctrl, callback=lambda val: self.set_mode_via_switch("tele", val), active_color="#ff4500")
        r_tele.addWidget(self.sw_tele)
        
        btn_copy_tele = QPushButton("📋 Link", card_ctrl)
        self.style_action_button(btn_copy_tele)
        btn_copy_tele.clicked.connect(lambda: self.copy_single_link_action("tele"))
        r_tele.addWidget(btn_copy_tele)
        ctrl_layout.addLayout(r_tele)

        # Divider 1
        d1 = QFrame(card_ctrl)
        d1.setFrameShape(QFrame.HLine)
        d1.setStyleSheet("background: rgba(255, 255, 255, 0.05); max-height: 1px;")
        ctrl_layout.addWidget(d1)

        # 2. Freeze Row Card
        r_freeze = QHBoxLayout()
        r_freeze.setSpacing(12)
        freeze_info_box = QVBoxLayout()
        freeze_info_box.setSpacing(2)
        self.lbl_freeze_ctrl = QLabel("🧊 FREEZE TARGET (Địch Đơ Toàn Diện)", card_ctrl)
        self.lbl_freeze_ctrl.setStyleSheet("color: #00aaff; font-family: 'Segoe UI'; font-size: 12px; font-weight: bold;")
        freeze_sub = QLabel("Chặn gói tin từ máy chủ, cố định đối phương trên màn hình", card_ctrl)
        freeze_sub.setStyleSheet("color: #64748b; font-size: 10px;")
        freeze_info_box.addWidget(self.lbl_freeze_ctrl)
        freeze_info_box.addWidget(freeze_sub)
        r_freeze.addLayout(freeze_info_box, 1)

        tag_freeze_key = QLabel("[ Phím X ]", card_ctrl)
        tag_freeze_key.setStyleSheet("color: #00aaff; background: rgba(0, 170, 255, 0.15); border: 1px solid rgba(0, 170, 255, 0.35); border-radius: 5px; font-family: 'Consolas'; font-size: 10px; font-weight: bold; padding: 3px 8px;")
        r_freeze.addWidget(tag_freeze_key)

        self.sw_freeze = ToggleSwitch(card_ctrl, callback=lambda val: self.set_mode_via_switch("freeze", val), active_color="#00aaff")
        r_freeze.addWidget(self.sw_freeze)
        
        btn_copy_freeze = QPushButton("📋 Link", card_ctrl)
        self.style_action_button(btn_copy_freeze)
        btn_copy_freeze.clicked.connect(lambda: self.copy_single_link_action("freeze"))
        r_freeze.addWidget(btn_copy_freeze)
        ctrl_layout.addLayout(r_freeze)

        # Divider 2
        d2 = QFrame(card_ctrl)
        d2.setFrameShape(QFrame.HLine)
        d2.setStyleSheet("background: rgba(255, 255, 255, 0.05); max-height: 1px;")
        ctrl_layout.addWidget(d2)

        # 3. Ghost Row Card
        r_ghost = QHBoxLayout()
        r_ghost.setSpacing(12)
        ghost_info_box = QVBoxLayout()
        ghost_info_box.setSpacing(2)
        self.lbl_ghost_ctrl = QLabel("👻 GHOST LAG (Bóng Ma Ẩn Hiện)", card_ctrl)
        self.lbl_ghost_ctrl.setStyleSheet("color: #c084fc; font-family: 'Segoe UI'; font-size: 12px; font-weight: bold;")
        ghost_sub = QLabel("Lệch hitbox và vị trí nhân vật khỏi tầm ngắm của địch", card_ctrl)
        ghost_sub.setStyleSheet("color: #64748b; font-size: 10px;")
        ghost_info_box.addWidget(self.lbl_ghost_ctrl)
        ghost_info_box.addWidget(ghost_sub)
        r_ghost.addLayout(ghost_info_box, 1)

        tag_ghost_key = QLabel("[ Phím B ]", card_ctrl)
        tag_ghost_key.setStyleSheet("color: #c084fc; background: rgba(192, 132, 252, 0.15); border: 1px solid rgba(192, 132, 252, 0.35); border-radius: 5px; font-family: 'Consolas'; font-size: 10px; font-weight: bold; padding: 3px 8px;")
        r_ghost.addWidget(tag_ghost_key)

        self.sw_ghost = ToggleSwitch(card_ctrl, callback=lambda val: self.set_mode_via_switch("ghost", val), active_color="#c084fc")
        r_ghost.addWidget(self.sw_ghost)
        
        btn_copy_ghost = QPushButton("📋 Link", card_ctrl)
        self.style_action_button(btn_copy_ghost)
        btn_copy_ghost.clicked.connect(lambda: self.copy_single_link_action("ghost"))
        r_ghost.addWidget(btn_copy_ghost)
        ctrl_layout.addLayout(r_ghost)

        p_status_layout.addWidget(card_ctrl)

        # Footer Row (Traffic telemetry & Quick Remote Buttons)
        footer_box = QHBoxLayout()
        footer_box.setSpacing(10)
        
        self.pkt_lbl_ctrl = QLabel("📊 Tổng gói: 0  |  Đã chặn: 0", page_status)
        self.pkt_lbl_ctrl.setStyleSheet("color: #94a3b8; font-family: 'Consolas'; font-size: 10px; border: none;")
        footer_box.addWidget(self.pkt_lbl_ctrl)
        
        footer_box.addStretch()

        btn_qr_fast = QPushButton("📱 QR Code", page_status)
        self.style_action_button(btn_qr_fast, width=80)
        btn_qr_fast.clicked.connect(self.open_qr_window)
        footer_box.addWidget(btn_qr_fast)
        
        btn_copy_web = QPushButton("🌐 Copy Link Web Remote", page_status)
        self.style_action_button(btn_copy_web, width=150)
        btn_copy_web.clicked.connect(self.copy_web_remote_action)
        footer_box.addWidget(btn_copy_web)
        p_status_layout.addLayout(footer_box)

        # --- PAGE 1: Keybinds Configuration ---
        page_keybinds = QWidget()
        self.main_stack.addWidget(page_keybinds)
        p_keybinds_layout = QVBoxLayout(page_keybinds)
        p_keybinds_layout.setContentsMargins(10, 4, 10, 4)
        p_keybinds_layout.setSpacing(10)

        # Header Title
        h2 = QHBoxLayout()
        dot2 = QLabel("🟢", page_keybinds)
        dot2.setStyleSheet("font-size: 9px; border: none;")
        h2.addWidget(dot2)
        lbl_keybinds_title = QLabel("CẤU HÌNH PHÍM TẮT TRỰC TIẾP (HOTKEYS)", page_keybinds)
        lbl_keybinds_title.setStyleSheet("color: #00f2fe; font-family: 'Consolas', 'Segoe UI'; font-size: 11px; font-weight: bold; border: none;")
        h2.addWidget(lbl_keybinds_title)
        h2.addStretch()
        p_keybinds_layout.addLayout(h2)

        # Card Frame
        card_keys = QFrame(page_keybinds)
        card_keys.setStyleSheet("""
            QFrame {
                background: rgba(14, 19, 32, 0.85);
                border: 1px solid rgba(255, 255, 255, 0.08);
                border-radius: 12px;
            }
            QLabel { border: none; }
        """)
        keys_layout = QVBoxLayout(card_keys)
        keys_layout.setContentsMargins(18, 16, 18, 16)
        keys_layout.setSpacing(12)

        # Telekill rebind row
        r_tele_key = QHBoxLayout()
        lbl_tele_kb = QLabel("⚡ TELEKILL HOTKEY:", card_keys)
        lbl_tele_kb.setStyleSheet("color: #ff4500; font-family: 'Consolas'; font-size: 11px; font-weight: bold;")
        r_tele_key.addWidget(lbl_tele_kb)
        r_tele_key.addStretch()
        
        self.btn_tele_bind = QPushButton("V", card_keys)
        self.style_keybind_button(self.btn_tele_bind)
        self.btn_tele_bind.clicked.connect(lambda: self.start_rebind_action('tele'))
        r_tele_key.addWidget(self.btn_tele_bind)
        keys_layout.addLayout(r_tele_key)

        # Freeze rebind row
        r_freeze_key = QHBoxLayout()
        lbl_freeze_kb = QLabel("🧊 FREEZE HOTKEY:", card_keys)
        lbl_freeze_kb.setStyleSheet("color: #00aaff; font-family: 'Consolas'; font-size: 11px; font-weight: bold;")
        r_freeze_key.addWidget(lbl_freeze_kb)
        r_freeze_key.addStretch()
        
        self.btn_freeze_bind = QPushButton("X", card_keys)
        self.style_keybind_button(self.btn_freeze_bind)
        self.btn_freeze_bind.clicked.connect(lambda: self.start_rebind_action('freeze'))
        r_freeze_key.addWidget(self.btn_freeze_bind)
        keys_layout.addLayout(r_freeze_key)

        # Ghost rebind row
        r_ghost_key = QHBoxLayout()
        lbl_ghost_kb = QLabel("👻 GHOST HOTKEY:", card_keys)
        lbl_ghost_kb.setStyleSheet("color: #c084fc; font-family: 'Consolas'; font-size: 11px; font-weight: bold;")
        r_ghost_key.addWidget(lbl_ghost_kb)
        r_ghost_key.addStretch()
        
        self.btn_ghost_bind = QPushButton("B", card_keys)
        self.style_keybind_button(self.btn_ghost_bind)
        self.btn_ghost_bind.clicked.connect(lambda: self.start_rebind_action('ghost'))
        r_ghost_key.addWidget(self.btn_ghost_bind)
        keys_layout.addLayout(r_ghost_key)

        p_keybinds_layout.addWidget(card_keys)

        # Sound toggle row
        r_sound = QHBoxLayout()
        r_sound.addStretch()
        self.btn_sound_ctrl = QPushButton("🔊 Âm Thanh Báo Hiệu: ON", page_keybinds)
        self.btn_sound_ctrl.setCursor(Qt.PointingHandCursor)
        self.btn_sound_ctrl.setStyleSheet("""
            QPushButton {
                background: rgba(56, 189, 248, 0.12);
                color: #38bdf8;
                font-family: 'Consolas';
                font-size: 11px;
                font-weight: bold;
                border: 1px solid rgba(56, 189, 248, 0.35);
                border-radius: 6px;
                padding: 6px 16px;
            }
            QPushButton:hover {
                background: #38bdf8;
                color: #08090d;
            }
        """)
        self.btn_sound_ctrl.clicked.connect(self.toggle_sound_action)
        r_sound.addWidget(self.btn_sound_ctrl)
        p_keybinds_layout.addLayout(r_sound)
        p_keybinds_layout.addStretch()

        # --- PAGE 2: Settings & Stream Proof Anti-Capture ---
        page_settings = QWidget()
        self.main_stack.addWidget(page_settings)
        ps_layout = QVBoxLayout(page_settings)
        ps_layout.setContentsMargins(10, 4, 10, 4)
        ps_layout.setSpacing(10)

        h3 = QHBoxLayout()
        dot3 = QLabel("🟢", page_settings)
        dot3.setStyleSheet("font-size: 9px; border: none;")
        h3.addWidget(dot3)
        lbl_settings_title = QLabel("CÀI ĐẶT HỆ THỐNG & BẢO VỆ STREAM", page_settings)
        lbl_settings_title.setStyleSheet("color: #00f2fe; font-family: 'Consolas', 'Segoe UI'; font-size: 11px; font-weight: bold; border: none;")
        h3.addWidget(lbl_settings_title)
        h3.addStretch()
        ps_layout.addLayout(h3)

        # Card 1: Stream Proof Settings Card
        card_stream_proof = QFrame(page_settings)
        card_stream_proof.setStyleSheet("""
            QFrame {
                background: rgba(14, 19, 32, 0.85);
                border: 1px solid rgba(255, 255, 255, 0.08);
                border-radius: 12px;
            }
            QLabel { border: none; }
        """)
        csp_layout = QVBoxLayout(card_stream_proof)
        csp_layout.setContentsMargins(16, 14, 16, 14)
        csp_layout.setSpacing(8)

        h_sp_head = QHBoxLayout()
        lbl_sp_title = QLabel("🎥 CHẾ ĐỘ STREAM PROOF (CHỐNG QUAY / CHỤP MÀN HÌNH)", card_stream_proof)
        lbl_sp_title.setStyleSheet("color: #22c55e; font-family: 'Segoe UI'; font-size: 12px; font-weight: bold;")
        h_sp_head.addWidget(lbl_sp_title)
        h_sp_head.addStretch()
        self.sw_stream = ToggleSwitch(card_stream_proof, active_color="#22c55e", callback=lambda val: self.apply_stream_mode(val))
        h_sp_head.addWidget(self.sw_stream)
        csp_layout.addLayout(h_sp_head)

        lbl_sp_desc = QLabel("Ẩn 100% tất cả cửa sổ và menu khỏi OBS Studio, Discord Screen Share, GeForce Experience, Windows Snipping Tool (Win+Shift+S).", card_stream_proof)
        lbl_sp_desc.setStyleSheet("color: #94a3b8; font-size: 10px;")
        lbl_sp_desc.setWordWrap(True)
        csp_layout.addWidget(lbl_sp_desc)

        ps_layout.addWidget(card_stream_proof)

        # Card 2: Server & Proxy Configuration
        card_network_info = QFrame(page_settings)
        card_network_info.setStyleSheet("""
            QFrame {
                background: rgba(14, 19, 32, 0.85);
                border: 1px solid rgba(255, 255, 255, 0.08);
                border-radius: 12px;
            }
            QLabel { border: none; }
        """)
        cni_layout = QVBoxLayout(card_network_info)
        cni_layout.setContentsMargins(16, 14, 16, 14)
        cni_layout.setSpacing(8)

        lbl_net_title = QLabel("🌐 MÁY CHỦ ĐIỀU KHIỂN & PROXY SOCKS5", card_network_info)
        lbl_net_title.setStyleSheet("color: #38bdf8; font-family: 'Segoe UI'; font-size: 12px; font-weight: bold;")
        cni_layout.addWidget(lbl_net_title)

        r_ip = QHBoxLayout()
        local_ip_val = get_local_ip()
        lbl_loc = QLabel(f"Local Server: http://{local_ip_val}:20000", card_network_info)
        lbl_loc.setStyleSheet("color: #cbd5e1; font-family: 'Consolas'; font-size: 10px;")
        r_ip.addWidget(lbl_loc)
        r_ip.addStretch()
        lbl_socks = QLabel("SOCKS5 Proxy: 10808 - 10811", card_network_info)
        lbl_socks.setStyleSheet("color: #a855f7; font-family: 'Consolas'; font-size: 10px; font-weight: bold;")
        r_ip.addWidget(lbl_socks)
        cni_layout.addLayout(r_ip)

        r_tunnel = QHBoxLayout()
        self.lbl_tunnel_status = QLabel(f"Cloudflare Tunnel: {cloudflare_tunnel_url if cloudflare_tunnel_url else 'Đang khởi tạo...'}", card_network_info)
        self.lbl_tunnel_status.setStyleSheet("color: #00ffd2; font-family: 'Consolas'; font-size: 10px;")
        r_tunnel.addWidget(self.lbl_tunnel_status)
        cni_layout.addLayout(r_tunnel)

        ps_layout.addWidget(card_network_info)

        # Card 3: Shortcut Info
        card_ins = QFrame(page_settings)
        card_ins.setStyleSheet("""
            QFrame {
                background: rgba(14, 19, 32, 0.85);
                border: 1px solid rgba(255, 255, 255, 0.08);
                border-radius: 12px;
            }
            QLabel { border: none; }
        """)
        ci_layout = QHBoxLayout(card_ins)
        ci_layout.setContentsMargins(16, 12, 16, 12)
        lbl_ins_t = QLabel("Phím tắt ẩn / hiện Menu trên màn hình:", card_ins)
        lbl_ins_t.setStyleSheet("color: #cbd5e1; font-size: 11px;")
        ci_layout.addWidget(lbl_ins_t)
        ci_layout.addStretch()
        lbl_ins_btn = QLabel("[ INSERT ]", card_ins)
        lbl_ins_btn.setStyleSheet("background: #1e293b; color: #00f2fe; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border-radius: 5px; padding: 4px 10px; border: 1px solid rgba(0, 242, 254, 0.3);")
        ci_layout.addWidget(lbl_ins_btn)
        ps_layout.addWidget(card_ins)
        ps_layout.addStretch()

        # --- PAGE 3: VIP License & HWID ---
        page_expiry = QWidget()
        self.main_stack.addWidget(page_expiry)
        p_expiry_layout = QVBoxLayout(page_expiry)
        p_expiry_layout.setContentsMargins(10, 4, 10, 4)
        p_expiry_layout.setSpacing(10)

        # Header Title
        h4 = QHBoxLayout()
        dot4 = QLabel("🟢", page_expiry)
        dot4.setStyleSheet("font-size: 9px; border: none;")
        h4.addWidget(dot4)
        lbl_exp_head = QLabel("THÔNG TIN BẢN QUYỀN VIP (VIP LICENSE & HWID)", page_expiry)
        lbl_exp_head.setStyleSheet("color: #00f2fe; font-family: 'Consolas', 'Segoe UI'; font-size: 11px; font-weight: bold; border: none;")
        h4.addWidget(lbl_exp_head)
        h4.addStretch()
        p_expiry_layout.addLayout(h4)

        # Expiry Card Frame
        card_expiry = QFrame(page_expiry)
        card_expiry.setStyleSheet("""
            QFrame {
                background: rgba(14, 19, 32, 0.85);
                border: 1px solid rgba(255, 255, 255, 0.08);
                border-radius: 12px;
            }
            QLabel { border: none; font-family: 'Consolas', 'Segoe UI'; }
        """)
        exp_layout = QVBoxLayout(card_expiry)
        exp_layout.setContentsMargins(18, 16, 18, 16)
        exp_layout.setSpacing(12)

        # User Key Row
        r_user = QHBoxLayout()
        lbl_usr_lbl = QLabel("Mã VIP License Key:", card_expiry)
        lbl_usr_lbl.setStyleSheet("color: #94a3b8; font-size: 11px; font-weight: bold;")
        r_user.addWidget(lbl_usr_lbl)
        r_user.addStretch()
        self.lbl_user_val = QLabel(current_key if current_key else "NETWORKING-HOTSPOT-VIP", card_expiry)
        self.lbl_user_val.setStyleSheet("color: #00f2fe; font-size: 11px; font-weight: bold;")
        r_user.addWidget(self.lbl_user_val)
        exp_layout.addLayout(r_user)

        # HWID Row
        r_hwid = QHBoxLayout()
        lbl_hwid_lbl = QLabel("Mã HWID Phần Cứng:", card_expiry)
        lbl_hwid_lbl.setStyleSheet("color: #94a3b8; font-size: 11px; font-weight: bold;")
        r_hwid.addWidget(lbl_hwid_lbl)
        r_hwid.addStretch()
        hwid_full = get_system_hwid()
        lbl_hwid_val = QLabel(f"{hwid_full[:18]}...", card_expiry)
        lbl_hwid_val.setStyleSheet("color: #cbd5e1; font-size: 11px;")
        r_hwid.addWidget(lbl_hwid_val)
        btn_copy_hwid = QPushButton("📋 Copy", card_expiry)
        self.style_action_button(btn_copy_hwid, width=60)
        btn_copy_hwid.clicked.connect(lambda: (QApplication.clipboard().setText(hwid_full), QMessageBox.information(self, "HWID", "Đã copy HWID!")))
        r_hwid.addWidget(btn_copy_hwid)
        exp_layout.addLayout(r_hwid)

        # Time Remaining Row
        r_time_val = QHBoxLayout()
        lbl_time_lbl = QLabel("Thời Hạn Bản Quyền:", card_expiry)
        lbl_time_lbl.setStyleSheet("color: #94a3b8; font-size: 11px; font-weight: bold;")
        r_time_val.addWidget(lbl_time_lbl)
        r_time_val.addStretch()
        self.lbl_time_val = QLabel(get_formatted_key_time(), card_expiry)
        self.lbl_time_val.setStyleSheet("color: #eab308; font-size: 12px; font-weight: bold;")
        r_time_val.addWidget(self.lbl_time_val)
        exp_layout.addLayout(r_time_val)

        p_expiry_layout.addWidget(card_expiry)
        p_expiry_layout.addStretch()

        body_layout.addWidget(self.main_stack, 1)

        self.sound_enabled = True
        self.load_saved_keybinds_gui()

        outer_layout.addWidget(self.body_container, 1)
        main_layout.addWidget(self.panel)

        self.switch_menu_tab(0)

    def open_qr_window(self):
        try:
            local_ip = get_local_ip()
            target_url = f"http://{local_ip}:20000/?key={current_key}"
            if cloudflare_tunnel_url and str(cloudflare_tunnel_url).startswith("http"):
                target_url = f"{cloudflare_tunnel_url.rstrip('/')}/?key={current_key}"
            
            qr_win = HotspotQRScanWindow(target_url, "Web Remote Control", self)
            qr_win.exec_()
        except Exception as e:
            print("[Open QR Error]", e)

    def toggle_collapse_menu(self):
        self.is_collapsed = not getattr(self, 'is_collapsed', False)
        if self.is_collapsed:
            if hasattr(self, 'body_container') and self.body_container:
                self.body_container.hide()
            self.setFixedSize(720, 52)
            self.btn_collapse.setText("➕ Mở rộng")
            self.btn_collapse.setStyleSheet("""
                QPushButton {
                    background: rgba(0, 242, 254, 0.2);
                    color: #00f2fe;
                    font-family: 'Segoe UI', 'Consolas';
                    font-size: 10px;
                    font-weight: bold;
                    border: 1px solid #00f2fe;
                    border-radius: 6px;
                }
                QPushButton:hover {
                    background: #00f2fe;
                    color: #08090d;
                }
            """)
        else:
            if hasattr(self, 'body_container') and self.body_container:
                self.body_container.show()
            self.setFixedSize(720, 475)
            self.btn_collapse.setText("➖ Mini Bar")
            self.btn_collapse.setStyleSheet("""
                QPushButton {
                    background: rgba(56, 189, 248, 0.15);
                    color: #38bdf8;
                    font-family: 'Segoe UI', 'Consolas';
                    font-size: 10px;
                    font-weight: bold;
                    border: 1px solid rgba(56, 189, 248, 0.4);
                    border-radius: 6px;
                }
                QPushButton:hover {
                    background: #38bdf8;
                    color: #08090d;
                }
            """)

    def toggle_stream_mode_action(self):
        cur = getattr(self, 'stream_mode_active', False)
        self.apply_stream_mode(not cur)

    def apply_stream_mode(self, enable: bool):
        self.stream_mode_active = enable
        apply_stream_mode_global(enable)

        if hasattr(self, 'sw_stream') and self.sw_stream:
            self.sw_stream.blockSignals(True)
            self.sw_stream.setChecked(enable)
            self.sw_stream.blockSignals(False)

        if hasattr(self, 'btn_stream_badge') and self.btn_stream_badge:
            if enable:
                self.btn_stream_badge.setText("🛡️ STREAM PROOF: ON")
                self.btn_stream_badge.setStyleSheet("""
                    QPushButton {
                        background: rgba(34, 197, 94, 0.25);
                        color: #22c55e;
                        font-family: 'Consolas', 'Segoe UI';
                        font-size: 10px;
                        font-weight: bold;
                        border: 1.5px solid #22c55e;
                        border-radius: 6px;
                        padding: 2px 6px;
                    }
                    QPushButton:hover {
                        background: #22c55e;
                        color: #08090d;
                    }
                """)
            else:
                self.btn_stream_badge.setText("🛡️ STREAM PROOF: OFF")
                self.btn_stream_badge.setStyleSheet("""
                    QPushButton {
                        background: rgba(255, 255, 255, 0.05);
                        color: #94a3b8;
                        font-family: 'Consolas', 'Segoe UI';
                        font-size: 10px;
                        font-weight: bold;
                        border: 1px solid rgba(255, 255, 255, 0.15);
                        border-radius: 6px;
                        padding: 2px 6px;
                    }
                    QPushButton:hover {
                        background: rgba(0, 242, 254, 0.15);
                        color: #00f2fe;
                        border-color: #00f2fe;
                    }
                """)

        if getattr(self, 'sound_enabled', True):
            beep_async(900 if enable else 450, 100)

        msg = "🛡️ Stream Proof BẬT (Menu & Overlay ẩn 100% khỏi OBS / Discord / Quay Chụp Màn Hình)" if enable else "🔴 Stream Proof TẮT (Hiển thị bình thường)"
        self.set_status(msg, "#00e676" if enable else "#ffaa44")

    def style_action_button(self, btn, width=60):
        btn.setFixedWidth(width)
        btn.setFixedHeight(24)
        btn.setCursor(Qt.PointingHandCursor)
        btn.setStyleSheet("""
            QPushButton {
                background: rgba(255, 255, 255, 0.05);
                color: #e2e8f0;
                font-family: 'Segoe UI', 'Consolas';
                font-size: 10px;
                font-weight: bold;
                border: 1px solid rgba(255, 255, 255, 0.15);
                border-radius: 6px;
            }
            QPushButton:hover {
                background: rgba(0, 242, 254, 0.2);
                color: #00f2fe;
                border-color: #00f2fe;
            }
        """)

    @pyqtSlot(list)
    def toggle_multiple_modes_hotkey(self, modes_list):
        with clients_lock:
            c = clients[0] if clients else None
            if not c: return

            tele_toggled_off = False
            freeze_toggled_off = False
            ghost_toggled_off = False
            any_on = False

            for mode in modes_list:
                if mode in ["tele"]:
                    c.tele_active = not c.tele_active
                    if c.tele_active:
                        c.tele_buffer.clear()
                        c.ghost_buffer.clear()
                        any_on = True
                    else:
                        tele_toggled_off = True
                elif mode in ["freeze"]:
                    c.freeze_active = not c.freeze_active
                    if c.freeze_active:
                        c.freeze_buffer.clear()
                        any_on = True
                    else:
                        freeze_toggled_off = True
                elif mode in ["ghost", "ghost_lag", "ghost_mode"]:
                    c.ghost_active = not c.ghost_active
                    if c.ghost_active:
                        c.ghost_buffer.clear()
                        any_on = True
                    else:
                        ghost_toggled_off = True

            # Xả đệm khi mode tương ứng tắt đi
            if tele_toggled_off:
                c.ghost_buffer.clear()
                flush_tele_buffer(c)
            
            if freeze_toggled_off:
                flush_freeze_buffer(c)

            if ghost_toggled_off and not tele_toggled_off:
                flush_ghost_buffer(c)

            if c.tele_active: c.lag_mode = "tele"
            elif c.freeze_active: c.lag_mode = "freeze"
            elif c.ghost_active: c.lag_mode = "ghost_lag"
            else: c.lag_mode = ""

            c.fake_lag_active = c.tele_active or c.freeze_active or c.ghost_active

            if any_on:
                beep_async(880, 80)
            else:
                beep_async(440, 80)

        self.update_all_toggles_realtime()

    @pyqtSlot(str)
    def toggle_mode_hotkey(self, mode):
        self.toggle_multiple_modes_hotkey([mode])

    def set_mode_via_switch(self, mode, is_on):
        with clients_lock:
            c = clients[0] if clients else None
            if not c: return
            if mode in ["tele"]:
                c.tele_active = is_on
                if is_on:
                    c.tele_buffer.clear()
                    c.flushing = False
                    beep_async(880, 80)
                else:
                    flush_tele_buffer(c)
                    beep_async(440, 80)
            elif mode in ["freeze"]:
                c.freeze_active = is_on
                if is_on:
                    c.freeze_buffer.clear()
                    c.flushing = False
                    beep_async(880, 80)
                else:
                    flush_freeze_buffer(c)
                    beep_async(440, 80)
            elif mode in ["ghost", "ghost_lag", "ghost_mode"]:
                c.ghost_active = is_on
                if is_on:
                    c.ghost_buffer.clear()
                    c.flushing = False
                    beep_async(880, 80)
                else:
                    flush_ghost_buffer(c)
                    beep_async(440, 80)
            
            if c.tele_active: c.lag_mode = "tele"
            elif c.freeze_active: c.lag_mode = "freeze"
            elif c.ghost_active: c.lag_mode = "ghost_lag"
            else: c.lag_mode = ""

            c.fake_lag_active = c.tele_active or c.freeze_active or c.ghost_active
        self.update_all_toggles_realtime()

    def copy_single_link_action(self, mode):
        base_url = get_clean_base_url()
        target_link = f"{base_url}/{mode}?key={current_key}"
        cb = QApplication.clipboard()
        cb.setText(target_link)
        QMessageBox.information(self, "Đã Copy Link", f"Đã sao chép link [{mode.upper()}]:\n{target_link}")

    def copy_web_remote_action(self):
        base_url = get_clean_base_url()
        target_link = f"{base_url}/?key={current_key}"
        cb = QApplication.clipboard()
        cb.setText(target_link)
        QMessageBox.information(self, "Đã Copy Link", f"Đã sao chép link giao diện:\n{target_link}")

    def update_all_toggles_realtime(self):
        with clients_lock:
            c = clients[0] if clients else None
            if not c: return
            is_tele = bool(c.tele_active)
            is_freeze = bool(c.freeze_active)
            is_ghost = bool(c.ghost_active)

        if hasattr(self, 'sw_tele') and self.sw_tele:
            self.sw_tele.blockSignals(True)
            self.sw_tele.setChecked(is_tele)
            self.sw_tele.blockSignals(False)
        if hasattr(self, 'sw_freeze') and self.sw_freeze:
            self.sw_freeze.blockSignals(True)
            self.sw_freeze.setChecked(is_freeze)
            self.sw_freeze.blockSignals(False)
        if hasattr(self, 'sw_ghost') and self.sw_ghost:
            self.sw_ghost.blockSignals(True)
            self.sw_ghost.setChecked(is_ghost)
            self.sw_ghost.blockSignals(False)

    def style_keybind_button(self, btn):
        btn.setFixedSize(50, 24)
        btn.setCursor(Qt.PointingHandCursor)
        btn.setStyleSheet("""
            QPushButton {
                background: #27272a;
                color: #00ffd2;
                font-family: 'Consolas';
                font-size: 10px;
                font-weight: bold;
                border-radius: 6px;
                border: 1px solid rgba(0, 255, 210, 0.3);
            }
            QPushButton:hover {
                background: rgba(0, 255, 210, 0.15);
            }
        """)

    def load_saved_keybinds_gui(self):
        saved = load_saved_hotkeys()
        self.btn_tele_bind.setText(saved.get("tele_key", "F"))
        self.btn_freeze_bind.setText(saved.get("freeze_key", "E"))
        self.btn_ghost_bind.setText(saved.get("ghost_key", "V"))

    def toggle_sound_action(self):
        self.sound_enabled = not self.sound_enabled
        self.btn_sound_ctrl.setText("Sound: ON" if self.sound_enabled else "Sound: OFF")
        if self.sound_enabled:
            beep_async(880, 100)

    def start_rebind_action(self, mode):
        if mode == 'tele': self.btn_tele_bind.setText("[ ... ]")
        elif mode == 'freeze': self.btn_freeze_bind.setText("[ ... ]")
        elif mode == 'ghost': self.btn_ghost_bind.setText("[ ... ]")
        
        def _catch():
            try:
                ev = keyboard.read_event(suppress=False)
                if ev and ev.event_type == keyboard.KEY_DOWN:
                    k_name = str(ev.name).upper()
                    if k_name == "SPACEBAR": k_name = "SPACE"
                    QMetaObject.invokeMethod(self, "_on_key_bound_slot_gui", Qt.QueuedConnection, Q_ARG(str, mode), Q_ARG(str, k_name))
            except Exception:
                pass
        threading.Thread(target=_catch, daemon=True).start()

    @pyqtSlot(str, str)
    def _on_key_bound_slot_gui(self, mode, k_name):
        if mode == 'tele': self.btn_tele_bind.setText(k_name)
        elif mode == 'freeze': self.btn_freeze_bind.setText(k_name)
        elif mode == 'ghost': self.btn_ghost_bind.setText(k_name)
        
        k_tele = self.btn_tele_bind.text()
        k_freeze = self.btn_freeze_bind.text()
        k_ghost = self.btn_ghost_bind.text()
        register_all_pc_hotkeys(k_tele, k_freeze, k_ghost)

    def on_tunnel_url_updated(self, url):
        link_on = f"{url}/on?slot=1&key={current_key}"
        link_off = f"{url}/off?slot=1&key={current_key}"
        main_url = f"{url}/?slot=1&key={current_key}"
        self.last_tunnel_url = main_url
        self.last_link_on = link_on
        self.last_link_off = link_off
        
        if hasattr(self, 'status_lbl') and self.status_lbl:
            self.status_lbl.setText(f'🟢 <a href="{link_on}" style="color: #00e676;">Link BẬT</a> | 🔴 <a href="{link_off}" style="color: #ff4444;">Link TẮT</a> | 🌐 <a href="{main_url}" style="color: #00ffd2;">Web Remote</a>')
            self.status_lbl.setStyleSheet("font-size: 10px; font-weight: bold; border: none;")
        print("\n" + "="*60)
        print(f"[+] LINK REMOTE BẬT (ON):  {link_on}")
        print(f"[+] LINK REMOTE TẮT (OFF): {link_off}")
        print(f"[+] LINK WEB GIAO DIỆN:    {main_url}")
        print("="*60 + "\n")

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            if hasattr(self, 'status_lbl') and self.status_lbl and self.status_lbl.geometry().contains(event.pos()) and hasattr(self, 'last_tunnel_url'):
                cb = QApplication.clipboard()
                cb.setText(self.last_tunnel_url)
                QMessageBox.information(self, "Đã Copy", f"Đã sao chép link điều khiển:\n{self.last_tunnel_url}")
                return
            self.drag_position = event.globalPos() - self.frameGeometry().topLeft()
            event.accept()

    def on_divert_error(self, err_msg):
        self.set_status(f"❌ Lỗi: {err_msg}", "#ff4444")

    def set_status(self, text, color="#ffaa44"):
        if hasattr(self, 'status_lbl') and self.status_lbl:
            self.status_lbl.setText(text)
            self.status_lbl.setStyleSheet(f"color: {color}; font-size: 11px; font-weight: bold; border: none;")


    def update_stats(self):
        total_pkt = 0
        total_drop = 0
        any_active = False
        
        with clients_lock:
            for c in clients:
                total_pkt += c.packet_count
                total_drop += c.dropped_count
                if c.fake_lag_active:
                    any_active = True
            
            c0 = clients[0] if clients else None
            
        if hasattr(self, 'pkt_lbl_ctrl') and self.pkt_lbl_ctrl:
            self.pkt_lbl_ctrl.setText(f"PKT: {total_pkt}  |  DROP: {total_drop}")
            
        ping = random.randint(25, 45) if not any_active else random.randint(35, 55)
        fps  = random.randint(58, 60)
        if hasattr(self, 'stats_lbl_ctrl') and self.stats_lbl_ctrl:
            self.stats_lbl_ctrl.setText(f"PING: {ping} ms  |  FPS: {fps}")
            
        if hasattr(self, 'lbl_time_val') and self.lbl_time_val:
            self.lbl_time_val.setText(get_formatted_key_time())
        if hasattr(self, 'lbl_user_val') and self.lbl_user_val:
            self.lbl_user_val.setText(current_key if current_key else "KEY-Q2WQF01P2K5Y")
            
        if hasattr(self, 'lbl_user_time') and self.lbl_user_time:
            self.lbl_user_time.setText(get_formatted_key_time())
        if hasattr(self, 'lbl_user_key') and self.lbl_user_key:
            self.lbl_user_key.setText(current_key if current_key else "KEY-Q2WQF01P2K5Y")

        # Update ON/OFF indicators in Trạng Thái tab
        if c0:
            is_tele = bool(c0.tele_active)
            is_freeze = bool(c0.freeze_active)
            is_ghost = bool(c0.ghost_active)

            if hasattr(self, 'lbl_tele_ctrl') and self.lbl_tele_ctrl:
                if is_tele:
                    self.lbl_tele_ctrl.setText("⚡ TELEKILL [ ON ]")
                    self.lbl_tele_ctrl.setStyleSheet("color: #ffffff; background: rgba(255, 69, 0, 0.45); border: 1px solid #ff4500; border-radius: 4px; font-family: 'Segoe UI'; font-size: 11px; font-weight: bold; padding: 2px 6px;")
                else:
                    self.lbl_tele_ctrl.setText("⚡ TELEKILL [ OFF ]")
                    self.lbl_tele_ctrl.setStyleSheet("color: #71717a; background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 4px; font-family: 'Segoe UI'; font-size: 11px; font-weight: bold; padding: 2px 6px;")

            if hasattr(self, 'lbl_freeze_ctrl') and self.lbl_freeze_ctrl:
                if is_freeze:
                    self.lbl_freeze_ctrl.setText("🧊 FREEZE [ ON ]")
                    self.lbl_freeze_ctrl.setStyleSheet("color: #ffffff; background: rgba(0, 170, 255, 0.45); border: 1px solid #00aaff; border-radius: 4px; font-family: 'Segoe UI'; font-size: 11px; font-weight: bold; padding: 2px 6px;")
                else:
                    self.lbl_freeze_ctrl.setText("🧊 FREEZE [ OFF ]")
                    self.lbl_freeze_ctrl.setStyleSheet("color: #71717a; background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 4px; font-family: 'Segoe UI'; font-size: 11px; font-weight: bold; padding: 2px 6px;")

            if hasattr(self, 'lbl_ghost_ctrl') and self.lbl_ghost_ctrl:
                if is_ghost:
                    self.lbl_ghost_ctrl.setText("👻 GHOST LAG [ ON ]")
                    self.lbl_ghost_ctrl.setStyleSheet("color: #ffffff; background: rgba(192, 132, 252, 0.45); border: 1px solid #c084fc; border-radius: 4px; font-family: 'Segoe UI'; font-size: 11px; font-weight: bold; padding: 2px 6px;")
                else:
                    self.lbl_ghost_ctrl.setText("👻 GHOST LAG [ OFF ]")
                    self.lbl_ghost_ctrl.setStyleSheet("color: #71717a; background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 4px; font-family: 'Segoe UI'; font-size: 11px; font-weight: bold; padding: 2px 6px;")

            if hasattr(self, 'overlay') and self.overlay:
                self.overlay.update_status(is_tele, is_freeze, is_ghost)

        self.update_all_toggles_realtime()

        if hasattr(self, 'status_lbl') and self.status_lbl:
            if any_active:
                if not self.status_lbl.text().startswith("☁️"):
                    self.set_status("⚡ FAKE LAG ĐANG KÍCH HOẠT (VÔ HẠN)", "#ffcc00")
            else:
                if not self.status_lbl.text().startswith("☁️"):
                    self.set_status("✅ Đường truyền hoạt động bình thường", "#00e676")

    def update_all_pc_hotkeys(self):
        k_tele = self.hk_tele_combo.currentText()
        k_freeze = self.hk_freeze_combo.currentText()
        k_ghost = self.hk_ghost_combo.currentText()
        register_all_pc_hotkeys(k_tele, k_freeze, k_ghost)
        self.set_status(f"✅ Đã lưu phím nóng: Tele[{k_tele}], Freeze[{k_freeze}], Ghost[{k_ghost}]", "#00ffd2")

    def listen_and_assign_hotkey(self, mode):
        if mode == 'tele':
            combo = self.hk_tele_combo
        elif mode == 'freeze':
            combo = self.hk_freeze_combo
        else:
            combo = self.hk_ghost_combo
            
        self.set_status(f"⌨️ Đang chờ gõ phím cho [{mode.upper()}]... (Hãy gõ 1 phím bất kỳ trên bàn phím)", "#ffb703")
        
        def _listen():
            try:
                event = keyboard.read_event(suppress=False)
                if event and event.event_type == keyboard.KEY_DOWN:
                    k_name = str(event.name).upper()
                    if k_name == "SPACEBAR": k_name = "Space"
                    
                    QMetaObject.invokeMethod(self, "_on_key_captured_slot", Qt.QueuedConnection, Q_ARG(str, mode), Q_ARG(str, k_name))
            except Exception as e:
                print("[Key Catch Error]", e)

        threading.Thread(target=_listen, daemon=True).start()

    @pyqtSlot(str, str)
    def _on_key_captured_slot(self, mode, k_name):
        if mode == 'tele':
            combo = self.hk_tele_combo
        elif mode == 'freeze':
            combo = self.hk_freeze_combo
        else:
            combo = self.hk_ghost_combo

        all_items = [combo.itemText(i) for i in range(combo.count())]
        if k_name not in all_items:
            combo.addItem(k_name)
        combo.setCurrentText(k_name)
        self.update_all_pc_hotkeys()
        beep_async(880, 120)
        self.set_status(f"✅ Đã gán phím nóng mới cho {mode.upper()}: [{k_name}]", "#00ffd2")



    @pyqtSlot(str)
    def update_ui_status_slot(self, target_mode):
        if target_mode == "tele":
            if tele_mode:
                self.set_status("🔥 BẬT TeleKill (⚡)", "#ff4500")
            else:
                self.set_status("🔴 TẮT TeleKill (Đã xả gói)", "#ff4444")
        elif target_mode == "freeze":
            if freeze_mode:
                self.set_status("🔥 BẬT Freeze Địch Đơ (🧊)", "#00aaff")
            else:
                self.set_status("🔴 TẮT Freeze (Đã xả gói)", "#ff4444")
        elif target_mode in ["ghost", "ghost_lag", "ghost_mode"]:
            if ghost_mode:
                self.set_status("🔥 BẬT Ghost Lag (👻)", "#c084fc")
            else:
                self.set_status("🔴 TẮT Ghost Lag (Đã xả gói)", "#ff4444")

        self.update_all_toggles_realtime()

    def hotkey_toggle_fakelag(self):
        self.update_all_toggles_realtime()

    def set_fakelag_remote(self, slot_idx, enable):
        self.update_all_toggles_realtime()

    def animate_neon_glow(self):
        self.glow_hue = (self.glow_hue + 3) % 360
        color = QColor.fromHsv(self.glow_hue, 220, 255)
        r, g, b = color.red(), color.green(), color.blue()
        
        bg_path = get_asset_path("app_bg.png").replace('\\', '/')
        if os.path.exists(bg_path):
            bg_style = f"background-image: url('{bg_path}'); background-position: center; background-repeat: no-repeat;"
        else:
            bg_style = "background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #05070e, stop:0.5 #0d1321, stop:1 #080c14);"

        self.panel.setStyleSheet(f"""
            QFrame#MainPanel {{
                {bg_style}
                border: 2px solid rgba({r}, {g}, {b}, 0.8);
                border-radius: 24px;
            }}
            QLabel {{ font-family: 'Segoe UI', sans-serif; }}
        """)

    def set_window_visibility(self, visible):
        if visible:
            self.show()
            self.raise_()
            self.activateWindow()
        else:
            self.hide()

    def mouseMoveEvent(self, event):
        if event.buttons() == Qt.LeftButton and self.drag_position:
            self.move(event.globalPos() - self.drag_position)
            event.accept()

    def close_window(self):
        try:
            if hasattr(self, 'overlay') and self.overlay:
                self.overlay.close()
        except: pass
        stop_engine()
        try: keyboard.unhook_all()
        except: pass
        QApplication.quit()

def map_key_to_keyboard(key_str):
    k = str(key_str).lower().strip()
    mapping = {
        'space': 'space',
        'capslock': 'caps lock',
        'shift': 'shift',
        'ctrl': 'ctrl',
        'alt': 'alt',
        'tab': 'tab',
        'enter': 'enter',
        'backspace': 'backspace',
        'delete': 'delete',
        'insert': 'insert',
        'home': 'home',
        'end': 'end',
        'pageup': 'page up',
        'pagedown': 'page down',
        'up': 'up',
        'down': 'down',
        'left': 'left',
        'right': 'right',
        'numpad0': '0',
        'numpad1': '1',
        'numpad2': '2',
        'numpad3': '3',
        'numpad4': '4',
        'numpad5': '5',
        'numpad6': '6',
        'numpad7': '7',
        'numpad8': '8',
        'numpad9': '9'
    }
    return mapping.get(k, k)

HOTKEY_CONFIG_FILE = "hotkeys.json"

def load_saved_hotkeys():
    default_hk = {"tele_key": "V", "freeze_key": "X", "ghost_key": "B"}
    try:
        if os.path.exists(HOTKEY_CONFIG_FILE):
            with open(HOTKEY_CONFIG_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                return {
                    "tele_key": str(data.get("tele_key", "V")).upper(),
                    "freeze_key": str(data.get("freeze_key", "X")).upper(),
                    "ghost_key": str(data.get("ghost_key", "B")).upper()
                }
    except Exception:
        pass
    return default_hk

def save_hotkeys_to_file(tele_key, freeze_key, ghost_key):
    try:
        data = {
            "tele_key": str(tele_key).upper(),
            "freeze_key": str(freeze_key).upper(),
            "ghost_key": str(ghost_key).upper()
        }
        with open(HOTKEY_CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        print("[Hotkey Save Error]", e)

active_hotkeys = {"tele": "v", "freeze": "x", "ghost": "b"}
hotkey_lock = threading.Lock()
hotkey_polling_started = False

main_window_instance = None

def update_active_hotkeys(tele_k, freeze_k, ghost_k):
    with hotkey_lock:
        active_hotkeys["tele"] = map_key_to_keyboard(tele_k).lower()
        active_hotkeys["freeze"] = map_key_to_keyboard(freeze_k).lower()
        active_hotkeys["ghost"] = map_key_to_keyboard(ghost_k).lower()

def start_hotkey_polling_loop():
    prev_states = {"tele": False, "freeze": False, "ghost": False}

    while not stop_event.is_set():
        try:
            with hotkey_lock:
                k_tele = active_hotkeys["tele"]
                k_freeze = active_hotkeys["freeze"]
                k_ghost = active_hotkeys["ghost"]

            triggered_modes = []

            # 1. TELEKILL HOTKEY
            if k_tele and str(k_tele).strip():
                st = keyboard.is_pressed(k_tele)
                if st and not prev_states["tele"]:
                    triggered_modes.append("tele")
                prev_states["tele"] = st

            # 2. FREEZE HOTKEY
            if k_freeze and str(k_freeze).strip():
                st = keyboard.is_pressed(k_freeze)
                if st and not prev_states["freeze"]:
                    triggered_modes.append("freeze")
                prev_states["freeze"] = st

            # 3. GHOST HOTKEY
            if k_ghost and str(k_ghost).strip():
                st = keyboard.is_pressed(k_ghost)
                if st and not prev_states["ghost"]:
                    triggered_modes.append("ghost")
                prev_states["ghost"] = st

            if triggered_modes and main_window_instance:
                QMetaObject.invokeMethod(
                    main_window_instance,
                    "toggle_multiple_modes_hotkey",
                    Qt.QueuedConnection,
                    Q_ARG(list, triggered_modes)
                )
        except Exception as e:
            print("[Hotkey Loop Error]", e)
        time.sleep(0.003)

def register_all_pc_hotkeys(tele_key=None, freeze_key=None, ghost_key=None):
    global hotkey_polling_started
    saved = load_saved_hotkeys()
    if tele_key is None: tele_key = saved.get("tele_key", "V")
    if freeze_key is None: freeze_key = saved.get("freeze_key", "X")
    if ghost_key is None: ghost_key = saved.get("ghost_key", "B")

    save_hotkeys_to_file(tele_key, freeze_key, ghost_key)
    update_active_hotkeys(tele_key, freeze_key, ghost_key)

    try:
        keyboard.unhook_all()
    except Exception:
        pass

    if not hotkey_polling_started:
        hotkey_polling_started = True
        threading.Thread(target=start_hotkey_polling_loop, daemon=True).start()

def beep_async(freq=880, dur=100):
    def _b():
        try: winsound.Beep(freq, dur)
        except Exception: pass
    threading.Thread(target=_b, daemon=True).start()

# === NEXT-GEN CYBER CONSTELLATION PARTICLE CANVAS ===
class ParticleCanvas(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAttribute(Qt.WA_TransparentForMouseEvents)
        self.particles = []
        for _ in range(35):
            self.particles.append({
                'x': random.uniform(0, 600),
                'y': random.uniform(0, 500),
                'r': random.uniform(1.0, 2.4),
                'speed_y': random.uniform(-0.4, 0.4),
                'speed_x': random.uniform(-0.4, 0.4),
                'alpha': random.randint(80, 220),
                'is_cyan': random.choice([True, False])
            })
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_particles)
        self.timer.start(33)

    def update_particles(self):
        w, h = max(1, self.width()), max(1, self.height())
        for p in self.particles:
            p['y'] += p['speed_y']
            p['x'] += p['speed_x']
            if p['y'] > h: p['y'] = 0
            elif p['y'] < 0: p['y'] = h
            if p['x'] > w: p['x'] = 0
            elif p['x'] < 0: p['x'] = w
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # 1. Draw glowing connecting lines between close particles
        count = len(self.particles)
        for i in range(count):
            p1 = self.particles[i]
            for j in range(i + 1, count):
                p2 = self.particles[j]
                dx = p1['x'] - p2['x']
                dy = p1['y'] - p2['y']
                dist_sq = dx*dx + dy*dy
                if dist_sq < 3600:
                    alpha = int((1.0 - (dist_sq / 3600.0)) * 45)
                    pen = QPen(QColor(0, 242, 254, alpha), 1)
                    painter.setPen(pen)
                    painter.drawLine(int(p1['x']), int(p1['y']), int(p2['x']), int(p2['y']))

        # 2. Draw glowing particle dots
        for p in self.particles:
            if p.get('is_cyan'):
                color = QColor(0, 242, 254, p['alpha'])
            else:
                color = QColor(139, 92, 246, p['alpha'])
            painter.setBrush(QBrush(color))
            painter.setPen(Qt.NoPen)
            painter.drawEllipse(QPointF(p['x'], p['y']), p['r'], p['r'])

# === HOTSPOT QR SCAN WINDOW (SCREENSHOT 1) ===
class HotspotQRScanWindow(QDialog):
    device_connected_signal = pyqtSignal()

    def __init__(self, target_url=None, title_desc="Hotspot Connect", parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Dialog)
        self.setFixedSize(320, 470)
        self.drag_position = None
        self.target_url = target_url
        self.title_desc = title_desc
        self.hotspot_ssid = "HoangHaVIP_Hotspot"
        self.hotspot_pass = "hoangha123"
        self.load_saved_hotspot()
        self.spinner_angle = 0
        self.device_connected_signal.connect(self.accept)
        self.init_ui()
        self.start_device_monitor()

    def showEvent(self, event):
        super().showEvent(event)
        if is_stream_mode_active:
            apply_stream_mode_global(True)

    def load_saved_hotspot(self):
        hs_file = get_asset_path("hotspot_config.json")
        if os.path.exists(hs_file):
            try:
                with open(hs_file, "r", encoding="utf-8") as f:
                    d = json.load(f)
                    self.hotspot_ssid = d.get("ssid", "HoangHaVIP_Hotspot")
                    self.hotspot_pass = d.get("pass", "hoangha123")
            except Exception:
                pass

    def save_hotspot_config(self, ssid, password):
        hs_file = get_asset_path("hotspot_config.json")
        try:
            with open(hs_file, "w", encoding="utf-8") as f:
                json.dump({"ssid": ssid, "pass": password}, f, ensure_ascii=False, indent=2)
        except Exception:
            pass

    def init_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.panel = QFrame(self)
        self.panel.setStyleSheet("""
            QFrame {
                background: #090c14;
                border: 1px solid rgba(0, 242, 254, 0.3);
                border-radius: 14px;
            }
        """)

        p_layout = QVBoxLayout(self.panel)
        p_layout.setContentsMargins(14, 10, 14, 10)
        p_layout.setSpacing(8)

        # Header: Green dot + SCAN QR + Close X
        header = QHBoxLayout()
        dot_lbl = QLabel("🟢", self.panel)
        dot_lbl.setStyleSheet("font-size: 8px; border: none;")
        header.addWidget(dot_lbl)

        title_lbl = QLabel("QUÉT MÃ QR KẾT NỐI", self.panel)
        title_lbl.setStyleSheet("color: #00f2fe; font-family: 'Consolas', 'Segoe UI'; font-size: 11px; font-weight: bold; border: none;")
        header.addWidget(title_lbl)
        header.addStretch()

        close_btn = QPushButton("✕", self.panel)
        close_btn.setFixedSize(18, 18)
        close_btn.setCursor(Qt.PointingHandCursor)
        close_btn.setStyleSheet("QPushButton { background: transparent; color: #64748b; border: none; font-size: 12px; font-weight: bold; } QPushButton:hover { color: #ff4444; }")
        close_btn.clicked.connect(self.accept)
        header.addWidget(close_btn)
        p_layout.addLayout(header)

        # Hotspot Inputs
        hs_box = QHBoxLayout()
        hs_box.setSpacing(6)

        self.input_ssid = QLineEdit(self.panel)
        self.input_ssid.setPlaceholderText("Tên Hotspot PC...")
        self.input_ssid.setText(self.hotspot_ssid)
        self.style_input(self.input_ssid)

        self.input_pass = QLineEdit(self.panel)
        self.input_pass.setPlaceholderText("Mật khẩu Hotspot...")
        self.input_pass.setText(self.hotspot_pass)
        self.style_input(self.input_pass)

        hs_box.addWidget(self.input_ssid, 1)
        hs_box.addWidget(self.input_pass, 1)
        p_layout.addLayout(hs_box)

        self.input_ssid.textChanged.connect(self.update_qr)
        self.input_pass.textChanged.connect(self.update_qr)

        # Center QR Image Frame
        qr_frame = QFrame(self.panel)
        qr_frame.setStyleSheet("background: white; border-radius: 10px; padding: 6px;")
        qr_layout = QVBoxLayout(qr_frame)
        qr_layout.setContentsMargins(4, 4, 4, 4)

        self.qr_label = QLabel(qr_frame)
        self.qr_label.setAlignment(Qt.AlignCenter)
        self.qr_label.setFixedSize(200, 200)
        self.render_qr_code()
        qr_layout.addWidget(self.qr_label)
        p_layout.addWidget(qr_frame, 0, Qt.AlignCenter)

        # Footer: Animated Spinner & Next Step Button
        footer = QVBoxLayout()
        footer.setAlignment(Qt.AlignCenter)
        footer.setSpacing(6)

        self.status_lbl = QLabel("🌀  Waiting for device...", self.panel)
        self.status_lbl.setStyleSheet("color: #38bdf8; font-family: 'Consolas', 'Segoe UI'; font-size: 11px; font-weight: bold; border: none;")
        self.status_lbl.setAlignment(Qt.AlignCenter)
        footer.addWidget(self.status_lbl)

        self.btn_next_step = QPushButton("⚡ ĐÃ BẮT MẠNG ➔ BƯỚC TIẾP THEO", self.panel)
        self.btn_next_step.setCursor(Qt.PointingHandCursor)
        self.btn_next_step.setStyleSheet("""
            QPushButton {
                background: rgba(0, 255, 210, 0.15);
                color: #00ffd2;
                font-family: 'Consolas', 'Segoe UI';
                font-size: 10px;
                font-weight: bold;
                border: 1px solid rgba(0, 255, 210, 0.4);
                border-radius: 6px;
                padding: 6px;
            }
            QPushButton:hover {
                background: #00ffd2;
                color: #08090d;
            }
        """)
        self.btn_next_step.clicked.connect(self.accept)
        footer.addWidget(self.btn_next_step)

        p_layout.addLayout(footer)
        layout.addWidget(self.panel)

        # Particles Overlay
        self.particles = ParticleCanvas(self.panel)
        self.particles.resize(320, 460)
        self.particles.raise_()

        # Spinner animation timer
        self.spinner_timer = QTimer(self)
        self.spinner_timer.timeout.connect(self.animate_spinner)
        self.spinner_timer.start(120)

    def style_input(self, inp):
        inp.setStyleSheet("""
            QLineEdit {
                background: rgba(5, 7, 14, 0.85);
                border: 1px solid rgba(56, 189, 248, 0.3);
                border-radius: 6px;
                color: #38bdf8;
                font-family: 'Consolas';
                font-size: 10px;
                font-weight: bold;
                padding: 4px 6px;
            }
            QLineEdit:focus {
                border-color: #00ffd2;
                color: #00ffd2;
            }
        """)

    def update_qr(self):
        s = self.input_ssid.text().strip()
        p = self.input_pass.text().strip()
        if s: self.hotspot_ssid = s
        if p: self.hotspot_pass = p
        self.save_hotspot_config(self.hotspot_ssid, self.hotspot_pass)
        self.render_qr_code()

    def animate_spinner(self):
        spinners = ["🌀  Waiting for device...", "🔄  Waiting for device...", "⚡  Waiting for device..."]
        self.spinner_angle = (self.spinner_angle + 1) % len(spinners)
        self.status_lbl.setText(spinners[self.spinner_angle])

    def render_qr_code(self):
        qr_string = f"WIFI:S:{self.hotspot_ssid};T:WPA;P:{self.hotspot_pass};;"
        try:
            if 'qrcode' in sys.modules:
                qr = qrcode.QRCode(version=1, box_size=8, border=2)
                qr.add_data(qr_string)
                qr.make(fit=True)
                img = qr.make_image(fill_color="black", back_color="white")
                buf = io.BytesIO()
                img.save(buf, format='PNG')
                pix = QPixmap()
                pix.loadFromData(buf.getvalue())
                self.qr_label.setPixmap(pix.scaled(190, 190, Qt.KeepAspectRatio, Qt.SmoothTransformation))
                return
        except Exception:
            pass

        try:
            url = f"https://quickchart.io/qr?text={urllib.parse.quote(self.hotspot_info)}&size=220&margin=1"
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=3, context=ssl_context) as resp:
                pix = QPixmap()
                pix.loadFromData(resp.read())
                self.qr_label.setPixmap(pix.scaled(210, 210, Qt.KeepAspectRatio, Qt.SmoothTransformation))
                return
        except Exception:
            pass

        # Fallback matrix draw
        pix = QPixmap(210, 210)
        pix.fill(Qt.white)
        p = QPainter(pix)
        p.setBrush(QBrush(Qt.black))
        p.drawRect(10, 10, 50, 50)
        p.drawRect(150, 10, 50, 50)
        p.drawRect(10, 150, 50, 50)
        p.fillRect(20, 20, 30, 30, Qt.white)
        p.fillRect(160, 20, 30, 30, Qt.white)
        p.fillRect(20, 160, 30, 30, Qt.white)
        p.fillRect(28, 28, 14, 14, Qt.black)
        p.fillRect(168, 28, 14, 14, Qt.black)
        p.fillRect(28, 168, 14, 14, Qt.black)
        p.end()
        self.qr_label.setPixmap(pix)

    def start_device_monitor(self):
        def _check():
            for _ in range(60):
                time.sleep(2)
                with clients_lock:
                    if any(c.client_ip and not c.client_ip.startswith("127.") for c in clients):
                        self.device_connected_signal.emit()
                        return
        threading.Thread(target=_check, daemon=True).start()

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.drag_position = event.globalPos() - self.frameGeometry().topLeft()
            event.accept()

    def mouseMoveEvent(self, event):
        if event.buttons() == Qt.LeftButton and self.drag_position:
            self.move(event.globalPos() - self.drag_position)
            event.accept()

# === KEYBINDS PANEL ===
class KeybindsPanelWindow(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setFixedSize(300, 230)
        self.drag_position = None
        self.active_mode_rebind = None
        self.sound_enabled = True
        self.init_ui()
        self.load_keys()

    def showEvent(self, event):
        super().showEvent(event)
        if is_stream_mode_active:
            apply_stream_mode_global(True)

    def init_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.panel = QFrame(self)
        self.panel.setStyleSheet("""
            QFrame {
                background: #090c14;
                border: 1px solid rgba(0, 242, 254, 0.3);
                border-radius: 12px;
            }
        """)

        p_layout = QVBoxLayout(self.panel)
        p_layout.setContentsMargins(14, 10, 14, 10)
        p_layout.setSpacing(8)

        # Header
        header = QHBoxLayout()
        dot = QLabel("🟢", self.panel)
        dot.setStyleSheet("font-size: 8px; border: none;")
        header.addWidget(dot)

        title = QLabel("HOTKEYS MONITOR", self.panel)
        title.setStyleSheet("color: #00f2fe; font-family: 'Consolas', 'Segoe UI'; font-size: 11px; font-weight: bold; border: none;")
        header.addWidget(title)
        header.addStretch()

        close_btn = QPushButton("✕", self.panel)
        close_btn.setFixedSize(16, 16)
        close_btn.setCursor(Qt.PointingHandCursor)
        close_btn.setStyleSheet("QPushButton { background: transparent; color: #64748b; border: none; font-size: 11px; font-weight: bold; } QPushButton:hover { color: #ff4444; }")
        close_btn.clicked.connect(self.hide)
        header.addWidget(close_btn)
        p_layout.addLayout(header)

        # Keybind Rows
        # Telekill
        r1 = QHBoxLayout()
        t1 = QLabel("⚡ TELEKILL:", self.panel)
        t1.setStyleSheet("color: #ff4500; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: none;")
        r1.addWidget(t1)
        r1.addStretch()

        self.btn_tele = QPushButton("V", self.panel)
        self.style_key_button(self.btn_tele)
        self.btn_tele.clicked.connect(lambda: self.start_rebind('tele'))
        r1.addWidget(self.btn_tele)
        p_layout.addLayout(r1)

        # Freeze
        r2 = QHBoxLayout()
        t2 = QLabel("🧊 FREEZE:", self.panel)
        t2.setStyleSheet("color: #00aaff; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: none;")
        r2.addWidget(t2)
        r2.addStretch()

        self.btn_freeze = QPushButton("X", self.panel)
        self.style_key_button(self.btn_freeze)
        self.btn_freeze.clicked.connect(lambda: self.start_rebind('freeze'))
        r2.addWidget(self.btn_freeze)
        p_layout.addLayout(r2)

        # Ghost
        r3 = QHBoxLayout()
        t3 = QLabel("👻 GHOST:", self.panel)
        t3.setStyleSheet("color: #c084fc; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: none;")
        r3.addWidget(t3)
        r3.addStretch()

        self.btn_ghost = QPushButton("B", self.panel)
        self.style_key_button(self.btn_ghost)
        self.btn_ghost.clicked.connect(lambda: self.start_rebind('ghost'))
        r3.addWidget(self.btn_ghost)
        p_layout.addLayout(r3)

        # Helper note
        sub = QLabel("Click nút rồi bấm phím bất kỳ để gán", self.panel)
        sub.setStyleSheet("color: #64748b; font-size: 9px; border: none;")
        sub.setAlignment(Qt.AlignCenter)
        p_layout.addWidget(sub)

        # Sound Button Toggle
        self.btn_sound = QPushButton("🔊 Âm thanh: BẬT", self.panel)
        self.btn_sound.setCursor(Qt.PointingHandCursor)
        self.btn_sound.setStyleSheet("""
            QPushButton {
                background: rgba(255, 255, 255, 0.05);
                color: #e2e8f0;
                font-family: 'Consolas';
                font-size: 10px;
                font-weight: bold;
                border: 1px solid rgba(255, 255, 255, 0.15);
                border-radius: 6px;
                padding: 5px;
            }
            QPushButton:hover {
                background: rgba(255, 255, 255, 0.12);
                border-color: #38bdf8;
            }
        """)
        self.btn_sound.clicked.connect(self.toggle_sound)
        p_layout.addWidget(self.btn_sound)

        layout.addWidget(self.panel)

        # Particle background overlay
        self.particles = ParticleCanvas(self.panel)
        self.particles.resize(300, 230)
        self.particles.raise_()

    def style_key_button(self, btn):
        btn.setFixedSize(65, 26)
        btn.setCursor(Qt.PointingHandCursor)
        btn.setStyleSheet("""
            QPushButton {
                background: rgba(255, 255, 255, 0.06);
                color: #f8fafc;
                font-family: 'Consolas';
                font-size: 11px;
                font-weight: bold;
                border: 1px solid rgba(255, 255, 255, 0.2);
                border-radius: 5px;
            }
            QPushButton:hover {
                border-color: #38bdf8;
                background: rgba(56, 189, 248, 0.15);
            }
        """)

    def load_keys(self):
        saved = load_saved_hotkeys()
        self.btn_tele.setText(saved.get("tele_key", "V"))
        self.btn_freeze.setText(saved.get("freeze_key", "X"))
        self.btn_ghost.setText(saved.get("ghost_key", "B"))

    def toggle_sound(self):
        self.sound_enabled = not self.sound_enabled
        self.btn_sound.setText("🔊 Âm thanh: BẬT" if self.sound_enabled else "🔇 Âm thanh: TẮT")
        if self.sound_enabled:
            beep_async(880, 100)

    def start_rebind(self, mode):
        self.active_mode_rebind = mode
        if mode == 'tele': self.btn_tele.setText("[ ... ]")
        elif mode == 'freeze': self.btn_freeze.setText("[ ... ]")
        elif mode == 'ghost': self.btn_ghost.setText("[ ... ]")
        
        def _catch():
            try:
                ev = keyboard.read_event(suppress=False)
                if ev and ev.event_type == keyboard.KEY_DOWN:
                    k_name = str(ev.name).upper()
                    if k_name == "SPACEBAR": k_name = "SPACE"
                    QMetaObject.invokeMethod(self, "_on_key_bound_slot", Qt.QueuedConnection, Q_ARG(str, mode), Q_ARG(str, k_name))
            except Exception:
                pass
        threading.Thread(target=_catch, daemon=True).start()

    @pyqtSlot(str, str)
    def _on_key_bound_slot(self, mode, k_name):
        if mode == 'tele': self.btn_tele.setText(k_name)
        elif mode == 'freeze': self.btn_freeze.setText(k_name)
        elif mode == 'ghost': self.btn_ghost.setText(k_name)
        
        k_tele = self.btn_tele.text()
        k_freeze = self.btn_freeze.text()
        k_ghost = self.btn_ghost.text()
        register_all_pc_hotkeys(k_tele, k_freeze, k_ghost)
        if self.sound_enabled:
            beep_async(1000, 120)

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.drag_position = event.globalPos() - self.frameGeometry().topLeft()
            event.accept()

    def mouseMoveEvent(self, event):
        if event.buttons() == Qt.LeftButton and self.drag_position:
            self.move(event.globalPos() - self.drag_position)
            event.accept()

def get_clean_base_url():
    global cloudflare_tunnel_url
    url = cloudflare_tunnel_url if (cloudflare_tunnel_url and str(cloudflare_tunnel_url).startswith("http")) else ""
    if not url and main_window_instance and hasattr(main_window_instance, 'last_tunnel_url') and main_window_instance.last_tunnel_url:
        url = main_window_instance.last_tunnel_url
    if not url:
        url = f"http://{get_local_ip()}:20000"
    
    if "?" in url:
        url = url.split("?")[0]
    return url.rstrip("/")

# === STATUS PANEL ===
class StatusPanelWindow(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setFixedSize(300, 220)
        self.drag_position = None
        self.init_ui()

    def showEvent(self, event):
        super().showEvent(event)
        if is_stream_mode_active:
            apply_stream_mode_global(True)

    def init_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.panel = QFrame(self)
        self.panel.setStyleSheet("""
            QFrame {
                background: #090c14;
                border: 1px solid rgba(0, 242, 254, 0.3);
                border-radius: 12px;
            }
        """)

        p_layout = QVBoxLayout(self.panel)
        p_layout.setContentsMargins(14, 10, 14, 10)
        p_layout.setSpacing(8)

        # Header
        header = QHBoxLayout()
        dot = QLabel("🟢", self.panel)
        dot.setStyleSheet("font-size: 8px; border: none;")
        header.addWidget(dot)

        title = QLabel("STATUS MONITOR", self.panel)
        title.setStyleSheet("color: #00f2fe; font-family: 'Consolas', 'Segoe UI'; font-size: 11px; font-weight: bold; border: none;")
        header.addWidget(title)
        header.addStretch()

        close_btn = QPushButton("✕", self.panel)
        close_btn.setFixedSize(16, 16)
        close_btn.setCursor(Qt.PointingHandCursor)
        close_btn.setStyleSheet("QPushButton { background: transparent; color: #64748b; border: none; font-size: 11px; font-weight: bold; } QPushButton:hover { color: #ff4444; }")
        close_btn.clicked.connect(self.hide)
        header.addWidget(close_btn)
        p_layout.addLayout(header)

        # Status items & Copy buttons
        # Telekill Row
        r_tele = QHBoxLayout()
        self.lbl_tele = QLabel("Telekill", self.panel)
        self.lbl_tele.setStyleSheet("color: #94a3b8; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: none;")
        r_tele.addWidget(self.lbl_tele)
        r_tele.addStretch()

        btn_copy_tele = QPushButton("📋 Tele", self.panel)
        self.style_copy_button(btn_copy_tele)
        btn_copy_tele.clicked.connect(lambda: self.copy_single_link("tele"))
        r_tele.addWidget(btn_copy_tele)
        p_layout.addLayout(r_tele)

        # Freeze Row
        r_freeze = QHBoxLayout()
        self.lbl_freeze = QLabel("Freeze", self.panel)
        self.lbl_freeze.setStyleSheet("color: #94a3b8; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: none;")
        r_freeze.addWidget(self.lbl_freeze)
        r_freeze.addStretch()

        btn_copy_freeze = QPushButton("📋 Freeze", self.panel)
        self.style_copy_button(btn_copy_freeze)
        btn_copy_freeze.clicked.connect(lambda: self.copy_single_link("freeze"))
        r_freeze.addWidget(btn_copy_freeze)
        p_layout.addLayout(r_freeze)

        # Ghost Row
        r_ghost = QHBoxLayout()
        self.lbl_ghost = QLabel("Ghost", self.panel)
        self.lbl_ghost.setStyleSheet("color: #94a3b8; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: none;")
        r_ghost.addWidget(self.lbl_ghost)
        r_ghost.addStretch()

        btn_copy_ghost = QPushButton("📋 Ghost", self.panel)
        self.style_copy_button(btn_copy_ghost)
        btn_copy_ghost.clicked.connect(lambda: self.copy_single_link("ghost"))
        r_ghost.addWidget(btn_copy_ghost)
        p_layout.addLayout(r_ghost)

        p_layout.addStretch()

        # Copy Remote Web Link Button
        self.btn_copy_links = QPushButton("🌐 Copy Web Remote Link", self.panel)
        self.btn_copy_links.setCursor(Qt.PointingHandCursor)
        self.btn_copy_links.setStyleSheet("""
            QPushButton {
                background: rgba(0, 242, 254, 0.1);
                color: #00f2fe;
                font-family: 'Consolas';
                font-size: 10px;
                font-weight: bold;
                border: 1px solid rgba(0, 242, 254, 0.3);
                border-radius: 6px;
                padding: 4px;
            }
            QPushButton:hover {
                background: #00f2fe;
                color: #08090d;
            }
        """)
        self.btn_copy_links.clicked.connect(self.copy_remote_links)
        p_layout.addWidget(self.btn_copy_links)

        layout.addWidget(self.panel)

        # Particle background overlay
        self.particles = ParticleCanvas(self.panel)
        self.particles.resize(300, 210)
        self.particles.raise_()

        # Status Update Timer
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_live_status)
        self.timer.start(250)

    def style_copy_button(self, btn):
        btn.setFixedSize(65, 22)
        btn.setCursor(Qt.PointingHandCursor)
        btn.setStyleSheet("""
            QPushButton {
                background: rgba(255, 255, 255, 0.06);
                color: #38bdf8;
                font-family: 'Consolas';
                font-size: 9px;
                font-weight: bold;
                border: 1px solid rgba(56, 189, 248, 0.3);
                border-radius: 4px;
            }
            QPushButton:hover {
                background: #38bdf8;
                color: #08090d;
            }
        """)

    def copy_single_link(self, mode):
        base_url = get_clean_base_url()
        target_link = f"{base_url}/{mode}?key={current_key}"
        cb = QApplication.clipboard()
        cb.setText(target_link)
        QMessageBox.information(self, "Đã Copy Link", f"Đã sao chép link [{mode.upper()}]:\n{target_link}")

    def update_live_status(self):
        with clients_lock:
            c = clients[0] if clients else None
            if c:
                if c.tele_active:
                    self.lbl_tele.setText("Telekill  [ ON ]")
                    self.lbl_tele.setStyleSheet("color: #ff4500; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: none;")
                else:
                    self.lbl_tele.setText("Telekill")
                    self.lbl_tele.setStyleSheet("color: #94a3b8; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: none;")

                if c.freeze_active:
                    self.lbl_freeze.setText("Freeze    [ ON ]")
                    self.lbl_freeze.setStyleSheet("color: #00aaff; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: none;")
                else:
                    self.lbl_freeze.setText("Freeze")
                    self.lbl_freeze.setStyleSheet("color: #94a3b8; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: none;")

                if c.ghost_active:
                    self.lbl_ghost.setText("Ghost     [ ON ]")
                    self.lbl_ghost.setStyleSheet("color: #c084fc; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: none;")
                else:
                    self.lbl_ghost.setText("Ghost")
                    self.lbl_ghost.setStyleSheet("color: #94a3b8; font-family: 'Consolas'; font-size: 10px; font-weight: bold; border: none;")

    def copy_remote_links(self):
        base_url = get_clean_base_url()
        target_link = f"{base_url}/?key={current_key}"
        cb = QApplication.clipboard()
        cb.setText(target_link)
        QMessageBox.information(self, "Copy Links", f"Đã copy Web Remote Control Link:\n{target_link}")

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.drag_position = event.globalPos() - self.frameGeometry().topLeft()
            event.accept()

    def mouseMoveEvent(self, event):
        if event.buttons() == Qt.LeftButton and self.drag_position:
            self.move(event.globalPos() - self.drag_position)
            event.accept()

# === KEY EXPIRY PANEL WINDOW ===
class KeyExpiryPanelWindow(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowFlags(
            Qt.WindowStaysOnTopHint |
            Qt.FramelessWindowHint |
            Qt.Tool
        )
        self.setFixedSize(300, 105)

        self._dragging = False
        self._drag_position = QPoint()

        self.setStyleSheet("""
            QFrame#ExpiryPanel {
                background-color: rgba(9, 12, 20, 0.94);
                border: 1.5px solid rgba(234, 179, 8, 0.5);
                border-radius: 10px;
            }
            QLabel { border: none; font-family: 'Consolas', 'Segoe UI', monospace; }
        """)
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        
        self.panel = QFrame(self)
        self.panel.setObjectName("ExpiryPanel")
        
        p_layout = QVBoxLayout(self.panel)
        p_layout.setContentsMargins(12, 8, 12, 8)
        p_layout.setSpacing(5)

        # Title bar
        tb = QHBoxLayout()
        dot = QLabel("🟡", self.panel)
        dot.setStyleSheet("font-size: 8px;")
        tb.addWidget(dot)

        lbl_title = QLabel("THỜI HẠN KEY VIP", self.panel)
        lbl_title.setStyleSheet("color: #00f2fe; font-size: 11px; font-weight: bold;")
        tb.addWidget(lbl_title)
        tb.addStretch()

        btn_close = QPushButton("✕", self.panel)
        btn_close.setFixedSize(16, 16)
        btn_close.setCursor(Qt.PointingHandCursor)
        btn_close.setStyleSheet("""
            QPushButton { background: transparent; color: #64748b; font-weight: bold; border: none; font-size: 11px; }
            QPushButton:hover { color: #ef4444; }
        """)
        btn_close.clicked.connect(self.hide)
        tb.addWidget(btn_close)
        p_layout.addLayout(tb)

        # User Key Row
        r_user = QHBoxLayout()
        lbl_usr = QLabel("User :", self.panel)
        lbl_usr.setStyleSheet("color: #94a3b8; font-size: 11px; font-weight: bold;")
        r_user.addWidget(lbl_usr)
        r_user.addStretch()
        self.val_user = QLabel(current_key if current_key else "KEY-VIP-HOTSPOT", self.panel)
        self.val_user.setStyleSheet("color: #00f2fe; font-size: 11px; font-weight: bold;")
        r_user.addWidget(self.val_user)
        p_layout.addLayout(r_user)

        # Time Expiry Row
        r_time = QHBoxLayout()
        lbl_tm = QLabel("Time :", self.panel)
        lbl_tm.setStyleSheet("color: #94a3b8; font-size: 11px; font-weight: bold;")
        r_time.addWidget(lbl_tm)
        r_time.addStretch()
        self.val_time = QLabel(get_formatted_key_time(), self.panel)
        self.val_time.setStyleSheet("color: #eab308; font-size: 12px; font-weight: bold;")
        r_time.addWidget(self.val_time)
        p_layout.addLayout(r_time)

        layout.addWidget(self.panel)

        # Timer for live update
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_expiry_info)
        self.timer.start(1000)

    def showEvent(self, event):
        super().showEvent(event)
        if is_stream_mode_active:
            apply_stream_mode_global(True)

    def update_expiry_info(self):
        if hasattr(self, 'val_time'):
            self.val_time.setText(get_formatted_key_time())
        if hasattr(self, 'val_user') and current_key:
            self.val_user.setText(current_key)

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self._dragging = True
            self._drag_position = event.globalPos() - self.pos()
            event.accept()

    def mouseMoveEvent(self, event):
        if self._dragging:
            self.move(event.globalPos() - self._drag_position)
            event.accept()

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.LeftButton:
            self._dragging = False
            event.accept()

main_win = None
keybinds_panel_win = None
status_panel_win = None
key_expiry_panel_win = None

def on_auth_success():
    global main_win, target_device_info, clients, keybinds_panel_win, status_panel_win, key_expiry_panel_win
    
    with clients_lock:
        clients = [
            ClientConfig(1, 10808),
            ClientConfig(2, 10809),
            ClientConfig(3, 10810),
            ClientConfig(4, 10811)
        ]
    
    local_ip = get_local_ip()
    target_device_info["os"] = "Mobile / PC"
    target_device_info["name"] = f"Hotspot / Wi-Fi ({local_ip})"
    
    start_http_server()
    start_socks5_proxy()
    threading.Thread(target=find_game_background, daemon=True).start()
    start_engine()
    threading.Thread(target=cloudflare_monitor_loop, daemon=True).start()
    
    print_links_console(current_key)
    
    register_all_pc_hotkeys()
    
    global main_window_instance
    main_win = HoangHaMenu(target_device_info)
    main_window_instance = main_win
    main_win.show()

def print_vip_console_logo():
    try:
        if sys.platform == 'win32':
            ctypes.windll.kernel32.SetConsoleTitleW("⚡ NETWORKING HOTSPOT VIP ANTI-CRACK ENGINE ⚡")
    except Exception:
        pass
    
    banner = r"""
========================================================================
  ███╗   ██╗███████╗████████╗██╗    ██╗██████╗ ██████╗ ██╗  ██╗
  ████╗  ██║██╔════╝╚══██╔══╝██║    ██║██╔══██╗██╔══██╗██║  ██║
  ██╔██╗ ██║█████╗     ██║   ██║ █╗ ██║██║  ██║██████╔╝███████║
  ██║╚██╗██║██╔══╝     ██║   ██║███╗██║██║  ██║██╔══██╗██╔══██║
  ██║ ╚████║███████╗   ██║   ╚███╔███╔╝██████╔╝██║  ██║██║  ██║
  ╚═╝  ╚═══╝╚══════╝   ╚═╝    ╚══╝╚══╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
 ----------------------------------------------------------------------
        🔥 NETWORKING HOTSPOT - VIP ANTI-CRACK C++ PRO CORE v4.0 🔥
           [⚡ Multi-Layer Anti-Debug | 🛡️ Process Shield | 🔒 RAM Guard]
========================================================================
"""
    print(banner, flush=True)

def print_links_console(key_str):
    local_ip = get_local_ip()
    base_url = f"http://{local_ip}:20000"
    print("\n============================================================", flush=True)
    print(" [⚡ NETWORKING HOTSPOT REMOTE CONTROL LINKS GENERATED]", flush=True)
    print("------------------------------------------------------------", flush=True)
    print(f" [+] LINK TELEKILL (ON/OFF):  {base_url}/tele?slot=1&key={key_str}", flush=True)
    print(f" [+] LINK FREEZE   (ON/OFF):  {base_url}/freeze?slot=1&key={key_str}", flush=True)
    print(f" [+] LINK GHOST    (ON/OFF):  {base_url}/ghost?slot=1&key={key_str}", flush=True)
    print(f" [+] LINK WEB REMOTE CONTROL: {base_url}/?slot=1&key={key_str}", flush=True)
    print("============================================================\n", flush=True)

if __name__ == '__main__':
    try:
        write_log("Application main entry point reached.")
        check_anti_debug()
        start_continuous_security_guard()
        print_vip_console_logo()
        
        app = QApplication(sys.argv)
        app.setQuitOnLastWindowClosed(False)
        font = QFont("Segoe UI", 9)
        app.setFont(font)
        
        app_icon = get_app_logo_icon()
        if not app_icon.isNull():
            app.setWindowIcon(app_icon)
        
        auth_dialog = KeyAuthWindow()
        if hasattr(auth_dialog, 'setWindowIcon') and not app_icon.isNull():
            auth_dialog.setWindowIcon(app_icon)
            
        if auth_dialog.exec_() == QDialog.Accepted:
            write_log("Key authentication accepted.")
            on_auth_success()
            sys.exit(app.exec_())
        else:
            write_log("Key authentication rejected.")
            sys.exit(0)
    except Exception as e:
        tb = traceback.format_exc()
        show_fatal_error("Runtime Crash", f"An unhandled exception occurred: {e}\n\nTraceback:\n{tb}")
