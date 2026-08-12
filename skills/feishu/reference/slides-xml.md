# Slides XML 参考（SML 2.0）

## 基本结构

```xml
<presentation xmlns="http://www.larkoffice.com/sml/2.0" width="960" height="540">
  <title>演示文稿标题</title>
</presentation>
```

```xml
<slide xmlns="http://www.larkoffice.com/sml/2.0">
  <style><!-- 页面背景 --></style>
  <data><!-- 内容元素 --></data>
  <note><!-- 备注 --></note>
</slide>
```

## 画布坐标

固定 960×540 单位（16:9 比例）。所有元素使用 `topLeftX`、`topLeftY`、`width`、`height` 定位。

## 核心元素

### shape（文本框/形状）

```xml
<shape type="text" topLeftX="80" topLeftY="80" width="800" height="120">
  <content textType="title">
    <p textAlign="center"><strong><span color="rgb(255,255,255)" fontSize="44">标题</span></strong></p>
  </content>
</shape>
```

- `type`：`text`（文本框）、`rect`（矩形）、`ellipse`（椭圆）、`triangle`（三角）、`custom`
- **必须**包含 `<content/>` 子元素（即使为空）
- `textType`：`title`（54pt）、`headline`（38pt）、`sub-headline`（32pt）、`body`（16pt）、`caption`（12pt）
- `<content>` 可包含 `<p>`、`<ul>`、`<ol>`

### img（图片）

```xml
<img src="file_token_from_upload" topLeftX="540" topLeftY="157" width="400" height="225"/>
```

- `src` **必须**是 `feishu slides upload-image` 返回的 `file_token`
- HTTP/HTTPS 外部 URL **不会渲染**
- `width:height` 应匹配原图比例，否则会被裁剪
- 创建时可用 `@./local.png` 占位符自动上传

### line（线条）

```xml
<line startX="60" startY="350" endX="180" endY="350">
  <border color="rgb(59,130,246)" width="3"/>
</line>
```

### table（表格）

```xml
<table topLeftX="60" topLeftY="120" width="840" height="300">
  <colgroup><col width="280"/><col width="280"/><col width="280"/></colgroup>
  <tr><td><p>单元格</p></td></tr>
</table>
```

## 背景样式

```xml
<!-- 纯色 -->
<style><fill><fillColor color="rgb(248,250,252)"/></fill></style>

<!-- 渐变（必须用 rgba + 百分比 stop） -->
<style><fill><fillColor color="linear-gradient(135deg,rgba(15,23,42,1) 0%,rgba(56,97,140,1) 100%)"/></fill></style>
```

> ⚠️ 渐变**必须**用 `rgba()` 格式。`rgb()` 或省略 stop 百分比会导致服务端回退为白色。

## 文本格式

```xml
<p textAlign="center">
  <strong><span color="rgb(255,255,255)" fontSize="44">粗体标题</span></strong>
</p>
<p>
  <span color="rgb(51,65,85)" fontSize="15">普通文本</span>
</p>
```

行间距：`<content lineSpacing="multiple:1.8">`

## 形状填充和边框

```xml
<shape type="rect" topLeftX="60" topLeftY="120" width="260" height="160">
  <fill><fillColor color="rgb(255,255,255)"/></fill>
  <border color="rgb(226,232,240)" width="1"/>
  <content>...</content>
</shape>
```

## 常见错误

| 错误码 | 含义 | 解决 |
|--------|------|------|
| 3350001 | 无效参数（block_id 不存在、XML 格式错误等） | 检查 block_id 是否存在、XML 结构是否正确 |
| 1061002 | 上传 parent_type 错误 | slides 图片上传**必须**用 `parent_type=slide_file` |
| 99991400 | 请求频率限制 | 自动重试，或稍后再试 |
| 99991672 | 缺少 API 权限 | 在飞书开放平台为应用申请 slides 相关权限 |

## block_replace 注意事项

1. `replacement` 根元素**必须**携带 `id="<block_id>"` — CLI 会自动注入
2. `<shape>` 元素**必须**包含 `<content/>` 子元素 — CLI 会自动注入
3. 单次最多 200 个 parts，操作是原子的（全部成功或全部回滚）
4. 坐标不能超出 960×540 画布范围
