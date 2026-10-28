"""Small authenticated profile thumbnails, stored with resident data and versions."""

import base64
from io import BytesIO

from PIL import Image

PRESETS = {f"assets/images/avatars/{name}.png" for name in ("wang", "zhang", "li", "chen")}
PREFIX = "data:image/png;base64,"


def normalize_avatar(value: str | None) -> str | None:
    if value is None or value == "" or value in PRESETS:
        return value
    if not value.startswith(PREFIX):
        raise ValueError("请选择预设头像或上传 PNG/JPEG 图片。")
    try:
        data = base64.b64decode(value[len(PREFIX) :], validate=True)
        if len(data) > 270000:
            raise ValueError("头像图片过大。")
        with Image.open(BytesIO(data)) as source:
            if source.format != "PNG" or max(source.size) > 256 or min(source.size) < 1:
                raise ValueError("头像须为最长边不超过 256 像素的 PNG 缩略图。")
            source.load()
            clean = source.convert("RGBA")
            clean.info.clear()
            output = BytesIO()
            clean.save(output, format="PNG")
        return PREFIX + base64.b64encode(output.getvalue()).decode("ascii")
    except (OSError, ValueError, Image.DecompressionBombError) as error:
        raise ValueError("头像无法读取，请重新选择图片。") from error
