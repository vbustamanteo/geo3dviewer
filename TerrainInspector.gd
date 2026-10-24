extends Node3D

@export var camera: Camera3D
@export var mesh_instance: MeshInstance3D
@export var ndvi_texture: Texture2D

@onready var label_coord: Label = $CanvasLayer/PanelContainer/MarginContainer/VBoxContainer/LabelCoord
@onready var label_height: Label = $CanvasLayer/PanelContainer/MarginContainer/VBoxContainer/LabelHeight
@onready var label_ndvi: Label = $CanvasLayer/PanelContainer/MarginContainer/VBoxContainer/LabelNDVI

var ndvi_image: Image
var plane_size: Vector2 = Vector2(100.0, 100.0) # Debe coincidir con el Size del PlaneMesh

func _ready() -> void:
	if ndvi_texture:
		ndvi_image = ndvi_texture.get_image()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_perform_raycast(event.position)

func _perform_raycast(mouse_pos: Vector2) -> void:
	if not camera or not mesh_instance:
		return

	# 1. Proyectar rayo desde la posición del cursor en pantalla hacia el mundo 3D
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_normal = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_normal * 1000.0

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)

	# 2. Verificar si el rayo impactó la malla del terreno
	if result:
		var hit_point_3d: Vector3 = result.position
		
		# Convertir punto 3D del mundo a espacio local de la malla PlaneMesh
		var local_point: Vector3 = mesh_instance.to_local(hit_point_3d)
		
		# 3. Mapear la posición local [-size/2, size/2] al rango UV [0.0, 1.0]
		var u: float = (local_point.x + plane_size.x / 2.0) / plane_size.x
		var v: float = (local_point.z + plane_size.y / 2.0) / plane_size.y
		
		u = clamp(u, 0.0, 1.0)
		v = clamp(v, 0.0, 1.0)

		# 4. Consultar el píxel exacto en la imagen de datos NDVI
		if ndvi_image:
			var img_w = ndvi_image.get_width()
			var img_h = ndvi_image.get_height()
			var px_x = int(clamp(u * (img_w - 1), 0, img_w - 1))
			var px_y = int(clamp(v * (img_h - 1), 0, img_h - 1))
			
			var pixel_color: Color = ndvi_image.get_pixel(px_x, px_y)
			
			# Reconstrucción del valor real NDVI (-1.0 a +1.0)
			# (C++ mapeó [-1.0, 1.0] -> [0, 255], por lo que canal R * 2.0 - 1.0 recupera el valor original)
			var raw_val = pixel_color.r
			var real_ndvi = (raw_val * 2.0) - 1.0
			
			# Clasificación cualitativa
			var status = ""
			if real_ndvi < 0.0:
				status = "Cuerpo de Agua / Sombra"
			elif real_ndvi < 0.2:
				status = "Suelo Expuesto / Roca"
			elif real_ndvi < 0.5:
				status = "Vegetación Escasa / Pastizal"
			else:
				status = "Vegetación Densa / Bosque"

			# 5. Actualizar la interfaz de usuario
			label_coord.text = "Coordenadas UV: (%.3f, %.3f)" % [u, v]
			label_height.text = "Elevación 3D: %.2f m" % hit_point_3d.y
			label_ndvi.text = "NDVI: %.3f (%s)" % [real_ndvi, status]
