"""Bounded medicine thumbnails travel with immutable prescription snapshots."""

import base64
from io import BytesIO

from PIL import Image

PREFIX = "data:image/png;base64,"


def normalize_medicine_image(value: str | None) -> str | None:
    if value is None or value == "":
        return value
    if not value.startswith(PREFIX):
        raise ValueError("请上传 PNG/JPEG 药品图片。")
    try:
        data = base64.b64decode(value[len(PREFIX) :], validate=True)
        if len(data) > 1100000:
            raise ValueError("药品图片过大。")
        with Image.open(BytesIO(data)) as source:
            if source.format != "PNG" or max(source.size) > 512 or min(source.size) < 1:
                raise ValueError("药品图片须为最长边不超过 512 像素的 PNG 缩略图。")
            source.load()
            clean = source.convert("RGBA")
            clean.info.clear()
            output = BytesIO()
            clean.save(output, format="PNG")
        if output.tell() > 1100000:
            raise ValueError("药品图片过大。")
        return PREFIX + base64.b64encode(output.getvalue()).decode("ascii")
    except (OSError, ValueError, Image.DecompressionBombError) as error:
        raise ValueError("药品图片无法读取，请重新选择图片。") from error
