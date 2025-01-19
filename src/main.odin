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
	Entry,
	Sled,
}

Collision_Masks :: enum {
	INTERACTABLE,
	ROOT,
}

Collision_White_List :: bit_set[Collision_Masks]

Processor :: struct {
	selected:            bool,
	connected:           bool,
	allowed_connections: Collision_White_List,
}

Battery :: struct {
	selected:            bool,
	connected:           bool,
	allowed_connections: Collision_White_List,
}

Creator :: struct {}

Entry :: struct {}

Sled :: struct {}


Machine :: struct {
	position:       [2]f32,
	size:           [2]f32,
	color:          rl.Color,
	price:          int,
	collision_mask: Collision_Masks,
	// shape-shifter
	variant:        Machine_Variant,
}


// shop state

Shop :: struct {
	machines:  [dynamic]Machine,
	shop_open: bool,
}

Factory :: struct {
	sounds:                [Sounds]rl.Sound,
	machines:              [dynamic]Machine,
	creator:               Machine,
	entry:                 Machine,
	sled:                  Machine,
	camera:                rl.Camera2D,
	window_size:           [2]i32,
	shop:                  Shop,
	energy:                int,
	since_energy_increase: f32,
}


// populate and create data structure instance with filled data
init_factory :: proc() -> ^Factory {
	factory_ptr := new(Factory)

	// init sounds

	not_enough_energy_sound := rl.LoadSound("assets/not_enough_energy.wav")


	machines := make([dynamic]Machine, 0)
	append(&machines, new_machine(Creator{}))

	machines_in_shop := make([dynamic]Machine, 0)
	append(&machines_in_shop, ..[]Machine{new_machine(Processor{}), new_machine(Battery{})}[:])

	factory_ptr^ = Factory {
		sounds = {.NOT_ENOUGH_ENERGY = not_enough_energy_sound},
		machines = machines,
		entry = new_machine(Entry{}),
		sled = new_machine(Sled{}),
		camera = rl.Camera2D {
			target = {0, 0}, // target will be placed not at the center, but at the 0, 0 positions of the screen
			zoom   = 1.0, // to see
		},
		shop = Shop{shop_open = false, machines = machines_in_shop},
		window_size = {640, 480},
		since_energy_increase = 0,
	}


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
			price = 4,
			collision_mask = .INTERACTABLE,
			variant = Processor{allowed_connections = {.INTERACTABLE}},
		}
	case Battery:
		return Machine {
			position = positon,
			size = {30, 30},
			color = rl.ORANGE,
			price = 2,
			collision_mask = .INTERACTABLE,
			variant = Processor{allowed_connections = {.INTERACTABLE}},
		}
	case Creator:
		return Machine {
			position = positon,
			size = {40, 60},
			color = rl.BLACK,
			price = 0,
			collision_mask = .ROOT,
			variant = variant,
		}
	case Entry:
		return Machine {
			position = positon,
			size = {40, 60},
			color = rl.WHITE,
			price = 0,
			collision_mask = .ROOT,
			variant = variant,
		}
	case Sled:
		return Machine {
			position = positon,
			size = {40, 60},
			color = rl.GREEN,
			price = 0,
			collision_mask = .ROOT,
			variant = variant,
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
		#partial switch v in machine.variant {
		case Processor:
			if v.connected {
				rl.DrawRectangleV(
					{machine.position.x - 2, machine.position.y - 2},
					{machine.size.x + 4, machine.size.y + 4},
					rl.GREEN,
				)
			} else if v.selected {
				rl.DrawRectangleV(
					{machine.position.x - 2, machine.position.y - 2},
					{machine.size.x + 4, machine.size.y + 4},
					rl.RED,
				)
			}
		case Battery:
			if v.connected {
				rl.DrawRectangleV(
					{machine.position.x - 2, machine.position.y - 2},
					{machine.size.x + 4, machine.size.y + 4},
					rl.GREEN,
				)
			} else if v.selected {
				rl.DrawRectangleV(
					{machine.position.x - 2, machine.position.y - 2},
					{machine.size.x + 4, machine.size.y + 4},
					rl.RED,
				)
			}
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

// todo: check on nested loops!!!
check_connection :: proc(factory: ^Factory, dragged_i: int) {
	dragged_top := factory.machines[dragged_i].position.y
	dragged_bottom := dragged_top + factory.machines[dragged_i].size.y
	dragged_left := factory.machines[dragged_i].position.x
	dragged_right := dragged_left + factory.machines[dragged_i].size.x

	for machine, i in factory.machines {
		connection_white_list: Collision_White_List
		#partial switch v in factory.machines[dragged_i].variant {
		case Processor:
			connection_white_list = v.allowed_connections
		case Battery:
			connection_white_list = v.allowed_connections

		}
		if i == dragged_i || machine.collision_mask not_in connection_white_list {
			continue
		}
		top := machine.position.y
		bottom := top + machine.size.y
		left := machine.position.x
		right := left + machine.size.x


		fmt.println(dragged_i)
		fmt.println(i)

		// dragged at the bottom of the static (with room/space to be inside)
		// note reverse y
		if (dragged_top <= bottom && dragged_top >= top) &&
		   (dragged_left <= right && dragged_right >= left) {
			fmt.println("bottom")
			#partial switch &v in factory.machines[dragged_i].variant {
			case Processor:
				v.connected = true
			case Battery:
				v.connected = true
			}

		}
		// dragged at the top of the static
		if dragged_bottom == top && dragged_left == left {
			fmt.println("top")
		}
		// dragged at the left of the static
		if dragged_top == bottom && dragged_right == left {
			fmt.println("left")
		}
		// dragged at the right of the static
		if dragged_top == bottom && dragged_left == right {
			fmt.println("right")
		}

	}
}

// todo: just general interaction with machine based on shape?
drag_machine :: proc(factory: ^Factory) {
	if !factory.shop.shop_open {
		if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
			cursor_position := get_position_in_space(factory^)
			for &machine, i in factory.machines {

				in_range := machine_in_range(cursor_position, machine)

				switch &v in machine.variant {
				case Processor:
					if in_range {
						v.selected = true
						break
					} else {
						v.selected = false
					}
				case Battery:
					if in_range {
						v.selected = true
						break
					} else {
						v.selected = false
					}
				case Creator, Entry, Sled:
					continue // for now, later other logic, see stats?
				}
			}
		}
		if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
			for &machine, i in factory.machines {
				// if this shape
				switch v in machine.variant {
				case Processor:
					if v.selected {
						cursor_position := get_position_in_space(factory^)
						machine.position = cursor_position
						fmt.println(factory.machines)
						fmt.println("index: ", i)
						check_connection(factory, i)
					}
				case Battery:
					if v.selected {
						cursor_position := get_position_in_space(factory^)
						machine.position = cursor_position
						check_connection(factory, i)
					}
				case Creator, Entry, Sled:
					continue
				}

			}
		}

	}

}

draw_shop :: proc(factory: ^Factory) {
	if factory.shop.shop_open {
		shop_x, shop_y: f32 = 0, f32(factory.window_size.y) / 2.0

		rl.DrawRectangleV(
			{shop_x, shop_y},
			{f32(factory.window_size.x), f32(factory.window_size.y) / 2},
			rl.DARKBLUE,
		)

		shift: f32 = 0.0
		for &machine in factory.shop.machines {
			machine.position = {shop_x + shift, shop_y * 1.5}
			rl.DrawRectangleV(machine.position, machine.size, machine.color)
			shift += machine.size.x * 2
		}
	}
}


buy_machine :: proc(factory: ^Factory, variant: Machine_Variant) {
	machine := new_machine(variant)
	if machine.price > factory.energy {
		rl.PlaySound(factory.sounds[.NOT_ENOUGH_ENERGY])
		return
	}
	factory.energy -= machine.price
	append(&factory.machines, machine)
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
					buy_machine(factory, machine.variant)
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
	// must be initialized before loading any audio
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	// init
	factory := init_factory()
	defer free(factory) // todo: refactor properly


	// bit set
	flags: rl.ConfigFlags = {rl.ConfigFlag.WINDOW_RESIZABLE}
	rl.SetConfigFlags(flags)

	rl.InitWindow(factory.window_size.x, factory.window_size.y, "north pole factory")
	defer rl.CloseWindow()


	rl.SetTargetFPS(60)

	rl.SetExitKey(rl.KeyboardKey.KEY_NULL)


	// game loop
	for !rl.WindowShouldClose() {

		update_game_state(factory)

		draw_game_frame(factory)
	}


}
