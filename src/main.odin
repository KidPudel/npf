package main

import "core:fmt"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

// constants --------------------------------------------

FONT_SIZE :: 20

Sounds :: enum u8 {
	NOT_ENOUGH_ENERGY,
}

// shape-shifter, for flexible fan-out data structure "capabilities"
Machine_Variant :: union {
	Processor,
	Battery,
	Creator,
}

Processor :: struct {}

Battery :: struct {}

Creator :: struct {}


Machine :: struct {
	position: [2]f32,
	size:     [2]f32,
	color:    rl.Color,
	price:    int,
	selected: bool,
	// shape-shifter
	variant:  Machine_Variant,
}


// shop state

Shop :: struct {
	machines:  [dynamic]Machine,
	shop_open: bool,
}

Factory :: struct {
	sounds:                 [Sounds]rl.Sound,
	machines:               [dynamic]Machine,
	camera:                 rl.Camera2D,
	window_size:            [2]i32,
	shop:                   Shop,
	energy:                 int,
	since_energy_increase:  f32,
	selected_machine_index: int,
}


// populate and create data structure instance with filled data
init_factory :: proc() -> ^Factory {
	factory_ptr := new(Factory)

	// init sounds

	not_enough_energy_sound := rl.LoadSound("assets/not_enough_energy.wav")


	machines := make([dynamic]Machine, 1)

	machines_in_shop := make([dynamic]Machine, 2)
	append(&machines_in_shop, ..[]Machine{new_machine(Processor{}), new_machine(Battery{})}[:])

	factory_ptr^ = Factory {
		//energy = 100,
		since_energy_increase = 0,
		sounds = {.NOT_ENOUGH_ENERGY = not_enough_energy_sound},
		machines = machines,
		camera = rl.Camera2D {
			target = {0, 0}, // target will be placed not at the center, but at the 0, 0 positions of the screen
			zoom   = 1.0, // to see
		},
		window_size = {640, 480},
		selected_machine_index = -1,
		shop = Shop{shop_open = false, machines = machines_in_shop},
	}

	append(&factory_ptr.machines, new_machine(Creator{}))


	return factory_ptr
}


// todo: kill factory


new_machine :: proc(machine_variant: Machine_Variant, positon: [2]f32 = {0, 0}) -> Machine {
	switch variant in machine_variant {
	case Processor:
		return Machine {
			position = positon,
			size = {20, 40},
			color = rl.BLUE,
			price = 40,
			selected = false,
			variant = Processor{},
		}
	case Battery:
		return Machine {
			position = positon,
			size = {30, 30},
			color = rl.ORANGE,
			price = 20,
			selected = false,
			variant = Battery{},
		}
	case Creator:
		return Machine {
			position = positon,
			size = {40, 60},
			color = rl.BLACK,
			price = 0,
			selected = false,
			variant = Creator{},
		}
	case:
		panic("unknown machine type while getting new machine")

	}

}


draw_info_factory :: proc(factory: Factory) {
	buf: [4]byte

	energy_str := strings.clone_to_cstring(strconv.itoa(buf[:], factory.energy))
	rl.DrawText(
		energy_str,
		i32(factory.window_size.x - FONT_SIZE * 2),
		i32(factory.window_size.y - FONT_SIZE),
		FONT_SIZE,
		rl.YELLOW,
	)
}

draw_machines :: proc(factory: Factory) {
	for machine in factory.machines {
		if machine.selected {
			rl.DrawRectangleV(
				{machine.position.x - 2, machine.position.y - 2},
				{machine.size.x + 4, machine.size.y + 4},
				rl.RED,
			)
		}
		rl.DrawRectangleV(machine.position, machine.size, machine.color)
	}
}

move_camera :: proc(factory: ^Factory) {
	// offset that is exists for the camera to meet the target
	if rl.IsKeyDown(rl.KeyboardKey.A) {
		factory.camera.offset.x += 10
	}
	if rl.IsKeyDown(rl.KeyboardKey.D) {
		factory.camera.offset.x -= 10
	}
	if rl.IsKeyDown(rl.KeyboardKey.W) {
		factory.camera.offset.y += 10
	}
	if rl.IsKeyDown(rl.KeyboardKey.S) {
		factory.camera.offset.y -= 10
	}

}


// adaptive cursor coordinates
get_position_in_space :: proc(factory: Factory) -> [2]f32 {
	return {
		f32(rl.GetMouseX()) - factory.camera.offset.x,
		f32(rl.GetMouseY()) - factory.camera.offset.y,
	}
}


machine_in_range :: proc(cursor_position: [2]f32, machine: Machine) -> bool {
	hover_on_x :=
		cursor_position.x <= machine.position.x + machine.size.x &&
		cursor_position.x >= machine.position.x
	hover_on_y :=
		cursor_position.y <= machine.position.y + machine.size.y &&
		cursor_position.y >= machine.position.y

	return hover_on_x && hover_on_y
}


drag_machine :: proc(factory: ^Factory) {
	if !factory.shop.shop_open {
		if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
			cursor_position := get_position_in_space(factory^)
			for machine, i in factory.machines {

				can_drag := machine_in_range(cursor_position, machine)

				if can_drag {
					factory.selected_machine_index = i // remove
					factory.machines[i].selected = true
					if _, isCreator := machine.variant.(Creator); !isCreator {
						break
					}
				} else {
					factory.selected_machine_index = -1
					if factory.machines[i].selected {
						factory.machines[i].selected = false
					}
				}
			}
		}
		// todo: make it less shit
		if factory.selected_machine_index >= 0 && rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
			if _, isCreator := factory.machines[factory.selected_machine_index].variant.(Creator);
			   !isCreator {
				cursor_position := get_position_in_space(factory^)
				factory.machines[factory.selected_machine_index].position = cursor_position
			}
		}

	}

}

draw_shop :: proc(factory: ^Factory) {
	if factory.shop.shop_open {
		shop_x, shop_y: f32 = 0, f32(factory.window_size.y) / 2.0
		fmt.println(shop_x, shop_y)

		rl.DrawRectangleV(
			{shop_x, shop_y},
			{f32(factory.window_size.x), f32(factory.window_size.y) / 2},
			rl.DARKBLUE,
		)

		shift: f32 = 0.0
		for &machine in factory.shop.machines {
			fmt.println(machine)
			machine.position = {shop_x + shift, shop_y * 1.5}
			fmt.println(machine.position)

			if machine.selected {
				rl.DrawRectangleV(
					{machine.position.x - 2, machine.position.y - 2},
					{machine.size.x + 4, machine.size.y + 4},
					rl.RED,
				)
			}
			rl.DrawRectangleV(machine.position, machine.size, machine.color)
			shift += machine.size.x * 2
		}
	}
}


interact_with_shop :: proc(factory: ^Factory) {
	if rl.IsKeyPressed(rl.KeyboardKey.E) {
		factory.shop.shop_open = true
	}
	if factory.shop.shop_open {
		if rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) {
			factory.shop.shop_open = false
		}

		if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
			cursor_positon_on_screen := [2]f32{f32(rl.GetMouseX()), f32(rl.GetMouseY())}

			for &machine in factory.shop.machines {
				in_range := machine_in_range(cursor_positon_on_screen, machine)
				if in_range {
					#partial switch v in machine.variant {
					case Processor:
						append(&factory.machines, new_machine(Processor{}))
					case Battery:
						append(&factory.machines, new_machine(Battery{}))
					case:
						panic("unknown machine")
					}
				}
			}
		}
	}

}

update_game_state :: proc(factory: ^Factory) {

	interact_with_shop(factory)

	move_camera(factory)
	drag_machine(factory)


	if rl.IsWindowResized() {
		factory.window_size.x = rl.GetScreenWidth()
		factory.window_size.y = rl.GetScreenHeight()
	}


	if factory.since_energy_increase > rl.GetFrameTime() * 30 {
		factory.since_energy_increase = 0
		factory.energy += 1
	}
	factory.since_energy_increase += rl.GetFrameTime()

}

draw_game_frame :: proc(factory: ^Factory) {
	rl.BeginDrawing()


	rl.ClearBackground(rl.GRAY)

	rl.BeginMode2D(factory.camera)

	// draw data from factory structure
	draw_machines(factory^)
	rl.EndMode2D()

	draw_shop(factory)
	draw_info_factory(factory^)

	rl.EndDrawing()
}


main :: proc() {
	// init
	factory := init_factory()
	defer free(factory) // todo: refactor properly


	// bit set
	flags: rl.ConfigFlags = {rl.ConfigFlag.WINDOW_RESIZABLE}
	rl.SetConfigFlags(flags)

	rl.InitWindow(factory.window_size.x, factory.window_size.y, "north pole factory")
	defer rl.CloseWindow()

	// must be initialized before loading any audio
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	rl.SetTargetFPS(60)

	rl.SetExitKey(rl.KeyboardKey.KEY_NULL)


	// game loop
	for !rl.WindowShouldClose() {

		update_game_state(factory)

		draw_game_frame(factory)
	}


}
