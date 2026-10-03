class_name PhotoStore
extends RefCounted
## Saves photo-mode captures to user://photos and loads small thumbnails for the album.

const DIR := "user://photos"
const THUMB_WIDTH := 320

static var _cache := {}


## Crops `rect` from the image, stores a PNG and returns its path ("" on failure).
static func save(img: Image, rect: Rect2i) -> String:
	if img == null or img.is_empty():
		return ""
	var r := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x < 8 or r.size.y < 8:
		return ""
	var crop := img.get_region(r)
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR.path_join("foto_%d_%d.png" % [int(Time.get_unix_time_from_system()), randi() % 10000])
	if crop.save_png(path) != OK:
		return ""
	return path


static func load_thumbnail(path: String) -> Texture2D:
	if path == "" or not FileAccess.file_exists(path):
		return null
	if _cache.has(path):
		return _cache[path]
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	if img.get_width() > THUMB_WIDTH:
		img.resize(THUMB_WIDTH, int(img.get_height() * THUMB_WIDTH / float(img.get_width())), Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_cache[path] = tex
	return tex
