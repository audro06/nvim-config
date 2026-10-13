# nvim-config: WSL에서 PIL의 Image.show()를 Windows 기본 이미지 뷰어로 연다.
# molten.nvim의 그래프 팝업(molten_auto_image_popup)이 이걸 사용한다.
# jupyter.lua의 build 단계가 nvim 전용 Python venv에 복사하고 .pth로 시작 시 import되게 한다.
def _register_windows_viewer():
    try:
        with open("/proc/version") as f:
            if "microsoft" not in f.read().lower():
                return
        from PIL import ImageShow
    except Exception:
        return

    import subprocess

    class WindowsViewer(ImageShow.Viewer):
        format = "PNG"
        options = {"compress_level": 1}

        def show_file(self, path, **options):
            win_path = subprocess.run(["wslpath", "-w", path], capture_output=True, text=True).stdout.strip()
            subprocess.Popen(["explorer.exe", win_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return 1

    ImageShow.register(WindowsViewer, order=-1)


_register_windows_viewer()
