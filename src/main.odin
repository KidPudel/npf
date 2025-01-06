package main

import "core:fmt"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

// constants --------------------------------------------

WIDTH :: 640
HEIGHT :: 480
FONT_SIZE :: 20

// strict meaningful access
Sounds :: enum u8 {
	NOT_ENOUGH_ENERGY,
}

// shape-shifter, for flexible fan-out data structure "capabilities"
// since we need hierarchical data control, we could also utilize it as an enum
Machine_Variant :: union {
	Processor,
	Battery,
	Creator,
}

Processor :: struct {}

Battery :: struct {}

Creator :: struct {}


Machine :: struct {
	// independent, not unique data field to machine variant
	position: [2]f32,
	size:     [2]f32,
	color:    rl.Color,
	price:    int,
	selected: bool,
	// shape-shifter
	variant:  Machine_Variant,
}

// factory is the most outter data structure in the game
Factory :: struct {
	// holding states and stuff
	energy:                 int,
	since_energy_increase:  f32,
	sounds:                 [Sounds]rl.Sound,
	machines:               [dynamic]Machine,
	camera:                 rl.Camera2D,
	selected_machine_index: int,
	shop_open:              bool,
}


// populate and create data structure instance with filled data
init_factory :: proc() -> ^Factory {
	factory_ptr := new(Factory)

	// init sounds

	not_enough_energy_sound := rl.LoadSound("assets/not_enough_energy.wav")


	machines := make([dynamic]Machine, 1)

	factory_ptr^ = Factory {
		energy = 100,
		since_energy_increase = 0,
		sounds = {.NOT_ENOUGH_ENERGY = not_enough_energy_sound},
		machines = machines,
		camera = rl.Camera2D {
			target = {0, 0}, // target will be placed not at the center, but at the 0, 0 positions of the screen
			zoom   = 1.0, // to see
		},
		selected_machine_index = -1,
	}

	new_machine(factory_ptr, Creator{})

	return factory_ptr
}


new_machine :: proc(factory: ^Factory, machine_variant: Machine_Variant) {
	machine := Machine{}
	switch variant in machine_variant {
	case Processor:
		machine = Machine {
			position = {0, 0},
			size     = {20, 40},
			color    = rl.BLUE,
			price    = 40,
			selected = false,
			variant  = Processor{},
		}
	case Battery:
		machine = Machine {
			position = {0, 0},
			size     = {30, 30},
			color    = rl.ORANGE,
			price    = 20,
			selected = false,
			variant  = Battery{},
		}
	case Creator:
		machine = Machine {
			position = {0, 0},
			size     = {40, 60},
			color    = rl.BLACK,
			price    = 0,
			selected = false,
			variant  = Creator{},
		}
	}

	append(&factory.machines, machine)
}


draw_info_factory :: proc(factory: Factory) {
	buf: [4]byte

	energy_str := strings.clone_to_cstring(strconv.itoa(buf[:], factory.energy))
	rl.DrawText(energy_str, WIDTH - FONT_SIZE * 2, HEIGHT - FONT_SIZE, FONT_SIZE, rl.YELLOW)
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


// drag machine on different button?
// add the feature to losso multiple objects
drag_machine :: proc(factory: ^Factory) {
	if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
		cursor_position := get_position_in_space(factory^)
		for machine, i in factory.machines {

			can_drag := machine_in_range(cursor_position, machine)

			if can_drag {
				factory.selected_machine_index = i
				// for drawing and in the future many
				factory.machines[i].selected = true
				// to grab only one
				break
			} else {
				// clear focus
				factory.selected_machine_index = -1
				if factory.machines[i].selected {
					factory.machines[i].selected = false
				}
			}
		}
	}
	// todo: add restriction on release, if it is in range with others, then move it
	if factory.selected_machine_index >= 0 &&
	   rl.IsMouseButtonDown(rl.MouseButton.LEFT) &&
	   type_of(factory.machines[factory.selected_machine_index]) != Creator {
		cursor_position := get_position_in_space(factory^)
		factory.machines[factory.selected_machine_index].position = cursor_position
	}
}

// constants procedure, the second main character in CS world after data
open_shop :: proc(factory: ^Factory) {
	factory.shop_open = true
}

draw_shop :: proc(factory: Factory) {
	if factory.shop_open {
		rl.DrawRectangle(0, HEIGHT / 2, WIDTH, HEIGHT / 2, rl.DARKBLUE)
	}
}


// more generic name
update_game_state :: proc(factory: ^Factory) {
	if rl.IsKeyPressed(rl.KeyboardKey.E) {
		open_shop(factory)
	}
	if factory.shop_open && rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) {
		factory.shop_open = false
	}


	move_camera(factory)
	drag_machine(factory)


	if factory.since_energy_increase > rl.GetFrameTime() * 30 {
		factory.since_energy_increase = 0
		factory.energy += 1
	}
	factory.since_energy_increase += rl.GetFrameTime()

}

draw_game_frame :: proc(factory: Factory) {
	rl.BeginDrawing()


	rl.ClearBackground(rl.GRAY)

	rl.BeginMode2D(factory.camera)

	// draw data from factory structure
	draw_machines(factory)
	rl.EndMode2D()

	draw_shop(factory)
	draw_info_factory(factory)

	rl.EndDrawing()
}


main :: proc() {
	// init

	rl.InitWindow(WIDTH, HEIGHT, "north pole factory")
	defer rl.CloseWindow()

	// must be initialized before loading any audio
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	rl.SetTargetFPS(60)

	factory := init_factory()
	// todo free properly
	defer free(factory)

	rl.SetExitKey(rl.KeyboardKey.KEY_NULL)


	// game loop
	for !rl.WindowShouldClose() {

		update_game_state(factory)

		draw_game_frame(factory^)
	}


}
