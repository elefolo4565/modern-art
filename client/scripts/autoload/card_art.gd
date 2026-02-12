extends Node

## Procedural card art generator. Each artist has a unique visual theme.
## Uses card_id as seed so the same card always produces the same art.

var _cache: Dictionary = {}

const ART_SIZE := 200

func get_card_texture(card_id: int, artist: String) -> ImageTexture:
	if card_id in _cache:
		return _cache[card_id]
	var img := _generate_art(card_id, artist)
	var tex := ImageTexture.create_from_image(img)
	_cache[card_id] = tex
	return tex

func _generate_art(card_id: int, artist: String) -> Image:
	var img := Image.create(ART_SIZE, ART_SIZE, false, Image.FORMAT_RGBA8)
	var base_color: Color = GameState.ARTIST_COLORS.get(artist, Color.WHITE)
	# Fill background with a light tint of the artist color
	var bg := Color(
		lerp(1.0, base_color.r, 0.12),
		lerp(1.0, base_color.g, 0.12),
		lerp(1.0, base_color.b, 0.12),
		1.0
	)
	img.fill(bg)

	var rng := RandomNumberGenerator.new()
	rng.seed = card_id * 31337 + 42

	match artist:
		"Orange Tarou": _draw_circles(img, rng, base_color)
		"Green Tarou": _draw_waves(img, rng, base_color)
		"Blue Tarou": _draw_grid(img, rng, base_color)
		"Yellow Tarou": _draw_radial(img, rng, base_color)
		"Red Tarou": _draw_slashes(img, rng, base_color)

	return img

# --- Orange Tarou: Overlapping circles composition ---
func _draw_circles(img: Image, rng: RandomNumberGenerator, base: Color) -> void:
	var count := rng.randi_range(5, 9)
	for i in range(count):
		var cx := rng.randf_range(20, ART_SIZE - 20)
		var cy := rng.randf_range(20, ART_SIZE - 20)
		var radius := rng.randf_range(20, 70)
		var hue_shift := rng.randf_range(-0.06, 0.06)
		var sat_shift := rng.randf_range(-0.1, 0.15)
		var alpha := rng.randf_range(0.25, 0.6)
		var c := base
		c.h = fmod(c.h + hue_shift + 1.0, 1.0)
		c.s = clampf(c.s + sat_shift, 0.2, 1.0)
		c.a = alpha
		_fill_circle(img, cx, cy, radius, c)
	# Add a few small accent circles
	for i in range(3):
		var cx := rng.randf_range(30, ART_SIZE - 30)
		var cy := rng.randf_range(30, ART_SIZE - 30)
		var radius := rng.randf_range(5, 15)
		var c := Color(base.r * 0.6, base.g * 0.5, base.b * 0.4, 0.7)
		_fill_circle(img, cx, cy, radius, c)

# --- Green Tarou: Organic wave patterns ---
func _draw_waves(img: Image, rng: RandomNumberGenerator, base: Color) -> void:
	var wave_count := rng.randi_range(4, 7)
	for w in range(wave_count):
		var freq := rng.randf_range(0.02, 0.06)
		var amp := rng.randf_range(15, 50)
		var phase := rng.randf_range(0, TAU)
		var y_offset := rng.randf_range(20, ART_SIZE - 20)
		var thickness := rng.randf_range(8, 25)
		var hue_shift := rng.randf_range(-0.05, 0.08)
		var alpha := rng.randf_range(0.3, 0.6)
		var c := base
		c.h = fmod(c.h + hue_shift + 1.0, 1.0)
		c.s = clampf(c.s + rng.randf_range(-0.1, 0.1), 0.3, 1.0)
		c.v = clampf(c.v + rng.randf_range(-0.1, 0.1), 0.4, 1.0)
		c.a = alpha
		for x in range(ART_SIZE):
			var wave_y := y_offset + sin(x * freq + phase) * amp
			for t in range(int(thickness)):
				var py := int(wave_y + t - thickness / 2.0)
				if py >= 0 and py < ART_SIZE:
					var existing := img.get_pixel(x, py)
					img.set_pixel(x, py, _blend(existing, c))
	# Add leaf-like dots
	for i in range(rng.randi_range(8, 15)):
		var cx := rng.randf_range(10, ART_SIZE - 10)
		var cy := rng.randf_range(10, ART_SIZE - 10)
		var r := rng.randf_range(3, 8)
		var c := Color(base.r * 0.7, base.g * 1.1, base.b * 0.6, 0.5)
		c = c.clamp()
		_fill_circle(img, cx, cy, r, c)

# --- Blue Tarou: Geometric grid patterns ---
func _draw_grid(img: Image, rng: RandomNumberGenerator, base: Color) -> void:
	var cell_size := rng.randi_range(20, 40)
	var cols := ART_SIZE / cell_size + 1
	var rows := ART_SIZE / cell_size + 1
	var offset_x := rng.randi_range(0, cell_size / 2)
	var offset_y := rng.randi_range(0, cell_size / 2)

	for row in range(rows):
		for col in range(cols):
			var x0 := col * cell_size + offset_x
			var y0 := row * cell_size + offset_y
			var fill_chance := rng.randf()
			if fill_chance < 0.55:
				var hue_shift := rng.randf_range(-0.05, 0.05)
				var val_shift := rng.randf_range(-0.15, 0.15)
				var alpha := rng.randf_range(0.2, 0.55)
				var c := base
				c.h = fmod(c.h + hue_shift + 1.0, 1.0)
				c.v = clampf(c.v + val_shift, 0.3, 1.0)
				c.a = alpha
				var margin := rng.randi_range(1, 3)
				_fill_rect(img, x0 + margin, y0 + margin,
					cell_size - margin * 2, cell_size - margin * 2, c)
			elif fill_chance < 0.7:
				# Diagonal line in cell
				var c := Color(base.r * 0.8, base.g * 0.85, base.b * 1.1, 0.4)
				c = c.clamp()
				_draw_line(img, x0, y0, x0 + cell_size, y0 + cell_size, c, 2)

# --- Yellow Tarou: Radial burst patterns ---
func _draw_radial(img: Image, rng: RandomNumberGenerator, base: Color) -> void:
	var burst_count := rng.randi_range(2, 4)
	for b in range(burst_count):
		var cx := rng.randf_range(30, ART_SIZE - 30)
		var cy := rng.randf_range(30, ART_SIZE - 30)
		var ray_count := rng.randi_range(8, 20)
		var max_len := rng.randf_range(40, 100)
		for r in range(ray_count):
			var angle := rng.randf_range(0, TAU)
			var length := rng.randf_range(max_len * 0.3, max_len)
			var thickness := rng.randi_range(2, 5)
			var hue_shift := rng.randf_range(-0.04, 0.04)
			var alpha := rng.randf_range(0.3, 0.65)
			var c := base
			c.h = fmod(c.h + hue_shift + 1.0, 1.0)
			c.s = clampf(c.s + rng.randf_range(-0.1, 0.1), 0.4, 1.0)
			c.a = alpha
			var ex := cx + cos(angle) * length
			var ey := cy + sin(angle) * length
			_draw_line(img, int(cx), int(cy), int(ex), int(ey), c, thickness)
		# Center glow
		var glow_c := Color(base.r, base.g, base.b, 0.4)
		_fill_circle(img, cx, cy, rng.randf_range(8, 18), glow_c)

# --- Red Tarou: Diagonal slash patterns ---
func _draw_slashes(img: Image, rng: RandomNumberGenerator, base: Color) -> void:
	var slash_count := rng.randi_range(6, 12)
	for i in range(slash_count):
		var x0 := rng.randf_range(-30, ART_SIZE + 30)
		var y0 := rng.randf_range(-30, ART_SIZE + 30)
		var angle := rng.randf_range(-0.8, 0.8) + (PI / 4.0 if rng.randf() > 0.5 else -PI / 4.0)
		var length := rng.randf_range(60, 180)
		var thickness := rng.randi_range(4, 16)
		var hue_shift := rng.randf_range(-0.04, 0.04)
		var alpha := rng.randf_range(0.25, 0.6)
		var c := base
		c.h = fmod(c.h + hue_shift + 1.0, 1.0)
		c.v = clampf(c.v + rng.randf_range(-0.15, 0.1), 0.35, 1.0)
		c.a = alpha
		var ex := x0 + cos(angle) * length
		var ey := y0 + sin(angle) * length
		_draw_line(img, int(x0), int(y0), int(ex), int(ey), c, thickness)
	# Add a few angular accent shapes
	for i in range(rng.randi_range(2, 4)):
		var x := rng.randi_range(20, ART_SIZE - 40)
		var y := rng.randi_range(20, ART_SIZE - 40)
		var w := rng.randi_range(15, 40)
		var h := rng.randi_range(15, 40)
		var c := Color(base.r * 0.7, base.g * 0.3, base.b * 0.3, 0.35)
		c = c.clamp()
		_fill_rect(img, x, y, w, h, c)

# --- Drawing primitives ---

func _fill_circle(img: Image, cx: float, cy: float, radius: float, color: Color) -> void:
	var r2 := radius * radius
	var x0 := maxi(int(cx - radius), 0)
	var x1 := mini(int(cx + radius) + 1, ART_SIZE)
	var y0 := maxi(int(cy - radius), 0)
	var y1 := mini(int(cy + radius) + 1, ART_SIZE)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r2:
				var existing := img.get_pixel(x, y)
				img.set_pixel(x, y, _blend(existing, color))

func _fill_rect(img: Image, x0: int, y0: int, w: int, h: int, color: Color) -> void:
	var x_start := maxi(x0, 0)
	var x_end := mini(x0 + w, ART_SIZE)
	var y_start := maxi(y0, 0)
	var y_end := mini(y0 + h, ART_SIZE)
	for y in range(y_start, y_end):
		for x in range(x_start, x_end):
			var existing := img.get_pixel(x, y)
			img.set_pixel(x, y, _blend(existing, color))

func _draw_line(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color, thickness: int = 1) -> void:
	# Bresenham with thickness
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	var half := thickness / 2

	while true:
		for ty in range(-half, half + 1):
			for tx in range(-half, half + 1):
				var px := x0 + tx
				var py := y0 + ty
				if px >= 0 and px < ART_SIZE and py >= 0 and py < ART_SIZE:
					var existing := img.get_pixel(px, py)
					img.set_pixel(px, py, _blend(existing, color))
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

func _blend(bg: Color, fg: Color) -> Color:
	var a := fg.a
	return Color(
		bg.r * (1.0 - a) + fg.r * a,
		bg.g * (1.0 - a) + fg.g * a,
		bg.b * (1.0 - a) + fg.b * a,
		1.0
	)
