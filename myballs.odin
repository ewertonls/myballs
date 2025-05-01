package myballs

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:strings"
import rl "vendor:raylib"

WIDTH :: 1280
HEIGHT :: 720

Metaball :: struct {
	pos:       rl.Vector2,
	radius:    f32,
	speed:     rl.Vector2,
	direction: rl.Vector2,
	color_hue: f32,
	color:     rl.Color,
}


MB_SPEED :: 150
MAX_METABALLS :: 32
METABALLS_ORIGINAL_SPEEDS: [MAX_METABALLS]rl.Vector2 = {}
METABALLS: [MAX_METABALLS]Metaball = {}
generate_metaballs :: proc() {
	width := f32(WIDTH)
	height := f32(HEIGHT)
	dir_opts: []f32 = {1, -1}
	for i in 0 ..< len(METABALLS) {
		radius := 10 + rand.float32() * 30
		color_hue := rand.float32() * 360
		pos := rl.Vector2 {
			radius + (rand.float32() * f32(WIDTH - radius * 2)),
			radius + (rand.float32() * f32(HEIGHT - radius * 2)),
		}
		speed: rl.Vector2 = 20 + {rand.float32(), rand.float32()} * MB_SPEED

		METABALLS_ORIGINAL_SPEEDS[i] = speed
		METABALLS[i] = {
			pos       = pos,
			radius    = radius,
			speed     = speed,
			direction = {rand.choice(dir_opts), rand.choice(dir_opts)},
			color_hue = color_hue,
			color     = rl.ColorFromHSV(color_hue, rand.float32(), 1),
		}
	}
}


mb_fragment_shader_file := #load("./myballs.fs", string)

main :: proc() {
	rl.InitWindow(width = WIDTH, height = HEIGHT, title = "Myballs Demo")
	defer rl.CloseWindow()
	rl.SetWindowState({.VSYNC_HINT, .WINDOW_RESIZABLE, .WINDOW_ALWAYS_RUN})
	rl.SetTraceLogLevel(.ALL)

	shader_content, err := strings.clone_to_cstring(mb_fragment_shader_file)
	if err != nil {
		panic("could not load shader content")
	}
	mb_shader := rl.LoadShaderFromMemory(nil, shader_content)
	u_resolution := rl.GetShaderLocation(mb_shader, "u_resolution")
	u_metaballs := rl.GetShaderLocation(mb_shader, "u_metaballs")
	u_mbColors := rl.GetShaderLocation(mb_shader, "u_mbColors")

	generate_metaballs()
	bg_color :: rl.BLACK

	DEBUG_METABALLS := false

	for !rl.WindowShouldClose() {
		scr_width := rl.GetScreenWidth()
		scr_height := rl.GetScreenHeight()

		rl.BeginDrawing()
		rl.ClearBackground(bg_color)

		if rl.IsKeyPressed(.D) {
			DEBUG_METABALLS = !DEBUG_METABALLS
		}

		for &mb, i in METABALLS {

			if !rl.IsMouseButtonDown(.LEFT) {
				og_speed := METABALLS_ORIGINAL_SPEEDS[i]
				if mb.speed.x > og_speed.x || mb.speed.y > og_speed.y {
					mb.speed = linalg.lerp(mb.speed, og_speed, rl.GetFrameTime() * 2)
				}
			}

			if mb.pos.x + mb.radius * 2 >= f32(scr_width) || mb.pos.x <= 0 {
				mb.direction *= {-1, 1}
			}
			if mb.pos.y + mb.radius * 2 >= f32(scr_height) || mb.pos.y <= 0 {
				mb.direction *= {1, -1}
			}


			mb.pos += mb.speed * mb.direction * rl.GetFrameTime()
			mb.pos = linalg.lerp(
				mb.pos,
				rl.Vector2{f32(scr_width) / 2, f32(scr_height) / 2},
				rl.GetFrameTime() / MAX_METABALLS,
			)

			for &other_mb, index in METABALLS {
				if rl.IsMouseButtonDown(.RIGHT) {break}
				if rl.Vector2Distance(other_mb.pos, mb.pos) < 200 && mb.radius > other_mb.radius {
					mb_direction := other_mb.pos - mb.pos
					mb_direction = rl.Vector2Normalize(mb_direction) * -1
					mbs_distance := rl.Vector2Distance(other_mb.pos, mb.pos)

					if mbs_distance <= other_mb.radius {
						mb_direction *= -1
					}

					if !rl.CheckCollisionCircles(
						mb.pos + mb.radius,
						mb.radius,
						other_mb.pos + other_mb.radius,
						other_mb.radius,
					) {
						mb_direction *= -1
					}

					other_mb.direction = linalg.lerp(
						other_mb.direction,
						mb_direction,
						rl.GetFrameTime(),
					)
				}
			}

			MOUSE_INFLUENCE_RADIUS: f32 : 400
			if rl.IsMouseButtonDown(.RIGHT) {
				og_speed := METABALLS_ORIGINAL_SPEEDS[i]
				mouse_pos := rl.GetMousePosition()
				mouse_dir := mb.pos - mouse_pos
				mouse_dir = rl.Vector2Normalize(mouse_dir) * -1

				if rl.Vector2Distance(mb.pos, mouse_pos) < MOUSE_INFLUENCE_RADIUS * 3 {
					mb.direction = linalg.lerp(mb.direction, mouse_dir, rl.GetFrameTime())
					if mb.speed.x < og_speed.x * 5 || mb.speed.y < og_speed.y * 5 {
						mb.speed = linalg.lerp(mb.speed, og_speed * 30, rl.GetFrameTime())
					}
				}
			} else if rl.IsMouseButtonDown(.LEFT) {
				og_speed := METABALLS_ORIGINAL_SPEEDS[i]
				mouse_pos := rl.GetMousePosition()
				mouse_dir := mb.pos - mouse_pos
				mouse_dir = rl.Vector2Normalize(mouse_dir)

				if rl.Vector2Distance(mb.pos, mouse_pos) < MOUSE_INFLUENCE_RADIUS {
					mb.direction = mouse_dir
					if mb.speed.x < og_speed.x * 5 || mb.speed.y < og_speed.y * 5 {
						mb.speed *= 1.5
					}

				}
			}
		}

		// Custom shader
		resolution := rl.Vector2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
		rl.SetShaderValue(mb_shader, u_resolution, &resolution, .VEC2)

		metaballs_pos: [MAX_METABALLS]rl.Vector3
		metaballs_colors: [MAX_METABALLS]rl.Vector3
		for metaball, index in METABALLS {
			metaballs_pos[index] = {
				metaball.pos.x + metaball.radius,
				// Invert Y axis because of opengl shit
				f32(rl.GetScreenHeight()) - metaball.pos.y - (metaball.radius),
				metaball.radius,
			}
			color := rl.ColorNormalize(metaball.color)
			metaballs_colors[index] = color.xyz
		}
		rl.SetShaderValueV(
			mb_shader,
			rl.ShaderLocationIndex(u_metaballs),
			&metaballs_pos,
			.VEC3,
			MAX_METABALLS,
		)
		rl.SetShaderValueV(
			mb_shader,
			rl.ShaderLocationIndex(u_mbColors),
			&metaballs_colors,
			.VEC3,
			MAX_METABALLS,
		)

		rl.BeginShaderMode(mb_shader)
		rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), rl.WHITE)
		rl.EndShaderMode()

		if DEBUG_METABALLS {
			for mb in METABALLS {
				rl.DrawCircleLinesV(mb.pos + mb.radius, mb.radius, mb.color)
			}
		}

		rl.DrawFPS(10, 10)
		rl.EndDrawing()
	}
}
