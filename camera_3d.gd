extends Camera3D

@export var target_center: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var distance: float = 80.0
@export var rot_sensitivity: float = 0.005
@export var zoom_sensitivity: float = 5.0

var rot_x: float = -0.6 # Inclinación inicial (mira desde arriba)
var rot_y: float = 0.0  # Ángulo azimutal

func _unhandled_input(event: InputEvent) -> void:
	# Clic Derecho + Arrastrar: Orbitar
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rot_y -= event.relative.x * rot_sensitivity
		rot_x -= event.relative.y * rot_sensitivity
		rot_x = clamp(rot_x, -deg_to_rad(85.0), -deg_to_rad(5.0)) # Limitar ángulos verticalmente
	
	# Rueda del Mouse: Zoom In / Zoom Out
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = max(10.0, distance - zoom_sensitivity)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = min(250.0, distance + zoom_sensitivity)

func _process(_delta: float) -> void:
	# Cálculo de coordenadas esféricas a cartesianas 3D
	var pos = Vector3.ZERO
	pos.x = target_center.x + distance * cos(rot_x) * sin(rot_y)
	pos.y = target_center.y - distance * sin(rot_x)
	pos.z = target_center.z + distance * cos(rot_x) * cos(rot_y)
	
	global_position = pos
	look_at(target_center)
